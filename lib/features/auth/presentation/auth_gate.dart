import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/features/auth/presentation/access_pending_page.dart';
import 'package:paper_route/features/auth/presentation/auth_providers.dart';
import 'package:paper_route/features/auth/presentation/email_verification_page.dart';
import 'package:paper_route/features/auth/presentation/login_page.dart';
import 'package:paper_route/features/areas/presentation/areas_page.dart';
import 'package:paper_route/features/business/presentation/business_settings_page.dart';
import 'package:paper_route/features/customers/presentation/customer_assignments_page.dart';
import 'package:paper_route/features/dashboard/presentation/dashboard_page.dart';
import 'package:paper_route/features/employees/presentation/employees_page.dart';

enum AuthenticatedDestination {
  dashboard,
  businessSettings,
  employees,
  areas,
  customerAssignments,
}

/// Single source of truth for auth and role routing. UI routes never trust a
/// role passed through navigation arguments.
class AuthGate extends ConsumerWidget {
  const AuthGate({
    this.destination = AuthenticatedDestination.dashboard,
    super.key,
  });

  final AuthenticatedDestination destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    return session.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (error, stackTrace) => Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'We could not load your account. Check your connection and try again.\n\n$error',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      data: (user) {
        if (user == null) return const LoginPage();
        if (!user.isEmailVerified) return EmailVerificationPage(user: user);
        if (!user.hasActiveAccess) return AccessPendingPage(user: user);
        if (!user.isHead) return DashboardPage(user: user);
        return switch (destination) {
          AuthenticatedDestination.dashboard => DashboardPage(user: user),
          AuthenticatedDestination.businessSettings => BusinessSettingsPage(
            user: user,
          ),
          AuthenticatedDestination.employees => EmployeesPage(user: user),
          AuthenticatedDestination.areas => AreasPage(user: user),
          AuthenticatedDestination.customerAssignments =>
            CustomerAssignmentsPage(user: user),
        };
      },
    );
  }
}
