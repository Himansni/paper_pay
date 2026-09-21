// BEGINNER NOTE:
// Compatibility alias mapping the former `CustomerAssignmentRepository` to [CustomerRepository].
// This preserves existing feature imports while directing all queries to the paginated
// customer repository implementation.
// Compatibility alias for Phase 2 imports. The implementation now exposes the
// full paginated customer repository contract.
import 'customer_repository.dart';

export 'customer_repository.dart';

typedef CustomerAssignmentRepository = CustomerRepository;
