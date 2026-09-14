import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/domain/billing_repository.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/collections/domain/collection_balance_engine.dart';
import 'package:paper_route/features/customers/data/firebase_customer_repository.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:uuid/uuid.dart';

class FirebaseBillingRepository implements BillingRepository {
  FirebaseBillingRepository(
    this._firestore, {
    Uuid? uuid,
    MonthlyBillPlanner planner = const MonthlyBillPlanner(),
  }) : _uuid = uuid ?? const Uuid(),
       _planner = planner;

  factory FirebaseBillingRepository.fromDefaultApp() =>
      FirebaseBillingRepository(FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;
  final Uuid _uuid;
  final MonthlyBillPlanner _planner;

  DocumentReference<Map<String, dynamic>> _customer(
    String businessId,
    String customerId,
  ) => _firestore
      .collection('businesses')
      .doc(businessId)
      .collection('customers')
      .doc(customerId);

  DocumentReference<Map<String, dynamic>> _bill(
    String businessId,
    String customerId,
    String month,
  ) => _customer(businessId, customerId).collection('bills').doc(month);

  DocumentReference<Map<String, dynamic>> _control(
    String businessId,
    String customerId,
    String month,
  ) => _customer(
    businessId,
    customerId,
  ).collection('billingControls').doc(month);

  DocumentReference<Map<String, dynamic>> _serviceBillingSource(
    String businessId,
    String customerId,
  ) => _customer(
    businessId,
    customerId,
  ).collection('billingSources').doc('service');

  DocumentReference<Map<String, dynamic>> _collectionState(
    String businessId,
    String customerId,
  ) => _customer(
    businessId,
    customerId,
  ).collection('collectionState').doc('current');

  DocumentReference<Map<String, dynamic>> _billBalance(
    String businessId,
    String customerId,
    String billingMonth,
  ) => _customer(
    businessId,
    customerId,
  ).collection('billBalances').doc(billingMonth);

  CollectionReference<Map<String, dynamic>> _audits(String businessId) =>
      _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('auditRecords');

  @override
  Future<BillingWorkspaceResult> fetchWorkspace({
    required AppUser actor,
    required LocalDate month,
    BillingWorkspaceCursor? cursor,
    int pageSize = 25,
  }) async {
    final businessId = _activeBusinessId(actor);
    billingMonthKey(month);
    if (pageSize < 1 || pageSize > 50) {
      throw const AppException('Billing page size must be between 1 and 50.');
    }
    try {
      final customerPage = await FirebaseCustomerRepository(
        _firestore,
      ).fetchCustomers(
        CustomerListRequest(
          businessId: businessId,
          requesterId: actor.uid,
          isHead: actor.isHead,
          cursor:
              cursor == null
                  ? null
                  : CustomerPageCursor(
                    searchName: cursor.searchName,
                    customerId: cursor.customerId,
                  ),
          pageSize: pageSize,
        ),
      );
      final monthKey = billingMonthKey(month);
      final bills = await Future.wait([
        for (final customer in customerPage.customers)
          _bill(businessId, customer.id, monthKey).get(),
      ]);
      return BillingWorkspaceResult(
        rows: [
          for (var index = 0; index < customerPage.customers.length; index++)
            BillingWorkspaceRow(
              customerId: customerPage.customers[index].id,
              customerCode: customerPage.customers[index].customerCode,
              customerName: customerPage.customers[index].name,
              areaId: customerPage.customers[index].areaId,
              finalizedBill:
                  bills[index].exists ? _billFromSnapshot(bills[index]) : null,
            ),
        ],
        nextCursor:
            customerPage.nextCursor == null
                ? null
                : BillingWorkspaceCursor(
                  searchName: customerPage.nextCursor!.searchName,
                  customerId: customerPage.nextCursor!.customerId,
                ),
        hasMore: customerPage.hasMore,
      );
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not load the billing workspace.');
    }
  }

  @override
  Future<MonthlyBillPreview> previewBill({
    required AppUser actor,
    required String customerId,
    required LocalDate month,
  }) async {
    if (!actor.isHead) {
      throw const AppException('Only the Head can preview monthly bills.');
    }
    return (await _prepare(
      actor: actor,
      customerId: customerId,
      month: month,
    )).preview;
  }

  @override
  Future<FinalizedMonthlyBill> finalizeBill({
    required AppUser actor,
    required String customerId,
    required LocalDate month,
  }) async {
    if (!actor.isHead) {
      throw const AppException('Only the Head can finalize monthly bills.');
    }
    final prepared = await _prepare(
      actor: actor,
      customerId: customerId,
      month: month,
    );
    final preview = prepared.preview;
    final existing = preview.alreadyFinalizedBill;
    if (existing != null) return existing;
    if (preview.issues.isNotEmpty) {
      throw AppException(
        preview.issues.map((issue) => issue.message).join('\n'),
        code: 'billing-preview-blocked',
      );
    }

    final businessId = _headBusinessId(actor);
    final monthKey = billingMonthKey(month);
    final billRef = _bill(businessId, customerId, monthKey);
    final controlRef = _control(businessId, customerId, monthKey);
    final collectionStateRef = _collectionState(businessId, customerId);
    final billBalanceRef = _billBalance(businessId, customerId, monthKey);
    final auditRef = _audits(businessId).doc();

    try {
      return await _firestore.runTransaction((transaction) async {
        final currentBill = await transaction.get(billRef);
        if (currentBill.exists) return _billFromSnapshot(currentBill);

        final currentControl = await transaction.get(controlRef);
        final controlData = currentControl.data();
        final currentRevision = controlData?['adjustmentRevision'] as int? ?? 0;
        if (currentRevision != prepared.adjustmentRevision ||
            (controlData?['status'] != null &&
                controlData?['status'] != 'open')) {
          throw const AppException(
            'Billing adjustments changed. Review the refreshed preview before finalizing.',
            code: 'billing-source-changed',
          );
        }
        for (final lock in prepared.locks) {
          final snapshot = await transaction.get(lock.reference);
          if (!lock.matches(snapshot)) {
            throw const AppException(
              'Customer, subscription, or pricing data changed. Review a new preview.',
              code: 'billing-source-changed',
            );
          }
        }
        final currentCollectionState = await transaction.get(
          collectionStateRef,
        );
        if (currentCollectionState.exists != prepared.collectionStateExists ||
            (currentCollectionState.data()?['revision'] as int? ?? 0) !=
                prepared.collectionStateRevision) {
          throw const AppException(
            'The customer outstanding balance changed. Review a new preview.',
            code: 'billing-source-changed',
          );
        }

        final now = FieldValue.serverTimestamp();
        transaction.set(billRef, {
          'businessId': businessId,
          'customerId': customerId,
          'customerCode': preview.customerCode,
          'customerName': preview.customerName,
          'customerSearchName': CustomerSearchIndex.normalizeText(
            preview.customerName,
          ),
          'customerAddress': preview.customerAddress,
          'areaId': preview.areaId,
          'assignedEmployeeId': preview.assignedEmployeeId,
          'customerStatus': preview.customerStatus,
          'billingMonth': monthKey,
          'status': 'finalized',
          'openingBalancePaise': preview.openingBalancePaise,
          'previousBillId': preview.previousBillId,
          'previousOutstandingPaise': preview.previousOutstandingPaise,
          'priorBalancePaise': preview.priorBalancePaise,
          'currentChargesPaise': preview.currentChargesPaise,
          'adjustmentsPaise': preview.adjustmentsPaise,
          'totalDuePaise': preview.totalDuePaise,
          'lineItemCount': preview.lineItems.length,
          'newspaperSummaries': [
            for (final summary in preview.newspaperSummaries) summary.toMap(),
          ],
          'calculationVersion': phase5CalculationVersion,
          'finalizedBy': actor.uid,
          'createdBy': actor.uid,
          'lastAuditId': auditRef.id,
          'finalizedAt': now,
          'createdAt': now,
        });
        for (final line in preview.lineItems) {
          transaction.set(billRef.collection('lineItems').doc(line.chargeKey), {
            'businessId': businessId,
            'customerId': customerId,
            'billId': monthKey,
            'billingMonth': monthKey,
            'chargeKey': line.chargeKey,
            'serviceDate': line.serviceDate.toString(),
            'subscriptionId': line.subscriptionId,
            'versionId': line.versionId,
            'newspaperId': line.newspaperId,
            'newspaperName': line.newspaperName,
            'unitPricePaise': line.unitPricePaise,
            'quantity': line.quantity,
            'totalPaise': line.totalPaise,
            'priceSource': line.priceSource.value,
            'priceSourceId': line.priceSourceId,
            'priceRuleRevision': line.priceRuleRevision,
            'lastAuditId': auditRef.id,
            'createdAt': now,
          });
        }
        final control = {
          'businessId': businessId,
          'customerId': customerId,
          'billingMonth': monthKey,
          'status': 'finalized',
          'adjustmentRevision': currentRevision,
          'finalizedBillId': monthKey,
          'updatedBy': actor.uid,
          'lastAuditId': auditRef.id,
          'updatedAt': now,
        };
        if (currentControl.exists) {
          transaction.update(controlRef, control);
        } else {
          transaction.set(controlRef, {...control, 'createdAt': now});
        }
        final componentAmountPaise =
            prepared.collectionStateExists
                ? preview.currentChargesPaise + preview.adjustmentsPaise
                : preview.totalDuePaise;
        final componentOutstandingPaise =
            componentAmountPaise > 0 ? componentAmountPaise : 0;
        transaction.set(billBalanceRef, {
          'businessId': businessId,
          'customerId': customerId,
          'billId': monthKey,
          'billingMonth': monthKey,
          'sourceAmountPaise': componentAmountPaise,
          'allocatedPaise': 0,
          'reversedPaise': 0,
          'outstandingPaise': componentOutstandingPaise,
          'status':
              componentAmountPaise > 0
                  ? 'outstanding'
                  : componentAmountPaise < 0
                  ? 'credit'
                  : 'settled',
          'revision': 0,
          'lastMutationType': 'billFinalized',
          'lastMutationId': monthKey,
          'createdAt': now,
          'updatedAt': now,
        });
        final nextCollectionState = {
          'businessId': businessId,
          'customerId': customerId,
          'stateId': 'current',
          'customerCode': preview.customerCode,
          'customerName': preview.customerName,
          'areaId': preview.areaId,
          'assignedEmployeeId': preview.assignedEmployeeId,
          'customerStatus': preview.customerStatus,
          'outstandingPaise': preview.totalDuePaise,
          'confirmedPaise': prepared.collectionConfirmedPaise,
          'reversedPaise': prepared.collectionReversedPaise,
          'reportingStatus': collectionReportingStatus(
            outstandingPaise: preview.totalDuePaise,
            confirmedPaise: prepared.collectionConfirmedPaise,
            reversedPaise: prepared.collectionReversedPaise,
          ),
          'oldestOutstandingMonth':
              preview.totalDuePaise <= 0
                  ? ''
                  : prepared.collectionOutstandingPaise > 0
                  ? prepared.collectionOldestOutstandingMonth
                  : monthKey,
          'revision': prepared.collectionStateRevision + 1,
          'lastMutationType': 'billFinalized',
          'lastMutationId': monthKey,
          'updatedBy': actor.uid,
          'updatedAt': now,
        };
        if (currentCollectionState.exists) {
          transaction.update(collectionStateRef, nextCollectionState);
        } else {
          transaction.set(collectionStateRef, {
            ...nextCollectionState,
            'createdAt': now,
          });
        }
        transaction.set(auditRef, {
          'businessId': businessId,
          'actorId': actor.uid,
          'action': 'billFinalized',
          'entityType': 'bill',
          'entityId': '$customerId:$monthKey',
          'customerId': customerId,
          'billingMonth': monthKey,
          'lineItemCount': preview.lineItems.length,
          'currentChargesPaise': preview.currentChargesPaise,
          'priorBalancePaise': preview.priorBalancePaise,
          'adjustmentsPaise': preview.adjustmentsPaise,
          'totalDuePaise': preview.totalDuePaise,
          'controlRevision': currentRevision,
          'createdAt': now,
        });
        return FinalizedMonthlyBill(
          id: monthKey,
          businessId: businessId,
          customerId: customerId,
          customerCode: preview.customerCode,
          customerName: preview.customerName,
          customerAddress: preview.customerAddress,
          areaId: preview.areaId,
          assignedEmployeeId: preview.assignedEmployeeId,
          billingMonth: monthKey,
          openingBalancePaise: preview.openingBalancePaise,
          previousBillId: preview.previousBillId,
          previousOutstandingPaise: preview.previousOutstandingPaise,
          priorBalancePaise: preview.priorBalancePaise,
          currentChargesPaise: preview.currentChargesPaise,
          adjustmentsPaise: preview.adjustmentsPaise,
          totalDuePaise: preview.totalDuePaise,
          lineItemCount: preview.lineItems.length,
          newspaperSummaries: preview.newspaperSummaries,
          calculationVersion: phase5CalculationVersion,
          finalizedBy: actor.uid,
          lastAuditId: auditRef.id,
        );
      });
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        final committed = await billRef.get();
        if (committed.exists) return _billFromSnapshot(committed);
      }
      throw _translate(error, 'Could not finalize this bill.');
    }
  }

  @override
  Future<String> createAdjustment({
    required AppUser actor,
    required String customerId,
    required BillingAdjustmentInput input,
  }) async {
    final businessId = _headBusinessId(actor);
    final value = input.normalized();
    value.validate();
    final adjustmentId = 'A-${_uuid.v4().replaceAll('-', '').toUpperCase()}';
    final customerRef = _customer(businessId, customerId);
    final billRef = _bill(businessId, customerId, value.billingMonth);
    final controlRef = _control(businessId, customerId, value.billingMonth);
    final adjustmentRef = customerRef
        .collection('adjustments')
        .doc(adjustmentId);
    final auditRef = _audits(businessId).doc();
    try {
      await _firestore.runTransaction((transaction) async {
        final snapshots = await Future.wait([
          transaction.get(customerRef),
          transaction.get(billRef),
          transaction.get(controlRef),
          if (value.referenceBillMonth.isNotEmpty)
            transaction.get(
              _bill(businessId, customerId, value.referenceBillMonth),
            ),
        ]);
        final customerData = snapshots[0].data();
        if (customerData == null || customerData['businessId'] != businessId) {
          throw const AppException('The customer no longer exists.');
        }
        if (snapshots[1].exists) {
          throw const AppException(
            'This month is finalized. Record any correction against a later open month.',
          );
        }
        final control = snapshots[2];
        if (control.exists && control.data()?['status'] != 'open') {
          throw const AppException('This billing month is no longer open.');
        }
        if (value.referenceBillMonth.isNotEmpty && !snapshots[3].exists) {
          throw const AppException(
            'The referenced earlier bill is not finalized.',
          );
        }
        final revision =
            (control.data()?['adjustmentRevision'] as int? ?? 0) + 1;
        final now = FieldValue.serverTimestamp();
        transaction.set(adjustmentRef, {
          'businessId': businessId,
          'customerId': customerId,
          'adjustmentId': adjustmentId,
          'billingMonth': value.billingMonth,
          'amountPaise': value.amountPaise,
          'reason': value.reason,
          'referenceBillMonth': value.referenceBillMonth,
          'createdBy': actor.uid,
          'lastAuditId': auditRef.id,
          'createdAt': now,
        });
        final nextControl = {
          'businessId': businessId,
          'customerId': customerId,
          'billingMonth': value.billingMonth,
          'status': 'open',
          'adjustmentRevision': revision,
          'finalizedBillId': '',
          'updatedBy': actor.uid,
          'lastAuditId': auditRef.id,
          'updatedAt': now,
        };
        if (control.exists) {
          transaction.update(controlRef, nextControl);
        } else {
          transaction.set(controlRef, {...nextControl, 'createdAt': now});
        }
        transaction.set(auditRef, {
          'businessId': businessId,
          'actorId': actor.uid,
          'action': 'billingAdjustmentCreated',
          'entityType': 'billingAdjustment',
          'entityId': adjustmentId,
          'customerId': customerId,
          'billingMonth': value.billingMonth,
          'amountPaise': value.amountPaise,
          'referenceBillMonth': value.referenceBillMonth,
          'controlRevision': revision,
          'createdAt': now,
        });
      });
      return adjustmentId;
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not save the billing adjustment.');
    }
  }

  @override
  Stream<FinalizedMonthlyBill?> watchBill({
    required String businessId,
    required String customerId,
    required String billingMonth,
  }) {
    billingMonthFromKey(billingMonth);
    return _bill(businessId, customerId, billingMonth).snapshots().map(
      (snapshot) => snapshot.exists ? _billFromSnapshot(snapshot) : null,
    );
  }

  @override
  Future<BillLinePage> fetchBillLines({
    required String businessId,
    required String customerId,
    required String billingMonth,
    BillLinePageCursor? cursor,
    int pageSize = 50,
  }) async {
    billingMonthFromKey(billingMonth);
    if (pageSize < 1 || pageSize > 100) {
      throw const AppException(
        'Bill line page size must be between 1 and 100.',
      );
    }
    try {
      Query<Map<String, dynamic>> query = _bill(
            businessId,
            customerId,
            billingMonth,
          )
          .collection('lineItems')
          .orderBy('serviceDate')
          .orderBy(FieldPath.documentId);
      if (cursor != null) {
        query = query.startAfter([cursor.serviceDate, cursor.chargeKey]);
      }
      final snapshot = await query.limit(pageSize + 1).get();
      final visible = snapshot.docs.take(pageSize).toList();
      final last = visible.isEmpty ? null : visible.last;
      return BillLinePage(
        items: [
          for (final document in visible)
            MonthlyBillLineItem.fromMap(document.id, document.data()),
        ],
        nextCursor:
            last == null
                ? null
                : BillLinePageCursor(
                  serviceDate: last.data()['serviceDate'] as String? ?? '',
                  chargeKey: last.id,
                ),
        hasMore: snapshot.docs.length > pageSize,
      );
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not load bill line items.');
    }
  }

  @override
  Stream<List<BillingAdjustment>> watchAdjustments({
    required String businessId,
    required String customerId,
    required String billingMonth,
  }) {
    billingMonthFromKey(billingMonth);
    return _customer(businessId, customerId)
        .collection('adjustments')
        .where('billingMonth', isEqualTo: billingMonth)
        .snapshots()
        .map((snapshot) {
          final result = [
            for (final document in snapshot.docs)
              BillingAdjustment.fromMap(
                document.id,
                _withDartDates(document.data()),
              ),
          ];
          result.sort(
            (left, right) => (right.createdAt ?? DateTime(1970)).compareTo(
              left.createdAt ?? DateTime(1970),
            ),
          );
          return result;
        });
  }

  Future<_PreparedBillingPreview> _prepare({
    required AppUser actor,
    required String customerId,
    required LocalDate month,
  }) async {
    final businessId = _headBusinessId(actor);
    final monthKey = billingMonthKey(month);
    final monthEnd = LocalDate(month.year, month.month, month.daysInMonth);
    final customerRef = _customer(businessId, customerId);
    try {
      final customerSnapshot = await customerRef.get();
      final rawCustomer = customerSnapshot.data();
      if (rawCustomer == null || rawCustomer['businessId'] != businessId) {
        throw const AppException('The customer no longer exists.');
      }
      final customer = Customer.fromMap(
        customerSnapshot.id,
        _withDartDates(rawCustomer),
      );
      final currentBill = await _bill(businessId, customerId, monthKey).get();
      if (currentBill.exists) {
        return _PreparedBillingPreview(
          preview: MonthlyBillPreview(
            businessId: businessId,
            customerId: customerId,
            customerCode: customer.customerCode,
            customerName: customer.name,
            customerAddress: customer.addressSummary,
            billingMonth: monthKey,
            lineItems: const [],
            openingBalancePaise: customer.openingBalancePaise,
            previousBillId: '',
            previousOutstandingPaise: 0,
            adjustments: const [],
            issues: const [],
            alreadyFinalizedBill: _billFromSnapshot(currentBill),
          ),
          locks: const [],
          adjustmentRevision: 0,
          collectionStateExists: false,
          collectionStateRevision: 0,
          collectionConfirmedPaise: 0,
          collectionReversedPaise: 0,
          collectionOutstandingPaise: 0,
          collectionOldestOutstandingMonth: '',
        );
      }

      final previousFuture =
          customerRef
              .collection('bills')
              .where('billingMonth', isLessThan: monthKey)
              .orderBy('billingMonth', descending: true)
              .limit(1)
              .get();
      final laterFuture =
          customerRef
              .collection('bills')
              .where('billingMonth', isGreaterThan: monthKey)
              .orderBy('billingMonth')
              .limit(1)
              .get();
      final subscriptionsFuture = customerRef.collection('subscriptions').get();
      final exceptionsFuture =
          customerRef
              .collection('deliveryExceptions')
              .where('serviceDate', isGreaterThanOrEqualTo: month.toString())
              .where('serviceDate', isLessThanOrEqualTo: monthEnd.toString())
              .get();
      final adjustmentsFuture =
          customerRef
              .collection('adjustments')
              .where('billingMonth', isEqualTo: monthKey)
              .get();
      final controlFuture = _control(businessId, customerId, monthKey).get();
      final serviceBillingSourceFuture =
          _serviceBillingSource(businessId, customerId).get();
      final collectionStateFuture =
          _collectionState(businessId, customerId).get();
      final previousSnapshot = await previousFuture;
      final laterSnapshot = await laterFuture;
      final subscriptions = await subscriptionsFuture;
      final exceptionDocuments = await exceptionsFuture;
      final adjustmentDocuments = await adjustmentsFuture;
      final controlSnapshot = await controlFuture;
      final serviceBillingSourceSnapshot = await serviceBillingSourceFuture;
      final collectionStateSnapshot = await collectionStateFuture;
      final collectionStateData = collectionStateSnapshot.data();

      final terms = <BillingTermSnapshot>[];
      final pauses = <BillingPauseSnapshot>[];
      final sourceIssues = <BillPreviewIssue>[];
      final locks = <_SourceLock>[
        _SourceLock(customerRef, 'lastAuditId', rawCustomer['lastAuditId']),
        _SourceLock.optional(
          serviceBillingSourceSnapshot.reference,
          'revision',
          serviceBillingSourceSnapshot.data()?['revision'],
          exists: serviceBillingSourceSnapshot.exists,
        ),
        _SourceLock.optional(
          collectionStateSnapshot.reference,
          'revision',
          collectionStateData?['revision'],
          exists: collectionStateSnapshot.exists,
        ),
      ];
      for (final subscription in subscriptions.docs) {
        final series = subscription.data();
        locks.add(
          _SourceLock(
            subscription.reference,
            'lastAuditId',
            series['lastAuditId'],
          ),
        );
        final versionsFuture =
            subscription.reference.collection('versions').get();
        final pausesFuture = subscription.reference.collection('pauses').get();
        final versionDocuments = await versionsFuture;
        final pauseDocuments = await pausesFuture;
        var relevantVersionCount = 0;
        for (final version in versionDocuments.docs) {
          final data = version.data();
          final from = _requiredDate(data['effectiveFrom'], 'version start');
          final to = _optionalDate(data['effectiveTo'], 'version end');
          if (from.isAfter(monthEnd) || (to != null && to.isBefore(month))) {
            continue;
          }
          relevantVersionCount++;
          final weekdays = _intSet(data['deliveryWeekdays']);
          terms.add(
            BillingTermSnapshot(
              subscriptionId:
                  data['subscriptionId'] as String? ?? subscription.id,
              versionId: version.id,
              newspaperId: data['newspaperId'] as String? ?? '',
              newspaperName:
                  series['newspaperName'] as String? ?? 'Unknown newspaper',
              effectiveFrom: from,
              effectiveTo: to,
              quantity: data['quantity'] as int? ?? 0,
              deliveryWeekdays: weekdays,
              customPricePaise: data['customPricePaise'] as int?,
            ),
          );
        }
        final seriesStart = _requiredDate(
          series['startDate'],
          'subscription start',
        );
        final seriesEnd = _optionalDate(series['endDate'], 'subscription end');
        final seriesOverlapsMonth =
            !seriesStart.isAfter(monthEnd) &&
            (seriesEnd == null || !seriesEnd.isBefore(month));
        if (seriesOverlapsMonth && relevantVersionCount == 0) {
          sourceIssues.add(
            BillPreviewIssue(
              code: 'missing-subscription-version',
              message:
                  'Subscription ${subscription.id} has no terms version for $monthKey.',
            ),
          );
        }
        for (final pause in pauseDocuments.docs) {
          final data = pause.data();
          final from = _requiredDate(data['startDate'], 'pause start');
          final to = _optionalDate(data['endDate'], 'pause end');
          if (from.isAfter(monthEnd) || (to != null && to.isBefore(month))) {
            continue;
          }
          pauses.add(
            BillingPauseSnapshot(
              subscriptionId:
                  data['subscriptionId'] as String? ?? subscription.id,
              pauseId: pause.id,
              startDate: from,
              endDate: to,
            ),
          );
        }
      }

      final newspaperIds = terms.map((term) => term.newspaperId).toSet();
      final newspapers = <String, BillingNewspaperSnapshot>{};
      for (final newspaperId in newspaperIds) {
        final paperRef = _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('newspapers')
            .doc(newspaperId);
        final paper = await paperRef.get();
        final data = paper.data();
        if (data == null || data['businessId'] != businessId) continue;
        locks.add(_SourceLock(paperRef, 'lastAuditId', data['lastAuditId']));
        final rules = paperRef.collection('priceRules');
        final exactFuture =
            rules
                .where('businessId', isEqualTo: businessId)
                .where('newspaperId', isEqualTo: newspaperId)
                .where('kind', isEqualTo: 'exactDate')
                .where('status', isEqualTo: 'active')
                .where('startDate', isGreaterThanOrEqualTo: month.toString())
                .where('startDate', isLessThanOrEqualTo: monthEnd.toString())
                .get();
        final periodFuture =
            rules
                .where('businessId', isEqualTo: businessId)
                .where('newspaperId', isEqualTo: newspaperId)
                .where('kind', isEqualTo: 'period')
                .where('status', isEqualTo: 'active')
                .where('endDate', isGreaterThanOrEqualTo: month.toString())
                .where('startDate', isLessThanOrEqualTo: monthEnd.toString())
                .get();
        final exactDocuments = await exactFuture;
        final periodDocuments = await periodFuture;
        final priceRules = <BillingPriceRuleSnapshot>[];
        for (final document in [
          ...exactDocuments.docs,
          ...periodDocuments.docs,
        ]) {
          final rule = document.data();
          final start = _requiredDate(rule['startDate'], 'price start');
          final exact = rule['kind'] == 'exactDate';
          priceRules.add(
            BillingPriceRuleSnapshot(
              ruleId: document.id,
              startDate: start,
              endDate:
                  exact ? start : _requiredDate(rule['endDate'], 'price end'),
              pricePaise: rule['pricePaise'] as int? ?? -1,
              isExactDate: exact,
              revision: rule['revision'] as int? ?? 0,
            ),
          );
        }
        final defaultPrice = data['defaultPricePaise'];
        newspapers[newspaperId] = BillingNewspaperSnapshot(
          newspaperId: newspaperId,
          name:
              data['name'] as String? ??
              terms
                  .firstWhere((term) => term.newspaperId == newspaperId)
                  .newspaperName,
          defaultPricePaise: defaultPrice is int ? defaultPrice : -1,
          rules: priceRules,
        );
      }

      final exceptions = <BillingDeliveryExceptionSnapshot>[];
      for (final document in exceptionDocuments.docs) {
        final data = document.data();
        if (data['type'] != 'noDelivery') continue;
        exceptions.add(
          BillingDeliveryExceptionSnapshot(
            id: document.id,
            subscriptionId: data['subscriptionId'] as String? ?? '',
            serviceDate: _requiredDate(
              data['serviceDate'],
              'delivery exception date',
            ),
          ),
        );
      }
      final adjustments = [
        for (final document in adjustmentDocuments.docs)
          BillingAdjustment.fromMap(
            document.id,
            _withDartDates(document.data()),
          ),
      ]..sort((left, right) => left.id.compareTo(right.id));

      final adjustmentRevision =
          controlSnapshot.data()?['adjustmentRevision'] as int? ?? 0;
      if (adjustments.length != adjustmentRevision) {
        sourceIssues.add(
          const BillPreviewIssue(
            code: 'billing-source-changed',
            message:
                'Billing adjustments changed while the preview loaded. Refresh before finalizing.',
          ),
        );
      }
      for (final adjustment in adjustments) {
        if (adjustment.billingMonth != monthKey ||
            adjustment.amountPaise == 0 ||
            adjustment.amountPaise.abs() > 100000000 ||
            adjustment.reason.trim().length < 3) {
          sourceIssues.add(
            BillPreviewIssue(
              code: 'invalid-adjustment',
              message:
                  'Adjustment ${adjustment.id} is invalid and must be reviewed.',
            ),
          );
        }
      }

      final issues = <BillPreviewIssue>[...sourceIssues];
      List<MonthlyBillLineItem> lines = const [];
      try {
        lines = _planner.calculate(
          customerId: customerId,
          month: month,
          terms: terms,
          pauses: pauses,
          deliveryExceptions: exceptions,
          newspapers: newspapers,
        );
      } on AppException catch (error) {
        issues.add(
          BillPreviewIssue(
            code: error.code ?? 'billing-data-invalid',
            message: error.message,
          ),
        );
      }
      if (customer.isArchived) {
        issues.add(
          const BillPreviewIssue(
            code: 'customer-archived',
            message: 'Archived customers cannot receive a new finalized bill.',
          ),
        );
      }
      if (laterSnapshot.docs.isNotEmpty) {
        issues.add(
          BillPreviewIssue(
            code: 'later-bill-exists',
            message:
                'A later bill (${laterSnapshot.docs.first.id}) is already finalized. '
                'Earlier months cannot be finalized afterward.',
          ),
        );
      }
      FinalizedMonthlyBill? previousBill;
      if (previousSnapshot.docs.isNotEmpty) {
        final previousDocument = previousSnapshot.docs.first;
        final previousData = previousDocument.data();
        if (previousData['status'] != 'finalized' ||
            previousData['billingMonth'] != previousDocument.id ||
            previousData['totalDuePaise'] is! int) {
          issues.add(
            BillPreviewIssue(
              code: 'invalid-prior-bill',
              message:
                  'The earlier bill ${previousDocument.id} is not a valid finalized balance source.',
            ),
          );
        } else {
          previousBill = _billFromSnapshot(previousDocument);
        }
      }
      if (collectionStateData != null &&
          (collectionStateData['businessId'] != businessId ||
              collectionStateData['customerId'] != customerId ||
              collectionStateData['stateId'] != 'current' ||
              collectionStateData['outstandingPaise'] is! int ||
              collectionStateData['confirmedPaise'] is! int ||
              collectionStateData['reversedPaise'] is! int ||
              collectionStateData['revision'] is! int ||
              (collectionStateData['confirmedPaise'] is int &&
                  (collectionStateData['confirmedPaise'] as int) < 0) ||
              (collectionStateData['reversedPaise'] is int &&
                  (collectionStateData['reversedPaise'] as int) < 0) ||
              (collectionStateData['confirmedPaise'] is int &&
                  collectionStateData['reversedPaise'] is int &&
                  (collectionStateData['reversedPaise'] as int) >
                      (collectionStateData['confirmedPaise'] as int)) ||
              (collectionStateData['revision'] is int &&
                  (collectionStateData['revision'] as int) < 1))) {
        issues.add(
          const BillPreviewIssue(
            code: 'invalid-collection-state',
            message:
                'The customer collection balance is invalid and must be reviewed.',
          ),
        );
      }
      if (collectionStateData != null && previousBill == null) {
        issues.add(
          const BillPreviewIssue(
            code: 'invalid-collection-state',
            message:
                'A collection balance exists without an earlier finalized bill.',
          ),
        );
      }
      if (previousBill != null && collectionStateData == null) {
        issues.add(
          const BillPreviewIssue(
            code: 'collection-projection-required',
            message:
                'This legacy finalized balance needs a reviewed collection projection migration before another bill or payment can be recorded.',
          ),
        );
      }
      if (collectionStateData != null &&
          (collectionStateData['customerCode'] is! String ||
              collectionStateData['customerName'] is! String ||
              collectionStateData['areaId'] is! String ||
              collectionStateData['assignedEmployeeId'] is! String ||
              collectionStateData['customerStatus'] is! String ||
              collectionStateData['reportingStatus'] is! String ||
              collectionStateData['oldestOutstandingMonth'] is! String ||
              ((collectionStateData['outstandingPaise'] as int? ?? 0) > 0 &&
                  !RegExp(r'^\d{4}-\d{2}$').hasMatch(
                    collectionStateData['oldestOutstandingMonth'] as String? ??
                        '',
                  )))) {
        issues.add(
          const BillPreviewIssue(
            code: 'reporting-projection-required',
            message:
                'This collection balance needs a reviewed Phase 7 reporting projection migration before another bill is finalized.',
          ),
        );
      }
      final previousOutstanding =
          previousBill == null
              ? 0
              : collectionStateData?['outstandingPaise'] is int
              ? collectionStateData!['outstandingPaise'] as int
              : previousBill.totalDuePaise;
      return _PreparedBillingPreview(
        preview: MonthlyBillPreview(
          businessId: businessId,
          customerId: customerId,
          customerCode: customer.customerCode,
          customerName: customer.name,
          customerAddress: customer.addressSummary,
          areaId: customer.areaId,
          assignedEmployeeId: customer.assignedEmployeeId,
          customerStatus: customer.status.value,
          billingMonth: monthKey,
          lineItems: lines,
          openingBalancePaise: customer.openingBalancePaise,
          previousBillId: previousBill?.id ?? '',
          previousOutstandingPaise: previousOutstanding,
          adjustments: adjustments,
          issues: issues,
          alreadyFinalizedBill: null,
        ),
        locks: locks,
        adjustmentRevision: adjustmentRevision,
        collectionStateExists: collectionStateSnapshot.exists,
        collectionStateRevision:
            collectionStateData?['revision'] is int
                ? collectionStateData!['revision'] as int
                : 0,
        collectionConfirmedPaise:
            collectionStateData?['confirmedPaise'] is int
                ? collectionStateData!['confirmedPaise'] as int
                : 0,
        collectionReversedPaise:
            collectionStateData?['reversedPaise'] is int
                ? collectionStateData!['reversedPaise'] as int
                : 0,
        collectionOutstandingPaise:
            collectionStateData?['outstandingPaise'] is int
                ? collectionStateData!['outstandingPaise'] as int
                : 0,
        collectionOldestOutstandingMonth:
            collectionStateData?['oldestOutstandingMonth'] as String? ?? '',
      );
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not prepare the monthly bill.');
    } on FormatException catch (error) {
      throw AppException(
        'Billing source data contains an invalid calendar date: $error',
        code: 'invalid-billing-date',
      );
    }
  }

  FinalizedMonthlyBill _billFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) => FinalizedMonthlyBill.fromMap(
    snapshot.id,
    _withDartDates(snapshot.data() ?? const {}),
  );

  String _activeBusinessId(AppUser actor) {
    final businessId = actor.businessId;
    if (!actor.hasActiveAccess || businessId == null || businessId.isEmpty) {
      throw const AppException('Your business access is no longer active.');
    }
    return businessId;
  }

  String _headBusinessId(AppUser actor) {
    final businessId = _activeBusinessId(actor);
    if (!actor.isHead) {
      throw const AppException('Only the Head can manage monthly billing.');
    }
    return businessId;
  }

  LocalDate _requiredDate(Object? value, String label) {
    if (value is! String) throw FormatException('Missing $label.');
    return LocalDate.parse(value);
  }

  LocalDate? _optionalDate(Object? value, String label) =>
      value == null ? null : _requiredDate(value, label);

  Set<int> _intSet(Object? value) =>
      value is List ? value.whereType<int>().toSet() : const {};

  Map<String, Object?> _withDartDates(Map<String, dynamic> data) {
    final result = <String, Object?>{...data};
    for (final key in const ['createdAt', 'updatedAt', 'finalizedAt']) {
      final value = result[key];
      if (value is Timestamp) result[key] = value.toDate();
    }
    return result;
  }

  AppException _translate(FirebaseException error, String fallback) {
    final message = switch (error.code) {
      'permission-denied' =>
        'Your membership does not permit this billing action.',
      'failed-precondition' =>
        'This billing query needs a reviewed Firestore index before deployment.',
      'aborted' =>
        'Billing data changed while finalizing. Review the new preview and retry.',
      'unavailable' =>
        'Billing requires a server connection. Check your network and retry.',
      _ => fallback,
    };
    return AppException(message, code: error.code);
  }
}

class _SourceLock {
  const _SourceLock(this.reference, this.field, this.value) : exists = true;

  const _SourceLock.optional(
    this.reference,
    this.field,
    this.value, {
    required this.exists,
  });

  final DocumentReference<Map<String, dynamic>> reference;
  final String field;
  final Object? value;
  final bool exists;

  bool matches(DocumentSnapshot<Map<String, dynamic>> snapshot) =>
      snapshot.exists == exists &&
      (!exists || snapshot.data()?[field] == value);
}

class _PreparedBillingPreview {
  const _PreparedBillingPreview({
    required this.preview,
    required this.locks,
    required this.adjustmentRevision,
    required this.collectionStateExists,
    required this.collectionStateRevision,
    required this.collectionConfirmedPaise,
    required this.collectionReversedPaise,
    required this.collectionOutstandingPaise,
    required this.collectionOldestOutstandingMonth,
  });

  final MonthlyBillPreview preview;
  final List<_SourceLock> locks;
  final int adjustmentRevision;
  final bool collectionStateExists;
  final int collectionStateRevision;
  final int collectionConfirmedPaise;
  final int collectionReversedPaise;
  final int collectionOutstandingPaise;
  final String collectionOldestOutstandingMonth;
}
