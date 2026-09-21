// BEGINNER NOTE:
// Architectural backward-compatibility alias:
// Earlier project phases used a distinct `CustomerAssignment` type for a 100-record assignment view.
// In the current architecture, customer operations are unified under the full [Customer] model.
// This typedef ensures older imports remain valid without code duplication.
// Kept as a compatibility export for Phase 2 imports. Customer management now
// uses the complete Customer model rather than a 100-record assignment view.
import 'customer.dart';

export 'customer.dart';

typedef CustomerAssignment = Customer;
