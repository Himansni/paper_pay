import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/collections/presentation/collections_providers.dart';
import 'package:paper_route/features/customers/domain/customer.dart';

class CustomerCollectionSummary extends ConsumerWidget {
  const CustomerCollectionSummary({
    required this.user,
    required this.customer,
    super.key,
  });

  final AppUser user;
  final Customer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (businessId: user.businessId!, customerId: customer.id);
    final outstanding = ref.watch(customerOutstandingProvider(key));
    const policy = AccessPolicy();
    final canCollect = policy.canRecordPayment(
      member: user,
      customerBusinessId: customer.businessId,
      assignedEmployeeId: customer.assignedEmployeeId,
      customerAreaId: customer.areaId,
      isCustomerArchived: customer.isArchived,
    );
    final canAdjustOutstanding = policy.canAdjustOutstanding(
      member: user,
      customerBusinessId: customer.businessId,
      assignedEmployeeId: customer.assignedEmployeeId,
      customerAreaId: customer.areaId,
      isCustomerArchived: customer.isArchived,
    );
    final canCreateManualBill = policy.canCreateManualBill(
      member: user,
      customerBusinessId: customer.businessId,
      assignedEmployeeId: customer.assignedEmployeeId,
      customerAreaId: customer.areaId,
      isCustomerArchived: customer.isArchived,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Collections',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            outstanding.when(
              loading: () => const LinearProgressIndicator(),
              error:
                  (error, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Could not load current outstanding. $error',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      TextButton.icon(
                        onPressed:
                            () => ref.invalidate(
                              customerOutstandingProvider(key),
                            ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
              data:
                  (summary) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current outstanding',
                        style: TextStyle(color: Color(0xFF486581)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        BillingMoney.formatPaise(summary.amountDuePaise),
                        key: const ValueKey('customer-current-outstanding'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      if (summary.collectiblePaise != summary.amountDuePaise &&
                          summary.amountDuePaise > 0) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Collectible now: ${BillingMoney.formatPaise(summary.collectiblePaise)}',
                            style: const TextStyle(
                              color: Color(0xFF486581),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (summary.unbilledOpeningPaise > 0 && summary.bills.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Unbilled opening balance will become collectible after the first monthly bill is finalized.',
                              style: TextStyle(
                                color: Color(0xFF627D98),
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                      if (summary.creditPaise > 0)
                        Text(
                          'Customer credit ${BillingMoney.formatPaise(summary.creditPaise)}',
                        ),
                      if (!summary.serverConfirmed)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'Server confirmation pending. Collection is disabled.',
                          ),
                        ),
                      if (summary.requiresProjectionSetup)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'A reviewed collection-projection migration is required before recording a payment against this legacy balance.',
                            key: ValueKey('customer-projection-required'),
                          ),
                        ),
                      const SizedBox(height: 16),
                      // FINANCIAL ACTIONS HIERARCHY
                      // Primary action: Collect Payment
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const ValueKey('open-collect-payment'),
                          onPressed:
                              canCollect &&
                                      summary.collectiblePaise > 0 &&
                                      summary.serverConfirmed &&
                                      !summary.requiresProjectionSetup
                                  ? () => context.push<void>(
                                    '/customers/${Uri.encodeComponent(customer.id)}/collect',
                                  )
                                  : null,
                          icon: const Icon(Icons.payments_outlined),
                          label: Text(
                            summary.collectiblePaise <= 0
                                ? 'Collect payment (Nothing collectible yet)'
                                : 'Collect payment (${BillingMoney.formatPaise(summary.collectiblePaise)})',
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Secondary actions: Adjust Outstanding and Create Bill
                      Row(
                        children: [
                          if (canAdjustOutstanding)
                            Expanded(
                              child: OutlinedButton.icon(
                                key: const ValueKey(
                                  'open-outstanding-adjustment',
                                ),
                                onPressed:
                                    () => context.push<void>(
                                      '/customers/${Uri.encodeComponent(customer.id)}/adjust-outstanding',
                                    ),
                                icon: const Icon(Icons.edit_document, size: 18),
                                label: const Text(
                                  'Adjust outstanding',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          if (canAdjustOutstanding && canCreateManualBill)
                            const SizedBox(width: 8),
                          if (canCreateManualBill)
                            Expanded(
                              child: OutlinedButton.icon(
                                key: const ValueKey('open-manual-bill'),
                                onPressed:
                                    () => context.push<void>(
                                      '/customers/${Uri.encodeComponent(customer.id)}/manual-bill',
                                    ),
                                icon: const Icon(Icons.receipt_long, size: 18),
                                label: const Text(
                                  'Create bill',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Tertiary action: Payment History
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const ValueKey('open-customer-payments'),
                          onPressed:
                              () => context.push<void>(
                                '/customers/${Uri.encodeComponent(customer.id)}/payments',
                              ),
                          icon: const Icon(Icons.history, size: 18),
                          label: const Text('View payment history'),
                        ),
                      ),
                      if (!canCollect &&
                          !canAdjustOutstanding &&
                          !customer.isArchived)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Collection requires this assignment, area access, and the record-payments permission.',
                            style: TextStyle(color: Color(0xFF486581), fontSize: 13),
                          ),
                        ),
                      if (canCollect &&
                          summary.collectiblePaise <= 0 &&
                          summary.amountDuePaise > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Outstanding: ${BillingMoney.formatPaise(summary.amountDuePaise)} • Collectible: ₹0.00\nOpening balance or unbilled amounts become collectible once a monthly bill is generated and finalized.',
                            style: const TextStyle(color: Color(0xFF486581), fontSize: 12),
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
