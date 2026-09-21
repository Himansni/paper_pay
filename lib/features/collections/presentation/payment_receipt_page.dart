import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';
import 'package:paper_route/features/collections/presentation/collect_payment_page.dart';
import 'package:paper_route/features/collections/presentation/collections_providers.dart';
import 'package:uuid/uuid.dart';

/// Displays an immutable confirmed payment together with its mutable reversal
/// projection and the customer's latest outstanding balance.
class PaymentReceiptPage extends ConsumerWidget {
  const PaymentReceiptPage({
    required this.user,
    required this.customerId,
    required this.paymentId,
    this.onReversed,
    super.key,
  });

  final AppUser user;
  final String customerId;
  final String paymentId;
  final ValueChanged<PaymentReversalResult>? onReversed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (actor: user, customerId: customerId, paymentId: paymentId);
    final payment = ref.watch(paymentProvider(key));
    return payment.when(
      loading:
          () => Scaffold(
            appBar: _appBar(context),
            body: const Center(child: CircularProgressIndicator()),
          ),
      error:
          (error, _) => Scaffold(
            appBar: _appBar(context),
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: AsyncErrorCard(
                message: 'Could not load payment receipt. $error',
                onRetry: () => ref.invalidate(paymentProvider(key)),
              ),
            ),
          ),
      data:
          (value) => _PaymentReceiptView(
            user: user,
            payment: value,
            paymentKey: key,
            onReversed: onReversed,
          ),
    );
  }

  AppBar _appBar(BuildContext context) => AppBar(
    leading: BackButton(onPressed: () => _back(context)),
    title: const Text('Payment receipt'),
  );

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/collections');
    }
  }
}

class _PaymentReceiptView extends ConsumerStatefulWidget {
  const _PaymentReceiptView({
    required this.user,
    required this.payment,
    required this.paymentKey,
    required this.onReversed,
  });

  final AppUser user;
  final ConfirmedPayment payment;
  final PaymentLookupKey paymentKey;
  final ValueChanged<PaymentReversalResult>? onReversed;

  @override
  ConsumerState<_PaymentReceiptView> createState() =>
      _PaymentReceiptViewState();
}

class _PaymentReceiptViewState extends ConsumerState<_PaymentReceiptView> {
  bool _reversing = false;

  @override
  Widget build(BuildContext context) {
    final payment = widget.payment;
    final summaryKey = (
      businessId: widget.user.businessId!,
      customerId: payment.customerId,
    );
    final outstanding = ref.watch(customerOutstandingProvider(summaryKey));
    final confirmedAt = payment.confirmedAt;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed:
              () =>
                  context.canPop() ? context.pop() : context.go('/collections'),
        ),
        title: const Text('Payment receipt'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                child: Icon(
                  payment.status == ConfirmedPaymentStatus.reversed
                      ? Icons.undo_outlined
                      : Icons.verified_outlined,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.serverConfirmed
                          ? 'Payment confirmed'
                          : 'Awaiting server confirmation',
                      key: const ValueKey('receipt-confirmation-state'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(payment.status.label),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!payment.serverConfirmed)
            Card(
              color: const Color(0xFFFFF0F0),
              child: const ListTile(
                leading: Icon(Icons.sync_problem_outlined),
                title: Text('Not yet a confirmed receipt'),
                subtitle: Text(
                  'Wait for a server-confirmed ledger record before treating this money as received.',
                ),
              ),
            )
          else
            Card(
              color: const Color(0xFFE5F5EE),
              child: const ListTile(
                leading: Icon(Icons.cloud_done_outlined),
                title: Text('Server-confirmed ledger entry'),
                subtitle: Text(
                  'The original payment and allocation history are immutable.',
                ),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    BillingMoney.formatPaise(payment.amountPaise),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ReceiptRow('Receipt / payment ID', payment.id),
                  _ReceiptRow(
                    'Customer',
                    '${payment.customerName} • ${payment.customerCode}',
                  ),
                  _ReceiptRow('Method', payment.method.label),
                  _ReceiptRow('Collector', payment.collectorUid),
                  _ReceiptRow(
                    'Confirmed at',
                    confirmedAt == null
                        ? 'Server timestamp pending'
                        : DateFormat(
                          'd MMM yyyy, h:mm a',
                        ).format(confirmedAt.toLocal()),
                  ),
                  if (payment.externalReference.isNotEmpty)
                    _ReceiptRow('Reference', payment.externalReference),
                  if (payment.notes.isNotEmpty)
                    _ReceiptRow('Notes', payment.notes),
                  if (payment.reversedPaise > 0)
                    _ReceiptRow(
                      'Reversed',
                      BillingMoney.formatPaise(payment.reversedPaise),
                    ),
                  _ReceiptRow(
                    'Net collected',
                    BillingMoney.formatPaise(payment.netAmountPaise),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Bill allocations',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (payment.allocations.isEmpty)
            const EmptyStateCard(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No allocation snapshots',
              message:
                  'This receipt does not contain a bill allocation snapshot.',
            )
          else
            for (final allocation in payment.allocations)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(allocation.billingMonth),
                  subtitle: Text('Bill ${allocation.billId}'),
                  trailing: Text(
                    BillingMoney.formatPaise(allocation.amountPaise),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          const SizedBox(height: 16),
          outstanding.when(
            loading: () => const LinearProgressIndicator(),
            error:
                (error, _) => Text(
                  'Current outstanding could not be loaded: $error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            data:
                (summary) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: const Text('Remaining outstanding'),
                    subtitle: const Text(
                      'Calculated from finalized bills, allocations, and reversals.',
                    ),
                    trailing: Text(
                      BillingMoney.formatPaise(summary.amountDuePaise),
                      key: const ValueKey('receipt-remaining-outstanding'),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
          ),
          if (widget.user.isHead &&
              payment.serverConfirmed &&
              payment.netAmountPaise > 0) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              key: const ValueKey('reverse-payment'),
              onPressed: _reversing ? null : _reverse,
              icon: const Icon(Icons.undo_outlined),
              label: Text(
                _reversing ? 'Recording reversal…' : 'Reverse payment',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _reverse() async {
    final input = await showDialog<_ReversalDraft>(
      context: context,
      builder:
          (context) =>
              _ReversalDialog(maximumPaise: widget.payment.netAmountPaise),
    );
    if (input == null || !mounted) return;
    // BEGINNER NOTE:
    // Reversal creates a separate compensating record. The original receipt
    // and allocations remain visible so the complete money trail is auditable.
    setState(() => _reversing = true);
    try {
      final result = await ref
          .read(collectionsRepositoryProvider)
          .reversePayment(
            actor: widget.user,
            customerId: widget.payment.customerId,
            input: PaymentReversalInput(
              paymentId: widget.payment.id,
              amountPaise: input.amountPaise,
              reason: input.reason,
              idempotencyKey: const Uuid().v4().replaceAll('-', ''),
            ),
          );
      if (!result.serverConfirmed || !result.reversal.serverConfirmed) {
        throw StateError(
          'The server has not confirmed this reversal. The receipt remains unchanged.',
        );
      }
      if (!mounted) return;
      widget.onReversed?.call(result);
      ref.invalidate(paymentProvider(widget.paymentKey));
      final summaryKey = (
        businessId: widget.user.businessId!,
        customerId: widget.payment.customerId,
      );
      ref.invalidate(customerOutstandingProvider(summaryKey));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${BillingMoney.formatPaise(result.reversal.amountPaise)} reversed without editing the original payment.',
          ),
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _reversing = false);
    }
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF486581),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _ReversalDraft {
  const _ReversalDraft({required this.amountPaise, required this.reason});

  final int amountPaise;
  final String reason;
}

class _ReversalDialog extends StatefulWidget {
  const _ReversalDialog({required this.maximumPaise});

  final int maximumPaise;

  @override
  State<_ReversalDialog> createState() => _ReversalDialogState();
}

class _ReversalDialogState extends State<_ReversalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final paise = widget.maximumPaise;
    _amountController = TextEditingController(
      text:
          paise % 100 == 0
              ? '${paise ~/ 100}'
              : '${paise ~/ 100}.${(paise % 100).toString().padLeft(2, '0')}',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record payment reversal'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'The original receipt remains immutable. A separate reversal entry restores the affected outstanding balance.',
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('reversal-amount'),
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Reversal amount (₹)',
                  prefixText: '₹ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  try {
                    final paise = parseRupeesToPaise(value ?? '');
                    if (paise <= 0) return 'Enter a positive amount.';
                    if (paise > widget.maximumPaise) {
                      return 'Cannot exceed the unreversed payment amount.';
                    }
                    return null;
                  } on FormatException {
                    return 'Enter a valid amount.';
                  }
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('reversal-reason'),
                controller: _reasonController,
                decoration: const InputDecoration(labelText: 'Reason'),
                minLines: 2,
                maxLines: 4,
                maxLength: 300,
                validator:
                    (value) =>
                        value == null || value.trim().length < 3
                            ? 'Enter a reason of at least 3 characters.'
                            : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('confirm-reversal'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _ReversalDraft(
                amountPaise: parseRupeesToPaise(_amountController.text),
                reason: _reasonController.text.trim(),
              ),
            );
          },
          child: const Text('Record reversal'),
        ),
      ],
    );
  }
}
