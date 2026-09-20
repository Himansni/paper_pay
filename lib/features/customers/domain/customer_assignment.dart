// Kept as a compatibility export for Phase 2 imports. Customer management now
// uses the complete Customer model rather than a 100-record assignment view.
import 'customer.dart';

export 'customer.dart';

typedef CustomerAssignment = Customer;
