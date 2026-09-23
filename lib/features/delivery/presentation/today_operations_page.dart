import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/core/theme/app_theme.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/delivery/domain/today_operations_models.dart';
import 'package:paper_route/features/delivery/presentation/delivery_providers.dart';
import 'package:paper_route/features/delivery/presentation/today_operations_providers.dart';
import 'package:paper_route/l10n/app_localizations.dart';

class TodayOperationsPage extends ConsumerWidget {
  const TodayOperationsPage({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selectedDate = ref.watch(headTodayOperationsDateProvider);
    final operationsAsync = ref.watch(headTodayOperationsProvider(user));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dashboard_customize_outlined, color: AppTheme.brand),
            const SizedBox(width: 8),
            Text(l10n?.headTodayTitle ?? "Today's Operations"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: l10n?.selectRouteDate ?? 'Select Date',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate.toDateTime(),
                firstDate: DateTime.now().subtract(const Duration(days: 7)),
                lastDate: DateTime.now().add(const Duration(days: 14)),
              );
              if (picked != null) {
                ref
                    .read(headTodayOperationsDateProvider.notifier)
                    .setDate(LocalDate.fromDateTime(picked));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n?.commonRefresh ?? 'Refresh',
            onPressed: () => ref.invalidate(headTodayOperationsProvider(user)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: operationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: AsyncErrorCard(
              message: 'Could not load today operations. $err',
              onRetry: () => ref.invalidate(headTodayOperationsProvider(user)),
            ),
          ),
          data: (summary) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(headTodayOperationsProvider(user));
              await ref.read(headTodayOperationsProvider(user).future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                // Top Header info card
                _HeaderOverviewCard(summary: summary, date: selectedDate),
                const SizedBox(height: 16),

                // Section 1: Depot Pickup Circulation Tally
                _DepotCirculationCard(summary: summary),
                const SizedBox(height: 16),

                // Section 2: Live Delivery Progress by Route
                _RouteProgressMonitorCard(summary: summary),
                const SizedBox(height: 16),

                // Section 3: Today's Collections & Outstanding
                _TodayCollectionsCard(summary: summary),
                const SizedBox(height: 16),

                // Section 4: Operational Alerts & Exceptions
                _OperationalAlertsCard(summary: summary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderOverviewCard extends StatelessWidget {
  const _HeaderOverviewCard({required this.summary, required this.date});

  final HeadTodayOperationsSummary summary;
  final LocalDate date;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isSunday = date.toDateTime().weekday == 7;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.headTodaySubtitle ?? 'Live Depot Circulation & Delivery Monitoring',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF486581),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${date.toString()} • ${isSunday ? "Sunday" : "Weekday"}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBF8FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBEE3F8)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.route_outlined, size: 16, color: Color(0xFF2B6CB0)),
                      const SizedBox(width: 6),
                      Text(
                        '${summary.completedRoutes} / ${summary.totalRoutes} Lines Done',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2B6CB0), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DepotCirculationCard extends StatelessWidget {
  const _DepotCirculationCard({required this.summary});

  final HeadTodayOperationsSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: Color(0xFFDD6B20)),
                const SizedBox(width: 8),
                Text(
                  l10n?.depotPickupTally ?? 'Depot Pickup Circulation',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/subscriptions'),
                  child: const Text('All Subscriptions →'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Top Stats Summary Pill Row
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _TallyMetric(
                    label: 'Ordered',
                    count: summary.totalOrderedCopies,
                    color: const Color(0xFF2B6CB0),
                  ),
                  Container(width: 1, height: 30, color: const Color(0xFFCBD5E0)),
                  _TallyMetric(
                    label: 'Paused',
                    count: summary.totalPausedCopies,
                    color: const Color(0xFFC53030),
                  ),
                  Container(width: 1, height: 30, color: const Color(0xFFCBD5E0)),
                  _TallyMetric(
                    label: 'To Pick Up',
                    count: summary.totalToDistributeCopies,
                    color: const Color(0xFF127C71),
                    isEmphasized: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Detailed publication breakdown list
            if (summary.circulationTallies.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('No active publication copies scheduled for this date.', style: TextStyle(color: Color(0xFF718096))),
                ),
              )
            else
              for (final tally in summary.circulationTallies)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEDF2F7)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tally.newspaperName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                      Text(
                        '${tally.orderedCopies} ordered',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
                      ),
                      if (tally.pausedCopies > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(-${tally.pausedCopies})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFC53030)),
                        ),
                      ],
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6FFFA),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFB2F5EA)),
                        ),
                        child: Text(
                          '${tally.toDistributeCopies} copies',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF234E52), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _TallyMetric extends StatelessWidget {
  const _TallyMetric({
    required this.label,
    required this.count,
    required this.color,
    this.isEmphasized = false,
  });

  final String label;
  final int count;
  final Color color;
  final bool isEmphasized;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF718096),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$count',
          style: TextStyle(
            fontSize: isEmphasized ? 20 : 17,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _RouteProgressMonitorCard extends ConsumerWidget {
  const _RouteProgressMonitorCard({required this.summary});

  final HeadTodayOperationsSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_bike_outlined, color: AppTheme.brand),
                const SizedBox(width: 8),
                Text(
                  l10n?.routeProgressTitle ?? 'Route Progress by Hawker',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (summary.routeProgresses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('No active distribution lines configured.', style: TextStyle(color: Color(0xFF718096))),
                ),
              )
            else
              for (final route in summary.routeProgresses)
                InkWell(
                  onTap: () {
                    // Preselect this area in morning route provider and open Morning Route
                    ref.read(selectedRouteAreaProvider.notifier).setArea(route.areaId);
                    context.push('/morning-route');
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              route.areaName,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            Row(
                              children: [
                                Text(
                                  '${route.deliveredStops} / ${route.activeStops} (${route.percentComplete}%)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: route.isCompleted ? const Color(0xFF127C71) : const Color(0xFF2B6CB0),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  route.isCompleted ? Icons.check_circle : Icons.chevron_right,
                                  size: 18,
                                  color: route.isCompleted ? const Color(0xFF127C71) : const Color(0xFF718096),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: route.progressRatio,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFEDF2F7),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              route.isCompleted ? const Color(0xFF127C71) : AppTheme.brand,
                            ),
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

class _TodayCollectionsCard extends StatelessWidget {
  const _TodayCollectionsCard({required this.summary});

  final HeadTodayOperationsSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments_outlined, color: Color(0xFF127C71)),
                const SizedBox(width: 8),
                Text(
                  l10n?.todayCollectionsTitle ?? "Today's Collections",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/reports?tab=collections'),
                  child: const Text('Collections Report →'),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDCFCE7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cash in Hand', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF166534))),
                        const SizedBox(height: 4),
                        Text(
                          BillingMoney.formatPaise(summary.collections.cashPaise),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF166534)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Direct UPI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF))),
                        const SizedBox(height: 4),
                        Text(
                          BillingMoney.formatPaise(summary.collections.upiPaise),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1E40AF)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Outstanding Summary Tile
            InkWell(
              onTap: () => context.push('/reports?tab=outstanding'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 20, color: Color(0xFFC2410C)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Total Outstanding Balance across Agency',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF9A3412)),
                      ),
                    ),
                    Text(
                      BillingMoney.formatPaise(summary.currentOutstandingPaise),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF9A3412)),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 18, color: Color(0xFF9A3412)),
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

class _OperationalAlertsCard extends StatelessWidget {
  const _OperationalAlertsCard({required this.summary});

  final HeadTodayOperationsSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final exceptions = summary.todayExceptions;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_outlined, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  l10n?.operationalAlertsTitle ?? 'Operational Exceptions Reported Today',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (exceptions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    l10n?.noOperationalAlerts ?? 'No delivery exceptions reported today. All routes running smoothly.',
                    style: const TextStyle(color: Color(0xFF486581), fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              )
            else
              for (final exc in exceptions)
                InkWell(
                  onTap: () => context.push('/customers/${exc.customerId}'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFED7D7)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.report_problem_outlined, color: Colors.red, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exc.exceptionReason ?? 'Issue reported',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF9B2C2C)),
                              ),
                              Text(
                                'Customer: ${exc.customerId} • Area: ${exc.areaId}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Color(0xFF718096)),
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
