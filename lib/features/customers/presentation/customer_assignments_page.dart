// BEGINNER NOTE:
// Compatibility widget redirecting legacy assignment page routes to [CustomersPage].
// The unified customer directory allows filtering, searching, and assigning collectors
// within the complete customer list.
import 'package:paper_route/features/customers/presentation/customers_page.dart';

/// Backward-compatible widget for the former Phase 2 assignment route.
///
/// The old 100-record assignment-only view is now the complete paginated
/// customer directory. Assignment remains available from customer details.
class CustomerAssignmentsPage extends CustomersPage {
  const CustomerAssignmentsPage({required super.user, super.key});
}
