// BEGINNER NOTE:
// Compatibility alias redirecting legacy `FirebaseCustomerAssignmentRepository` to
// [FirebaseCustomerRepository], which handles customer persistence, audit logging,
// and area filtering.
// Compatibility export for the renamed Phase 3 repository.
import 'firebase_customer_repository.dart';

export 'firebase_customer_repository.dart';

typedef FirebaseCustomerAssignmentRepository = FirebaseCustomerRepository;
