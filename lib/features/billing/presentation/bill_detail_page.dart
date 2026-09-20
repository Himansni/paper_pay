import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/billing/presentation/billing_providers.dart';

class BillDetailPage extends ConsumerWidget {
  const BillDetailPage({
    required this.user,
    required this.customerId,
    required this.billingMonth,
    super.key,
  });

  final AppUser user;
  final String customerId;
  final String billingMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Riverpod watches the exact tenant/customer/month bill document so a newly
    // finalized record appears without mixing it with another account or month.
    final key = (
      businessId: user.businessId!,
      customerId: customerId,
      billingMonth: billingMonth,
    );
    final bill = ref.watch(monthlyBillProvider(key));
    return bill.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (error, _) => Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: () => context.pop()),
              title: const Text('Finalized bill'),
            ),
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: AsyncErrorCard(
                message: error.toString(),
                onRetry: () => ref.invalidate(monthlyBillProvider(key)),
              ),
            ),
          ),
      data:
          (value) =>
              value == null
                  ? Scaffold(
                    appBar: AppBar(
                      leading: BackButton(onPressed: () => context.pop()),
                      title: const Text('Finalized bill'),
                    ),
                    body: const Padding(
                      padding: EdgeInsets.all(20),
                      child: EmptyStateCard(
                        icon: Icons.receipt_long_outlined,
                        title: 'Bill not finalized',
                        message:
                            'The Head must review and finalize this month first.',
                      ),
                    ),
                  )
                  : _FinalizedBillView(user: user, bill: value, keyValue: key),
    );
  }
}

class _FinalizedBillView extends ConsumerStatefulWidget {
  const _FinalizedBillView({
    required this.user,
    required this.bill,
    required this.keyValue,
  });

  final AppUser user;
  final FinalizedMonthlyBill bill;
  final BillDocumentKey keyValue;

  @override
  ConsumerState<_FinalizedBillView> createState() => _FinalizedBillViewState();
}

class _FinalizedBillViewState extends ConsumerState<_FinalizedBillView> {
  final _lines = <MonthlyBillLineItem>[];
  BillLinePageCursor? _cursor;
  bool _hasMore = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  Future<void> _load({required bool reset}) async {
    if (_loading) return;
    if (reset) _cursor = null;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _lines.clear();
    });
    try {
      // Daily snapshots can be numerous, so the immutable line-item collection
      // is read in stable service-date/document-ID pages.
      final page = await ref
          .read(billingRepositoryProvider)
          .fetchBillLines(
            businessId: widget.keyValue.businessId,
            customerId: widget.keyValue.customerId,
            billingMonth: widget.keyValue.billingMonth,
            cursor: reset ? null : _cursor,
          );
      if (!mounted) return;
      setState(() {
        _lines.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final adjustments =
        widget.user.isHead
            ? ref.watch(billingAdjustmentsProvider(widget.keyValue))
            : const AsyncData<List<BillingAdjustment>>([]);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text('${bill.billingMonth} bill'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Text(
            'Finalized monthly bill',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${bill.customerName} • ${bill.customerCode}\n${bill.customerAddress}',
            style: const TextStyle(color: Color(0xFF486581), height: 1.4),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFFE5F5EE),
            child: const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Immutable financial snapshot'),
              subtitle: Text(
                'Prices, quantities, delivery dates, and totals are preserved exactly as finalized.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _amountRow(
                    'Opening balance snapshot',
                    bill.openingBalancePaise,
                  ),
                  _amountRow(
                    bill.previousBillId.isEmpty
                        ? 'Prior balance (opening source)'
                        : 'Previous outstanding (${bill.previousBillId})',
                    bill.priorBalancePaise,
                  ),
                  _amountRow('Current month charges', bill.currentChargesPaise),
                  _amountRow('Signed adjustments', bill.adjustmentsPaise),
                  const Divider(),
                  _amountRow('Total due', bill.totalDuePaise, strong: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Newspaper subtotals',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          for (final summary in bill.newspaperSummaries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(summary.newspaperName),
              subtitle: Text('${summary.deliveryCount} delivery lines'),
              trailing: Text(_money(summary.subtotalPaise)),
            ),
          if (widget.user.isHead) ...[
            const Divider(height: 28),
            Text(
              'Adjustment history',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            adjustments.when(
              loading:
                  () => const LinearProgressIndicator(
                    key: ValueKey('adjustments-loading'),
                  ),
              error: (error, _) => Text('Could not load adjustments: $error'),
              data:
                  (items) =>
                      items.isEmpty
                          ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('No adjustments were applied.'),
                          )
                          : Column(
                            children: [
                              for (final item in items)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(_money(item.amountPaise)),
                                  subtitle: Text(item.reason),
                                ),
                            ],
                          ),
            ),
          ],
          const Divider(height: 28),
          Text(
            'Daily snapshots (${bill.lineItemCount})',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (_error != null)
            AsyncErrorCard(
              message: _error!,
              onRetry: () => _load(reset: _lines.isEmpty),
            ),
          for (final item in _lines)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${item.serviceDate} • ${item.newspaperName}'),
              subtitle: Text(
                '${item.priceSource.label} • ${_money(item.unitPricePaise)} × ${item.quantity}',
              ),
              trailing: Text(_money(item.totalPaise)),
            ),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_hasMore)
            OutlinedButton(
              onPressed: () => _load(reset: false),
              child: const Text('Load more daily lines'),
            ),
        ],
      ),
    );
  }

  Widget _amountRow(String label, int value, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: strong ? const TextStyle(fontWeight: FontWeight.w800) : null,
          ),
        ),
        Text(
          _money(value),
          style: strong ? const TextStyle(fontWeight: FontWeight.w800) : null,
        ),
      ],
    ),
  );
}

String _money(int paise) => BillingMoney.formatPaise(paise);
