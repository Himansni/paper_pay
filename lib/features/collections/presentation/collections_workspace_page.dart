import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';
import 'package:paper_route/features/collections/presentation/collections_providers.dart';

class CollectionsWorkspacePage extends ConsumerStatefulWidget {
  const CollectionsWorkspacePage({
    required this.user,
    this.customerId,
    super.key,
  });

  final AppUser user;
  final String? customerId;

  @override
  ConsumerState<CollectionsWorkspacePage> createState() =>
      _CollectionsWorkspacePageState();
}

class _CollectionsWorkspacePageState
    extends ConsumerState<CollectionsWorkspacePage> {
  final _payments = <ConfirmedPayment>[];
  PaymentHistoryCursor? _cursor;
  bool _hasMore = false;
  bool _loading = false;
  String? _error;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  Future<void> _load({required bool reset}) async {
    if (_loading && !reset) return;
    final version = ++_requestVersion;
    if (reset) _cursor = null;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _payments.clear();
    });
    try {
      final page = await ref
          .read(collectionsRepositoryProvider)
          .fetchPaymentHistory(
            actor: widget.user,
            customerId: widget.customerId,
            cursor: reset ? null : _cursor,
          );
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _payments.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: const Text('Collections'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              widget.customerId != null
                  ? 'Customer payment history'
                  : widget.user.isHead
                  ? 'Payment history'
                  : 'My collections',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              widget.customerId != null
                  ? 'Confirmed payments for this customer, including reversal status and immutable allocations.'
                  : widget.user.isHead
                  ? 'Confirmed payments and reversals are retained as an immutable financial trail.'
                  : 'Your own immutable collection receipts remain available after a customer is reassigned.',
              style: const TextStyle(color: Color(0xFF486581), height: 1.4),
            ),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFFFFF8E8),
              child: const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Collect from a customer record'),
                subtitle: Text(
                  'Open an active customer to confirm cash, UPI, bank-transfer, or other manual collection.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_payments.isEmpty && _loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_payments.isEmpty && _error != null)
              AsyncErrorCard(
                message: _error!,
                onRetry: () => _load(reset: true),
              )
            else if (_payments.isEmpty)
              const EmptyStateCard(
                icon: Icons.payments_outlined,
                title: 'No confirmed payments',
                message:
                    'A payment appears here only after an authorized collector confirms receipt.',
              )
            else ...[
              for (final payment in _payments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PaymentHistoryCard(
                    payment: payment,
                    onTap:
                        () => context.push<void>(
                          '/collections/${Uri.encodeComponent(payment.customerId)}/${Uri.encodeComponent(payment.id)}',
                        ),
                  ),
                ),
              if (_error != null)
                AsyncErrorCard(
                  message: _error!,
                  onRetry: () => _load(reset: false),
                ),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_hasMore)
                OutlinedButton.icon(
                  key: const ValueKey('load-more-payments'),
                  onPressed: () => _load(reset: false),
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Load more payments'),
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'End of payment history',
                      style: TextStyle(color: Color(0xFF829AB1)),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  const _PaymentHistoryCard({required this.payment, required this.onTap});

  final ConfirmedPayment payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final confirmedAt = payment.confirmedAt;
    final subtitle = <String>[
      payment.customerCode,
      payment.method.label,
      if (confirmedAt != null)
        DateFormat('d MMM yyyy, h:mm a').format(confirmedAt.toLocal()),
    ].join(' • ');
    return Card(
      child: ListTile(
        key: ValueKey('payment-${payment.id}'),
        onTap: onTap,
        leading: Icon(
          payment.status == ConfirmedPaymentStatus.reversed
              ? Icons.undo_outlined
              : Icons.verified_outlined,
        ),
        title: Text(payment.customerName),
        subtitle: Text('$subtitle\n${payment.status.label}'),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              BillingMoney.formatPaise(payment.netAmountPaise),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
