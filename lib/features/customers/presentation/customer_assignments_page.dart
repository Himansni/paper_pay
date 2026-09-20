import 'package:paper_route/features/customers/presentation/customers_page.dart';

/// Backward-compatible widget for the former Phase 2 assignment route.
///
/// The old 100-record assignment-only view is now the complete paginated
/// customer directory. Assignment remains available from customer details.
class CustomerAssignmentsPage extends CustomersPage {
  const CustomerAssignmentsPage({required super.user, super.key});
}
