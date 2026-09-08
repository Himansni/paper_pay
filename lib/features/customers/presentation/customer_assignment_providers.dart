// Compatibility export for Phase 2 imports. The provider now serves the full
// Phase 3 customer repository.
import 'customer_providers.dart';

export 'customer_providers.dart';

final customerAssignmentRepositoryProvider = customerRepositoryProvider;
