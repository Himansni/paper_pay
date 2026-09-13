import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/config/firebase_bootstrap.dart';
import 'package:paper_route/core/theme/app_theme.dart';
import 'package:paper_route/features/auth/presentation/access_pending_page.dart';
import 'package:paper_route/features/auth/presentation/auth_gate.dart';
import 'package:paper_route/features/auth/presentation/forgot_password_page.dart';
import 'package:paper_route/features/auth/presentation/invite_registration_page.dart';
import 'package:paper_route/features/auth/presentation/setup_required_page.dart';

class PaperRouteApp extends StatefulWidget {
  const PaperRouteApp({required this.startup, super.key});

  final FirebaseStartup startup;

  @override
  State<PaperRouteApp> createState() => _PaperRouteAppState();
}

class _PaperRouteAppState extends State<PaperRouteApp> {
  late final GoRouter _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? const AuthGate()
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/join',
        builder: (context, state) => const InviteRegistrationPage(),
      ),
      GoRoute(
        path: '/activate',
        builder: (context, state) => const AccessPendingPage(),
      ),
      GoRoute(
        path: '/business-settings',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? const AuthGate(
                      destination: AuthenticatedDestination.businessSettings,
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/employees',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? const AuthGate(
                      destination: AuthenticatedDestination.employees,
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/areas',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? const AuthGate(
                      destination: AuthenticatedDestination.areas,
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/customers',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? const AuthGate(
                      destination: AuthenticatedDestination.customers,
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/billing',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? const AuthGate(
                      destination: AuthenticatedDestination.billing,
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/billing/:customerId/:billingMonth/preview',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? AuthGate(
                      destination: AuthenticatedDestination.billPreview,
                      resourceId: state.pathParameters['customerId'],
                      secondaryResourceId: state.pathParameters['billingMonth'],
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/billing/:customerId/:billingMonth',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? AuthGate(
                      destination: AuthenticatedDestination.billDetail,
                      resourceId: state.pathParameters['customerId'],
                      secondaryResourceId: state.pathParameters['billingMonth'],
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/collections',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? const AuthGate(
                      destination: AuthenticatedDestination.collections,
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/collections/:customerId/:paymentId',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? AuthGate(
                      destination: AuthenticatedDestination.paymentReceipt,
                      resourceId: state.pathParameters['customerId'],
                      secondaryResourceId: state.pathParameters['paymentId'],
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/customers/:customerId/collect',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? AuthGate(
                      destination: AuthenticatedDestination.collectPayment,
                      resourceId: state.pathParameters['customerId'],
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/customers/:customerId/payments',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? AuthGate(
                      destination: AuthenticatedDestination.collections,
                      resourceId: state.pathParameters['customerId'],
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/business-settings/upi',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? const AuthGate(
                      destination: AuthenticatedDestination.upiSettings,
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/customers/new',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? const AuthGate(
                      destination: AuthenticatedDestination.customerCreate,
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/customers/:customerId/subscriptions/new',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? AuthGate(
                      destination: AuthenticatedDestination.subscriptionCreate,
                      resourceId: state.pathParameters['customerId'],
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/customers/:customerId/subscriptions/:subscriptionId/change',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? AuthGate(
                      destination: AuthenticatedDestination.subscriptionChange,
                      resourceId: state.pathParameters['customerId'],
                      secondaryResourceId:
                          state.pathParameters['subscriptionId'],
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/customers/:customerId/subscriptions/:subscriptionId',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? AuthGate(
                      destination: AuthenticatedDestination.subscriptionDetail,
                      resourceId: state.pathParameters['customerId'],
                      secondaryResourceId:
                          state.pathParameters['subscriptionId'],
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/customers/:customerId',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? AuthGate(
                      destination: AuthenticatedDestination.customerDetail,
                      resourceId: state.pathParameters['customerId'],
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/customers/:customerId/edit',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? AuthGate(
                      destination: AuthenticatedDestination.customerEdit,
                      resourceId: state.pathParameters['customerId'],
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/customer-assignments',
        redirect: (context, state) => '/customers',
      ),
      GoRoute(
        path: '/newspapers',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? const AuthGate(
                      destination: AuthenticatedDestination.newspapers,
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/newspapers/new',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? const AuthGate(
                      destination: AuthenticatedDestination.newspaperCreate,
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/newspapers/:newspaperId/edit',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? AuthGate(
                      destination: AuthenticatedDestination.newspaperEdit,
                      resourceId: state.pathParameters['newspaperId'],
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/newspapers/:newspaperId/prices',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? AuthGate(
                      destination: AuthenticatedDestination.newspaperPricing,
                      resourceId: state.pathParameters['newspaperId'],
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
      GoRoute(
        path: '/newspapers/:newspaperId',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? AuthGate(
                      destination: AuthenticatedDestination.newspaperDetail,
                      resourceId: state.pathParameters['newspaperId'],
                    )
                    : SetupRequiredPage(message: widget.startup.message),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PaperRoute',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
