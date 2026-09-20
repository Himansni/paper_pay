import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';
import 'package:paper_route/features/reports/domain/report_models.dart';
import 'package:paper_route/features/reports/domain/reporting_repository.dart';

class FirebaseReportingRepository implements ReportingRepository {
  FirebaseReportingRepository(this._firestore);

  factory FirebaseReportingRepository.fromDefaultApp() =>
      FirebaseReportingRepository(FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _businessCollection(
    String businessId,
    String collection,
  ) => _firestore
      .collection('businesses')
      .doc(businessId)
      .collection(collection);

  @override
  Future<OperationalDashboard> fetchDashboard({
    required AppUser actor,
    required DateTime now,
  }) async {
    final businessId = _businessId(actor);
    final month = ReportingPeriod.month(now);
    final today = ReportingPeriod.day(now);
    final monthKey = _monthKey(now);
    try {
      return actor.isHead
          ? await _headDashboard(
            actor: actor,
            businessId: businessId,
            month: month,
            today: today,
            monthKey: monthKey,
          )
          : await _employeeDashboard(
            actor: actor,
            businessId: businessId,
            month: month,
            today: today,
            monthKey: monthKey,
          );
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not load dashboard metrics.');
    }
  }

  Future<OperationalDashboard> _headDashboard({
    required AppUser actor,
    required String businessId,
    required ReportingPeriod month,
    required ReportingPeriod today,
    required String monthKey,
  }) async {
    final customers = _businessCollection(
      businessId,
      'customers',
    ).where('businessId', isEqualTo: businessId);
    final members = _businessCollection(
      businessId,
      'members',
    ).where('businessId', isEqualTo: businessId);
    final areas = _businessCollection(
      businessId,
      'areas',
    ).where('businessId', isEqualTo: businessId);
    final newspapers = _businessCollection(
      businessId,
      'newspapers',
    ).where('businessId', isEqualTo: businessId);
    final bills = _firestore
        .collectionGroup('bills')
        .where('businessId', isEqualTo: businessId)
        .where('billingMonth', isEqualTo: monthKey)
        .where('status', isEqualTo: 'finalized');
    final monthPayments = _paymentQuery(businessId, month);
    final todayPayments = _paymentQuery(businessId, today);
    final monthReversals = _reversalQuery(businessId, month);
    final balances = _firestore
        .collectionGroup('collectionState')
        .where('businessId', isEqualTo: businessId)
        .where('stateId', isEqualTo: 'current');

    final values = await Future.wait<Object>([
      _count(customers.where('status', isEqualTo: 'active')),
      _count(customers.where('status', isEqualTo: 'archived')),
      _count(
        members
            .where('role', isEqualTo: 'employee')
            .where('status', isEqualTo: 'active'),
      ),
      _count(areas.where('status', isEqualTo: 'active')),
      _count(newspapers.where('status', isEqualTo: 'active')),
      _sum(bills, 'currentChargesPaise'),
      _sum(monthPayments, 'amountPaise'),
      _sum(balances, 'outstandingPaise'),
      _sum(todayPayments, 'amountPaise'),
      _count(monthPayments),
      _count(monthReversals),
      _sum(monthReversals, 'amountPaise'),
      _count(balances.where('reportingStatus', isEqualTo: 'unpaid')),
      _count(balances.where('reportingStatus', isEqualTo: 'partiallyPaid')),
      _count(balances.where('reportingStatus', isEqualTo: 'fullyPaid')),
      _count(bills.where('customerStatus', isEqualTo: 'active')),
    ]);

    final activeCustomers = values[0] as int;
    final recentPaymentsFuture = _recentPayments(
      actor: actor,
      businessId: businessId,
    );
    final recentBillingFuture = _recentBilling(businessId);
    final recentCustomersFuture = _recentCustomers(businessId);
    final employeeSummaryFuture = _employeeCollections(
      businessId: businessId,
      period: month,
    );
    final areaSummaryFuture = _areaOutstanding(businessId);

    return OperationalDashboard(
      monthKey: monthKey,
      activeCustomers: activeCustomers,
      archivedCustomers: values[1] as int,
      activeEmployees: values[2] as int,
      activeAreas: values[3] as int,
      activeNewspapers: values[4] as int,
      currentMonthBilledPaise: values[5] as int,
      currentMonthCollectionsPaise: values[6] as int,
      currentOutstandingPaise: values[7] as int,
      todayCollectionsPaise: values[8] as int,
      currentMonthPayments: values[9] as int,
      currentMonthReversals: values[10] as int,
      currentMonthReversedPaise: values[11] as int,
      unpaidCustomers: values[12] as int,
      partiallyPaidCustomers: values[13] as int,
      fullyPaidCustomers: values[14] as int,
      customersWithoutFinalizedBill: (activeCustomers - (values[15] as int))
          .clamp(0, activeCustomers),
      recentPayments: await recentPaymentsFuture,
      recentBilling: await recentBillingFuture,
      recentCustomers: await recentCustomersFuture,
      employeeCollections: await employeeSummaryFuture,
      areaOutstanding: await areaSummaryFuture,
      routeSummaries: const [],
    );
  }

  Future<OperationalDashboard> _employeeDashboard({
    required AppUser actor,
    required String businessId,
    required ReportingPeriod month,
    required ReportingPeriod today,
    required String monthKey,
  }) async {
    final customers = _businessCollection(businessId, 'customers')
        .where('businessId', isEqualTo: businessId)
        .where('assignedEmployeeId', isEqualTo: actor.uid);
    final monthPayments = _paymentQuery(
      businessId,
      month,
      employeeId: actor.uid,
    );
    final todayPayments = _paymentQuery(
      businessId,
      today,
      employeeId: actor.uid,
    );
    final values = await Future.wait<Object>([
      _count(customers.where('status', isEqualTo: 'active')),
      _count(customers.where('status', isEqualTo: 'archived')),
      _count(
        _businessCollection(
          businessId,
          'newspapers',
        ).where('status', isEqualTo: 'active'),
      ),
      _sum(monthPayments, 'amountPaise'),
      _sum(todayPayments, 'amountPaise'),
      _count(monthPayments),
      _employeeBalanceValues(actor, businessId),
    ]);
    final balanceValues = values[6] as List<int>;
    return OperationalDashboard(
      monthKey: monthKey,
      activeCustomers: values[0] as int,
      archivedCustomers: values[1] as int,
      activeEmployees: 0,
      activeAreas: actor.areaIds.length,
      activeNewspapers: values[2] as int,
      currentMonthBilledPaise: 0,
      currentMonthCollectionsPaise: values[3] as int,
      currentOutstandingPaise: balanceValues[0],
      todayCollectionsPaise: values[4] as int,
      currentMonthPayments: values[5] as int,
      currentMonthReversals: 0,
      currentMonthReversedPaise: 0,
      unpaidCustomers: balanceValues[1],
      partiallyPaidCustomers: balanceValues[2],
      fullyPaidCustomers: balanceValues[3],
      customersWithoutFinalizedBill: 0,
      recentPayments: await _recentPayments(
        actor: actor,
        businessId: businessId,
      ),
      recentBilling: const [],
      recentCustomers: const [],
      employeeCollections: const [],
      areaOutstanding: const [],
      routeSummaries: await _employeeRoutes(actor, businessId),
    );
  }

  Future<List<int>> _employeeBalanceValues(
    AppUser actor,
    String businessId,
  ) async {
    if (actor.areaIds.isEmpty) return const [0, 0, 0, 0];
    final areaIds = actor.areaIds.toList()..sort();
    final chunks = <List<String>>[];
    for (var offset = 0; offset < areaIds.length; offset += 30) {
      final end = offset + 30 < areaIds.length ? offset + 30 : areaIds.length;
      chunks.add(areaIds.sublist(offset, end));
    }
    final chunkValues = await Future.wait([
      for (final chunk in chunks)
        _employeeBalanceValuesForAreas(actor, businessId, chunk),
    ]);
    return [
      for (var index = 0; index < 4; index++)
        chunkValues.fold(0, (total, values) => total + values[index]),
    ];
  }

  Future<List<int>> _employeeBalanceValuesForAreas(
    AppUser actor,
    String businessId,
    List<String> areaIds,
  ) async {
    final balances = _firestore
        .collectionGroup('collectionState')
        .where('businessId', isEqualTo: businessId)
        .where('stateId', isEqualTo: 'current')
        .where('assignedEmployeeId', isEqualTo: actor.uid)
        .where('customerStatus', isEqualTo: 'active')
        .where('areaId', whereIn: areaIds);
    return Future.wait([
      _sum(balances, 'outstandingPaise'),
      _count(balances.where('reportingStatus', isEqualTo: 'unpaid')),
      _count(balances.where('reportingStatus', isEqualTo: 'partiallyPaid')),
      _count(balances.where('reportingStatus', isEqualTo: 'fullyPaid')),
    ]);
  }

  @override
  Future<ReportPage> fetchReport({
    required AppUser actor,
    required ReportFilter filter,
    ReportCursor? cursor,
    int pageSize = 25,
  }) async {
    if (!actor.isHead) {
      throw const AppException('Reports are available only to the Head.');
    }
    _businessId(actor);
    final effectiveFilter = filter.canonicalized();
    effectiveFilter.period.validate();
    if (pageSize < 1 || pageSize > 100) {
      throw const AppException('Report page size must be between 1 and 100.');
    }
    try {
      return switch (effectiveFilter.kind) {
        ReportKind.collections => _collectionReport(
          actor,
          effectiveFilter,
          cursor,
          pageSize,
        ),
        ReportKind.billing => _billingReport(
          actor,
          effectiveFilter,
          cursor,
          pageSize,
        ),
        ReportKind.outstanding => _outstandingReport(
          actor,
          effectiveFilter,
          cursor,
          pageSize,
        ),
        ReportKind.customers => _customerReport(
          actor,
          effectiveFilter,
          cursor,
          pageSize,
        ),
        ReportKind.subscriptions => _subscriptionReport(
          actor,
          effectiveFilter,
          cursor,
          pageSize,
        ),
      };
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not load this report.');
    }
  }

  @override
  Future<List<ReportRow>> fetchExportRows({
    required AppUser actor,
    required ReportFilter filter,
    int maximumRows = 5000,
  }) async {
    if (maximumRows < 1 || maximumRows > 5000) {
      throw const AppException('CSV exports are limited to 5,000 rows.');
    }
    final rows = <ReportRow>[];
    ReportCursor? cursor;
    var hasMore = true;
    while (hasMore && rows.length < maximumRows) {
      final page = await fetchReport(
        actor: actor,
        filter: filter,
        cursor: cursor,
        pageSize: 100,
      );
      rows.addAll(page.rows.take(maximumRows - rows.length));
      cursor = page.nextCursor;
      hasMore = page.hasMore;
      if (page.rows.isEmpty) break;
    }
    if (hasMore) {
      throw const AppException(
        'This export exceeds 5,000 rows. Narrow the filters and try again.',
      );
    }
    return List.unmodifiable(rows);
  }

  Future<ReportPage> _collectionReport(
    AppUser actor,
    ReportFilter filter,
    ReportCursor? cursor,
    int pageSize,
  ) async {
    final businessId = actor.businessId!;
    var query = _paymentQuery(
      businessId,
      filter.period,
      employeeId: filter.employeeId,
      areaId: filter.areaId,
      customerId: filter.customerId,
      method: filter.paymentMethod,
    );
    query = query
        .orderBy('confirmedAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (cursor != null && cursor.sortValue is DateTime) {
      query = query.startAfter([
        Timestamp.fromDate(cursor.sortValue as DateTime),
        cursor.documentPath,
      ]);
    }
    final snapshot = await query.limit(pageSize + 1).get();
    final visible = snapshot.docs.take(pageSize).toList();
    final summaryQuery = _paymentQuery(
      businessId,
      filter.period,
      employeeId: filter.employeeId,
      areaId: filter.areaId,
      customerId: filter.customerId,
      method: filter.paymentMethod,
    );
    final reversals = _reversalQuery(
      businessId,
      filter.period,
      customerId: filter.customerId,
      employeeId: filter.employeeId,
      areaId: filter.areaId,
      method: filter.paymentMethod,
    );
    final totals = await Future.wait<Object>([
      _count(summaryQuery),
      _sum(summaryQuery, 'amountPaise'),
      _count(reversals),
      _sum(reversals, 'amountPaise'),
    ]);
    final breakdown = <String, int>{};
    for (final method in PaymentMethod.values) {
      breakdown['Method ₹ · ${method.label}'] = await _sum(
        _paymentQuery(
          businessId,
          filter.period,
          employeeId: filter.employeeId,
          areaId: filter.areaId,
          customerId: filter.customerId,
          method: method,
        ),
        'amountPaise',
      );
    }
    final noEntityScope =
        filter.employeeId.isEmpty &&
        filter.areaId.isEmpty &&
        filter.customerId.isEmpty;
    if (noEntityScope) {
      final members =
          await _businessCollection(businessId, 'members')
              .where('role', isEqualTo: 'employee')
              .where('status', isEqualTo: 'active')
              .orderBy('displayName')
              .limit(20)
              .get();
      final employeeTotals = await Future.wait([
        for (final member in members.docs)
          _netCollectionForScope(
            businessId: businessId,
            period: filter.period,
            employeeId: member.id,
            method: filter.paymentMethod,
          ),
      ]);
      for (var index = 0; index < members.docs.length; index++) {
        final member = members.docs[index];
        final label = member.data()['displayName'] as String? ?? member.id;
        breakdown['Employee net ₹ · $label'] = employeeTotals[index];
      }

      final areas =
          await _businessCollection(businessId, 'areas')
              .where('status', isEqualTo: 'active')
              .orderBy('name')
              .limit(20)
              .get();
      final areaTotals = await Future.wait([
        for (final area in areas.docs)
          _netCollectionForScope(
            businessId: businessId,
            period: filter.period,
            areaId: area.id,
            method: filter.paymentMethod,
          ),
      ]);
      for (var index = 0; index < areas.docs.length; index++) {
        final area = areas.docs[index];
        final label = area.data()['name'] as String? ?? area.id;
        breakdown['Area net ₹ · $label'] = areaTotals[index];
      }
    }
    return ReportPage(
      rows: [
        for (final document in visible)
          _paymentRow(document.id, document.data()),
      ],
      summary: ReportSummary(
        totalCount: totals[0] as int,
        totalPaise: totals[1] as int,
        secondaryCount: totals[2] as int,
        secondaryPaise: totals[3] as int,
        breakdown: breakdown,
      ),
      nextCursor: _dateCursor(visible, 'confirmedAt'),
      hasMore: snapshot.docs.length > pageSize,
    );
  }

  Future<ReportPage> _billingReport(
    AppUser actor,
    ReportFilter filter,
    ReportCursor? cursor,
    int pageSize,
  ) async {
    final businessId = actor.businessId!;
    var base = _firestore
        .collectionGroup('bills')
        .where('businessId', isEqualTo: businessId)
        .where('billingMonth', isEqualTo: filter.billingMonth);
    if (filter.billStatus.isNotEmpty) {
      base = base.where('status', isEqualTo: filter.billStatus);
    }
    if (filter.customerId.isNotEmpty) {
      base = base.where('customerId', isEqualTo: filter.customerId);
    }
    if (filter.areaId.isNotEmpty) {
      base = base.where('areaId', isEqualTo: filter.areaId);
    }
    if (filter.employeeId.isNotEmpty) {
      base = base.where('assignedEmployeeId', isEqualTo: filter.employeeId);
    }
    var query = base
        .orderBy('customerSearchName')
        .orderBy(FieldPath.documentId);
    if (cursor != null && cursor.sortValue is String) {
      query = query.startAfter([cursor.sortValue, cursor.documentPath]);
    }
    final snapshot = await query.limit(pageSize + 1).get();
    final visible = snapshot.docs.take(pageSize).toList();
    final summary =
        await base
            .aggregate(
              count(),
              sum('currentChargesPaise'),
              sum('totalDuePaise'),
            )
            .get();
    final activeCustomers = await _count(
      _businessCollection(businessId, 'customers')
          .where('businessId', isEqualTo: businessId)
          .where('status', isEqualTo: 'active'),
    );
    final billedCustomers = await _count(
      _firestore
          .collectionGroup('bills')
          .where('businessId', isEqualTo: businessId)
          .where('billingMonth', isEqualTo: filter.billingMonth)
          .where('status', isEqualTo: 'finalized')
          .where('customerStatus', isEqualTo: 'active'),
    );
    final previousMonth = _previousMonth(filter.billingMonth);
    final previousBilled = await _sum(
      _firestore
          .collectionGroup('bills')
          .where('businessId', isEqualTo: businessId)
          .where('billingMonth', isEqualTo: previousMonth)
          .where('status', isEqualTo: 'finalized'),
      'currentChargesPaise',
    );
    return ReportPage(
      rows: [
        for (final document in visible)
          _billingRow(document.id, document.data()),
      ],
      summary: ReportSummary(
        totalCount: summary.count ?? 0,
        totalPaise: _aggregateInt(summary.getSum('currentChargesPaise')),
        secondaryPaise: _aggregateInt(summary.getSum('totalDuePaise')),
        secondaryCount: (activeCustomers - billedCustomers).clamp(
          0,
          activeCustomers,
        ),
        breakdown: {
          'Month ₹ · $previousMonth': previousBilled,
          'Month ₹ · ${filter.billingMonth}': _aggregateInt(
            summary.getSum('currentChargesPaise'),
          ),
        },
      ),
      nextCursor: _stringCursor(visible, 'customerSearchName'),
      hasMore: snapshot.docs.length > pageSize,
    );
  }

  Future<ReportPage> _outstandingReport(
    AppUser actor,
    ReportFilter filter,
    ReportCursor? cursor,
    int pageSize,
  ) async {
    final businessId = actor.businessId!;
    var base = _firestore
        .collectionGroup('collectionState')
        .where('businessId', isEqualTo: businessId)
        .where('stateId', isEqualTo: 'current');
    if (filter.customerStatus.isNotEmpty) {
      base = base.where('customerStatus', isEqualTo: filter.customerStatus);
    }
    if (filter.employeeId.isNotEmpty) {
      base = base.where('assignedEmployeeId', isEqualTo: filter.employeeId);
    }
    if (filter.areaId.isNotEmpty) {
      base = base.where('areaId', isEqualTo: filter.areaId);
    }
    if (filter.customerId.isNotEmpty) {
      base = base.where('customerId', isEqualTo: filter.customerId);
    }
    if (filter.outstandingStatus != null) {
      base = base.where(
        'reportingStatus',
        isEqualTo: filter.outstandingStatus!.value,
      );
    }
    var query = base
        .orderBy('outstandingPaise', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (cursor != null && cursor.sortValue is int) {
      query = query.startAfter([cursor.sortValue, cursor.documentPath]);
    }
    final snapshot = await query.limit(pageSize + 1).get();
    final visible = snapshot.docs.take(pageSize).toList();
    final totals = await Future.wait<Object>([
      _count(base),
      _sum(base, 'outstandingPaise'),
    ]);
    final breakdown = <String, int>{};
    for (final status in OutstandingStatus.values) {
      breakdown[status.label] = await _count(
        _firestore
            .collectionGroup('collectionState')
            .where('businessId', isEqualTo: businessId)
            .where('stateId', isEqualTo: 'current')
            .where('reportingStatus', isEqualTo: status.value),
      );
    }
    final previousMonth = _previousMonth(filter.billingMonth);
    breakdown['Aging · Current month'] = await _count(
      _firestore
          .collectionGroup('collectionState')
          .where('businessId', isEqualTo: businessId)
          .where('stateId', isEqualTo: 'current')
          .where('oldestOutstandingMonth', isEqualTo: filter.billingMonth),
    );
    breakdown['Aging · 1 month old'] = await _count(
      _firestore
          .collectionGroup('collectionState')
          .where('businessId', isEqualTo: businessId)
          .where('stateId', isEqualTo: 'current')
          .where('oldestOutstandingMonth', isEqualTo: previousMonth),
    );
    breakdown['Aging · 2+ months old'] = await _count(
      _firestore
          .collectionGroup('collectionState')
          .where('businessId', isEqualTo: businessId)
          .where('stateId', isEqualTo: 'current')
          .where('oldestOutstandingMonth', isLessThan: previousMonth)
          .where('reportingStatus', whereIn: const ['unpaid', 'partiallyPaid']),
    );
    return ReportPage(
      rows: [
        for (final document in visible)
          _outstandingRow(document.id, document.data(), filter.billingMonth),
      ],
      summary: ReportSummary(
        totalCount: totals[0] as int,
        totalPaise: totals[1] as int,
        secondaryPaise: 0,
        secondaryCount: 0,
        breakdown: breakdown,
      ),
      nextCursor: _intCursor(visible, 'outstandingPaise'),
      hasMore: snapshot.docs.length > pageSize,
    );
  }

  Future<ReportPage> _customerReport(
    AppUser actor,
    ReportFilter filter,
    ReportCursor? cursor,
    int pageSize,
  ) async {
    final businessId = actor.businessId!;
    var base = _businessCollection(
      businessId,
      'customers',
    ).where('businessId', isEqualTo: businessId);
    if (filter.customerStatus.isNotEmpty) {
      base = base.where('status', isEqualTo: filter.customerStatus);
    }
    if (filter.areaId.isNotEmpty) {
      base = base.where('areaId', isEqualTo: filter.areaId);
    }
    if (filter.employeeId.isNotEmpty) {
      base = base.where('assignedEmployeeId', isEqualTo: filter.employeeId);
    }
    if (filter.customerId.isNotEmpty) {
      base = base.where('customerCode', isEqualTo: filter.customerId);
    }
    var query = base.orderBy('searchName').orderBy(FieldPath.documentId);
    if (cursor != null && cursor.sortValue is String) {
      query = query.startAfter([cursor.sortValue, cursor.documentPath]);
    }
    final snapshot = await query.limit(pageSize + 1).get();
    final visible = snapshot.docs.take(pageSize).toList();
    final newCustomers = base
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(filter.period.start),
        )
        .where(
          'createdAt',
          isLessThan: Timestamp.fromDate(filter.period.endExclusive),
        );
    final totals = await Future.wait<int>([_count(base), _count(newCustomers)]);
    final breakdown = <String, int>{};
    if (filter.areaId.isEmpty) {
      final areas =
          await _businessCollection(businessId, 'areas')
              .where('status', isEqualTo: 'active')
              .orderBy('name')
              .limit(20)
              .get();
      for (final area in areas.docs) {
        breakdown['Area · ${area.data()['name'] ?? area.id}'] = await _count(
          base.where('areaId', isEqualTo: area.id),
        );
      }
    }
    if (filter.employeeId.isEmpty) {
      final members =
          await _businessCollection(businessId, 'members')
              .where('role', isEqualTo: 'employee')
              .where('status', isEqualTo: 'active')
              .orderBy('displayName')
              .limit(20)
              .get();
      for (final member in members.docs) {
        breakdown['Employee · ${member.data()['displayName'] ?? member.id}'] =
            await _count(
              base.where('assignedEmployeeId', isEqualTo: member.id),
            );
      }
    }
    return ReportPage(
      rows: [
        for (final document in visible)
          _customerRow(document.id, document.data()),
      ],
      summary: ReportSummary(
        totalCount: totals[0],
        totalPaise: 0,
        secondaryPaise: 0,
        secondaryCount: totals[1],
        breakdown: breakdown,
      ),
      nextCursor: _stringCursor(visible, 'searchName', fullPath: false),
      hasMore: snapshot.docs.length > pageSize,
    );
  }

  Future<ReportPage> _subscriptionReport(
    AppUser actor,
    ReportFilter filter,
    ReportCursor? cursor,
    int pageSize,
  ) async {
    final businessId = actor.businessId!;
    var base = _firestore
        .collectionGroup('subscriptions')
        .where('businessId', isEqualTo: businessId);
    if (filter.subscriptionStatus.isNotEmpty) {
      base = base.where('status', isEqualTo: filter.subscriptionStatus);
    }
    if (filter.customerId.isNotEmpty) {
      base = base.where('customerId', isEqualTo: filter.customerId);
    }
    if (filter.newspaperId.isNotEmpty) {
      base = base.where('newspaperId', isEqualTo: filter.newspaperId);
    }
    var query = base
        .orderBy('updatedAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (cursor != null && cursor.sortValue is DateTime) {
      query = query.startAfter([
        Timestamp.fromDate(cursor.sortValue as DateTime),
        cursor.documentPath,
      ]);
    }
    final snapshot = await query.limit(pageSize + 1).get();
    final visible = snapshot.docs.take(pageSize).toList();
    final breakdown = <String, int>{};
    for (final status in const ['active', 'paused', 'ended']) {
      breakdown[status] = await _count(
        _firestore
            .collectionGroup('subscriptions')
            .where('businessId', isEqualTo: businessId)
            .where('status', isEqualTo: status),
      );
    }
    final papers =
        await _businessCollection(businessId, 'newspapers')
            .where('status', isEqualTo: 'active')
            .orderBy('searchName')
            .limit(20)
            .get();
    for (final paper in papers.docs) {
      final name = paper.data()['name'] as String? ?? paper.id;
      breakdown['Subscribers · $name'] = await _count(
        _firestore
            .collectionGroup('subscriptions')
            .where('businessId', isEqualTo: businessId)
            .where('newspaperId', isEqualTo: paper.id)
            .where('status', whereIn: const ['active', 'paused']),
      );
      breakdown['Billing · $name'] = await _sum(
        _firestore
            .collectionGroup('lineItems')
            .where('businessId', isEqualTo: businessId)
            .where('billingMonth', isEqualTo: filter.billingMonth)
            .where('newspaperId', isEqualTo: paper.id),
        'totalPaise',
      );
    }
    return ReportPage(
      rows: [
        for (final document in visible)
          _subscriptionRow(document.id, document.data()),
      ],
      summary: ReportSummary(
        totalCount: await _count(base),
        totalPaise: 0,
        secondaryPaise: 0,
        secondaryCount: 0,
        breakdown: breakdown,
      ),
      nextCursor: _dateCursor(visible, 'updatedAt'),
      hasMore: snapshot.docs.length > pageSize,
    );
  }

  Query<Map<String, dynamic>> _paymentQuery(
    String businessId,
    ReportingPeriod period, {
    String employeeId = '',
    String areaId = '',
    String customerId = '',
    PaymentMethod? method,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collectionGroup('payments')
        .where('businessId', isEqualTo: businessId)
        .where(
          'confirmedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(period.start),
        )
        .where(
          'confirmedAt',
          isLessThan: Timestamp.fromDate(period.endExclusive),
        );
    if (employeeId.isNotEmpty) {
      query = query.where('collectorUid', isEqualTo: employeeId);
    }
    if (areaId.isNotEmpty) {
      query = query.where('areaId', isEqualTo: areaId);
    }
    if (customerId.isNotEmpty) {
      query = query.where('customerId', isEqualTo: customerId);
    }
    if (method != null) {
      query = query.where('method', isEqualTo: method.value);
    }
    return query;
  }

  Query<Map<String, dynamic>> _reversalQuery(
    String businessId,
    ReportingPeriod period, {
    String customerId = '',
    String employeeId = '',
    String areaId = '',
    PaymentMethod? method,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collectionGroup('paymentReversals')
        .where('businessId', isEqualTo: businessId)
        .where(
          'reversedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(period.start),
        )
        .where(
          'reversedAt',
          isLessThan: Timestamp.fromDate(period.endExclusive),
        );
    if (customerId.isNotEmpty) {
      query = query.where('customerId', isEqualTo: customerId);
    }
    if (employeeId.isNotEmpty) {
      query = query.where('collectorUid', isEqualTo: employeeId);
    }
    if (areaId.isNotEmpty) {
      query = query.where('areaId', isEqualTo: areaId);
    }
    if (method != null) {
      query = query.where('method', isEqualTo: method.value);
    }
    return query;
  }

  Future<List<DashboardActivity>> _recentPayments({
    required AppUser actor,
    required String businessId,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collectionGroup('payments')
        .where('businessId', isEqualTo: businessId);
    if (!actor.isHead) {
      query = query.where('collectorUid', isEqualTo: actor.uid);
    }
    final snapshot =
        await query.orderBy('confirmedAt', descending: true).limit(5).get();
    return [
      for (final document in snapshot.docs)
        DashboardActivity(
          id: document.id,
          title: document.data()['customerName'] as String? ?? 'Customer',
          subtitle:
              '${document.data()['method'] ?? 'payment'} · ${document.data()['customerCode'] ?? ''}',
          occurredAt: _date(document.data()['confirmedAt']),
          amountPaise: document.data()['amountPaise'] as int? ?? 0,
          route: '/collections/${document.data()['customerId']}/${document.id}',
        ),
    ];
  }

  Future<List<DashboardActivity>> _recentBilling(String businessId) async {
    final snapshot =
        await _firestore
            .collectionGroup('bills')
            .where('businessId', isEqualTo: businessId)
            .orderBy('finalizedAt', descending: true)
            .limit(5)
            .get();
    return [
      for (final document in snapshot.docs)
        DashboardActivity(
          id: document.id,
          title: document.data()['customerName'] as String? ?? 'Customer',
          subtitle: 'Finalized ${document.data()['billingMonth'] ?? ''}',
          occurredAt: _date(document.data()['finalizedAt']),
          amountPaise: document.data()['currentChargesPaise'] as int? ?? 0,
          route:
              '/billing/${document.data()['customerId']}/${document.data()['billingMonth']}',
        ),
    ];
  }

  Future<List<DashboardActivity>> _recentCustomers(String businessId) async {
    final snapshot =
        await _businessCollection(businessId, 'auditRecords')
            .where('entityType', isEqualTo: 'customer')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();
    return [
      for (final document in snapshot.docs)
        DashboardActivity(
          id: document.id,
          title: _activityLabel(document.data()['action']),
          subtitle: document.data()['entityId'] as String? ?? '',
          occurredAt: _date(document.data()['createdAt']),
          route: '/customers/${document.data()['entityId']}',
        ),
    ];
  }

  Future<List<NamedMetric>> _employeeCollections({
    required String businessId,
    required ReportingPeriod period,
  }) async {
    final members =
        await _businessCollection(businessId, 'members')
            .where('role', isEqualTo: 'employee')
            .where('status', isEqualTo: 'active')
            .orderBy('displayName')
            .limit(20)
            .get();
    return Future.wait([
      for (final member in members.docs)
        _namedPaymentMetric(
          businessId: businessId,
          period: period,
          id: member.id,
          label: member.data()['displayName'] as String? ?? member.id,
        ),
    ]);
  }

  Future<NamedMetric> _namedPaymentMetric({
    required String businessId,
    required ReportingPeriod period,
    required String id,
    required String label,
  }) async {
    final query = _paymentQuery(businessId, period, employeeId: id);
    final aggregate = await query.aggregate(count(), sum('amountPaise')).get();
    return NamedMetric(
      id: id,
      label: label,
      amountPaise: _aggregateInt(aggregate.getSum('amountPaise')),
      count: aggregate.count ?? 0,
    );
  }

  Future<int> _netCollectionForScope({
    required String businessId,
    required ReportingPeriod period,
    String employeeId = '',
    String areaId = '',
    PaymentMethod? method,
  }) async {
    final values = await Future.wait([
      _sum(
        _paymentQuery(
          businessId,
          period,
          employeeId: employeeId,
          areaId: areaId,
          method: method,
        ),
        'amountPaise',
      ),
      _sum(
        _reversalQuery(
          businessId,
          period,
          employeeId: employeeId,
          areaId: areaId,
          method: method,
        ),
        'amountPaise',
      ),
    ]);
    return values[0] - values[1];
  }

  Future<List<NamedMetric>> _areaOutstanding(String businessId) async {
    final areas =
        await _businessCollection(
          businessId,
          'areas',
        ).where('status', isEqualTo: 'active').orderBy('name').limit(20).get();
    return Future.wait([
      for (final area in areas.docs)
        _areaMetric(
          businessId: businessId,
          areaId: area.id,
          label: area.data()['name'] as String? ?? area.id,
        ),
    ]);
  }

  Future<NamedMetric> _areaMetric({
    required String businessId,
    required String areaId,
    required String label,
    String employeeId = '',
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collectionGroup('collectionState')
        .where('businessId', isEqualTo: businessId)
        .where('stateId', isEqualTo: 'current')
        .where('areaId', isEqualTo: areaId);
    if (employeeId.isNotEmpty) {
      query = query
          .where('assignedEmployeeId', isEqualTo: employeeId)
          .where('customerStatus', isEqualTo: 'active');
    }
    final aggregate =
        await query.aggregate(count(), sum('outstandingPaise')).get();
    return NamedMetric(
      id: areaId,
      label: label,
      amountPaise: _aggregateInt(aggregate.getSum('outstandingPaise')),
      count: aggregate.count ?? 0,
    );
  }

  Future<List<NamedMetric>> _employeeRoutes(
    AppUser actor,
    String businessId,
  ) async {
    if (actor.areaIds.isEmpty) return const [];
    final areas = await Future.wait([
      for (final areaId in actor.areaIds)
        _businessCollection(businessId, 'areas').doc(areaId).get(),
    ]);
    return Future.wait([
      for (final area in areas)
        if (area.exists)
          _areaMetric(
            businessId: businessId,
            areaId: area.id,
            label: area.data()?['name'] as String? ?? area.id,
            employeeId: actor.uid,
          ),
    ]);
  }

  Future<int> _count(Query<Map<String, dynamic>> query) async =>
      (await query.count().get()).count ?? 0;

  Future<int> _sum(Query<Map<String, dynamic>> query, String field) async =>
      _aggregateInt((await query.aggregate(sum(field)).get()).getSum(field));

  int _aggregateInt(double? value) => value?.round() ?? 0;

  ReportRow _paymentRow(String id, Map<String, dynamic> data) => ReportRow(
    id: id,
    title: data['customerName'] as String? ?? 'Customer',
    subtitle: data['customerCode'] as String? ?? '',
    status: data['status'] as String? ?? 'confirmed',
    amountPaise: data['amountPaise'] as int? ?? 0,
    occurredAt: _date(data['confirmedAt']),
    route: '/collections/${data['customerId']}/$id',
    fields: {
      'Method': data['method'] as String? ?? '',
      'Collector': data['collectorUid'] as String? ?? '',
      'Area': data['areaId'] as String? ?? '',
      'Reference': data['externalReference'] as String? ?? '',
    },
  );

  ReportRow _billingRow(String id, Map<String, dynamic> data) => ReportRow(
    id: id,
    title: data['customerName'] as String? ?? 'Customer',
    subtitle: data['customerCode'] as String? ?? '',
    status: data['status'] as String? ?? 'finalized',
    amountPaise: data['currentChargesPaise'] as int? ?? 0,
    occurredAt: _date(data['finalizedAt']),
    route: '/billing/${data['customerId']}/${data['billingMonth']}',
    fields: {
      'Billing month': data['billingMonth'] as String? ?? '',
      'Total due': '${data['totalDuePaise'] ?? 0}',
      'Area': data['areaId'] as String? ?? '',
      'Employee': data['assignedEmployeeId'] as String? ?? '',
    },
  );

  ReportRow _outstandingRow(
    String id,
    Map<String, dynamic> data,
    String selectedMonth,
  ) {
    final outstanding = data['outstandingPaise'] as int? ?? 0;
    final oldest = data['oldestOutstandingMonth'] as String? ?? '';
    return ReportRow(
      id: data['customerId'] as String? ?? id,
      title: data['customerName'] as String? ?? 'Customer',
      subtitle: data['customerCode'] as String? ?? '',
      status:
          data['reportingStatus'] as String? ??
          ReportMath.outstandingStatus(
            outstandingPaise: outstanding,
            confirmedPaise: data['confirmedPaise'] as int? ?? 0,
            reversedPaise: data['reversedPaise'] as int? ?? 0,
          ).value,
      amountPaise: outstanding,
      occurredAt: _date(data['updatedAt']),
      route: '/customers/${data['customerId']}/payments',
      fields: {
        'Area': data['areaId'] as String? ?? '',
        'Employee': data['assignedEmployeeId'] as String? ?? '',
        'Oldest outstanding': oldest,
        'Aging':
            ReportMath.age(
              oldestOutstandingMonth: oldest,
              selectedMonth: selectedMonth,
              outstandingPaise: outstanding,
            ).label,
      },
    );
  }

  ReportRow _customerRow(String id, Map<String, dynamic> data) => ReportRow(
    id: id,
    title: data['name'] as String? ?? 'Customer',
    subtitle: data['customerCode'] as String? ?? id,
    status: data['status'] as String? ?? '',
    occurredAt: _date(data['createdAt']),
    route: '/customers/$id',
    fields: {
      'Phone': data['phone'] as String? ?? '',
      'Area': data['areaId'] as String? ?? '',
      'Employee': data['assignedEmployeeId'] as String? ?? '',
      'Landmark': data['landmark'] as String? ?? '',
    },
  );

  ReportRow _subscriptionRow(String id, Map<String, dynamic> data) => ReportRow(
    id: id,
    title: data['newspaperName'] as String? ?? 'Newspaper',
    subtitle: data['customerId'] as String? ?? '',
    status: data['status'] as String? ?? '',
    occurredAt: _date(data['updatedAt']),
    route:
        '/customers/${data['customerId']}/subscriptions/${data['subscriptionId'] ?? id}',
    fields: {
      'Newspaper': data['newspaperId'] as String? ?? '',
      'Quantity': '${data['quantity'] ?? 0}',
      'Start date': data['startDate'] as String? ?? '',
      'End date': data['endDate'] as String? ?? '',
    },
  );

  ReportCursor? _dateCursor(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
    String field,
  ) {
    if (documents.isEmpty) return null;
    final last = documents.last;
    final date = _date(last.data()[field]);
    return date == null
        ? null
        : ReportCursor(sortValue: date, documentPath: last.reference.path);
  }

  ReportCursor? _stringCursor(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
    String field, {
    bool fullPath = true,
  }) {
    if (documents.isEmpty) return null;
    final last = documents.last;
    return ReportCursor(
      sortValue: last.data()[field] as String? ?? '',
      documentPath: fullPath ? last.reference.path : last.id,
    );
  }

  ReportCursor? _intCursor(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
    String field,
  ) {
    if (documents.isEmpty) return null;
    final last = documents.last;
    return ReportCursor(
      sortValue: last.data()[field] as int? ?? 0,
      documentPath: last.reference.path,
    );
  }

  DateTime? _date(Object? value) => value is Timestamp ? value.toDate() : null;

  String _businessId(AppUser actor) {
    final businessId = actor.businessId;
    if (!actor.hasActiveAccess || businessId == null || businessId.isEmpty) {
      throw const AppException('Your business access is no longer active.');
    }
    return businessId;
  }

  String _monthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

  String _previousMonth(String month) {
    final parts = month.split('-');
    if (parts.length != 2) return month;
    final year = int.tryParse(parts[0]);
    final value = int.tryParse(parts[1]);
    if (year == null || value == null || value < 1 || value > 12) return month;
    final previous = DateTime.utc(year, value - 1);
    return _monthKey(previous);
  }

  String _activityLabel(Object? action) => switch (action) {
    'customerCreated' => 'Customer added',
    'customerArchived' => 'Customer archived',
    'customerReactivated' => 'Customer reactivated',
    'customerAssignmentUpdated' => 'Customer transferred',
    _ => 'Customer updated',
  };

  AppException _translate(FirebaseException error, String fallback) {
    final message = switch (error.code) {
      'permission-denied' =>
        'Your current membership does not permit this report.',
      'failed-precondition' =>
        'This report needs a reviewed Firestore index before deployment.',
      'unavailable' => 'Reports require a server connection. Try again.',
      _ => fallback,
    };
    return AppException(message, code: error.code);
  }
}
