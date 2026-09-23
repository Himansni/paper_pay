import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/features/saas/domain/saas_models.dart';
import 'package:paper_route/features/saas/presentation/saas_providers.dart';

class ReadOnlyNoticeBanner extends ConsumerWidget {
  const ReadOnlyNoticeBanner({required this.businessId, super.key});

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(saasEntitlementProvider(businessId));
    if (entitlement == null) return const SizedBox.shrink();

    if (entitlement.effectiveStatus == SaasSubscriptionStatus.expired) {
      return Container(
        color: const Color(0xFFFFF0F0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.lock_clock_outlined, color: Color(0xFFC53030), size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Subscription expired — Read-Only Mode. Records are safe.',
                style: TextStyle(
                  color: Color(0xFF9B2C2C),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/business-settings/subscription'),
              child: const Text('View plans', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    if (entitlement.isInGracePeriod) {
      return Container(
        color: const Color(0xFFFFF8E8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFB7791F), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Trial concluded. Grace period: ${entitlement.graceDaysRemaining} days remaining.',
                style: const TextStyle(
                  color: Color(0xFF744210),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/business-settings/subscription'),
              child: const Text('Renew now', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Utility function to check whether writes are allowed, or display a reassuring read-only explanation.
bool checkCanPerformMutation(
  BuildContext context,
  WidgetRef ref,
  String businessId,
) {
  final entitlement = ref.read(saasEntitlementProvider(businessId));
  if (entitlement == null) return true;

  if (entitlement.isReadOnly) {
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Read-Only Mode Active'),
            content: const Text(
              'Your agency trial and 7-day grace period have concluded.\n\n'
              '• All existing customer records, bills, and ledger payments are permanently preserved.\n'
              '• You can view and export records anytime.\n'
              '• To create new records or record new collections, please renew your PaperRoute subscription.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  context.push('/business-settings/subscription');
                },
                child: const Text('View subscription plans'),
              ),
            ],
          ),
    );
    return false;
  }
  return true;
}
