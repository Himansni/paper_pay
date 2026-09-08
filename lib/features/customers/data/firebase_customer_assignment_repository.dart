import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/customers/domain/customer_assignment.dart';
import 'package:paper_route/features/customers/domain/customer_assignment_repository.dart';

class FirebaseCustomerAssignmentRepository
    implements CustomerAssignmentRepository {
  FirebaseCustomerAssignmentRepository(this._firestore);

  factory FirebaseCustomerAssignmentRepository.fromDefaultApp() =>
      FirebaseCustomerAssignmentRepository(FirebaseFirestore.instance);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(
    String businessId,
    String name,
  ) => _firestore.collection('businesses').doc(businessId).collection(name);

  @override
  Stream<List<CustomerAssignment>> watchCustomers(String businessId) {
    return _collection(businessId, 'customers')
        .where('businessId', isEqualTo: businessId)
        .limit(100)
        .snapshots()
        .map((event) {
          final customers =
              event.docs
                  .map((doc) => CustomerAssignment.fromMap(doc.id, doc.data()))
                  .toList();
          customers.sort(
            (left, right) =>
                left.name.toLowerCase().compareTo(right.name.toLowerCase()),
          );
          return customers;
        });
  }

  @override
  Future<void> assignCustomer({
    required String businessId,
    required String actorId,
    required String customerId,
    required String employeeId,
    required String areaId,
  }) async {
    final customerRef = _collection(businessId, 'customers').doc(customerId);
    final memberRef =
        employeeId.isEmpty
            ? null
            : _collection(businessId, 'members').doc(employeeId);
    final areaRef =
        areaId.isEmpty ? null : _collection(businessId, 'areas').doc(areaId);
    final auditRef = _collection(businessId, 'auditRecords').doc();

    try {
      await _firestore.runTransaction((transaction) async {
        final customer = await transaction.get(customerRef);
        final member =
            memberRef == null ? null : await transaction.get(memberRef);
        final area = areaRef == null ? null : await transaction.get(areaRef);
        final customerData = customer.data();
        if (!customer.exists || customerData == null) {
          throw const AppException('Customer no longer exists.');
        }
        if (customerData['businessId'] != businessId) {
          throw const AppException(
            'Customer does not belong to this business.',
          );
        }
        if (member != null &&
            (!member.exists ||
                member.data()?['businessId'] != businessId ||
                member.data()?['role'] != 'employee' ||
                member.data()?['status'] != 'active')) {
          throw const AppException('Select an active employee.');
        }
        if (area != null &&
            (!area.exists ||
                area.data()?['businessId'] != businessId ||
                area.data()?['status'] != 'active')) {
          throw const AppException('Select an active area.');
        }
        if (member != null && areaId.isNotEmpty) {
          final rawAreaIds = member.data()?['areaIds'];
          final memberAreaIds =
              rawAreaIds is List
                  ? rawAreaIds.whereType<String>().toSet()
                  : <String>{};
          if (!memberAreaIds.contains(areaId)) {
            throw const AppException(
              'Assign this area to the employee before transferring its customers.',
            );
          }
        }

        final now = FieldValue.serverTimestamp();
        transaction.update(customerRef, {
          'assignedEmployeeId': employeeId,
          'areaId': areaId,
          'updatedAt': now,
        });
        transaction.set(auditRef, {
          'businessId': businessId,
          'actorId': actorId,
          'action': 'customerAssignmentUpdated',
          'entityType': 'customer',
          'entityId': customerId,
          'previousEmployeeId':
              customerData['assignedEmployeeId'] as String? ?? '',
          'employeeId': employeeId,
          'previousAreaId': customerData['areaId'] as String? ?? '',
          'areaId': areaId,
          'createdAt': now,
        });
      });
    } on AppException {
      rethrow;
    } on FirebaseException catch (error) {
      throw AppException(
        error.code == 'permission-denied'
            ? 'Your Head access no longer permits customer assignment.'
            : 'Could not update the customer assignment.',
        code: error.code,
      );
    }
  }
}
