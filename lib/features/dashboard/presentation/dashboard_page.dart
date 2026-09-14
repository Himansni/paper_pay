import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/core/theme/app_theme.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/auth/presentation/auth_providers.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/reports/domain/report_models.dart';
import 'package:paper_route/features/reports/presentation/reporting_providers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstName = user.displayName.trim().split(' ').firstOrNull ?? 'there';
    final dashboard = ref.watch(operationalDashboardProvider(user));
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
            onPressed: () => ref.invalidate(operationalDashboardProvider(user)),
            tooltip: 'Refresh dashboard',
            icon: const Icon(Icons.refresh),
          ),
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
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(operationalDashboardProvider(user));
            await ref.read(operationalDashboardProvider(user).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              Text(
                'Good day, ${firstName.isEmpty ? 'there' : firstName}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.isHead
                    ? 'Head Distributor workspace'
                    : 'Employee distribution workspace',
                style: const TextStyle(color: Color(0xFF486581)),
              ),
              const SizedBox(height: 18),
              dashboard.when(
                loading: () => const _DashboardLoading(),
                error:
                    (error, _) => AsyncErrorCard(
                      message: 'Could not load operational metrics. $error',
                      onRetry:
                          () => ref.invalidate(
                            operationalDashboardProvider(user),
                          ),
                    ),
                data:
                    (metrics) =>
                        user.isHead
                            ? _HeadDashboard(metrics: metrics)
                            : _EmployeeDashboard(metrics: metrics),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeadDashboard extends StatelessWidget {
  const _HeadDashboard({required this.metrics});

  final OperationalDashboard metrics;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _PrimaryMetrics(
        items: [
          _MetricSpec(
            'Current outstanding',
            BillingMoney.formatPaise(metrics.currentOutstandingPaise),
            Icons.account_balance_wallet_outlined,
            AppTheme.accent,
            '/reports?tab=outstanding',
          ),
          _MetricSpec(
            "Today's collection",
            BillingMoney.formatPaise(metrics.todayCollectionsPaise),
            Icons.today_outlined,
            AppTheme.brand,
            '/reports?tab=collections',
          ),
          _MetricSpec(
            '${metrics.monthKey} billed',
            BillingMoney.formatPaise(metrics.currentMonthBilledPaise),
            Icons.receipt_long_outlined,
            const Color(0xFF486581),
            '/reports?tab=billing',
          ),
          _MetricSpec(
            '${metrics.monthKey} net collected',
            BillingMoney.formatPaise(metrics.netCollectionsPaise),
            Icons.payments_outlined,
            const Color(0xFF127C71),
            '/reports?tab=collections',
          ),
        ],
      ),
      const SizedBox(height: 22),
      const _SectionTitle('Quick actions'),
      const SizedBox(height: 10),
      const _QuickActions(
        actions: [
          _ActionSpec(
            'Daily pricing',
            'Set one date for every applicable subscription',
            Icons.price_change_outlined,
            '/daily-pricing',
            emphasized: true,
          ),
          _ActionSpec(
            'Add customer',
            'Create a delivery and billing profile',
            Icons.person_add_alt_1,
            '/customers/new',
          ),
          _ActionSpec(
            'Add employee',
            'Open secure invitations and access',
            Icons.manage_accounts_outlined,
            '/employees',
          ),
          _ActionSpec(
            'Add area',
            'Manage delivery coverage',
            Icons.add_location_alt_outlined,
            '/areas',
          ),
          _ActionSpec(
            'Monthly bills',
            'Preview or finalize a selected month',
            Icons.receipt_long_outlined,
            '/billing',
          ),
          _ActionSpec(
            'Collect payment',
            'Find a customer and record receipt',
            Icons.payments_outlined,
            '/customers',
          ),
          _ActionSpec(
            'View reports',
            'Collections, billing, outstanding and routes',
            Icons.analytics_outlined,
            '/reports',
          ),
          _ActionSpec(
            'Business settings',
            'Details, pricing region and UPI',
            Icons.storefront_outlined,
            '/business-settings',
          ),
        ],
      ),
      const SizedBox(height: 22),
      const _SectionTitle('Customers and operations'),
      const SizedBox(height: 10),
      _CompactMetrics(
        values: {
          'Active customers': metrics.activeCustomers,
          'Archived customers': metrics.archivedCustomers,
          'Active employees': metrics.activeEmployees,
          'Active areas': metrics.activeAreas,
          'Active newspapers': metrics.activeNewspapers,
          'Payments this month': metrics.currentMonthPayments,
          'Reversals this month': metrics.currentMonthReversals,
          'No finalized bill': metrics.customersWithoutFinalizedBill,
          'Unpaid': metrics.unpaidCustomers,
          'Partially paid': metrics.partiallyPaidCustomers,
          'Fully paid': metrics.fullyPaidCustomers,
        },
      ),
      const SizedBox(height: 22),
      _SummaryPair(
        leftTitle: 'Employee collections',
        left: metrics.employeeCollections,
        rightTitle: 'Area outstanding',
        right: metrics.areaOutstanding,
      ),
      const SizedBox(height: 22),
      _ActivityGrid(
        payments: metrics.recentPayments,
        billing: metrics.recentBilling,
        customers: metrics.recentCustomers,
      ),
    ],
  );
}

class _EmployeeDashboard extends StatelessWidget {
  const _EmployeeDashboard({required this.metrics});

  final OperationalDashboard metrics;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _PrimaryMetrics(
        items: [
          _MetricSpec(
            'Assigned outstanding',
            BillingMoney.formatPaise(metrics.currentOutstandingPaise),
            Icons.account_balance_wallet_outlined,
            AppTheme.accent,
            '/customers',
          ),
          _MetricSpec(
            "Today's collection",
            BillingMoney.formatPaise(metrics.todayCollectionsPaise),
            Icons.today_outlined,
            AppTheme.brand,
            '/collections',
          ),
          _MetricSpec(
            'This month',
            BillingMoney.formatPaise(metrics.currentMonthCollectionsPaise),
            Icons.payments_outlined,
            const Color(0xFF127C71),
            '/collections',
          ),
          _MetricSpec(
            'Assigned customers',
            '${metrics.activeCustomers}',
            Icons.people_alt_outlined,
            const Color(0xFF486581),
            '/customers',
          ),
        ],
      ),
      const SizedBox(height: 18),
      const _QuickCustomerSearch(),
      const SizedBox(height: 18),
      const _SectionTitle('My daily work'),
      const SizedBox(height: 10),
      const _QuickActions(
        actions: [
          _ActionSpec(
            'Customers needing collection',
            'Open assigned customers with pending balances',
            Icons.pending_actions_outlined,
            '/customers',
            emphasized: true,
          ),
          _ActionSpec(
            'Collect payment',
            'Find an assigned customer',
            Icons.payments_outlined,
            '/customers',
          ),
          _ActionSpec(
            'Recent collections',
            'Your confirmed collection history',
            Icons.history,
            '/collections',
          ),
          _ActionSpec(
            'New customer',
            'Available when your permission allows it',
            Icons.person_add_alt_1,
            '/customers/new',
          ),
        ],
      ),
      const SizedBox(height: 20),
      _CompactMetrics(
        values: {
          'Assigned areas': metrics.activeAreas,
          'Pending customers':
              metrics.unpaidCustomers + metrics.partiallyPaidCustomers,
          'Unpaid': metrics.unpaidCustomers,
          'Partially paid': metrics.partiallyPaidCustomers,
          'Fully paid': metrics.fullyPaidCustomers,
          'Payments this month': metrics.currentMonthPayments,
        },
      ),
      const SizedBox(height: 20),
      _NamedMetricCard(
        title: 'My route groups',
        values: metrics.routeSummaries,
      ),
      const SizedBox(height: 20),
      _ActivityCard(title: 'Recent collections', items: metrics.recentPayments),
    ],
  );
}

class _PrimaryMetrics extends StatelessWidget {
  const _PrimaryMetrics({required this.items});

  final List<_MetricSpec> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1000 ? 4 : 2;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final item in items)
            SizedBox(
              width: width,
              child: Card(
                child: InkWell(
                  onTap: () => context.go(item.route),
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(item.icon, color: item.color),
                        const SizedBox(height: 12),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.value,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: const TextStyle(color: Color(0xFF486581)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.actions});

  final List<_ActionSpec> actions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900 ? 4 : 2;
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final action in actions)
            SizedBox(
              width: width,
              child: Card(
                color:
                    action.emphasized ? const Color(0xFFFFF5D6) : Colors.white,
                child: InkWell(
                  onTap: () => context.go(action.route),
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          action.icon,
                          color:
                              action.emphasized
                                  ? const Color(0xFF9A6700)
                                  : AppTheme.brand,
                        ),
                        const SizedBox(height: 9),
                        Text(
                          action.label,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          action.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF486581),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _CompactMetrics extends StatelessWidget {
  const _CompactMetrics({required this.values});

  final Map<String, int> values;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final entry in values.entries)
            Chip(
              label: Text('${entry.key}: ${entry.value}'),
              side: BorderSide.none,
              backgroundColor: const Color(0xFFF0F4F2),
            ),
        ],
      ),
    ),
  );
}

class _SummaryPair extends StatelessWidget {
  const _SummaryPair({
    required this.leftTitle,
    required this.left,
    required this.rightTitle,
    required this.right,
  });

  final String leftTitle;
  final List<NamedMetric> left;
  final String rightTitle;
  final List<NamedMetric> right;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 760) {
        return Column(
          children: [
            _NamedMetricCard(title: leftTitle, values: left),
            const SizedBox(height: 12),
            _NamedMetricCard(title: rightTitle, values: right),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _NamedMetricCard(title: leftTitle, values: left)),
          const SizedBox(width: 12),
          Expanded(child: _NamedMetricCard(title: rightTitle, values: right)),
        ],
      );
    },
  );
}

class _NamedMetricCard extends StatelessWidget {
  const _NamedMetricCard({required this.title, required this.values});

  final String title;
  final List<NamedMetric> values;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (values.isEmpty)
            const Text(
              'No activity yet.',
              style: TextStyle(color: Color(0xFF829AB1)),
            )
          else
            for (final value in values.take(6))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(child: Text(value.label)),
                    Text(
                      BillingMoney.formatPaise(value.amountPaise),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
        ],
      ),
    ),
  );
}

class _ActivityGrid extends StatelessWidget {
  const _ActivityGrid({
    required this.payments,
    required this.billing,
    required this.customers,
  });

  final List<DashboardActivity> payments;
  final List<DashboardActivity> billing;
  final List<DashboardActivity> customers;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cards = [
        _ActivityCard(title: 'Recent payments', items: payments),
        _ActivityCard(title: 'Recent billing', items: billing),
        _ActivityCard(title: 'Recent customer activity', items: customers),
      ];
      if (constraints.maxWidth < 900) {
        return Column(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              cards[index],
              if (index < cards.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < cards.length; index++) ...[
            Expanded(child: cards[index]),
            if (index < cards.length - 1) const SizedBox(width: 12),
          ],
        ],
      );
    },
  );
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.title, required this.items});

  final String title;
  final List<DashboardActivity> items;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text(
              'No recent activity.',
              style: TextStyle(color: Color(0xFF829AB1)),
            )
          else
            for (final item in items)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                onTap: item.route.isEmpty ? null : () => context.go(item.route),
                title: Text(item.title, maxLines: 1),
                subtitle: Text(
                  [
                    item.subtitle,
                    if (item.occurredAt != null)
                      DateFormat('d MMM, h:mm a').format(item.occurredAt!),
                  ].where((value) => value.isNotEmpty).join(' · '),
                  maxLines: 2,
                ),
                trailing:
                    item.amountPaise == null
                        ? null
                        : Text(
                          BillingMoney.formatPaise(item.amountPaise!),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
              ),
        ],
      ),
    ),
  );
}

class _QuickCustomerSearch extends StatefulWidget {
  const _QuickCustomerSearch();

  @override
  State<_QuickCustomerSearch> createState() => _QuickCustomerSearchState();
}

class _QuickCustomerSearchState extends State<_QuickCustomerSearch> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    key: const ValueKey('dashboard-customer-search'),
    controller: _controller,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      labelText: 'Quick customer search',
      hintText: 'Name, phone, code, or landmark',
      prefixIcon: const Icon(Icons.search),
      suffixIcon: IconButton(
        tooltip: 'Search customers',
        onPressed: _search,
        icon: const Icon(Icons.arrow_forward),
      ),
    ),
    onSubmitted: (_) => _search(),
  );

  void _search() {
    final value = _controller.text.trim();
    context.go(
      value.isEmpty
          ? '/customers'
          : '/customers?q=${Uri.encodeComponent(value)}',
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('Loading current operations…'),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
  );
}

class _MetricSpec {
  const _MetricSpec(this.label, this.value, this.icon, this.color, this.route);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String route;
}

class _ActionSpec {
  const _ActionSpec(
    this.label,
    this.description,
    this.icon,
    this.route, {
    this.emphasized = false,
  });

  final String label;
  final String description;
  final IconData icon;
  final String route;
  final bool emphasized;
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
