import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/collections/presentation/collections_providers.dart';
import 'package:paper_route/features/customers/domain/customer.dart';

/// Customer-detail summary backed by the server-maintained collection
/// projection, not by locally subtracting receipt cards from bill totals.
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
    // The button mirrors access policy for usability; Firestore Rules remain
    // authoritative if an assignment or permission changes concurrently.
    final canCollect = policy.canRecordPayment(
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
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            key: const ValueKey('open-collect-payment'),
                            onPressed:
                                canCollect &&
                                        summary.amountDuePaise > 0 &&
                                        summary.serverConfirmed &&
                                        !summary.requiresProjectionSetup
                                    ? () => context.push<void>(
                                      '/customers/${Uri.encodeComponent(customer.id)}/collect',
                                    )
                                    : null,
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Collect payment'),
                          ),
                          OutlinedButton.icon(
                            key: const ValueKey('open-customer-payments'),
                            onPressed:
                                () => context.push<void>(
                                  '/customers/${Uri.encodeComponent(customer.id)}/payments',
                                ),
                            icon: const Icon(Icons.history),
                            label: const Text('Payment history'),
                          ),
                        ],
                      ),
                      if (!canCollect && !customer.isArchived)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Collection requires this assignment, area access, and the record-payments permission.',
                            style: TextStyle(color: Color(0xFF486581)),
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
