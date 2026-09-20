import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/billing/presentation/billing_providers.dart';

class BillPreviewPage extends ConsumerStatefulWidget {
  const BillPreviewPage({
    required this.user,
    required this.customerId,
    required this.billingMonth,
    super.key,
  });

  final AppUser user;
  final String customerId;
  final String billingMonth;

  @override
  ConsumerState<BillPreviewPage> createState() => _BillPreviewPageState();
}

class _BillPreviewPageState extends ConsumerState<BillPreviewPage> {
  MonthlyBillPreview? _preview;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // The repository assembles current source data and calculates daily lines
      // without writing. A finalized month redirects to its immutable detail.
      final value = await ref
          .read(billingRepositoryProvider)
          .previewBill(
            actor: widget.user,
            customerId: widget.customerId,
            month: billingMonthFromKey(widget.billingMonth),
          );
      if (!mounted) return;
      if (value.alreadyFinalizedBill != null) {
        context.go('/billing/${widget.customerId}/${widget.billingMonth}');
        return;
      }
      setState(() {
        _preview = value;
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

  Future<void> _addAdjustment() async {
    final input = await showDialog<BillingAdjustmentInput>(
      context: context,
      builder:
          (context) => _AdjustmentDialog(billingMonth: widget.billingMonth),
    );
    if (input == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(billingRepositoryProvider)
          .createAdjustment(
            actor: widget.user,
            customerId: widget.customerId,
            input: input,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adjustment recorded with audit history.'),
        ),
      );
      await _load();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finalize() async {
    // Finalization is deliberately explicit because it freezes the financial
    // snapshot; later corrections are separate audited adjustments.
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Finalize immutable bill?'),
            content: const Text(
              'The bill and daily snapshots cannot be edited or deleted. '
              'Later corrections must be new audited adjustments.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Finalize bill'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(billingRepositoryProvider)
          .finalizeBill(
            actor: widget.user,
            customerId: widget.customerId,
            month: billingMonthFromKey(widget.billingMonth),
          );
      if (!mounted) return;
      context.go('/billing/${widget.customerId}/${widget.billingMonth}');
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
        await _load();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text('${widget.billingMonth} preview'),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Padding(
                padding: const EdgeInsets.all(20),
                child: AsyncErrorCard(message: _error!, onRetry: _load),
              )
              : preview == null
              ? const SizedBox.shrink()
              : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  Text(
                    'Review before finalization',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${preview.customerName} • ${preview.customerCode}\n'
                    '${preview.customerAddress}',
                    style: const TextStyle(
                      color: Color(0xFF486581),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.visibility_outlined),
                      title: Text('Read-only calculation'),
                      subtitle: Text(
                        'Opening this preview does not create or change Firestore records.',
                      ),
                    ),
                  ),
                  if (preview.issues.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: const Color(0xFFFFF4E5),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Finalization blocked',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            for (final issue in preview.issues)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('• ${issue.message}'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _TotalsCard(
                    openingBalancePaise: preview.openingBalancePaise,
                    previousBillId: preview.previousBillId,
                    previousOutstandingPaise: preview.previousOutstandingPaise,
                    priorBalancePaise: preview.priorBalancePaise,
                    currentChargesPaise: preview.currentChargesPaise,
                    adjustmentsPaise: preview.adjustmentsPaise,
                    totalDuePaise: preview.totalDuePaise,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Adjustments (${preview.adjustments.length})',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _addAdjustment,
                        icon: const Icon(Icons.exposure_outlined),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  if (preview.adjustments.isEmpty)
                    const Text(
                      'No signed adjustments for this month.',
                      style: TextStyle(color: Color(0xFF486581)),
                    )
                  else
                    for (final adjustment in preview.adjustments)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_money(adjustment.amountPaise)),
                        subtitle: Text(adjustment.reason),
                      ),
                  const Divider(height: 32),
                  Text(
                    'Newspaper subtotals',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (preview.newspaperSubtotalsPaise.isEmpty)
                    const Text(
                      'No chargeable delivery dates in this month.',
                      style: TextStyle(color: Color(0xFF486581)),
                    )
                  else
                    for (final entry in preview.newspaperSubtotalsPaise.entries)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.key),
                        trailing: Text(_money(entry.value)),
                      ),
                  const Divider(height: 32),
                  Text(
                    'Daily lines (${preview.lineItems.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final item in preview.lineItems)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${item.serviceDate} • ${item.newspaperName}',
                      ),
                      subtitle: Text(
                        '${item.priceSource.label} • ${_money(item.unitPricePaise)} × ${item.quantity}',
                      ),
                      trailing: Text(_money(item.totalPaise)),
                    ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    key: const ValueKey('finalize-monthly-bill'),
                    onPressed: _busy || !preview.canFinalize ? null : _finalize,
                    icon:
                        _busy
                            ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.lock_outline),
                    label: const Text('Finalize immutable bill'),
                  ),
                ],
              ),
    );
  }
}

class _AdjustmentDialog extends StatefulWidget {
  const _AdjustmentDialog({required this.billingMonth});

  final String billingMonth;

  @override
  State<_AdjustmentDialog> createState() => _AdjustmentDialogState();
}

class _AdjustmentDialogState extends State<_AdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final _reference = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    _reference.dispose();
    super.dispose();
  }

  int _parseAmount(String value) {
    final normalized = value.trim().replaceAll(',', '');
    if (!RegExp(r'^-?\d{1,7}(\.\d{1,2})?$').hasMatch(normalized)) {
      throw const FormatException();
    }
    final negative = normalized.startsWith('-');
    final unsigned = negative ? normalized.substring(1) : normalized;
    final parts = unsigned.split('.');
    final paise =
        int.parse(parts.first) * 100 +
        (parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0')));
    return negative ? -paise : paise;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    try {
      final input = BillingAdjustmentInput(
        billingMonth: widget.billingMonth,
        amountPaise: _parseAmount(_amount.text),
        reason: _reason.text,
        referenceBillMonth: _reference.text,
      );
      input.validate();
      Navigator.pop(context, input.normalized());
    } on Object catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Signed billing adjustment'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amount,
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                helperText: 'Use a minus sign for a credit.',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              validator: (value) {
                try {
                  return _parseAmount(value ?? '') == 0
                      ? 'Enter a non-zero amount.'
                      : null;
                } on Object {
                  return 'Enter rupees with at most two decimals.';
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reason,
              decoration: const InputDecoration(labelText: 'Reason'),
              maxLength: 300,
              validator:
                  (value) =>
                      (value ?? '').trim().length < 3
                          ? 'Explain this financial adjustment.'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reference,
              decoration: const InputDecoration(
                labelText: 'Earlier bill month (optional)',
                hintText: 'YYYY-MM',
              ),
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
      FilledButton(onPressed: _submit, child: const Text('Record adjustment')),
    ],
  );
}

class _TotalsCard extends StatelessWidget {
  // This separates the balance brought into the month from delivery-derived
  // current charges and signed adjustments before showing their total.
  const _TotalsCard({
    required this.openingBalancePaise,
    required this.previousBillId,
    required this.previousOutstandingPaise,
    required this.priorBalancePaise,
    required this.currentChargesPaise,
    required this.adjustmentsPaise,
    required this.totalDuePaise,
  });

  final int openingBalancePaise;
  final String previousBillId;
  final int previousOutstandingPaise;
  final int priorBalancePaise;
  final int currentChargesPaise;
  final int adjustmentsPaise;
  final int totalDuePaise;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _row('Opening balance snapshot', openingBalancePaise),
          _row(
            previousBillId.isEmpty
                ? 'Prior balance (opening source)'
                : 'Previous outstanding ($previousBillId)',
            previousBillId.isEmpty
                ? priorBalancePaise
                : previousOutstandingPaise,
          ),
          _row('Current month charges', currentChargesPaise),
          _row('Signed adjustments', adjustmentsPaise),
          const Divider(),
          _row('Total due', totalDuePaise, strong: true),
        ],
      ),
    ),
  );

  Widget _row(String label, int value, {bool strong = false}) => Padding(
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
