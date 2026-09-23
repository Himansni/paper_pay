import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/saas/domain/saas_models.dart';
import 'package:paper_route/features/saas/presentation/saas_providers.dart';

class SaasSubscriptionPage extends ConsumerWidget {
  const SaasSubscriptionPage({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!user.isHead) {
      return Scaffold(
        appBar: _appBar(context),
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: EmptyStateCard(
            icon: Icons.lock_outline,
            title: 'Head access required',
            message:
                'Only the Agency Head can view or manage the PaperRoute SaaS subscription and plan tiers.',
          ),
        ),
      );
    }

    final businessId = user.businessId!;
    final subscriptionAsync = ref.watch(saasSubscriptionProvider(businessId));

    return Scaffold(
      appBar: _appBar(context),
      body: SafeArea(
        top: false,
        child: subscriptionAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (error, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: AsyncErrorCard(
                  message: 'Could not load subscription details: $error',
                  onRetry:
                      () => ref.invalidate(saasSubscriptionProvider(businessId)),
                ),
              ),
          data: (subscription) {
            final now = DateTime.now();
            final effectiveStatus = subscription.effectiveStatus(now);
            final daysLeft = subscription.daysRemaining(now);
            final graceDaysLeft = subscription.graceDaysRemaining(now);

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                _StatusHeroCard(
                  subscription: subscription,
                  effectiveStatus: effectiveStatus,
                  daysLeft: daysLeft,
                  graceDaysLeft: graceDaysLeft,
                ),
                const SizedBox(height: 16),
                _DataPreservationCard(onExportPressed: () => context.go('/reports')),
                const SizedBox(height: 24),
                Text(
                  'Available subscription plans',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose the plan that fits your agency scale. Subscriptions are billed directly to the agency.',
                  style: TextStyle(color: Color(0xFF486581), height: 1.3),
                ),
                const SizedBox(height: 16),
                for (final plan in SaasPlan.catalog) ...[
                  _PlanCard(
                    plan: plan,
                    isCurrentPlan: subscription.planId == plan.id,
                    onSelect: () => _handlePlanSelection(context, ref, plan),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  AppBar _appBar(BuildContext context) => AppBar(
    leading: BackButton(
      onPressed:
          () =>
              context.canPop()
                  ? context.pop()
                  : context.go('/business-settings'),
    ),
    title: const Text('PaperRoute subscription'),
  );

  void _handlePlanSelection(
    BuildContext context,
    WidgetRef ref,
    SaasPlan plan,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('Select ${plan.name}'),
            content: Text(
              '${plan.description}\n\n'
              '• Max customers: ${plan.customerLimit}\n'
              '• Max staff accounts: ${plan.employeeLimit}\n\n'
              'Submit a subscription renewal / upgrade request for this agency? Our team will activate the plan after verification.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Submit request'),
              ),
            ],
          ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(saasRepositoryProvider).requestPlanRenewal(
          businessId: user.businessId!,
          actorId: user.uid,
          targetPlanId: plan.id,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Plan request for ${plan.name} submitted successfully.',
              ),
            ),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Could not submit request: $error')));
        }
      }
    }
  }
}

class _StatusHeroCard extends StatelessWidget {
  const _StatusHeroCard({
    required this.subscription,
    required this.effectiveStatus,
    required this.daysLeft,
    required this.graceDaysLeft,
  });

  final SaasSubscription subscription;
  final SaasSubscriptionStatus effectiveStatus;
  final int daysLeft;
  final int graceDaysLeft;

  @override
  Widget build(BuildContext context) {
    Color cardColor;
    Color textColor;
    IconData icon;
    String title;
    String subtitle;

    switch (effectiveStatus) {
      case SaasSubscriptionStatus.trial:
        cardColor = const Color(0xFFE6F6FF);
        textColor = const Color(0xFF004E7C);
        icon = Icons.star_outline_rounded;
        title = 'Free 30-Day Trial Active';
        subtitle =
            '$daysLeft days remaining in your trial. All operational features, direct UPI QR collections, and billing are fully available.';
        break;
      case SaasSubscriptionStatus.active:
        cardColor = const Color(0xFFE5F5EE);
        textColor = const Color(0xFF0E5838);
        icon = Icons.verified_outlined;
        title = 'Active Subscription';
        subtitle =
            'Your agency subscription is active. Billed directly for PaperRoute software access.';
        break;
      case SaasSubscriptionStatus.gracePeriod:
        cardColor = const Color(0xFFFFF8E8);
        textColor = const Color(0xFF8A5B00);
        icon = Icons.warning_amber_rounded;
        title = 'Grace Period: $graceDaysLeft Days Left';
        subtitle =
            'Your trial period has concluded. You have $graceDaysLeft days of grace before new entries become read-only. Existing records remain safe.';
        break;
      case SaasSubscriptionStatus.expired:
        cardColor = const Color(0xFFFFF0F0);
        textColor = const Color(0xFF9E1B1B);
        icon = Icons.lock_clock_outlined;
        title = 'Subscription Expired (Read-Only)';
        subtitle =
            'Your trial and grace periods have ended. Existing customer records, bills, and ledgers remain preserved and exportable.';
        break;
    }

    final dateFormat = DateFormat('d MMM yyyy');

    return Card(
      key: const ValueKey('saas-status-card'),
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: textColor.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: textColor.withValues(alpha: 0.15),
                  child: Icon(icon, color: textColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        key: const ValueKey('saas-status-title'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Activated on: ${dateFormat.format(subscription.trialStartsAt.toLocal())}',
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: textColor.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _StatBadge(
                  label: 'Customer limit',
                  value: '${subscription.customerLimit}',
                  color: textColor,
                ),
                _StatBadge(
                  label: 'Staff accounts',
                  value: '${subscription.employeeLimit}',
                  color: textColor,
                ),
                _StatBadge(
                  label: 'Trial duration',
                  value: '30 Days',
                  color: textColor,
                ),
                _StatBadge(
                  label: 'Grace period',
                  value: '${subscription.graceDays} Days',
                  color: textColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _DataPreservationCard extends StatelessWidget {
  const _DataPreservationCard({required this.onExportPressed});

  final VoidCallback onExportPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF7F9FC),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFD9E2EC)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.shield_outlined, color: Color(0xFF334E68), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Financial Records Permanently Preserved',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF102A43),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'PaperRoute never deletes agency data or ledger entries upon subscription expiry.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF486581)),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              key: const ValueKey('saas-export-data-btn'),
              onPressed: onExportPressed,
              icon: const Icon(Icons.download_outlined, size: 16),
              label: const Text('Export CSV', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isCurrentPlan,
    required this.onSelect,
  });

  final SaasPlan plan;
  final bool isCurrentPlan;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: plan.isPopular ? 2 : 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color:
              plan.isPopular
                  ? Theme.of(context).colorScheme.primary
                  : const Color(0xFFD9E2EC),
          width: plan.isPopular ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (plan.isPopular)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'MOST POPULAR',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              plan.description,
              style: const TextStyle(fontSize: 12, color: Color(0xFF486581)),
            ),
            const SizedBox(height: 8),
            Text(
              plan.priceDescription,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF243B53),
              ),
            ),
            const Divider(height: 20),
            for (final feature in plan.features) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 15,
                      color: Color(0xFF0E5838),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(fontSize: 12, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child:
                  isCurrentPlan
                      ? OutlinedButton(
                        onPressed: null,
                        child: const Text('Current active plan'),
                      )
                      : FilledButton.tonal(
                        onPressed: onSelect,
                        child: Text('Select ${plan.name}'),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
