import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/features/auth/presentation/access_pending_page.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/agency_registration/presentation/agency_registration_gate.dart';
import 'package:paper_route/features/agency_registration/presentation/agency_registration_providers.dart';
import 'package:paper_route/features/auth/presentation/auth_providers.dart';
import 'package:paper_route/features/auth/presentation/email_verification_page.dart';
import 'package:paper_route/features/auth/presentation/login_page.dart';
import 'package:paper_route/features/areas/presentation/areas_page.dart';
import 'package:paper_route/features/billing/presentation/bill_detail_page.dart';
import 'package:paper_route/features/billing/presentation/bill_preview_page.dart';
import 'package:paper_route/features/billing/presentation/billing_workspace_page.dart';
import 'package:paper_route/features/business/presentation/business_settings_page.dart';
import 'package:paper_route/features/collections/presentation/collect_payment_page.dart';
import 'package:paper_route/features/collections/presentation/collections_workspace_page.dart';
import 'package:paper_route/features/collections/presentation/payment_receipt_page.dart';
import 'package:paper_route/features/collections/presentation/upi_settings_page.dart';
import 'package:paper_route/features/customers/presentation/customer_detail_page.dart';
import 'package:paper_route/features/customers/presentation/customer_form_page.dart';
import 'package:paper_route/features/customers/presentation/customer_import_page.dart';
import 'package:paper_route/features/customers/presentation/customers_page.dart';
import 'package:paper_route/features/dashboard/presentation/dashboard_page.dart';
import 'package:paper_route/features/employees/presentation/employees_page.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_detail_page.dart';
import 'package:paper_route/features/newspapers/presentation/daily_pricing_page.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_form_page.dart';
import 'package:paper_route/features/newspapers/presentation/newspaper_pricing_page.dart';
import 'package:paper_route/features/newspapers/presentation/newspapers_page.dart';
import 'package:paper_route/features/profile/presentation/account_settings_page.dart';
import 'package:paper_route/features/subscriptions/presentation/subscription_detail_page.dart';
import 'package:paper_route/features/subscriptions/presentation/subscription_form_page.dart';
import 'package:paper_route/features/delivery/presentation/morning_route_page.dart';
import 'package:paper_route/features/delivery/presentation/today_operations_page.dart';
import 'package:paper_route/features/reports/presentation/reports_page.dart';

enum AuthenticatedDestination {
  dashboard,
  accountSettings,
  businessSettings,
  employees,
  areas,
  customers,
  reports,
  dailyPricing,
  billing,
  billPreview,
  billDetail,
  collections,
  collectPayment,
  paymentReceipt,
  upiSettings,
  customerCreate,
  customerImport,
  customerDetail,
  customerEdit,
  newspapers,
  newspaperCreate,
  newspaperDetail,
  newspaperEdit,
  newspaperPricing,
  subscriptionCreate,
  subscriptionDetail,
  subscriptionChange,
  morningRoute,
  todayOperations,
}

/// Single source of truth for auth and role routing. UI routes never trust a
/// role passed through navigation arguments.
class AuthGate extends ConsumerWidget {
  const AuthGate({
    this.destination = AuthenticatedDestination.dashboard,
    this.resourceId,
    this.secondaryResourceId,
    super.key,
  });

  final AuthenticatedDestination destination;
  final String? resourceId;
  final String? secondaryResourceId;

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
        if (user.status == AccountStatus.inactive) {
          return AccessPendingPage(user: user);
        }
        if (!user.hasActiveAccess) {
          return ref.watch(agencyRegistrationEnabledProvider)
              ? AgencyRegistrationGate(user: user)
              : AccessPendingPage(user: user);
        }
        final headOnly = switch (destination) {
          AuthenticatedDestination.businessSettings ||
          AuthenticatedDestination.employees ||
          AuthenticatedDestination.areas ||
          AuthenticatedDestination.reports ||
          AuthenticatedDestination.dailyPricing ||
          AuthenticatedDestination.newspaperCreate ||
          AuthenticatedDestination.newspaperEdit => true,
          AuthenticatedDestination.billPreview => true,
          AuthenticatedDestination.upiSettings => true,
          AuthenticatedDestination.todayOperations => true,
          _ => false,
        };
        if (headOnly && !user.isHead) return DashboardPage(user: user);
        return switch (destination) {
          AuthenticatedDestination.dashboard => DashboardPage(user: user),
          AuthenticatedDestination.accountSettings => AccountSettingsPage(
            user: user,
          ),
          AuthenticatedDestination.businessSettings => BusinessSettingsPage(
            user: user,
          ),
          AuthenticatedDestination.employees => EmployeesPage(user: user),
          AuthenticatedDestination.areas => AreasPage(user: user),
          AuthenticatedDestination.customers => CustomersPage(
            user: user,
            initialSearch: resourceId ?? '',
          ),
          AuthenticatedDestination.reports => ReportsPage(
            user: user,
            initialTab: resourceId ?? '',
          ),
          AuthenticatedDestination.dailyPricing => DailyPricingPage(user: user),
          AuthenticatedDestination.billing => BillingWorkspacePage(user: user),
          AuthenticatedDestination.billPreview => BillPreviewPage(
            user: user,
            customerId: resourceId ?? '',
            billingMonth: secondaryResourceId ?? '',
          ),
          AuthenticatedDestination.billDetail => BillDetailPage(
            user: user,
            customerId: resourceId ?? '',
            billingMonth: secondaryResourceId ?? '',
          ),
          AuthenticatedDestination.collections => CollectionsWorkspacePage(
            user: user,
            customerId: resourceId,
          ),
          AuthenticatedDestination.collectPayment => CollectPaymentPage(
            user: user,
            customerId: resourceId ?? '',
          ),
          AuthenticatedDestination.paymentReceipt => PaymentReceiptPage(
            user: user,
            customerId: resourceId ?? '',
            paymentId: secondaryResourceId ?? '',
          ),
          AuthenticatedDestination.upiSettings => UpiSettingsPage(user: user),
          AuthenticatedDestination.customerCreate => CustomerFormRoutePage(
            user: user,
          ),
          AuthenticatedDestination.customerImport => CustomerImportPage(
            user: user,
          ),
          AuthenticatedDestination.customerDetail => CustomerDetailPage(
            user: user,
            customerId: resourceId ?? '',
          ),
          AuthenticatedDestination.customerEdit => CustomerFormRoutePage(
            user: user,
            customerId: resourceId ?? '',
          ),
          AuthenticatedDestination.newspapers => NewspapersPage(user: user),
          AuthenticatedDestination.newspaperCreate => NewspaperFormRoutePage(
            user: user,
          ),
          AuthenticatedDestination.newspaperDetail => NewspaperDetailPage(
            user: user,
            newspaperId: resourceId ?? '',
          ),
          AuthenticatedDestination.newspaperEdit => NewspaperFormRoutePage(
            user: user,
            newspaperId: resourceId ?? '',
          ),
          AuthenticatedDestination.newspaperPricing => NewspaperPricingPage(
            user: user,
            newspaperId: resourceId ?? '',
          ),
          AuthenticatedDestination.subscriptionCreate =>
            SubscriptionFormRoutePage(user: user, customerId: resourceId ?? ''),
          AuthenticatedDestination.subscriptionDetail =>
            SubscriptionDetailRoutePage(
              user: user,
              customerId: resourceId ?? '',
              subscriptionId: secondaryResourceId ?? '',
            ),
          AuthenticatedDestination.subscriptionChange =>
            SubscriptionFormRoutePage(
              user: user,
              customerId: resourceId ?? '',
              subscriptionId: secondaryResourceId ?? '',
            ),
          AuthenticatedDestination.morningRoute =>
            MorningRoutePage(user: user),
          AuthenticatedDestination.todayOperations =>
            TodayOperationsPage(user: user),
        };
      },
    );
  }
}
