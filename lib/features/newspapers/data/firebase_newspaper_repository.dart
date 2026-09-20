import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/newspapers/domain/newspaper.dart';
import 'package:paper_route/features/newspapers/domain/newspaper_repository.dart';
import 'package:uuid/uuid.dart';

class FirebaseNewspaperRepository implements NewspaperRepository {
  FirebaseNewspaperRepository(this._firestore, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  factory FirebaseNewspaperRepository.fromDefaultApp() =>
      FirebaseNewspaperRepository(FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> _newspapers(String businessId) =>
      _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('newspapers');

  CollectionReference<Map<String, dynamic>> _priceRules(
    String businessId,
    String newspaperId,
  ) => _newspapers(businessId).doc(newspaperId).collection('priceRules');

  CollectionReference<Map<String, dynamic>> _audits(String businessId) =>
      _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('auditRecords');

  @override
  Future<NewspaperPage> fetchNewspapers(NewspaperListRequest request) async {
    if (request.pageSize < 1 || request.pageSize > 50) {
      throw const AppException('Newspaper page size must be between 1 and 50.');
    }
    if (request.businessId.isEmpty || request.requesterId.isEmpty) {
      throw const AppException('A valid business session is required.');
    }

    try {
      Query<Map<String, dynamic>> query = _newspapers(request.businessId)
          .where('businessId', isEqualTo: request.businessId)
          .where('status', isEqualTo: request.status.value);
      final searchToken = request.searchToken;
      if (request.isCodeSearch) {
        final snapshot =
            await query
                .where('newspaperCode', isEqualTo: searchToken)
                .limit(2)
                .get();
        return NewspaperPage(
          newspapers: snapshot.docs.map(_newspaperFromDocument).toList(),
          nextCursor: null,
          hasMore: false,
        );
      }

      query = query.orderBy('searchName').orderBy(FieldPath.documentId);
      if (searchToken != null) {
        query =
            request.cursor == null
                ? query.startAt([searchToken])
                : query.startAfter([
                  request.cursor!.searchName,
                  request.cursor!.newspaperId,
                ]);
        query = query.endAt(['$searchToken\uf8ff']);
      } else if (request.cursor != null) {
        query = query.startAfter([
          request.cursor!.searchName,
          request.cursor!.newspaperId,
        ]);
      }
      query = query.limit(request.pageSize + 1);

      final snapshot = await query.get();
      final hasMore = snapshot.docs.length > request.pageSize;
      final visible = snapshot.docs.take(request.pageSize).toList();
      final last = visible.isEmpty ? null : visible.last;
      return NewspaperPage(
        newspapers: visible.map(_newspaperFromDocument).toList(),
        nextCursor:
            last == null
                ? null
                : NewspaperPageCursor(
                  searchName: last.data()['searchName'] as String? ?? '',
                  newspaperId: last.id,
                ),
        hasMore: hasMore,
      );
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not load newspapers.');
    }
  }

  @override
  Stream<Newspaper?> watchNewspaper({
    required String businessId,
    required String newspaperId,
  }) => _newspapers(businessId)
      .doc(newspaperId)
      .snapshots()
      .map(
        (snapshot) => snapshot.exists ? _newspaperFromDocument(snapshot) : null,
      );

  @override
  Stream<List<NewspaperAuditEntry>> watchNewspaperHistory({
    required String businessId,
    required String newspaperId,
  }) => _audits(businessId)
      .where('entityType', isEqualTo: 'newspaper')
      .where('entityId', isEqualTo: newspaperId)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs
                .map(
                  (document) => NewspaperAuditEntry.fromMap(
                    document.id,
                    _withDartDates(document.data()),
                  ),
                )
                .toList(),
      );

  @override
  Future<String> createNewspaper({
    required AppUser actor,
    required NewspaperInput input,
  }) async {
    final businessId = _headBusinessId(actor);
    final value = input.normalized();
    value.validate();
    final newspaperId = 'N-${_uuid.v4().replaceAll('-', '').toUpperCase()}';
    final newspaperRef = _newspapers(businessId).doc(newspaperId);
    final auditRef = _audits(businessId).doc();

    try {
      await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(newspaperRef);
        if (existing.exists) {
          throw const AppException(
            'The generated newspaper code already exists. Try again.',
          );
        }
        final now = FieldValue.serverTimestamp();
        transaction.set(newspaperRef, {
          'businessId': businessId,
          'newspaperCode': newspaperId,
          'name': value.name,
          'searchName': NewspaperSearchIndex.normalizeText(value.name),
          'edition': value.edition,
          'language': value.language,
          'defaultPricePaise': value.defaultPricePaise,
          'status': NewspaperStatus.active.value,
          'createdBy': actor.uid,
          'updatedBy': actor.uid,
          'lastAuditId': auditRef.id,
          'createdAt': now,
          'updatedAt': now,
        });
        transaction.set(auditRef, {
          'businessId': businessId,
          'actorId': actor.uid,
          'action': 'newspaperCreated',
          'entityType': 'newspaper',
          'entityId': newspaperId,
          'defaultPricePaise': value.defaultPricePaise,
          'createdAt': now,
        });
      });
      return newspaperId;
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not create the newspaper.');
    } on Object {
      throw const AppException(
        'Could not create the newspaper. Reload and try again.',
        code: 'transaction-failed',
      );
    }
  }

  @override
  Future<void> updateNewspaperProfile({
    required AppUser actor,
    required String newspaperId,
    required NewspaperProfileInput input,
  }) async {
    final businessId = _headBusinessId(actor);
    final value = input.normalized();
    value.validate();
    final newspaperRef = _newspapers(businessId).doc(newspaperId);
    final auditRef = _audits(businessId).doc();

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(newspaperRef);
        final data = snapshot.data();
        _validateNewspaper(data, businessId);
        final updates = <String, Object?>{
          'name': value.name,
          'searchName': NewspaperSearchIndex.normalizeText(value.name),
          'edition': value.edition,
          'language': value.language,
        };
        final changedFields = <String>[
          for (final entry in updates.entries)
            if (data![entry.key] != entry.value) entry.key,
        ]..sort();
        if (changedFields.isEmpty) return;

        final now = FieldValue.serverTimestamp();
        transaction.update(newspaperRef, {
          ...updates,
          'updatedBy': actor.uid,
          'lastAuditId': auditRef.id,
          'updatedAt': now,
        });
        transaction.set(auditRef, {
          'businessId': businessId,
          'actorId': actor.uid,
          'action': 'newspaperUpdated',
          'entityType': 'newspaper',
          'entityId': newspaperId,
          'changedFields': changedFields,
          'createdAt': now,
        });
      });
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not update the newspaper.');
    } on Object {
      throw const AppException(
        'Could not update the newspaper. Reload and try again.',
        code: 'transaction-failed',
      );
    }
  }

  @override
  Future<void> setNewspaperArchived({
    required AppUser actor,
    required String newspaperId,
    required bool archived,
  }) async {
    final businessId = _headBusinessId(actor);
    final newspaperRef = _newspapers(businessId).doc(newspaperId);
    final auditRef = _audits(businessId).doc();
    final nextStatus =
        archived ? NewspaperStatus.archived : NewspaperStatus.active;

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(newspaperRef);
        final data = snapshot.data();
        _validateNewspaper(data, businessId);
        if (data!['status'] == nextStatus.value) return;
        final now = FieldValue.serverTimestamp();
        transaction.update(newspaperRef, {
          'status': nextStatus.value,
          'updatedBy': actor.uid,
          'lastAuditId': auditRef.id,
          'updatedAt': now,
        });
        transaction.set(auditRef, {
          'businessId': businessId,
          'actorId': actor.uid,
          'action': archived ? 'newspaperArchived' : 'newspaperReactivated',
          'entityType': 'newspaper',
          'entityId': newspaperId,
          'createdAt': now,
        });
      });
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not update newspaper status.');
    } on Object {
      throw const AppException(
        'Could not update newspaper status. Reload and try again.',
        code: 'transaction-failed',
      );
    }
  }

  @override
  Future<PriceRulePage> fetchPriceRules(PriceRuleListRequest request) async {
    if (request.pageSize < 1 || request.pageSize > 50) {
      throw const AppException(
        'Price-rule page size must be between 1 and 50.',
      );
    }
    if (request.businessId.isEmpty || request.newspaperId.isEmpty) {
      throw const AppException('A valid newspaper is required.');
    }
    try {
      Query<Map<String, dynamic>> query = _priceRules(
            request.businessId,
            request.newspaperId,
          )
          .where('businessId', isEqualTo: request.businessId)
          .where('newspaperId', isEqualTo: request.newspaperId)
          .orderBy('startDate', descending: true)
          .orderBy(FieldPath.documentId, descending: true)
          .limit(request.pageSize + 1);
      final cursor = request.cursor;
      if (cursor != null) {
        query = query.startAfter([cursor.startDate.toString(), cursor.ruleId]);
      }
      final snapshot = await query.get();
      final hasMore = snapshot.docs.length > request.pageSize;
      final visible = snapshot.docs.take(request.pageSize).toList();
      final last = visible.isEmpty ? null : visible.last;
      return PriceRulePage(
        rules: visible.map(_priceRuleFromDocument).toList(),
        nextCursor:
            last == null
                ? null
                : PriceRulePageCursor(
                  startDate: LocalDate.parse(
                    last.data()['startDate'] as String? ?? '',
                  ),
                  ruleId: last.id,
                ),
        hasMore: hasMore,
      );
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not load price history.');
    }
  }

  @override
  Future<String> createPriceRule({
    required AppUser actor,
    required String newspaperId,
    required PriceRuleInput input,
  }) => _writePriceRule(
    actor: actor,
    newspaperId: newspaperId,
    input: input,
    replacedRuleId: null,
  );

  @override
  Future<String> correctPriceRule({
    required AppUser actor,
    required String newspaperId,
    required String replacedRuleId,
    required PriceRuleInput replacement,
  }) => _writePriceRule(
    actor: actor,
    newspaperId: newspaperId,
    input: replacement,
    replacedRuleId: replacedRuleId,
  );

  Future<String> _writePriceRule({
    required AppUser actor,
    required String newspaperId,
    required PriceRuleInput input,
    required String? replacedRuleId,
  }) async {
    final businessId = _headBusinessId(actor);
    final value = input.normalized();
    value.validate();
    final newspaperRef = _newspapers(businessId).doc(newspaperId);
    final initialNewspaper = await newspaperRef.get();
    final initialData = initialNewspaper.data();
    _validateNewspaper(initialData, businessId);
    if (replacedRuleId == null && initialData!['status'] != 'active') {
      throw const AppException(
        'Reactivate this newspaper before adding a new price rule.',
      );
    }

    final conflicts = await _conflictingRules(
      businessId: businessId,
      newspaperId: newspaperId,
      input: value,
    );
    final relevantConflicts =
        conflicts.where((document) => document.id != replacedRuleId).toList();
    if (relevantConflicts.isNotEmpty) {
      throw AppException(
        value.kind == PriceRuleKind.exactDate
            ? 'An active exact-date price already exists for ${value.startDate}.'
            : 'This effective period overlaps another active period.',
      );
    }

    final expectedLock = initialData!['lastAuditId'] as String? ?? '';
    final replacementId = _uuid.v4().replaceAll('-', '').toUpperCase();
    final replacementRef = _priceRules(
      businessId,
      newspaperId,
    ).doc(replacementId);
    final replacedRef =
        replacedRuleId == null
            ? null
            : _priceRules(businessId, newspaperId).doc(replacedRuleId);
    final auditRef = _audits(businessId).doc();

    try {
      await _firestore.runTransaction((transaction) async {
        final currentNewspaper = await transaction.get(newspaperRef);
        final currentData = currentNewspaper.data();
        _validateNewspaper(currentData, businessId);
        if (currentData!['lastAuditId'] != expectedLock) {
          throw const AppException(
            'Pricing changed while this form was open. Reload and try again.',
          );
        }

        for (final conflict in relevantConflicts) {
          final currentConflict = await transaction.get(conflict.reference);
          if (currentConflict.data()?['status'] == 'active') {
            throw const AppException(
              'A conflicting price rule was created. Reload and try again.',
            );
          }
        }

        var revision = 1;
        if (replacedRef != null) {
          final replaced = await transaction.get(replacedRef);
          final replacedData = replaced.data();
          if (!replaced.exists ||
              replacedData == null ||
              replacedData['businessId'] != businessId ||
              replacedData['newspaperId'] != newspaperId ||
              replacedData['status'] != PriceRuleStatus.active.value) {
            throw const AppException(
              'The price rule is no longer active. Reload and try again.',
            );
          }
          revision = (replacedData['revision'] as int? ?? 1) + 1;
          transaction.update(replacedRef, {
            'status': PriceRuleStatus.superseded.value,
            'supersededByRuleId': replacementId,
            'updatedBy': actor.uid,
            'lastAuditId': auditRef.id,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        final now = FieldValue.serverTimestamp();
        transaction.set(replacementRef, {
          'businessId': businessId,
          'newspaperId': newspaperId,
          'priceRuleId': replacementId,
          'kind': value.kind.value,
          'startDate': value.startDate.toString(),
          'endDate': value.endDate?.toString(),
          'pricePaise': value.pricePaise,
          'status': PriceRuleStatus.active.value,
          'supersedesRuleId': replacedRuleId ?? '',
          'supersededByRuleId': '',
          'revision': revision,
          'reason': value.reason,
          'createdBy': actor.uid,
          'updatedBy': actor.uid,
          'lastAuditId': auditRef.id,
          'createdAt': now,
          'updatedAt': now,
        });
        transaction.update(newspaperRef, {
          'updatedBy': actor.uid,
          'lastAuditId': auditRef.id,
          'updatedAt': now,
        });
        transaction.set(auditRef, {
          'businessId': businessId,
          'actorId': actor.uid,
          'action':
              replacedRuleId == null
                  ? 'newspaperPriceRuleCreated'
                  : 'newspaperPriceRuleCorrected',
          'entityType': 'newspaper',
          'entityId': newspaperId,
          'priceRuleId': replacementId,
          'replacedPriceRuleId': replacedRuleId ?? '',
          'kind': value.kind.value,
          'startDate': value.startDate.toString(),
          'endDate': value.endDate?.toString(),
          'pricePaise': value.pricePaise,
          'reason': value.reason,
          'createdAt': now,
        });
      });
      return replacementId;
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not save the price rule.');
    } on Object {
      throw const AppException(
        'Could not save the price rule. Reload and try again.',
        code: 'transaction-failed',
      );
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _conflictingRules({
    required String businessId,
    required String newspaperId,
    required PriceRuleInput input,
  }) async {
    Query<Map<String, dynamic>> query = _priceRules(businessId, newspaperId)
        .where('businessId', isEqualTo: businessId)
        .where('newspaperId', isEqualTo: newspaperId)
        .where('kind', isEqualTo: input.kind.value)
        .where('status', isEqualTo: PriceRuleStatus.active.value);
    if (input.kind == PriceRuleKind.exactDate) {
      query = query.where('startDate', isEqualTo: input.startDate.toString());
    } else {
      query = query
          .where(
            'startDate',
            isLessThanOrEqualTo: input.effectiveEnd.toString(),
          )
          .where('endDate', isGreaterThanOrEqualTo: input.startDate.toString());
    }
    return (await query.limit(10).get()).docs;
  }

  @override
  Future<ResolvedNewspaperPrice> resolvePriceOn({
    required String businessId,
    required String newspaperId,
    required LocalDate date,
  }) async {
    if (businessId.isEmpty || newspaperId.isEmpty) {
      throw const AppException('A valid newspaper is required.');
    }
    try {
      final newspaper = await _newspapers(businessId).doc(newspaperId).get();
      final newspaperData = newspaper.data();
      _validateNewspaper(newspaperData, businessId);
      final rules = _priceRules(businessId, newspaperId);
      final snapshots = await Future.wait([
        rules
            .where('businessId', isEqualTo: businessId)
            .where('newspaperId', isEqualTo: newspaperId)
            .where('kind', isEqualTo: PriceRuleKind.exactDate.value)
            .where('status', isEqualTo: PriceRuleStatus.active.value)
            .where('startDate', isEqualTo: date.toString())
            .limit(2)
            .get(),
        rules
            .where('businessId', isEqualTo: businessId)
            .where('newspaperId', isEqualTo: newspaperId)
            .where('kind', isEqualTo: PriceRuleKind.period.value)
            .where('status', isEqualTo: PriceRuleStatus.active.value)
            .where('startDate', isLessThanOrEqualTo: date.toString())
            .where('endDate', isGreaterThanOrEqualTo: date.toString())
            .limit(2)
            .get(),
      ]);
      final applicable = <NewspaperPriceRule>[
        for (final snapshot in snapshots)
          ...snapshot.docs.map(_priceRuleFromDocument),
      ];
      return DateSpecificPriceResolver.resolve(
        defaultPricePaise: newspaperData!['defaultPricePaise'] as int? ?? 0,
        date: date,
        rules: applicable,
      );
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not resolve the price for this date.');
    }
  }

  String _headBusinessId(AppUser actor) {
    final businessId = actor.businessId;
    if (!actor.hasActiveAccess || businessId == null || businessId.isEmpty) {
      throw const AppException('Your business access is no longer active.');
    }
    if (!actor.isHead) {
      throw const AppException(
        'Only the Head can change newspapers and pricing.',
      );
    }
    return businessId;
  }

  void _validateNewspaper(Map<String, dynamic>? data, String businessId) {
    if (data == null) {
      throw const AppException('The newspaper no longer exists.');
    }
    if (data['businessId'] != businessId) {
      throw const AppException('Newspaper does not belong to this business.');
    }
  }

  Newspaper _newspaperFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) => Newspaper.fromMap(
    document.id,
    _withDartDates(document.data() ?? const {}),
  );

  NewspaperPriceRule _priceRuleFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) => NewspaperPriceRule.fromMap(
    document.id,
    _withDartDates(document.data() ?? const {}),
  );

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
        'Your membership does not permit this newspaper action.',
      'failed-precondition' =>
        'This newspaper query needs a reviewed Firestore index before deployment.',
      'unavailable' =>
        'Newspaper changes require a server connection. Check your network and retry.',
      _ => fallback,
    };
    return AppException(message, code: error.code);
  }
}
