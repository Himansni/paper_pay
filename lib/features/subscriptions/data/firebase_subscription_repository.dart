import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/subscriptions/domain/customer_subscription.dart';
import 'package:paper_route/features/subscriptions/domain/subscription_repository.dart';
import 'package:uuid/uuid.dart';

// Subscriptions are nested below their customer:
// businesses/{businessId}/customers/{customerId}/subscriptions/{newspaperId}.
// Versions and pauses are child collections; business audit records provide a
// separate append-only explanation of significant actions.
class FirebaseSubscriptionRepository implements SubscriptionRepository {
  FirebaseSubscriptionRepository(this._firestore, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  factory FirebaseSubscriptionRepository.fromDefaultApp() =>
      FirebaseSubscriptionRepository(FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  DocumentReference<Map<String, dynamic>> _customer(
    String businessId,
    String customerId,
  ) => _firestore
      .collection('businesses')
      .doc(businessId)
      .collection('customers')
      .doc(customerId);

  CollectionReference<Map<String, dynamic>> _subscriptions(
    String businessId,
    String customerId,
  ) => _customer(businessId, customerId).collection('subscriptions');

  DocumentReference<Map<String, dynamic>> _subscription(
    String businessId,
    String customerId,
    String subscriptionId,
  ) => _subscriptions(businessId, customerId).doc(subscriptionId);

  DocumentReference<Map<String, dynamic>> _newspaper(
    String businessId,
    String newspaperId,
  ) => _firestore
      .collection('businesses')
      .doc(businessId)
      .collection('newspapers')
      .doc(newspaperId);

  DocumentReference<Map<String, dynamic>> _serviceBillingSource(
    String businessId,
    String customerId,
  ) => _customer(
    businessId,
    customerId,
  ).collection('billingSources').doc('service');

  CollectionReference<Map<String, dynamic>> _audits(String businessId) =>
      _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('auditRecords');

  // The current projection is streamed for responsive UI, while version and
  // pause providers independently expose the dated history.
  @override
  Stream<List<CustomerSubscription>> watchCustomerSubscriptions({
    required String businessId,
    required String customerId,
  }) => _subscriptions(businessId, customerId)
      .orderBy('startDate', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(
              (doc) => CustomerSubscription.fromMap(
                doc.id,
                _withDartDates(doc.data()),
              ),
            )
            .toList(growable: false),
      );

  @override
  Stream<CustomerSubscription?> watchSubscription({
    required String businessId,
    required String customerId,
    required String subscriptionId,
  }) => _subscription(businessId, customerId, subscriptionId).snapshots().map(
    (snapshot) =>
        snapshot.exists
            ? CustomerSubscription.fromMap(
              snapshot.id,
              _withDartDates(snapshot.data() ?? {}),
            )
            : null,
  );

  @override
  Stream<List<SubscriptionVersion>> watchVersions({
    required String businessId,
    required String customerId,
    required String subscriptionId,
  }) => _subscription(businessId, customerId, subscriptionId)
      .collection('versions')
      .orderBy('effectiveFrom', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(
              (doc) => SubscriptionVersion.fromMap(
                doc.id,
                _withDartDates(doc.data()),
              ),
            )
            .toList(growable: false),
      );

  @override
  Stream<List<SubscriptionPause>> watchPauses({
    required String businessId,
    required String customerId,
    required String subscriptionId,
  }) => _subscription(businessId, customerId, subscriptionId)
      .collection('pauses')
      .orderBy('startDate', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(
              (doc) =>
                  SubscriptionPause.fromMap(doc.id, _withDartDates(doc.data())),
            )
            .toList(growable: false),
      );

  @override
  Stream<List<SubscriptionAuditEntry>> watchHistory({
    required String businessId,
    required String customerId,
    required String subscriptionId,
  }) => _audits(businessId)
      .where('entityType', isEqualTo: 'subscription')
      .where('entityId', isEqualTo: '$customerId:$subscriptionId')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(
              (doc) => SubscriptionAuditEntry.fromMap(
                doc.id,
                _withDartDates(doc.data()),
              ),
            )
            .toList(growable: false),
      );

  @override
  Future<String> createSubscription({
    required AppUser actor,
    required String customerId,
    required SubscriptionInput input,
  }) async {
    final businessId = _businessId(actor);
    final value = input.normalized();
    value.validate();
    // Customer-specific prices bypass normal catalog precedence, so employees
    // cannot create them. Firestore Rules repeat this security boundary.
    if (!actor.isHead && value.customPricePaise != null) {
      throw const AppException(
        'Only the Head can authorize customer-specific pricing.',
      );
    }

    // One stable series per customer/newspaper. Quantity represents copies and
    // a term version records every later configuration change.
    final subscriptionId = value.newspaperId;
    final subscriptionRef = _subscription(
      businessId,
      customerId,
      subscriptionId,
    );
    final versionId = 'V-${_uuid.v4().replaceAll('-', '').toUpperCase()}';
    final versionRef = subscriptionRef.collection('versions').doc(versionId);
    final auditRef = _audits(businessId).doc();
    final billingSourceRef = _serviceBillingSource(businessId, customerId);

    try {
      // The current projection, first version, audit, and billing-source
      // revision commit together so downstream billing never sees half a change.
      await _firestore.runTransaction((transaction) async {
        final customerSnapshot = await transaction.get(
          _customer(businessId, customerId),
        );
        final newspaperSnapshot = await transaction.get(
          _newspaper(businessId, value.newspaperId),
        );
        final existing = await transaction.get(subscriptionRef);
        final billingSource = await transaction.get(billingSourceRef);
        _validateManageableCustomer(
          actor,
          customerSnapshot,
          requireActive: true,
        );
        final newspaperData = newspaperSnapshot.data();
        if (!newspaperSnapshot.exists ||
            newspaperData == null ||
            newspaperData['businessId'] != businessId ||
            newspaperData['status'] != 'active') {
          throw const AppException('Select an active newspaper.');
        }
        if (existing.exists) {
          throw const AppException(
            'This customer already has a history for that newspaper. Restart or change the existing subscription.',
          );
        }

        final now = FieldValue.serverTimestamp();
        final newspaperName = newspaperData['name'] as String? ?? '';
        final billingSourceData = billingSource.data();
        final billingSourceRevision =
            (billingSourceData?['revision'] as int? ?? 0) + 1;
        transaction.set(subscriptionRef, {
          'businessId': businessId,
          'customerId': customerId,
          'subscriptionId': subscriptionId,
          'newspaperId': value.newspaperId,
          'newspaperName': newspaperName,
          'currentVersionId': versionId,
          'currentPauseId': '',
          'status': SubscriptionStatus.active.value,
          'startDate': value.startDate.toString(),
          'endDate': value.endDate?.toString(),
          'currentEffectiveFrom': value.startDate.toString(),
          'quantity': value.quantity,
          'deliveryWeekdays': _sortedWeekdays(value.deliveryWeekdays),
          'customPricePaise': value.customPricePaise,
          'customPriceReason': value.customPriceReason,
          'createdBy': actor.uid,
          'updatedBy': actor.uid,
          'lastAuditId': auditRef.id,
          'createdAt': now,
          'updatedAt': now,
        });
        transaction.set(
          versionRef,
          _versionData(
            businessId: businessId,
            customerId: customerId,
            subscriptionId: subscriptionId,
            versionId: versionId,
            newspaperId: value.newspaperId,
            effectiveFrom: value.startDate,
            input: value,
            predecessorVersionId: '',
            actorId: actor.uid,
            auditId: auditRef.id,
            now: now,
          ),
        );
        transaction.set(
          auditRef,
          _auditData(
            businessId: businessId,
            customerId: customerId,
            subscriptionId: subscriptionId,
            actorId: actor.uid,
            action: 'subscriptionCreated',
            auditId: auditRef.id,
            now: now,
            extra: {'newspaperId': value.newspaperId, 'versionId': versionId},
          ),
        );
        transaction.set(billingSourceRef, {
          'businessId': businessId,
          'customerId': customerId,
          'sourceId': 'service',
          'revision': billingSourceRevision,
          'lastMutationType': 'subscriptionCreated',
          'lastMutationId': subscriptionId,
          'updatedBy': actor.uid,
          'createdAt': billingSourceData?['createdAt'] ?? now,
          'updatedAt': now,
        });
      });
      return subscriptionId;
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not create the subscription.');
    } on Object {
      throw const AppException(
        'Could not create the subscription. Reload and try again.',
        code: 'transaction-failed',
      );
    }
  }

  @override
  Future<void> replaceTerms({
    required AppUser actor,
    required String customerId,
    required String subscriptionId,
    required LocalDate effectiveFrom,
    required SubscriptionInput replacement,
  }) async {
    final businessId = _businessId(actor);
    final value = replacement.normalized();
    final subscriptionRef = _subscription(
      businessId,
      customerId,
      subscriptionId,
    );
    final nextVersionId = 'V-${_uuid.v4().replaceAll('-', '').toUpperCase()}';
    final nextVersionRef = subscriptionRef
        .collection('versions')
        .doc(nextVersionId);
    final auditRef = _audits(businessId).doc();

    try {
      await _firestore.runTransaction((transaction) async {
        final customerSnapshot = await transaction.get(
          _customer(businessId, customerId),
        );
        final newspaperSnapshot = await transaction.get(
          _newspaper(businessId, value.newspaperId),
        );
        final subscriptionSnapshot = await transaction.get(subscriptionRef);
        final subscriptionData = subscriptionSnapshot.data();
        _validateManageableCustomer(
          actor,
          customerSnapshot,
          requireActive: true,
        );
        if (!subscriptionSnapshot.exists || subscriptionData == null) {
          throw const AppException('Subscription no longer exists.');
        }
        final current = CustomerSubscription.fromMap(
          subscriptionSnapshot.id,
          _withDartDates(subscriptionData),
        );
        // Changing active terms closes the current version. Restarting an ended
        // series opens a new service period while leaving its closed history intact.
        final restarting = current.isEnded;
        if (restarting) {
          value.validate();
          if (current.endDate == null ||
              !effectiveFrom.isAfter(current.endDate!)) {
            throw const AppException(
              'A restarted subscription must begin after the previous end date.',
            );
          }
        } else {
          validateReplacement(
            current: current,
            effectiveFrom: effectiveFrom,
            replacement: value,
          );
        }
        if (current.isPaused) {
          throw const AppException(
            'Resume the subscription before changing terms.',
          );
        }
        // Employees may change permitted delivery terms, but only the Head may
        // introduce or alter a customer-specific price exception.
        if (!actor.isHead &&
            (value.customPricePaise != current.customPricePaise ||
                value.customPriceReason != current.customPriceReason)) {
          throw const AppException(
            'Only the Head can change customer-specific pricing.',
          );
        }
        final newspaperData = newspaperSnapshot.data();
        if (!newspaperSnapshot.exists ||
            newspaperData == null ||
            newspaperData['businessId'] != businessId ||
            newspaperData['status'] != 'active') {
          throw const AppException(
            'New terms require an active newspaper. Existing archived-paper history remains readable.',
          );
        }

        final currentVersionId =
            subscriptionData['currentVersionId'] as String? ?? '';
        final currentVersionRef = subscriptionRef
            .collection('versions')
            .doc(currentVersionId);
        final currentVersionSnapshot = await transaction.get(currentVersionRef);
        final currentVersionData = currentVersionSnapshot.data();
        if (!currentVersionSnapshot.exists || currentVersionData == null) {
          throw const AppException('Current subscription terms are missing.');
        }
        if (!restarting && currentVersionData['effectiveTo'] != null) {
          throw const AppException(
            'Current subscription terms are already closed.',
          );
        }

        final now = FieldValue.serverTimestamp();
        if (!restarting) {
          transaction.update(currentVersionRef, {
            'effectiveTo': effectiveFrom.addDays(-1).toString(),
            'successorVersionId': nextVersionId,
            'status': 'closed',
            'updatedBy': actor.uid,
            'lastAuditId': auditRef.id,
            'updatedAt': now,
          });
        }
        transaction.set(
          nextVersionRef,
          _versionData(
            businessId: businessId,
            customerId: customerId,
            subscriptionId: subscriptionId,
            versionId: nextVersionId,
            newspaperId: value.newspaperId,
            effectiveFrom: effectiveFrom,
            input: value,
            predecessorVersionId: currentVersionId,
            actorId: actor.uid,
            auditId: auditRef.id,
            now: now,
          ),
        );
        transaction.update(subscriptionRef, {
          'currentVersionId': nextVersionId,
          'status': SubscriptionStatus.active.value,
          if (restarting) 'startDate': effectiveFrom.toString(),
          'endDate': value.endDate?.toString(),
          'currentEffectiveFrom': effectiveFrom.toString(),
          'quantity': value.quantity,
          'deliveryWeekdays': _sortedWeekdays(value.deliveryWeekdays),
          'customPricePaise': value.customPricePaise,
          'customPriceReason': value.customPriceReason,
          'updatedBy': actor.uid,
          'lastAuditId': auditRef.id,
          'updatedAt': now,
        });
        transaction.set(
          auditRef,
          _auditData(
            businessId: businessId,
            customerId: customerId,
            subscriptionId: subscriptionId,
            actorId: actor.uid,
            action:
                restarting
                    ? 'subscriptionRestarted'
                    : 'subscriptionTermsChanged',
            auditId: auditRef.id,
            now: now,
            extra: {
              'previousVersionId': currentVersionId,
              'versionId': nextVersionId,
              'effectiveFrom': effectiveFrom.toString(),
              'changedFields': <String>[
                'quantity',
                'deliveryWeekdays',
                'endDate',
                'customPricePaise',
                'customPriceReason',
              ],
            },
          ),
        );
      });
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not change subscription terms.');
    } on Object {
      throw const AppException(
        'Could not change subscription terms. Reload and try again.',
        code: 'transaction-failed',
      );
    }
  }

  @override
  Future<void> addPause({
    required AppUser actor,
    required String customerId,
    required String subscriptionId,
    required LocalDate startDate,
    required LocalDate? endDate,
    required String reason,
  }) async {
    final businessId = _businessId(actor);
    final pauseId = 'P-${_uuid.v4().replaceAll('-', '').toUpperCase()}';
    final subscriptionRef = _subscription(
      businessId,
      customerId,
      subscriptionId,
    );
    final pauseRef = subscriptionRef.collection('pauses').doc(pauseId);
    final auditRef = _audits(businessId).doc();

    try {
      final initialSubscription = await subscriptionRef.get();
      final initialData = initialSubscription.data();
      if (!initialSubscription.exists || initialData == null) {
        throw const AppException('Subscription no longer exists.');
      }
      // The last audit ID acts as an optimistic lock. If another lifecycle
      // change wins first, this pause is rejected instead of using stale state.
      final expectedLock = initialData['lastAuditId'] as String? ?? '';
      final existingPauses =
          await subscriptionRef.collection('pauses').limit(100).get();
      final parsedPauses =
          existingPauses.docs
              .map(
                (doc) => SubscriptionPause.fromMap(
                  doc.id,
                  _withDartDates(doc.data()),
                ),
              )
              .toList();
      await _firestore.runTransaction((transaction) async {
        final customerSnapshot = await transaction.get(
          _customer(businessId, customerId),
        );
        final subscriptionSnapshot = await transaction.get(subscriptionRef);
        final data = subscriptionSnapshot.data();
        _validateManageableCustomer(
          actor,
          customerSnapshot,
          requireActive: true,
        );
        if (!subscriptionSnapshot.exists || data == null) {
          throw const AppException('Subscription no longer exists.');
        }
        if (data['lastAuditId'] != expectedLock) {
          throw const AppException(
            'Subscription history changed while this pause was being saved. Reload and try again.',
          );
        }
        final subscription = CustomerSubscription.fromMap(
          subscriptionSnapshot.id,
          _withDartDates(data),
        );
        validatePausePeriod(
          subscription: subscription,
          startDate: startDate,
          endDate: endDate,
          reason: reason,
          existingPauses: parsedPauses,
        );
        if (endDate == null && !subscription.isActive) {
          throw const AppException(
            'Only an active subscription can begin an open pause.',
          );
        }

        final now = FieldValue.serverTimestamp();
        transaction.set(pauseRef, {
          'businessId': businessId,
          'customerId': customerId,
          'subscriptionId': subscriptionId,
          'pauseId': pauseId,
          'startDate': startDate.toString(),
          'endDate': endDate?.toString(),
          'reason': reason.trim(),
          'status': endDate == null ? 'open' : 'closed',
          'createdBy': actor.uid,
          'updatedBy': actor.uid,
          'lastAuditId': auditRef.id,
          'createdAt': now,
          'updatedAt': now,
        });
        transaction.update(subscriptionRef, {
          if (endDate == null) 'status': SubscriptionStatus.paused.value,
          if (endDate == null) 'currentPauseId': pauseId,
          'updatedBy': actor.uid,
          'lastAuditId': auditRef.id,
          'updatedAt': now,
        });
        transaction.set(
          auditRef,
          _auditData(
            businessId: businessId,
            customerId: customerId,
            subscriptionId: subscriptionId,
            actorId: actor.uid,
            action: 'subscriptionPauseAdded',
            auditId: auditRef.id,
            now: now,
            extra: {
              'pauseId': pauseId,
              'startDate': startDate.toString(),
              'endDate': endDate?.toString(),
            },
          ),
        );
      });
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not add the subscription pause.');
    } on Object {
      throw const AppException(
        'Could not add the subscription pause. Reload and try again.',
        code: 'transaction-failed',
      );
    }
  }

  @override
  Future<void> resumeSubscription({
    required AppUser actor,
    required String customerId,
    required String subscriptionId,
    required String pauseId,
    required LocalDate resumeDate,
  }) async {
    final businessId = _businessId(actor);
    final subscriptionRef = _subscription(
      businessId,
      customerId,
      subscriptionId,
    );
    final pauseRef = subscriptionRef.collection('pauses').doc(pauseId);
    final auditRef = _audits(businessId).doc();

    try {
      await _firestore.runTransaction((transaction) async {
        final customerSnapshot = await transaction.get(
          _customer(businessId, customerId),
        );
        final subscriptionSnapshot = await transaction.get(subscriptionRef);
        final pauseSnapshot = await transaction.get(pauseRef);
        _validateManageableCustomer(
          actor,
          customerSnapshot,
          requireActive: true,
        );
        final subscriptionData = subscriptionSnapshot.data();
        final pauseData = pauseSnapshot.data();
        if (!subscriptionSnapshot.exists || subscriptionData == null) {
          throw const AppException('Subscription no longer exists.');
        }
        if (subscriptionData['status'] != SubscriptionStatus.paused.value ||
            !pauseSnapshot.exists ||
            pauseData == null ||
            pauseData['status'] != 'open' ||
            pauseData['endDate'] != null) {
          throw const AppException('No matching open pause can be resumed.');
        }
        final pauseStart = LocalDate.parse(pauseData['startDate'] as String);
        if (!resumeDate.isAfter(pauseStart)) {
          throw const AppException(
            'Resume date must be after the pause start date.',
          );
        }
        // Deliveries resume on resumeDate, so the inclusive pause ends on the
        // preceding date.
        final pauseEnd = resumeDate.addDays(-1);
        final now = FieldValue.serverTimestamp();
        transaction.update(pauseRef, {
          'endDate': pauseEnd.toString(),
          'status': 'closed',
          'updatedBy': actor.uid,
          'lastAuditId': auditRef.id,
          'updatedAt': now,
        });
        transaction.update(subscriptionRef, {
          'status': SubscriptionStatus.active.value,
          'currentPauseId': '',
          'updatedBy': actor.uid,
          'lastAuditId': auditRef.id,
          'updatedAt': now,
        });
        transaction.set(
          auditRef,
          _auditData(
            businessId: businessId,
            customerId: customerId,
            subscriptionId: subscriptionId,
            actorId: actor.uid,
            action: 'subscriptionResumed',
            auditId: auditRef.id,
            now: now,
            extra: {'pauseId': pauseId, 'resumeDate': resumeDate.toString()},
          ),
        );
      });
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not resume the subscription.');
    } on Object {
      throw const AppException(
        'Could not resume the subscription. Reload and try again.',
        code: 'transaction-failed',
      );
    }
  }

  @override
  Future<void> endSubscription({
    required AppUser actor,
    required String customerId,
    required String subscriptionId,
    required LocalDate endDate,
  }) async {
    final businessId = _businessId(actor);
    final subscriptionRef = _subscription(
      businessId,
      customerId,
      subscriptionId,
    );
    final auditRef = _audits(businessId).doc();

    try {
      await _firestore.runTransaction((transaction) async {
        final customerSnapshot = await transaction.get(
          _customer(businessId, customerId),
        );
        final subscriptionSnapshot = await transaction.get(subscriptionRef);
        final data = subscriptionSnapshot.data();
        _validateManageableCustomer(
          actor,
          customerSnapshot,
          requireActive: !actor.isHead,
        );
        if (!subscriptionSnapshot.exists || data == null) {
          throw const AppException('Subscription no longer exists.');
        }
        final subscription = CustomerSubscription.fromMap(
          subscriptionSnapshot.id,
          _withDartDates(data),
        );
        validateEndDate(subscription, endDate);
        final versionId = data['currentVersionId'] as String? ?? '';
        final versionRef = subscriptionRef
            .collection('versions')
            .doc(versionId);
        final version = await transaction.get(versionRef);
        if (!version.exists || version.data() == null) {
          throw const AppException('Current subscription terms are missing.');
        }
        final effectiveFrom = LocalDate.parse(
          version.data()!['effectiveFrom'] as String,
        );
        if (endDate.isBefore(effectiveFrom)) {
          throw const AppException(
            'End date cannot be before the current terms became effective.',
          );
        }

        final now = FieldValue.serverTimestamp();
        // Ending closes both the active terms and any open pause. The records
        // remain available as history; no subscription data is deleted.
        final currentPauseId = data['currentPauseId'] as String? ?? '';
        if (currentPauseId.isNotEmpty) {
          final pauseRef = subscriptionRef
              .collection('pauses')
              .doc(currentPauseId);
          final pause = await transaction.get(pauseRef);
          final pauseData = pause.data();
          if (!pause.exists ||
              pauseData == null ||
              pauseData['status'] != 'open' ||
              pauseData['endDate'] != null) {
            throw const AppException('The open pause record is inconsistent.');
          }
          final pauseStart = LocalDate.parse(pauseData['startDate'] as String);
          if (endDate.isBefore(pauseStart)) {
            throw const AppException(
              'End date cannot be before the current pause begins.',
            );
          }
          transaction.update(pauseRef, {
            'endDate': endDate.toString(),
            'status': 'closed',
            'updatedBy': actor.uid,
            'lastAuditId': auditRef.id,
            'updatedAt': now,
          });
        }
        transaction.update(versionRef, {
          'effectiveTo': endDate.toString(),
          'status': 'closed',
          'updatedBy': actor.uid,
          'lastAuditId': auditRef.id,
          'updatedAt': now,
        });
        transaction.update(subscriptionRef, {
          'status': SubscriptionStatus.ended.value,
          'endDate': endDate.toString(),
          'currentPauseId': '',
          'updatedBy': actor.uid,
          'lastAuditId': auditRef.id,
          'updatedAt': now,
        });
        transaction.set(
          auditRef,
          _auditData(
            businessId: businessId,
            customerId: customerId,
            subscriptionId: subscriptionId,
            actorId: actor.uid,
            action: 'subscriptionEnded',
            auditId: auditRef.id,
            now: now,
            extra: {'endDate': endDate.toString(), 'versionId': versionId},
          ),
        );
      });
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not end the subscription.');
    } on Object {
      throw const AppException(
        'Could not end the subscription. Reload and try again.',
        code: 'transaction-failed',
      );
    }
  }

  Map<String, Object?> _versionData({
    required String businessId,
    required String customerId,
    required String subscriptionId,
    required String versionId,
    required String newspaperId,
    required LocalDate effectiveFrom,
    required SubscriptionInput input,
    required String predecessorVersionId,
    required String actorId,
    required String auditId,
    required Object now,
  }) => {
    'businessId': businessId,
    'customerId': customerId,
    'subscriptionId': subscriptionId,
    'versionId': versionId,
    'newspaperId': newspaperId,
    'effectiveFrom': effectiveFrom.toString(),
    'effectiveTo': null,
    'quantity': input.quantity,
    'deliveryWeekdays': _sortedWeekdays(input.deliveryWeekdays),
    'customPricePaise': input.customPricePaise,
    'customPriceReason': input.customPriceReason,
    'predecessorVersionId': predecessorVersionId,
    'successorVersionId': '',
    'status': 'current',
    'createdBy': actorId,
    'updatedBy': actorId,
    'lastAuditId': auditId,
    'createdAt': now,
    'updatedAt': now,
  };

  Map<String, Object?> _auditData({
    required String businessId,
    required String customerId,
    required String subscriptionId,
    required String actorId,
    required String action,
    required String auditId,
    required Object now,
    Map<String, Object?> extra = const {},
  }) => {
    'businessId': businessId,
    'actorId': actorId,
    'action': action,
    'entityType': 'subscription',
    'entityId': '$customerId:$subscriptionId',
    'customerId': customerId,
    'subscriptionId': subscriptionId,
    'auditId': auditId,
    ...extra,
    'createdAt': now,
  };

  List<int> _sortedWeekdays(Set<int> weekdays) => weekdays.toList()..sort();

  String _businessId(AppUser actor) {
    final businessId = actor.businessId;
    if (!actor.hasActiveAccess || businessId == null || businessId.isEmpty) {
      throw const AppException('Your business access is no longer active.');
    }
    return businessId;
  }

  void _validateManageableCustomer(
    AppUser actor,
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    required bool requireActive,
  }) {
    final data = snapshot.data();
    if (!snapshot.exists ||
        data == null ||
        data['businessId'] != actor.businessId) {
      throw const AppException('Customer no longer exists in this business.');
    }
    if (requireActive && data['status'] != 'active') {
      throw const AppException(
        'Subscriptions cannot be changed for an archived customer.',
      );
    }
    // BEGINNER NOTE:
    // The UI and repository check assignment, area, and permission for helpful
    // feedback. Firestore Rules remain the final server-side authority.
    if (!actor.isHead &&
        (data['assignedEmployeeId'] != actor.uid ||
            !actor.areaIds.contains(data['areaId']) ||
            !actor.permissions.contains(
              PermissionKey.manageAssignedSubscriptions,
            ))) {
      throw const AppException(
        'You are not permitted to manage this customer subscription.',
      );
    }
  }

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
        'Your current membership does not permit this subscription action.',
      'failed-precondition' =>
        'This subscription query needs a reviewed Firestore index before deployment.',
      'unavailable' =>
        'Subscription changes require a server connection. Check your network and retry.',
      _ => fallback,
    };
    return AppException(message, code: error.code);
  }
}
