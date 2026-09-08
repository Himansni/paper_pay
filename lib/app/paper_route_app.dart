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
        path: '/customer-assignments',
        builder:
            (context, state) =>
                widget.startup.isReady
                    ? const AuthGate(
                      destination: AuthenticatedDestination.customerAssignments,
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
