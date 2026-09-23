import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/domain/local_date.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/core/theme/app_theme.dart';
import 'package:paper_route/features/areas/presentation/area_providers.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/delivery/domain/delivery_models.dart';
import 'package:paper_route/features/delivery/presentation/arrange_route_page.dart';
import 'package:paper_route/features/delivery/presentation/delivery_providers.dart';
import 'package:paper_route/l10n/app_localizations.dart';

class MorningRoutePage extends ConsumerStatefulWidget {
  const MorningRoutePage({required this.user, super.key});

  final AppUser user;

  @override
  ConsumerState<MorningRoutePage> createState() => _MorningRoutePageState();
}

class _MorningRoutePageState extends ConsumerState<MorningRoutePage> {
  static const _accessPolicy = AccessPolicy();
  String _filter = 'all'; // all | pending | delivered | paused

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final businessId = user.businessId!;
    final areasAsync = ref.watch(deliveryAreasProvider(businessId));
    final selectedDate = ref.watch(morningRouteDateProvider);
    final stopsAsync = ref.watch(morningRouteStopsProvider(user));
    final selectedAreaId = ref.watch(selectedRouteAreaProvider);
    final areas = areasAsync.asData?.value ?? [];

    String activeAreaId = selectedAreaId;
    if (activeAreaId.isEmpty) {
      if (user.areaIds.isNotEmpty) {
        activeAreaId = user.areaIds.first;
      } else if (areas.isNotEmpty) {
        activeAreaId = areas.first.id;
      }
    }

    final activeAreaName = areas
            .where((a) => a.id == activeAreaId)
            .map((a) => a.name)
            .firstOrNull ??
        'Route';

    final canArrange =
        _accessPolicy.canArrangeRoutes(member: user, areaId: activeAreaId);

    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_bike_outlined, color: AppTheme.brand),
            const SizedBox(width: 8),
            Text(l10n?.morningRouteTitle ?? 'Morning Route'),
          ],
        ),
        actions: [
          if (canArrange && activeAreaId.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.swap_vert),
              tooltip: l10n?.arrangeDeliveryRoute ?? 'Arrange Route',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => ArrangeRoutePage(
                      user: user,
                      areaId: activeAreaId,
                      areaName: activeAreaName,
                    ),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: l10n?.selectRouteDate ?? 'Select Route Date',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate.toDateTime(),
                firstDate: DateTime.now().subtract(const Duration(days: 7)),
                lastDate: DateTime.now().add(const Duration(days: 14)),
              );
              if (picked != null) {
                ref.read(morningRouteDateProvider.notifier).setDate(LocalDate.fromDateTime(picked));
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n?.refreshRoute ?? 'Refresh Route',
            onPressed: () => ref.invalidate(morningRouteStopsProvider(user)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: stopsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: AsyncErrorCard(
              message: 'Could not load morning route. $err',
              onRetry: () => ref.invalidate(morningRouteStopsProvider(user)),
            ),
          ),
          data: (stops) {
            final areas = areasAsync.asData?.value ?? [];
            final total = stops.length;
            final delivered = stops.where((s) => s.isDelivered).length;
            final paused = stops.where((s) => s.isPausedToday).length;
            final exceptions = stops.where((s) => s.status == DeliveryStopStatus.exception).length;
            final pending = total - delivered - paused - exceptions;
            final progress = total == 0 ? 0.0 : (delivered / (total - paused > 0 ? total - paused : 1));

            final filteredStops = stops.where((s) {
              if (_filter == 'pending') return s.status == DeliveryStopStatus.pending && !s.isPausedToday;
              if (_filter == 'delivered') return s.isDelivered;
              if (_filter == 'paused') return s.isPausedToday;
              return true;
            }).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                // Top Route & Progress Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                    stops.isNotEmpty ? stops.first.areaName : 'Delivery Route',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${selectedDate.toString()} • ${selectedDate.toDateTime().weekday == 7 ? "Sunday" : "Weekday"}',
                                    style: const TextStyle(color: Color(0xFF486581), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            if (areas.length > 1)
                              DropdownButton<String>(
                                value: ref.watch(selectedRouteAreaProvider).isEmpty
                                    ? (stops.isNotEmpty ? stops.first.areaId : '')
                                    : ref.watch(selectedRouteAreaProvider),
                                underline: const SizedBox.shrink(),
                                items: [
                                  for (final a in areas)
                                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    ref.read(selectedRouteAreaProvider.notifier).setArea(val);
                                  }
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 10,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.brand),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$delivered of ${total - paused} active delivered',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${(progress * 100).round()}% Completed',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.brand),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: l10n?.filterAll(total) ?? 'All ($total)',
                        isSelected: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: l10n?.filterPending(pending) ?? 'Pending ($pending)',
                        isSelected: _filter == 'pending',
                        onTap: () => setState(() => _filter = 'pending'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: l10n?.filterDelivered(delivered) ?? 'Delivered ($delivered)',
                        isSelected: _filter == 'delivered',
                        onTap: () => setState(() => _filter = 'delivered'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: l10n?.filterPaused(paused) ?? 'Paused ($paused)',
                        isSelected: _filter == 'paused',
                        onTap: () => setState(() => _filter = 'paused'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (filteredStops.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        _filter == 'pending'
                            ? (l10n?.allDropsCompleted ?? '🎉 All active drops completed!')
                            : (l10n?.noMatchingStops ?? 'No stops match this filter.'),
                        style: const TextStyle(fontSize: 16, color: Color(0xFF486581), fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                else
                  for (final stop in filteredStops)
                    _RouteStopCard(
                      key: ValueKey('stop-${stop.customerId}'),
                      stop: stop,
                      onMarkDelivered: () {
                        ref.read(deliveryStatusStateProvider.notifier).markDelivered(
                              stop.customerId,
                              businessId: businessId,
                              areaId: stop.areaId,
                              date: selectedDate,
                              actorUid: user.uid,
                            );
                      },
                      onUndoDelivered: () {
                        ref.read(deliveryStatusStateProvider.notifier).reset(
                              stop.customerId,
                              businessId: businessId,
                              areaId: stop.areaId,
                              date: selectedDate,
                              actorUid: user.uid,
                            );
                      },
                      onReportIssue: () => _showExceptionDialog(context, ref, stop, user.uid, businessId, selectedDate),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showExceptionDialog(
    BuildContext context,
    WidgetRef ref,
    DailyRouteStop stop,
    String actorUid,
    String businessId,
    LocalDate selectedDate,
  ) async {
    final l10n = AppLocalizations.of(context);
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n?.reportIssueFor(stop.customerName) ?? 'Report Issue for ${stop.customerName}'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'House Locked / Gate Closed'),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: Colors.orange),
                const SizedBox(width: 12),
                Text(l10n?.exceptionHouseLocked ?? 'House Locked / Gate Closed'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Heavy Rain / Waterlogged'),
            child: Row(
              children: [
                const Icon(Icons.water_drop_outlined, color: Colors.blue),
                const SizedBox(width: 12),
                Text(l10n?.exceptionRain ?? 'Heavy Rain / Waterlogged'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Newspaper Shortage'),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_outlined, color: Colors.amber),
                const SizedBox(width: 12),
                Text(l10n?.exceptionPaperShortage ?? 'Newspaper Shortage'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'Customer Refused Delivery'),
            child: Row(
              children: [
                const Icon(Icons.person_off_outlined, color: Colors.red),
                const SizedBox(width: 12),
                Text(l10n?.exceptionCustomerRefused ?? 'Customer Refused Delivery'),
              ],
            ),
          ),
        ],
      ),
    );

    if (reason != null) {
      ref.read(deliveryStatusStateProvider.notifier).markException(
            stop.customerId,
            reason,
            businessId: businessId,
            areaId: stop.areaId,
            date: selectedDate,
            actorUid: actorUid,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Issue logged for ${stop.customerName}: $reason')),
      );
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600)),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.brand.withValues(alpha: 0.15),
      checkmarkColor: AppTheme.brand,
    );
  }
}

class _RouteStopCard extends StatelessWidget {
  const _RouteStopCard({
    required this.stop,
    required this.onMarkDelivered,
    required this.onUndoDelivered,
    required this.onReportIssue,
    super.key,
  });

  final DailyRouteStop stop;
  final VoidCallback onMarkDelivered;
  final VoidCallback onUndoDelivered;
  final VoidCallback onReportIssue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPaused = stop.isPausedToday;
    final isDelivered = stop.isDelivered;
    final isException = stop.status == DeliveryStopStatus.exception;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDelivered
              ? const Color(0xFF127C71)
              : isPaused
                  ? const Color(0xFFFF9900)
                  : isException
                      ? Colors.red
                      : const Color(0xFFE2E8F0),
          width: isDelivered || isPaused || isException ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stop header with code and status badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF2F7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#${stop.routeSequence} • ${stop.customerCode}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF2D3748)),
                  ),
                ),
                const Spacer(),
                if (isDelivered)
                  Chip(
                    avatar: const Icon(Icons.check_circle, color: Colors.white, size: 16),
                    label: Text(l10n?.deliveredBadge ?? 'Delivered', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    backgroundColor: const Color(0xFF127C71),
                    padding: EdgeInsets.zero,
                  )
                else if (isPaused)
                  Chip(
                    avatar: const Icon(Icons.pause_circle_filled, color: Colors.white, size: 16),
                    label: Text(l10n?.pausedTodayBadge ?? 'Paused', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    backgroundColor: const Color(0xFFDD6B20),
                    padding: EdgeInsets.zero,
                  )
                else if (isException)
                  Chip(
                    avatar: const Icon(Icons.warning, color: Colors.white, size: 16),
                    label: Text(l10n?.issueBadge ?? 'Issue', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // House number and customer name
            Text(
              stop.customerName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (stop.houseNumber.isNotEmpty || stop.buildingInfo.isNotEmpty)
              Text(
                [stop.houseNumber, stop.buildingInfo].where((s) => s.isNotEmpty).join(', '),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1A202C)),
              ),
            Text(
              stop.address,
              style: const TextStyle(color: Color(0xFF4A5568), fontSize: 14),
            ),
            if (stop.landmark.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '📍 Landmark: ${stop.landmark}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF8A4B00), fontSize: 13),
                ),
              ),
            if (stop.deliveryPlacement.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '📌 Placement: ${stop.deliveryPlacement}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2B6CB0), fontSize: 13),
                ),
              ),

            const Divider(height: 20),

            // Paper Drop Badges
            if (isPaused)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFD599)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.pause_circle_outline, color: Color(0xFF8A4B00)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '⛔ PAUSED TODAY — DO NOT DELIVER ANY PAPERS',
                            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF8A4B00), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final drop in stop.drops)
                      Padding(
                        padding: const EdgeInsets.only(left: 28, top: 2),
                        child: Text(
                          '• ${drop.newspaperName} (${drop.pauseReason ?? "Paused"})',
                          style: const TextStyle(color: Color(0xFF8A4B00), fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              )
            else ...[
              const Text('PAPERS TO DELIVER:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF718096))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final drop in stop.activeDrops)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF8FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBEE3F8)),
                      ),
                      child: Text(
                        '${drop.newspaperName}  × ${drop.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2B6CB0), fontSize: 14),
                      ),
                    ),
                  for (final drop in stop.pausedDrops)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5F5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFED7D7)),
                      ),
                      child: Text(
                        '${drop.newspaperName} (Paused)',
                        style: const TextStyle(color: Color(0xFFC53030), fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 14),

            // Actions row
            Row(
              children: [
                if (!isPaused && !isDelivered) ...[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onMarkDelivered,
                      icon: const Icon(Icons.check),
                      label: Text(l10n?.markDelivered ?? 'Mark Delivered'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF127C71),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: onReportIssue,
                    tooltip: l10n?.logException ?? 'Report Issue',
                    icon: const Icon(Icons.warning_amber_outlined, color: Colors.orange),
                  ),
                ] else if (isDelivered) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onUndoDelivered,
                      icon: const Icon(Icons.undo),
                      label: Text(l10n?.undoDelivered ?? 'Undo Delivered'),
                    ),
                  ),
                ] else if (isPaused) ...[
                  Expanded(
                    child: Text(
                      l10n?.pausedHouseholdNotice ?? 'No action required for paused household.',
                      style: const TextStyle(color: Color(0xFF718096), fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
