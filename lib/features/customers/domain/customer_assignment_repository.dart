// Compatibility alias for Phase 2 imports. The implementation now exposes the
// full paginated customer repository contract.
import 'customer_repository.dart';

export 'customer_repository.dart';

typedef CustomerAssignmentRepository = CustomerRepository;
