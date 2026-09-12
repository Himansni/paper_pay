import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/theme/app_theme.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/auth/presentation/auth_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameParts = user.displayName.trim().split(' ');
    final firstName = nameParts.first.isEmpty ? 'there' : nameParts.first;
    final plannedSections =
        user.isHead
            ? const ['Collections', 'Reports']
            : const ['Collections', 'Profile'];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.newspaper_rounded, color: AppTheme.brand),
            SizedBox(width: 10),
            Text('PaperRoute'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'Good day, $firstName',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              user.isHead
                  ? 'Head Distributor workspace'
                  : 'Employee distribution workspace',
              style: const TextStyle(color: Color(0xFF627D98)),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5F5EE),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.verified_user_outlined,
                        color: AppTheme.brand,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Secure access active',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Business ${user.businessId} • ${user.email}',
                            style: const TextStyle(
                              color: Color(0xFF627D98),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              user.isHead ? 'Business operations' : 'Workspace modules',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (user.isHead)
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 720;
                  final width =
                      compact
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 24) / 3;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _WorkspaceActionCard(
                        width: width,
                        icon: Icons.storefront_outlined,
                        title: 'Business settings',
                        subtitle: 'Distributor name, phone, and address',
                        onTap: () => context.go('/business-settings'),
                      ),
                      _WorkspaceActionCard(
                        width: width,
                        icon: Icons.manage_accounts_outlined,
                        title: 'Employees',
                        subtitle: 'Invitations, details, status, permissions',
                        onTap: () => context.go('/employees'),
                      ),
                      _WorkspaceActionCard(
                        width: width,
                        icon: Icons.map_outlined,
                        title: 'Areas',
                        subtitle: 'Coverage and employee assignments',
                        onTap: () => context.go('/areas'),
                      ),
                      _WorkspaceActionCard(
                        width: width,
                        icon: Icons.people_alt_outlined,
                        title: 'Customers',
                        subtitle: 'Profiles, routes, search, and assignments',
                        onTap: () => context.go('/customers'),
                      ),
                      _WorkspaceActionCard(
                        width: width,
                        icon: Icons.newspaper_outlined,
                        title: 'Newspapers',
                        subtitle: 'Catalog, effective prices, and history',
                        onTap: () => context.go('/newspapers'),
                      ),
                      _WorkspaceActionCard(
                        width: width,
                        icon: Icons.receipt_long_outlined,
                        title: 'Monthly billing',
                        subtitle: 'Preview, finalize, and review monthly bills',
                        onTap: () => context.go('/billing'),
                      ),
                    ],
                  );
                },
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _WorkspaceActionCard(
                    width: double.infinity,
                    icon: Icons.people_alt_outlined,
                    title: 'My customers',
                    subtitle: 'Assigned customer routes and house details',
                    onTap: () => context.go('/customers'),
                  ),
                  const SizedBox(height: 12),
                  _WorkspaceActionCard(
                    width: double.infinity,
                    icon: Icons.newspaper_outlined,
                    title: 'Newspaper catalog',
                    subtitle: 'Active publications and dated pricing',
                    onTap: () => context.go('/newspapers'),
                  ),
                  const SizedBox(height: 12),
                  _WorkspaceActionCard(
                    width: double.infinity,
                    icon: Icons.receipt_long_outlined,
                    title: 'My customer bills',
                    subtitle: 'Read finalized bills for assigned customers',
                    onTap: () => context.go('/billing'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final section in plannedSections)
                        Chip(
                          avatar: const Icon(Icons.lock_outline, size: 18),
                          label: Text(section),
                          side: BorderSide.none,
                          backgroundColor: Colors.white,
                        ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.isHead ? 'Connected workflows' : 'Secure foundation',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user.isHead
                          ? 'Employee access, delivery areas, customers, catalog pricing, subscriptions, and deterministic monthly billing use connected Firestore workflows.'
                          : 'Your active membership, assigned areas, customer access, and subscription permissions are enforced by Firestore Security Rules.',
                      style: const TextStyle(
                        color: Color(0xFF627D98),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceActionCard extends StatelessWidget {
  const _WorkspaceActionCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppTheme.brand, size: 30),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF627D98),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
