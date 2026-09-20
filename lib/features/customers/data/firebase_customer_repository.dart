import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/domain/customer_repository.dart';
import 'package:uuid/uuid.dart';

class FirebaseCustomerRepository implements CustomerRepository {
  FirebaseCustomerRepository(this._firestore, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  factory FirebaseCustomerRepository.fromDefaultApp() =>
      FirebaseCustomerRepository(FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;
  final Uuid _uuid;
  static const _accessPolicy = AccessPolicy();

  CollectionReference<Map<String, dynamic>> _collection(
    String businessId,
    String name,
  ) => _firestore.collection('businesses').doc(businessId).collection(name);

  @override
  Future<CustomerPage> fetchCustomers(CustomerListRequest request) async {
    if (request.pageSize < 1 || request.pageSize > 50) {
      throw const AppException('Customer page size must be between 1 and 50.');
    }
    if (request.businessId.isEmpty || request.requesterId.isEmpty) {
      throw const AppException('A valid business session is required.');
    }

    try {
      Query<Map<String, dynamic>> query = _collection(
            request.businessId,
            'customers',
          )
          .where('businessId', isEqualTo: request.businessId)
          .where('status', isEqualTo: request.status.value);
      if (!request.isHead) {
        query = query.where(
          'assignedEmployeeId',
          isEqualTo: request.requesterId,
        );
      }
      if (request.areaId.isNotEmpty) {
        query = query.where('areaId', isEqualTo: request.areaId);
      }

      final searchToken = request.searchToken;
      if (request.isCodeSearch) {
        query = query.where('customerCode', isEqualTo: searchToken);
        final snapshot = await query.limit(2).get();
        final customers = snapshot.docs.map(_fromDocument).toList();
        return CustomerPage(
          customers: customers,
          nextCursor: null,
          hasMore: false,
        );
      }
      if (searchToken != null) {
        query = query.where('searchTokens', arrayContains: searchToken);
      }

      query = query
          .orderBy('searchName')
          .orderBy(FieldPath.documentId)
          .limit(request.pageSize + 1);
      final cursor = request.cursor;
      if (cursor != null) {
        query = query.startAfter([cursor.searchName, cursor.customerId]);
      }

      final snapshot = await query.get();
      final hasMore = snapshot.docs.length > request.pageSize;
      final visibleDocs = snapshot.docs.take(request.pageSize).toList();
      final customers = visibleDocs.map(_fromDocument).toList();
      final lastDocument = visibleDocs.isEmpty ? null : visibleDocs.last;
      return CustomerPage(
        customers: customers,
        nextCursor:
            lastDocument == null
                ? null
                : CustomerPageCursor(
                  searchName:
                      lastDocument.data()['searchName'] as String? ?? '',
                  customerId: lastDocument.id,
                ),
        hasMore: hasMore,
      );
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not load customers.');
    }
  }

  @override
  Stream<Customer?> watchCustomer({
    required String businessId,
    required String customerId,
  }) => _collection(businessId, 'customers')
      .doc(customerId)
      .snapshots()
      .map((snapshot) => snapshot.exists ? _fromDocument(snapshot) : null);

  @override
  Stream<List<CustomerAuditEntry>> watchCustomerHistory({
    required String businessId,
    required String customerId,
  }) => _collection(businessId, 'auditRecords')
      .where('entityType', isEqualTo: 'customer')
      .where('entityId', isEqualTo: customerId)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) {
              final data = _withDartDates(doc.data());
              return CustomerAuditEntry.fromMap(doc.id, data);
            }).toList(),
      );

  @override
  Future<String> createCustomer({
    required AppUser actor,
    required CustomerInput input,
  }) async {
    final businessId = _businessId(actor);
    if (!_accessPolicy.canCreateCustomer(actor)) {
      throw const AppException('You are not permitted to create customers.');
    }
    final value = input.normalized();
    value.validate();
    if (!actor.isHead && value.openingBalancePaise != 0) {
      throw const AppException('Only the Head can set an opening balance.');
    }
    if (!actor.isHead &&
        value.assignedEmployeeId.isNotEmpty &&
        value.assignedEmployeeId != actor.uid) {
      throw const AppException(
        'Employees can create only their own customers.',
      );
    }

    final customerCode = 'C-${_uuid.v4().replaceAll('-', '').toUpperCase()}';
    final customerRef = _collection(businessId, 'customers').doc(customerCode);
    final auditRef = _collection(businessId, 'auditRecords').doc();
    final employeeId = actor.isHead ? value.assignedEmployeeId : actor.uid;

    try {
      await _firestore.runTransaction((transaction) async {
        final areaSnapshot = await transaction.get(
          _collection(businessId, 'areas').doc(value.areaId),
        );
        final employeeSnapshot = await transaction.get(
          _collection(
            businessId,
            'members',
          ).doc(employeeId.isEmpty ? actor.uid : employeeId),
        );
        _validateActiveArea(areaSnapshot, businessId);
        if (employeeId.isNotEmpty) {
          _validateEmployeeForArea(
            employeeSnapshot,
            businessId: businessId,
            employeeId: employeeId,
            areaId: value.areaId,
          );
        }

        final now = FieldValue.serverTimestamp();
        transaction.set(customerRef, {
          ..._profileFields(value, customerCode: customerCode),
          'businessId': businessId,
          'customerCode': customerCode,
          'areaId': value.areaId,
          'assignedEmployeeId': employeeId,
          'status': CustomerStatus.active.value,
          'subscriptionStatus': 'notConfigured',
          'openingBalancePaise': actor.isHead ? value.openingBalancePaise : 0,
          'createdBy': actor.uid,
          'updatedBy': actor.uid,
          'lastAuditId': auditRef.id,
          'createdAt': now,
          'updatedAt': now,
        });
        transaction.set(auditRef, {
          'businessId': businessId,
          'actorId': actor.uid,
          'action': 'customerCreated',
          'entityType': 'customer',
          'entityId': customerCode,
          'employeeId': employeeId,
          'areaId': value.areaId,
          'openingBalancePaise': actor.isHead ? value.openingBalancePaise : 0,
          'createdAt': now,
        });
      });
      return customerCode;
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not create the customer.');
    }
  }

  @override
  Future<void> updateCustomerProfile({
    required AppUser actor,
    required String customerId,
    required CustomerInput input,
  }) async {
    final businessId = _businessId(actor);
    final value = input.normalized();
    value.validate();
    final customerRef = _collection(businessId, 'customers').doc(customerId);
    final auditRef = _collection(businessId, 'auditRecords').doc();

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(customerRef);
        final data = snapshot.data();
        if (!snapshot.exists || data == null) {
          throw const AppException('Customer no longer exists.');
        }
        _validateCustomerTenant(data, businessId);
        final customer = _fromDocument(snapshot);
        final collectionState = await transaction.get(
          customerRef.collection('collectionState').doc('current'),
        );
        if (!_accessPolicy.canEditCustomer(
          member: actor,
          customerBusinessId: customer.businessId,
          assignedEmployeeId: customer.assignedEmployeeId,
          isArchived: customer.isArchived,
        )) {
          throw const AppException(
            'You are not permitted to edit this customer.',
          );
        }
        if (value.areaId != customer.areaId ||
            value.assignedEmployeeId != customer.assignedEmployeeId) {
          throw const AppException(
            'Use the assignment action to change area or employee.',
          );
        }
        if (value.openingBalancePaise != customer.openingBalancePaise) {
          throw const AppException(
            'Opening balance is immutable. Record future corrections as financial adjustments.',
          );
        }

        final profile = _profileFields(
          value,
          customerCode: customer.customerCode,
        );
        final changedFields = <String>[
          for (final entry in profile.entries)
            if (!_sameValue(data[entry.key], entry.value)) entry.key,
        ];
        if (changedFields.isEmpty) return;

        final now = FieldValue.serverTimestamp();
        transaction.update(customerRef, {
          ...profile,
          'updatedBy': actor.uid,
          'lastAuditId': auditRef.id,
          'updatedAt': now,
        });
        _updateReportingProjection(
          transaction: transaction,
          snapshot: collectionState,
          actorId: actor.uid,
          mutationType: 'customerProfileUpdated',
          mutationId: auditRef.id,
          now: now,
          fields: {
            'customerCode': customer.customerCode,
            'customerName': value.name,
            'areaId': customer.areaId,
            'assignedEmployeeId': customer.assignedEmployeeId,
            'customerStatus': customer.status.value,
          },
        );
        transaction.set(auditRef, {
          'businessId': businessId,
          'actorId': actor.uid,
          'action': 'customerUpdated',
          'entityType': 'customer',
          'entityId': customerId,
          'changedFields': changedFields..sort(),
          'createdAt': now,
        });
      });
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not update the customer.');
    }
  }

  @override
  Future<void> setCustomerArchived({
    required AppUser actor,
    required String customerId,
    required bool archived,
  }) async {
    final businessId = _businessId(actor);
    if (!_accessPolicy.canManageCustomerLifecycle(actor)) {
      throw const AppException(
        'Only the Head can archive or reactivate customers.',
      );
    }
    final customerRef = _collection(businessId, 'customers').doc(customerId);
    final auditRef = _collection(businessId, 'auditRecords').doc();
    final nextStatus =
        archived ? CustomerStatus.archived : CustomerStatus.active;

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(customerRef);
        final collectionState = await transaction.get(
          customerRef.collection('collectionState').doc('current'),
        );
        final data = snapshot.data();
        if (!snapshot.exists || data == null) {
          throw const AppException('Customer no longer exists.');
        }
        _validateCustomerTenant(data, businessId);
        if (data['status'] == nextStatus.value) return;
        final now = FieldValue.serverTimestamp();
        transaction.update(customerRef, {
          'status': nextStatus.value,
          'updatedBy': actor.uid,
          'lastAuditId': auditRef.id,
          'updatedAt': now,
        });
        _updateReportingProjection(
          transaction: transaction,
          snapshot: collectionState,
          actorId: actor.uid,
          mutationType: 'customerStatusUpdated',
          mutationId: auditRef.id,
          now: now,
          fields: {
            'customerCode': data['customerCode'] as String? ?? customerId,
            'customerName': data['name'] as String? ?? '',
            'areaId': data['areaId'] as String? ?? '',
            'assignedEmployeeId': data['assignedEmployeeId'] as String? ?? '',
            'customerStatus': nextStatus.value,
          },
        );
        transaction.set(auditRef, {
          'businessId': businessId,
          'actorId': actor.uid,
          'action': archived ? 'customerArchived' : 'customerReactivated',
          'entityType': 'customer',
          'entityId': customerId,
          'createdAt': now,
        });
      });
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not update customer status.');
    }
  }

  @override
  Future<void> assignCustomer({
    required AppUser actor,
    required String customerId,
    required String employeeId,
    required String areaId,
  }) async {
    final businessId = _businessId(actor);
    if (!actor.isHead) {
      throw const AppException('Only the Head can transfer customers.');
    }
    if (areaId.trim().isEmpty) {
      throw const AppException('Select an active delivery area.');
    }
    final customerRef = _collection(businessId, 'customers').doc(customerId);
    final auditRef = _collection(businessId, 'auditRecords').doc();

    try {
      await _firestore.runTransaction((transaction) async {
        final customer = await transaction.get(customerRef);
        final area = await transaction.get(
          _collection(businessId, 'areas').doc(areaId),
        );
        final employee =
            employeeId.isEmpty
                ? null
                : await transaction.get(
                  _collection(businessId, 'members').doc(employeeId),
                );
        final collectionState = await transaction.get(
          customerRef.collection('collectionState').doc('current'),
        );
        final data = customer.data();
        if (!customer.exists || data == null) {
          throw const AppException('Customer no longer exists.');
        }
        _validateCustomerTenant(data, businessId);
        _validateActiveArea(area, businessId);
        if (employee != null) {
          _validateEmployeeForArea(
            employee,
            businessId: businessId,
            employeeId: employeeId,
            areaId: areaId,
          );
        }
        final previousEmployeeId = data['assignedEmployeeId'] as String? ?? '';
        final previousAreaId = data['areaId'] as String? ?? '';
        if (previousEmployeeId == employeeId && previousAreaId == areaId) {
          return;
        }

        final now = FieldValue.serverTimestamp();
        transaction.update(customerRef, {
          'assignedEmployeeId': employeeId,
          'areaId': areaId,
          'updatedBy': actor.uid,
          'lastAuditId': auditRef.id,
          'updatedAt': now,
        });
        _updateReportingProjection(
          transaction: transaction,
          snapshot: collectionState,
          actorId: actor.uid,
          mutationType: 'customerAssignmentUpdated',
          mutationId: auditRef.id,
          now: now,
          fields: {
            'customerCode': data['customerCode'] as String? ?? customerId,
            'customerName': data['name'] as String? ?? '',
            'areaId': areaId,
            'assignedEmployeeId': employeeId,
            'customerStatus': data['status'] as String? ?? 'active',
          },
        );
        transaction.set(auditRef, {
          'businessId': businessId,
          'actorId': actor.uid,
          'action': 'customerAssignmentUpdated',
          'entityType': 'customer',
          'entityId': customerId,
          'previousEmployeeId': previousEmployeeId,
          'employeeId': employeeId,
          'previousAreaId': previousAreaId,
          'areaId': areaId,
          'createdAt': now,
        });
      });
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw _translate(error, 'Could not update the customer assignment.');
    }
  }

  String _businessId(AppUser actor) {
    final businessId = actor.businessId;
    if (!actor.hasActiveAccess || businessId == null || businessId.isEmpty) {
      throw const AppException('Your business access is no longer active.');
    }
    return businessId;
  }

  Map<String, Object?> _profileFields(
    CustomerInput input, {
    required String customerCode,
  }) => {
    'name': input.name,
    'searchName': CustomerSearchIndex.normalizeText(input.name),
    'phone': input.phone,
    'searchPhone': CustomerSearchIndex.normalizePhone(input.phone),
    'alternatePhone': input.alternatePhone,
    'address': input.address,
    'landmark': input.landmark,
    'searchLandmark': CustomerSearchIndex.normalizeText(input.landmark),
    'searchTokens': CustomerSearchIndex.buildTokens(
      customerCode: customerCode,
      name: input.name,
      phone: input.phone,
      alternatePhone: input.alternatePhone,
      landmark: input.landmark,
    ),
    'houseNumber': input.houseNumber,
    'buildingInfo': input.buildingInfo,
    'locationNotes': input.locationNotes,
    'locationConsent': input.locationConsent,
    'coordinates': input.coordinates?.toMap(),
    'deliveryPreferences': {'placement': input.deliveryPlacement.value},
    'billingPreferences': {'cycle': input.billingCycle.value},
    'notes': input.notes,
  };

  Customer _fromDocument(DocumentSnapshot<Map<String, dynamic>> snapshot) =>
      Customer.fromMap(snapshot.id, _withDartDates(snapshot.data() ?? {}));

  Map<String, Object?> _withDartDates(Map<String, dynamic> data) {
    final result = <String, Object?>{...data};
    for (final key in const ['createdAt', 'updatedAt']) {
      final value = result[key];
      if (value is Timestamp) result[key] = value.toDate();
    }
    return result;
  }

  void _validateCustomerTenant(Map<String, dynamic> data, String businessId) {
    if (data['businessId'] != businessId) {
      throw const AppException('Customer does not belong to this business.');
    }
  }

  void _validateActiveArea(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    String businessId,
  ) {
    final data = snapshot.data();
    if (!snapshot.exists ||
        data == null ||
        data['businessId'] != businessId ||
        data['status'] != 'active') {
      throw const AppException('Select an active delivery area.');
    }
  }

  void _validateEmployeeForArea(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    required String businessId,
    required String employeeId,
    required String areaId,
  }) {
    final data = snapshot.data();
    final rawAreaIds = data?['areaIds'];
    final areaIds =
        rawAreaIds is List
            ? rawAreaIds.whereType<String>().toSet()
            : <String>{};
    if (!snapshot.exists ||
        data == null ||
        data['businessId'] != businessId ||
        data['uid'] != employeeId ||
        data['role'] != 'employee' ||
        data['status'] != 'active' ||
        !areaIds.contains(areaId)) {
      throw const AppException(
        'Select an active employee assigned to this area.',
      );
    }
  }

  bool _sameValue(Object? left, Object? right) {
    if (left is List && right is List) {
      if (left.length != right.length) return false;
      for (var index = 0; index < left.length; index++) {
        if (!_sameValue(left[index], right[index])) return false;
      }
      return true;
    }
    if (left is Map && right is Map) {
      if (left.length != right.length) return false;
      for (final key in left.keys) {
        if (!right.containsKey(key) || !_sameValue(left[key], right[key])) {
          return false;
        }
      }
      return true;
    }
    return left == right;
  }

  void _updateReportingProjection({
    required Transaction transaction,
    required DocumentSnapshot<Map<String, dynamic>> snapshot,
    required String actorId,
    required String mutationType,
    required String mutationId,
    required FieldValue now,
    required Map<String, Object?> fields,
  }) {
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return;
    transaction.update(snapshot.reference, {
      ...fields,
      'revision': (data['revision'] as int? ?? 0) + 1,
      'lastMutationType': mutationType,
      'lastMutationId': mutationId,
      'updatedBy': actorId,
      'updatedAt': now,
    });
  }

  AppException _translate(FirebaseException error, String fallback) {
    final message = switch (error.code) {
      'permission-denied' =>
        'Your current membership does not permit this customer action.',
      'failed-precondition' =>
        'This customer query needs a reviewed Firestore index before deployment.',
      'unavailable' =>
        'Customer changes require a server connection. Check your network and retry.',
      _ => fallback,
    };
    return AppException(message, code: error.code);
  }
}
