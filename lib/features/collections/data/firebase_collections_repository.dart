import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';
import 'package:paper_route/features/collections/domain/collection_repository.dart';
import 'package:paper_route/features/collections/domain/payment_allocation_engine.dart';
import 'package:paper_route/features/customers/domain/customer.dart';

const _maximumBillBalanceDocuments = 120;

class FirebaseCollectionsRepository implements CollectionsRepository {
  FirebaseCollectionsRepository(
    this._firestore, {
    PaymentAllocationEngine allocationEngine = const PaymentAllocationEngine(),
  }) : _allocationEngine = allocationEngine;

  factory FirebaseCollectionsRepository.fromDefaultApp() =>
      FirebaseCollectionsRepository(FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;
  final PaymentAllocationEngine _allocationEngine;

  DocumentReference<Map<String, dynamic>> _customer(
    String businessId,
    String customerId,
  ) => _firestore
      .collection('businesses')
      .doc(businessId)
      .collection('customers')
      .doc(customerId);

  CollectionReference<Map<String, dynamic>> _payments(
    String businessId,
    String customerId,
  ) => _customer(businessId, customerId).collection('payments');

  CollectionReference<Map<String, dynamic>> _paymentStates(
    String businessId,
    String customerId,
  ) => _customer(businessId, customerId).collection('paymentStates');

  CollectionReference<Map<String, dynamic>> _reversals(
    String businessId,
    String customerId,
  ) => _customer(businessId, customerId).collection('paymentReversals');

  CollectionReference<Map<String, dynamic>> _billBalances(
    String businessId,
    String customerId,
  ) => _customer(businessId, customerId).collection('billBalances');

  DocumentReference<Map<String, dynamic>> _collectionState(
    String businessId,
    String customerId,
  ) => _customer(
    businessId,
    customerId,
  ).collection('collectionState').doc('current');

  DocumentReference<Map<String, dynamic>> _upiSettings(String businessId) =>
      _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('configuration')
          .doc('upi');

  CollectionReference<Map<String, dynamic>> _audits(String businessId) =>
      _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('auditRecords');

  @override
  Stream<CustomerOutstandingSummary> watchCustomerOutstanding({
    required String businessId,
    required String customerId,
  }) => _collectionState(businessId, customerId).snapshots().asyncMap(
    (_) => _fetchOutstanding(businessId: businessId, customerId: customerId),
  );

  @override
  Future<CustomerOutstandingSummary> fetchCustomerOutstanding({
    required AppUser actor,
    required String customerId,
  }) async {
    final businessId = _activeBusinessId(actor);
    await _readAuthorizedCustomer(
      actor: actor,
      businessId: businessId,
      customerId: customerId,
    );
    return _fetchOutstanding(businessId: businessId, customerId: customerId);
  }

  @override
  Future<PaymentHistoryPage> fetchPaymentHistory({
    required AppUser actor,
    String? customerId,
    PaymentHistoryCursor? cursor,
    int pageSize = 25,
  }) async {
    final businessId = _activeBusinessId(actor);
    if (pageSize < 1 || pageSize > 50) {
      throw const AppException(
        'Payment-history page size must be between 1 and 50.',
      );
    }
    final normalizedCustomerId = customerId?.trim() ?? '';
    if (!actor.isHead && normalizedCustomerId.isEmpty) {
      return _fetchCollectionGroupHistory(
        actor: actor,
        businessId: businessId,
        cursor: cursor,
        pageSize: pageSize,
      );
    }

    Query<Map<String, dynamic>> query;
    if (normalizedCustomerId.isNotEmpty) {
      await _readAuthorizedCustomer(
        actor: actor,
        businessId: businessId,
        customerId: normalizedCustomerId,
      );
      query = _payments(businessId, normalizedCustomerId);
    } else {
      query = _firestore
          .collectionGroup('payments')
          .where('businessId', isEqualTo: businessId);
    }
    query = query
        .orderBy('confirmedAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (cursor != null) {
      query = query.startAfter([
        Timestamp.fromDate(cursor.confirmedAt),
        normalizedCustomerId.isEmpty
            ? cursor.documentPath
            : cursor.documentPath.split('/').last,
      ]);
    }
    return _readPaymentPage(query: query, pageSize: pageSize);
  }

  Future<PaymentHistoryPage> _fetchCollectionGroupHistory({
    required AppUser actor,
    required String businessId,
    required PaymentHistoryCursor? cursor,
    required int pageSize,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collectionGroup('payments')
        .where('businessId', isEqualTo: businessId)
        .where('collectorUid', isEqualTo: actor.uid)
        .orderBy('confirmedAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true);
    if (cursor != null) {
      query = query.startAfter([
        Timestamp.fromDate(cursor.confirmedAt),
        cursor.documentPath,
      ]);
    }
    return _readPaymentPage(query: query, pageSize: pageSize);
  }

  Future<PaymentHistoryPage> _readPaymentPage({
    required Query<Map<String, dynamic>> query,
    required int pageSize,
  }) async {
    try {
      final snapshot = await query.limit(pageSize + 1).get();
      final visible = snapshot.docs.take(pageSize).toList();
      final payments = await Future.wait([
        for (final document in visible) _paymentWithState(document),
      ]);
      final last = visible.isEmpty ? null : visible.last;
      final confirmedAt = last?.data()['confirmedAt'];
      return PaymentHistoryPage(
        items: List.unmodifiable(payments),
        nextCursor:
            last == null || confirmedAt is! Timestamp
                ? null
                : PaymentHistoryCursor(
                  confirmedAt: confirmedAt.toDate(),
                  documentPath: last.reference.path,
                ),
        hasMore: snapshot.docs.length > pageSize,
      );
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not load payment history.');
    }
  }

  @override
  Future<ConfirmedPayment> getPayment({
    required AppUser actor,
    required String customerId,
    required String paymentId,
  }) async {
    final businessId = _activeBusinessId(actor);
    try {
      final snapshot = await _payments(
        businessId,
        customerId,
      ).doc(paymentId).get(const GetOptions(source: Source.server));
      if (!snapshot.exists) {
        throw const AppException('The confirmed payment no longer exists.');
      }
      if (!actor.isHead && snapshot.data()?['collectorUid'] != actor.uid) {
        await _readAuthorizedCustomer(
          actor: actor,
          businessId: businessId,
          customerId: customerId,
        );
      }
      return _paymentWithState(snapshot);
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not load the payment receipt.');
    }
  }

  @override
  Future<PaymentConfirmationResult> confirmPayment({
    required AppUser actor,
    required String customerId,
    required PaymentConfirmationInput input,
  }) async {
    final businessId = _activeBusinessId(actor);
    final value = input.normalized();
    value.validate();
    final paymentRef = _payments(
      businessId,
      customerId,
    ).doc(value.idempotencyKey);

    try {
      final existing = await paymentRef.get(
        const GetOptions(source: Source.server),
      );
      if (existing.exists) {
        _verifyIdempotentPayment(existing.data()!, actor, value);
        return _confirmedResult(
          businessId: businessId,
          customerId: customerId,
          paymentId: value.idempotencyKey,
        );
      }
      // One bounded application retry reloads projections after a concurrent
      // confirmation. The immutable payment ID makes this retry idempotent.
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          await _confirmOnce(
            actor: actor,
            businessId: businessId,
            customerId: customerId,
            value: value,
          );
          return _confirmedResult(
            businessId: businessId,
            customerId: customerId,
            paymentId: value.idempotencyKey,
          );
        } on AppException catch (error) {
          if (attempt == 0 && error.code == 'collection-state-changed') {
            continue;
          }
          rethrow;
        }
      }
      throw const AppException('Could not confirm this payment safely.');
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      if (_mayBeCommittedRace(error)) {
        final recovered = await _recoverPaymentConfirmation(
          businessId: businessId,
          customerId: customerId,
          actor: actor,
          input: value,
        );
        if (recovered != null) return recovered;
      }
      throw _translate(error, 'Could not confirm this payment.');
    }
  }

  Future<void> _confirmOnce({
    required AppUser actor,
    required String businessId,
    required String customerId,
    required PaymentConfirmationInput value,
  }) async {
    final context = await _loadAllocationContext(
      actor: actor,
      businessId: businessId,
      customerId: customerId,
    );
    final plan = _allocationEngine.allocate(
      amountPaise: value.amountPaise,
      accountOutstandingPaise: context.outstandingPaise,
      bills: context.bills,
      preferredBillId: value.preferredBillId,
    );
    final paymentRef = _payments(
      businessId,
      customerId,
    ).doc(value.idempotencyKey);
    final paymentStateRef = _paymentStates(
      businessId,
      customerId,
    ).doc(value.idempotencyKey);
    final accountRef = _collectionState(businessId, customerId);
    final auditRef = _audits(businessId).doc();

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(paymentRef);
      if (existing.exists) {
        _verifyIdempotentPayment(existing.data()!, actor, value);
        return;
      }
      final customerSnapshot = await transaction.get(
        _customer(businessId, customerId),
      );
      final customerData = customerSnapshot.data();
      if (customerData == null) {
        throw const AppException('The customer no longer exists.');
      }
      _ensureCanCollect(actor, businessId, customerData);

      final stateSnapshot = await transaction.get(accountRef);
      final currentState = stateSnapshot.data();
      if (stateSnapshot.exists != context.stateExists ||
          (currentState?['revision'] as int? ?? 0) != context.revision) {
        throw const AppException(
          'The account balance changed. Refreshing before confirmation.',
          code: 'collection-state-changed',
        );
      }
      final liveBills = <String, OutstandingBill>{};
      for (final allocation in plan.allocations) {
        final expected = context.byBillId[allocation.billId]!;
        final ref = _billBalances(
          businessId,
          customerId,
        ).doc(allocation.billId);
        final snapshot = await transaction.get(ref);
        if (snapshot.exists) {
          final live = _outstandingBill(snapshot.id, snapshot.data()!);
          if (live.revision != expected.revision ||
              live.outstandingPaise != expected.outstandingPaise) {
            throw const AppException(
              'A bill balance changed. Refreshing before confirmation.',
              code: 'collection-state-changed',
            );
          }
          liveBills[allocation.billId] = live;
        } else {
          throw const AppException(
            'A bill balance is unavailable. Refresh before confirmation.',
            code: 'collection-state-changed',
          );
        }
      }

      final now = FieldValue.serverTimestamp();
      final allocations = [
        for (final allocation in plan.allocations) allocation.toMap(),
      ];
      transaction.set(paymentRef, {
        'businessId': businessId,
        'customerId': customerId,
        'customerCode': customerData['customerCode'],
        'customerName': customerData['name'],
        'paymentId': value.idempotencyKey,
        'idempotencyKey': value.idempotencyKey,
        'amountPaise': value.amountPaise,
        'method': value.method.value,
        'status': 'confirmed',
        'externalReference': value.externalReference,
        'notes': value.notes,
        'collectorUid': actor.uid,
        'allocations': allocations,
        'allocationCount': allocations.length,
        'allocatedPaise': value.amountPaise,
        'lastAuditId': auditRef.id,
        'confirmedAt': now,
        'createdAt': now,
      });
      transaction.set(paymentStateRef, {
        'businessId': businessId,
        'customerId': customerId,
        'paymentId': value.idempotencyKey,
        'amountPaise': value.amountPaise,
        'reversedPaise': 0,
        'refundablePaise': value.amountPaise,
        'status': 'confirmed',
        'allocationStates': [
          for (final allocation in plan.allocations)
            PaymentAllocationState(
              billId: allocation.billId,
              billingMonth: allocation.billingMonth,
              amountPaise: allocation.amountPaise,
              reversedPaise: 0,
            ).toMap(),
        ],
        'revision': 0,
        'lastReversalId': '',
        'createdAt': now,
        'updatedAt': now,
      });

      final nextOutstanding = context.outstandingPaise - value.amountPaise;
      final nextState = {
        'businessId': businessId,
        'customerId': customerId,
        'stateId': 'current',
        'outstandingPaise': nextOutstanding,
        'confirmedPaise': context.confirmedPaise + value.amountPaise,
        'reversedPaise': context.reversedPaise,
        'revision': context.revision + 1,
        'lastMutationType': 'paymentConfirmed',
        'lastMutationId': value.idempotencyKey,
        'updatedBy': actor.uid,
        'updatedAt': now,
      };
      transaction.update(accountRef, nextState);

      for (final allocation in plan.allocations) {
        final current = liveBills[allocation.billId]!;
        final ref = _billBalances(
          businessId,
          customerId,
        ).doc(allocation.billId);
        final nextOutstanding =
            current.outstandingPaise - allocation.amountPaise;
        final next = {
          'businessId': businessId,
          'customerId': customerId,
          'billId': current.billId,
          'billingMonth': current.billingMonth,
          'sourceAmountPaise': current.sourceAmountPaise,
          'allocatedPaise': current.allocatedPaise + allocation.amountPaise,
          'reversedPaise': current.reversedPaise,
          'outstandingPaise': nextOutstanding,
          'status': nextOutstanding == 0 ? 'settled' : 'outstanding',
          'revision': current.revision + 1,
          'lastMutationType': 'paymentConfirmed',
          'lastMutationId': value.idempotencyKey,
          'updatedAt': now,
        };
        transaction.update(ref, next);
      }
      transaction.set(auditRef, {
        'businessId': businessId,
        'actorId': actor.uid,
        'action': 'paymentConfirmed',
        'entityType': 'payment',
        'entityId': value.idempotencyKey,
        'customerId': customerId,
        'paymentId': value.idempotencyKey,
        'amountPaise': value.amountPaise,
        'method': value.method.value,
        'allocationCount': allocations.length,
        'createdAt': now,
      });
    });
  }

  @override
  Future<PaymentReversalResult> reversePayment({
    required AppUser actor,
    required String customerId,
    required PaymentReversalInput input,
  }) async {
    final businessId = _headBusinessId(actor);
    final value = input.normalized();
    value.validate();
    final reversalRef = _reversals(
      businessId,
      customerId,
    ).doc(value.idempotencyKey);
    final paymentRef = _payments(businessId, customerId).doc(value.paymentId);
    final paymentStateRef = _paymentStates(
      businessId,
      customerId,
    ).doc(value.paymentId);
    final accountRef = _collectionState(businessId, customerId);
    final auditRef = _audits(businessId).doc();

    try {
      await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(reversalRef);
        if (existing.exists) {
          _verifyIdempotentReversal(existing.data()!, value);
          return;
        }
        final paymentSnapshot = await transaction.get(paymentRef);
        final paymentStateSnapshot = await transaction.get(paymentStateRef);
        final accountSnapshot = await transaction.get(accountRef);
        final payment = paymentSnapshot.data();
        final paymentState = paymentStateSnapshot.data();
        final account = accountSnapshot.data();
        if (payment == null || paymentState == null || account == null) {
          throw const AppException(
            'The confirmed payment state is incomplete and cannot be reversed.',
            code: 'invalid-payment-state',
          );
        }
        if (payment['businessId'] != businessId ||
            payment['customerId'] != customerId ||
            payment['status'] != 'confirmed') {
          throw const AppException('The confirmed payment is invalid.');
        }
        final allocationStates = _allocationStates(
          paymentState['allocationStates'],
        );
        final plan = _allocationEngine.reverse(
          amountPaise: value.amountPaise,
          allocationStates: allocationStates,
        );
        final balances = <String, OutstandingBill>{};
        for (final allocation in plan.allocations) {
          final snapshot = await transaction.get(
            _billBalances(businessId, customerId).doc(allocation.billId),
          );
          if (!snapshot.exists) {
            throw const AppException(
              'A bill allocation is unavailable and cannot be reversed.',
              code: 'invalid-bill-balance',
            );
          }
          balances[allocation.billId] = _outstandingBill(
            snapshot.id,
            snapshot.data()!,
          );
        }

        final now = FieldValue.serverTimestamp();
        final allocationMaps = [
          for (final allocation in plan.allocations) allocation.toMap(),
        ];
        transaction.set(reversalRef, {
          'businessId': businessId,
          'customerId': customerId,
          'reversalId': value.idempotencyKey,
          'paymentId': value.paymentId,
          'idempotencyKey': value.idempotencyKey,
          'amountPaise': value.amountPaise,
          'reason': value.reason,
          'reversedBy': actor.uid,
          'allocations': allocationMaps,
          'allocationCount': allocationMaps.length,
          'restoredPaise': value.amountPaise,
          'lastAuditId': auditRef.id,
          'reversedAt': now,
          'createdAt': now,
        });

        final priorReversed = paymentState['reversedPaise'] as int? ?? 0;
        final nextReversed = priorReversed + value.amountPaise;
        final paymentAmount = payment['amountPaise'] as int? ?? 0;
        final nextStatus =
            nextReversed == paymentAmount ? 'reversed' : 'partiallyReversed';
        transaction.update(paymentStateRef, {
          'reversedPaise': nextReversed,
          'refundablePaise': paymentAmount - nextReversed,
          'status': nextStatus,
          'allocationStates': [
            for (final allocation in plan.nextAllocationStates)
              allocation.toMap(),
          ],
          'revision': (paymentState['revision'] as int? ?? 0) + 1,
          'lastReversalId': value.idempotencyKey,
          'updatedAt': now,
        });
        transaction.update(accountRef, {
          'outstandingPaise':
              (account['outstandingPaise'] as int? ?? 0) + value.amountPaise,
          'reversedPaise':
              (account['reversedPaise'] as int? ?? 0) + value.amountPaise,
          'revision': (account['revision'] as int? ?? 0) + 1,
          'lastMutationType': 'paymentReversed',
          'lastMutationId': value.idempotencyKey,
          'updatedBy': actor.uid,
          'updatedAt': now,
        });
        for (final allocation in plan.allocations) {
          final current = balances[allocation.billId]!;
          final nextOutstanding =
              current.outstandingPaise + allocation.amountPaise;
          transaction.update(
            _billBalances(businessId, customerId).doc(allocation.billId),
            {
              'reversedPaise': current.reversedPaise + allocation.amountPaise,
              'outstandingPaise': nextOutstanding,
              'status': 'outstanding',
              'revision': current.revision + 1,
              'lastMutationType': 'paymentReversed',
              'lastMutationId': value.idempotencyKey,
              'updatedAt': now,
            },
          );
        }
        transaction.set(auditRef, {
          'businessId': businessId,
          'actorId': actor.uid,
          'action': 'paymentReversed',
          'entityType': 'paymentReversal',
          'entityId': value.idempotencyKey,
          'customerId': customerId,
          'paymentId': value.paymentId,
          'amountPaise': value.amountPaise,
          'reason': value.reason,
          'allocationCount': allocationMaps.length,
          'createdAt': now,
        });
      });
      return _reversalResult(
        businessId: businessId,
        customerId: customerId,
        reversalId: value.idempotencyKey,
        paymentId: value.paymentId,
      );
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      if (_mayBeCommittedRace(error)) {
        final recovered = await _recoverPaymentReversal(
          businessId: businessId,
          customerId: customerId,
          input: value,
        );
        if (recovered != null) return recovered;
      }
      throw _translate(error, 'Could not reverse this payment.');
    }
  }

  bool _mayBeCommittedRace(FirebaseException error) =>
      error.code == 'permission-denied' ||
      error.code == 'aborted' ||
      error.code == 'unavailable';

  Future<PaymentConfirmationResult?> _recoverPaymentConfirmation({
    required String businessId,
    required String customerId,
    required AppUser actor,
    required PaymentConfirmationInput input,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
      try {
        final payment = await _payments(businessId, customerId)
            .doc(input.idempotencyKey)
            .get(const GetOptions(source: Source.server));
        if (!payment.exists) continue;
        _verifyIdempotentPayment(payment.data()!, actor, input);
        return _confirmedResult(
          businessId: businessId,
          customerId: customerId,
          paymentId: input.idempotencyKey,
        );
      } on AppException {
        rethrow;
      } on FirebaseException {
        // A bounded second server read is safe because no write is retried.
      }
    }
    return null;
  }

  Future<PaymentReversalResult?> _recoverPaymentReversal({
    required String businessId,
    required String customerId,
    required PaymentReversalInput input,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
      try {
        final reversal = await _reversals(businessId, customerId)
            .doc(input.idempotencyKey)
            .get(const GetOptions(source: Source.server));
        if (!reversal.exists) continue;
        _verifyIdempotentReversal(reversal.data()!, input);
        return _reversalResult(
          businessId: businessId,
          customerId: customerId,
          reversalId: input.idempotencyKey,
          paymentId: input.paymentId,
        );
      } on AppException {
        rethrow;
      } on FirebaseException {
        // A bounded second server read is safe because no write is retried.
      }
    }
    return null;
  }

  @override
  Stream<UpiSettings> watchUpiSettings(String businessId) =>
      _upiSettings(businessId).snapshots().map((snapshot) {
        final data = snapshot.data();
        if (data == null) return UpiSettings.empty(businessId);
        return _upiSettingsFromData(
          data,
          serverConfirmed: !snapshot.metadata.hasPendingWrites,
        );
      });

  @override
  Future<void> updateUpiSettings({
    required AppUser actor,
    required UpiSettingsInput input,
  }) async {
    final businessId = _headBusinessId(actor);
    final value = input.normalized();
    value.validate();
    final settingsRef = _upiSettings(businessId);
    final auditRef = _audits(businessId).doc();
    try {
      await _firestore.runTransaction((transaction) async {
        final current = await transaction.get(settingsRef);
        final now = FieldValue.serverTimestamp();
        final settings = {
          'businessId': businessId,
          'upiId': value.upiId,
          'payeeName': value.payeeName,
          'referencePrefix': value.referencePrefix,
          'enabled': value.enabled,
          'updatedBy': actor.uid,
          'lastAuditId': auditRef.id,
          'updatedAt': now,
        };
        if (current.exists) {
          transaction.update(settingsRef, settings);
        } else {
          transaction.set(settingsRef, {...settings, 'createdAt': now});
        }
        transaction.set(auditRef, {
          'businessId': businessId,
          'actorId': actor.uid,
          'action': 'upiSettingsUpdated',
          'entityType': 'configuration',
          'entityId': 'upi',
          'enabled': value.enabled,
          'createdAt': now,
        });
      });
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not update UPI settings.');
    }
  }

  Future<CustomerOutstandingSummary> _fetchOutstanding({
    required String businessId,
    required String customerId,
  }) async {
    try {
      final state = await _collectionState(businessId, customerId).get();
      final data = state.data();
      if (data == null) {
        final latest =
            await _customer(businessId, customerId)
                .collection('bills')
                .where('status', isEqualTo: 'finalized')
                .orderBy('billingMonth', descending: true)
                .limit(1)
                .get();
        if (latest.docs.isEmpty) {
          return CustomerOutstandingSummary(
            businessId: businessId,
            customerId: customerId,
            outstandingPaise: 0,
            confirmedPaise: 0,
            reversedPaise: 0,
            bills: const [],
            revision: 0,
            serverConfirmed: !state.metadata.hasPendingWrites,
            requiresProjectionSetup: false,
          );
        }
        final bill = latest.docs.single;
        final total = bill.data()['totalDuePaise'] as int? ?? 0;
        return CustomerOutstandingSummary(
          businessId: businessId,
          customerId: customerId,
          outstandingPaise: total,
          confirmedPaise: 0,
          reversedPaise: 0,
          bills: [
            OutstandingBill(
              billId: bill.id,
              billingMonth: bill.data()['billingMonth'] as String? ?? bill.id,
              sourceAmountPaise: total,
              allocatedPaise: 0,
              reversedPaise: 0,
              outstandingPaise: math.max(0, total),
              status:
                  total > 0
                      ? 'outstanding'
                      : total < 0
                      ? 'credit'
                      : 'settled',
              revision: 0,
            ),
          ],
          revision: 0,
          serverConfirmed:
              !state.metadata.hasPendingWrites &&
              !latest.metadata.hasPendingWrites,
          requiresProjectionSetup: true,
        );
      }
      final balances =
          await _billBalances(businessId, customerId)
              .orderBy('billingMonth')
              .limit(_maximumBillBalanceDocuments + 1)
              .get();
      if (balances.docs.length > _maximumBillBalanceDocuments) {
        throw const AppException(
          'This account has too many billing components to collect safely.',
          code: 'bill-balance-limit',
        );
      }
      return CustomerOutstandingSummary(
        businessId: businessId,
        customerId: customerId,
        outstandingPaise: data['outstandingPaise'] as int? ?? 0,
        confirmedPaise: data['confirmedPaise'] as int? ?? 0,
        reversedPaise: data['reversedPaise'] as int? ?? 0,
        bills: List.unmodifiable([
          for (final document in balances.docs)
            _outstandingBill(document.id, document.data()),
        ]),
        revision: data['revision'] as int? ?? 0,
        updatedAt: _date(data['updatedAt']),
        serverConfirmed:
            !state.metadata.hasPendingWrites &&
            !balances.metadata.hasPendingWrites,
        requiresProjectionSetup: false,
      );
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not calculate the outstanding balance.');
    }
  }

  Future<_AllocationContext> _loadAllocationContext({
    required AppUser actor,
    required String businessId,
    required String customerId,
  }) async {
    final customerSnapshot = await _customer(businessId, customerId).get();
    final customerData = customerSnapshot.data();
    if (customerData == null) {
      throw const AppException('The customer no longer exists.');
    }
    _ensureCanCollect(actor, businessId, customerData);
    final state = await _collectionState(businessId, customerId).get();
    final stateData = state.data();
    if (stateData == null) {
      throw const AppException(
        'This legacy finalized balance needs a reviewed collection projection migration before a payment can be confirmed.',
        code: 'collection-projection-required',
      );
    }
    final snapshots =
        await _billBalances(
          businessId,
          customerId,
        ).orderBy('billingMonth').limit(_maximumBillBalanceDocuments + 1).get();
    if (snapshots.docs.length > _maximumBillBalanceDocuments) {
      throw const AppException(
        'This account has too many billing components to collect safely.',
        code: 'bill-balance-limit',
      );
    }
    return _AllocationContext(
      stateExists: true,
      outstandingPaise: stateData['outstandingPaise'] as int? ?? 0,
      confirmedPaise: stateData['confirmedPaise'] as int? ?? 0,
      reversedPaise: stateData['reversedPaise'] as int? ?? 0,
      revision: stateData['revision'] as int? ?? 0,
      bills: [
        for (final snapshot in snapshots.docs)
          _outstandingBill(snapshot.id, snapshot.data()),
      ],
    );
  }

  Future<PaymentConfirmationResult> _confirmedResult({
    required String businessId,
    required String customerId,
    required String paymentId,
  }) async {
    final snapshots = await Future.wait([
      _payments(
        businessId,
        customerId,
      ).doc(paymentId).get(const GetOptions(source: Source.server)),
      _paymentStates(
        businessId,
        customerId,
      ).doc(paymentId).get(const GetOptions(source: Source.server)),
      _collectionState(
        businessId,
        customerId,
      ).get(const GetOptions(source: Source.server)),
    ]);
    final payment = snapshots[0];
    final state = snapshots[1];
    final account = snapshots[2];
    if (!payment.exists || !state.exists || !account.exists) {
      throw const AppException(
        'The server did not confirm the complete payment transaction.',
        code: 'payment-not-server-confirmed',
      );
    }
    final confirmed = _paymentFromData(
      payment.id,
      payment.data()!,
      state.data(),
      serverConfirmed:
          !payment.metadata.hasPendingWrites &&
          !state.metadata.hasPendingWrites,
    );
    return PaymentConfirmationResult(
      payment: confirmed,
      remainingOutstandingPaise:
          account.data()?['outstandingPaise'] as int? ?? 0,
      serverConfirmed:
          confirmed.serverConfirmed && !account.metadata.hasPendingWrites,
    );
  }

  Future<PaymentReversalResult> _reversalResult({
    required String businessId,
    required String customerId,
    required String reversalId,
    required String paymentId,
  }) async {
    final snapshots = await Future.wait([
      _reversals(
        businessId,
        customerId,
      ).doc(reversalId).get(const GetOptions(source: Source.server)),
      _paymentStates(
        businessId,
        customerId,
      ).doc(paymentId).get(const GetOptions(source: Source.server)),
      _collectionState(
        businessId,
        customerId,
      ).get(const GetOptions(source: Source.server)),
    ]);
    final reversal = snapshots[0];
    final paymentState = snapshots[1];
    final account = snapshots[2];
    if (!reversal.exists || !paymentState.exists || !account.exists) {
      throw const AppException(
        'The server did not confirm the complete reversal transaction.',
        code: 'reversal-not-server-confirmed',
      );
    }
    final state = paymentState.data()!;
    final confirmed =
        !reversal.metadata.hasPendingWrites &&
        !paymentState.metadata.hasPendingWrites &&
        !account.metadata.hasPendingWrites;
    return PaymentReversalResult(
      reversal: _reversalFromData(
        reversal.id,
        reversal.data()!,
        serverConfirmed: confirmed,
      ),
      paymentStatus: ConfirmedPaymentStatus.fromValue(state['status']),
      paymentReversedPaise: state['reversedPaise'] as int? ?? 0,
      remainingOutstandingPaise:
          account.data()?['outstandingPaise'] as int? ?? 0,
      serverConfirmed: confirmed,
    );
  }

  Future<ConfirmedPayment> _paymentWithState(
    DocumentSnapshot<Map<String, dynamic>> payment,
  ) async {
    final customerRef = payment.reference.parent.parent;
    if (customerRef == null) {
      throw const AppException('The payment path is invalid.');
    }
    final paymentData = payment.data();
    if (paymentData == null) {
      throw const AppException('The confirmed payment no longer exists.');
    }
    final state =
        await customerRef.collection('paymentStates').doc(payment.id).get();
    return _paymentFromData(
      payment.id,
      paymentData,
      state.data(),
      serverConfirmed:
          !payment.metadata.hasPendingWrites &&
          !state.metadata.hasPendingWrites,
    );
  }

  Future<Map<String, dynamic>> _readAuthorizedCustomer({
    required AppUser actor,
    required String businessId,
    required String customerId,
  }) async {
    try {
      final snapshot = await _customer(businessId, customerId).get();
      final data = snapshot.data();
      if (data == null) {
        throw const AppException('The customer no longer exists.');
      }
      final customer = Customer.fromMap(snapshot.id, _withDartDates(data));
      if (!const AccessPolicy().canReadCustomer(
        member: actor,
        customerBusinessId: customer.businessId,
        assignedEmployeeId: customer.assignedEmployeeId,
      )) {
        throw const AppException(
          'Your current assignment does not allow access to this customer.',
        );
      }
      return data;
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not load the customer.');
    }
  }

  void _ensureCanCollect(
    AppUser actor,
    String businessId,
    Map<String, dynamic> customer,
  ) {
    if (customer['businessId'] != businessId ||
        customer['status'] != 'active') {
      throw const AppException(
        'Collections can be recorded only for an active customer in this business.',
      );
    }
    if (actor.isHead) return;
    final areaId = customer['areaId'] as String? ?? '';
    if (customer['assignedEmployeeId'] != actor.uid ||
        !actor.areaIds.contains(areaId) ||
        !actor.permissions.contains(PermissionKey.recordPayments)) {
      throw const AppException(
        'Your assignment, area coverage, or permissions do not allow collection.',
      );
    }
  }

  ConfirmedPayment _paymentFromData(
    String id,
    Map<String, dynamic> data,
    Map<String, dynamic>? state, {
    required bool serverConfirmed,
  }) => ConfirmedPayment(
    id: id,
    businessId: data['businessId'] as String? ?? '',
    customerId: data['customerId'] as String? ?? '',
    customerCode: data['customerCode'] as String? ?? '',
    customerName: data['customerName'] as String? ?? '',
    amountPaise: data['amountPaise'] as int? ?? 0,
    method: PaymentMethod.fromValue(data['method']),
    status: ConfirmedPaymentStatus.fromValue(state?['status']),
    externalReference: data['externalReference'] as String? ?? '',
    notes: data['notes'] as String? ?? '',
    collectorUid: data['collectorUid'] as String? ?? '',
    allocations: _allocations(data['allocations']),
    reversedPaise: state?['reversedPaise'] as int? ?? 0,
    lastAuditId: data['lastAuditId'] as String? ?? '',
    confirmedAt: _date(data['confirmedAt']),
    serverConfirmed: serverConfirmed && _date(data['confirmedAt']) != null,
  );

  PaymentReversalRecord _reversalFromData(
    String id,
    Map<String, dynamic> data, {
    required bool serverConfirmed,
  }) => PaymentReversalRecord(
    id: id,
    businessId: data['businessId'] as String? ?? '',
    customerId: data['customerId'] as String? ?? '',
    paymentId: data['paymentId'] as String? ?? '',
    amountPaise: data['amountPaise'] as int? ?? 0,
    reason: data['reason'] as String? ?? '',
    reversedBy: data['reversedBy'] as String? ?? '',
    allocations: _allocations(data['allocations']),
    lastAuditId: data['lastAuditId'] as String? ?? '',
    reversedAt: _date(data['reversedAt']),
    serverConfirmed: serverConfirmed && _date(data['reversedAt']) != null,
  );

  void _verifyIdempotentPayment(
    Map<String, dynamic> data,
    AppUser actor,
    PaymentConfirmationInput input,
  ) {
    if (data['idempotencyKey'] != input.idempotencyKey ||
        data['amountPaise'] != input.amountPaise ||
        data['method'] != input.method.value ||
        data['externalReference'] != input.externalReference ||
        data['notes'] != input.notes ||
        data['collectorUid'] != actor.uid) {
      throw const AppException(
        'This payment retry key was already used for different details.',
        code: 'idempotency-conflict',
      );
    }
  }

  void _verifyIdempotentReversal(
    Map<String, dynamic> data,
    PaymentReversalInput input,
  ) {
    if (data['idempotencyKey'] != input.idempotencyKey ||
        data['paymentId'] != input.paymentId ||
        data['amountPaise'] != input.amountPaise ||
        data['reason'] != input.reason) {
      throw const AppException(
        'This reversal retry key was already used for different details.',
        code: 'idempotency-conflict',
      );
    }
  }

  OutstandingBill _outstandingBill(String id, Map<String, dynamic> data) =>
      OutstandingBill(
        billId: data['billId'] as String? ?? id,
        billingMonth: data['billingMonth'] as String? ?? id,
        sourceAmountPaise: data['sourceAmountPaise'] as int? ?? 0,
        allocatedPaise: data['allocatedPaise'] as int? ?? 0,
        reversedPaise: data['reversedPaise'] as int? ?? 0,
        outstandingPaise: data['outstandingPaise'] as int? ?? 0,
        status: data['status'] as String? ?? 'settled',
        revision: data['revision'] as int? ?? 0,
      );

  List<BillAllocation> _allocations(Object? value) =>
      value is List
          ? List.unmodifiable([
            for (final entry in value.whereType<Map>())
              BillAllocation.fromMap(entry.cast<String, Object?>()),
          ])
          : const [];

  List<PaymentAllocationState> _allocationStates(Object? value) =>
      value is List
          ? List.unmodifiable([
            for (final entry in value.whereType<Map>())
              PaymentAllocationState.fromMap(entry.cast<String, Object?>()),
          ])
          : const [];

  UpiSettings _upiSettingsFromData(
    Map<String, dynamic> data, {
    required bool serverConfirmed,
  }) => UpiSettings(
    businessId: data['businessId'] as String? ?? '',
    upiId: data['upiId'] as String? ?? '',
    payeeName: data['payeeName'] as String? ?? '',
    referencePrefix: data['referencePrefix'] as String? ?? 'PAPERROUTE',
    enabled: data['enabled'] == true,
    updatedBy: data['updatedBy'] as String? ?? '',
    lastAuditId: data['lastAuditId'] as String? ?? '',
    createdAt: _date(data['createdAt']),
    updatedAt: _date(data['updatedAt']),
    serverConfirmed: serverConfirmed,
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
      throw const AppException(
        'Only the Head can reverse payments or change UPI settings.',
      );
    }
    return businessId;
  }

  DateTime? _date(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime date => date,
    _ => null,
  };

  Map<String, Object?> _withDartDates(Map<String, dynamic> data) {
    final result = <String, Object?>{...data};
    for (final key in const ['createdAt', 'updatedAt']) {
      final value = result[key];
      if (value is Timestamp) result[key] = value.toDate();
    }
    return result;
  }

  AppException _translate(FirebaseException error, String fallback) {
    final message = switch (error.code) {
      'permission-denied' =>
        'Your membership, assignment, or collection permission no longer allows this action.',
      'failed-precondition' =>
        'This collection query needs a reviewed Firestore index.',
      'aborted' =>
        'The account balance changed while saving. Refresh and retry.',
      'unavailable' =>
        'A server connection is required to confirm financial activity.',
      _ => fallback,
    };
    return AppException(message, code: error.code);
  }
}

class _AllocationContext {
  const _AllocationContext({
    required this.stateExists,
    required this.outstandingPaise,
    required this.confirmedPaise,
    required this.reversedPaise,
    required this.revision,
    required this.bills,
  });

  final bool stateExists;
  final int outstandingPaise;
  final int confirmedPaise;
  final int reversedPaise;
  final int revision;
  final List<OutstandingBill> bills;

  Map<String, OutstandingBill> get byBillId => {
    for (final bill in bills) bill.billId: bill,
  };
}
