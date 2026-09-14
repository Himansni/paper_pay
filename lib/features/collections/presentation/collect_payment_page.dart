import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/auth/domain/access_policy.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/billing/domain/monthly_bill.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';
import 'package:paper_route/features/collections/domain/upi_payment_uri.dart';
import 'package:paper_route/features/collections/presentation/collections_providers.dart';
import 'package:paper_route/features/customers/domain/customer.dart';
import 'package:paper_route/features/customers/presentation/customer_providers.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

class CollectPaymentPage extends ConsumerWidget {
  const CollectPaymentPage({
    required this.user,
    required this.customerId,
    this.onConfirmed,
    super.key,
  });

  final AppUser user;
  final String customerId;
  final ValueChanged<PaymentConfirmationResult>? onConfirmed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessId = user.businessId!;
    final customerKey = (businessId: businessId, customerId: customerId);
    final customer = ref.watch(customerProvider(customerKey));
    final outstanding = ref.watch(customerOutstandingProvider(customerKey));
    final upiSettings = ref.watch(upiSettingsProvider(businessId));

    return customer.when(
      loading: () => _loadingScaffold(context),
      error:
          (error, _) => _errorScaffold(
            context,
            message: 'Could not load customer. $error',
            onRetry: () => ref.invalidate(customerProvider(customerKey)),
          ),
      data: (value) {
        if (value == null) {
          return _missingScaffold(context, 'Customer not found');
        }
        const policy = AccessPolicy();
        final canCollect = policy.canRecordPayment(
          member: user,
          customerBusinessId: value.businessId,
          assignedEmployeeId: value.assignedEmployeeId,
          customerAreaId: value.areaId,
          isCustomerArchived: value.isArchived,
        );
        if (!canCollect) {
          return _missingScaffold(
            context,
            value.isArchived
                ? 'Collections are disabled for archived customers.'
                : 'You are not authorized to collect from this customer.',
          );
        }
        return outstanding.when(
          loading: () => _loadingScaffold(context),
          error:
              (error, _) => _errorScaffold(
                context,
                message: 'Could not load the current outstanding. $error',
                onRetry:
                    () => ref.invalidate(
                      customerOutstandingProvider(customerKey),
                    ),
              ),
          data:
              (summary) => _CollectPaymentForm(
                user: user,
                customer: value,
                summary: summary,
                upiSettings: upiSettings,
                onConfirmed: onConfirmed,
              ),
        );
      },
    );
  }

  Scaffold _loadingScaffold(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: () => _back(context)),
      title: const Text('Collect payment'),
    ),
    body: const Center(child: CircularProgressIndicator()),
  );

  Scaffold _errorScaffold(
    BuildContext context, {
    required String message,
    required VoidCallback onRetry,
  }) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: () => _back(context)),
      title: const Text('Collect payment'),
    ),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: AsyncErrorCard(message: message, onRetry: onRetry),
    ),
  );

  Scaffold _missingScaffold(BuildContext context, String message) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: () => _back(context)),
      title: const Text('Collect payment'),
    ),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: EmptyStateCard(
        icon: Icons.lock_outline,
        title: 'Collection unavailable',
        message: message,
      ),
    ),
  );

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/customers/$customerId');
    }
  }
}

class _CollectPaymentForm extends ConsumerStatefulWidget {
  const _CollectPaymentForm({
    required this.user,
    required this.customer,
    required this.summary,
    required this.upiSettings,
    required this.onConfirmed,
  });

  final AppUser user;
  final Customer customer;
  final CustomerOutstandingSummary summary;
  final AsyncValue<UpiSettings> upiSettings;
  final ValueChanged<PaymentConfirmationResult>? onConfirmed;

  @override
  ConsumerState<_CollectPaymentForm> createState() =>
      _CollectPaymentFormState();
}

class _CollectPaymentFormState extends ConsumerState<_CollectPaymentForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  var _method = PaymentMethod.cash;
  var _preferredBillId = '';
  late String _idempotencyKey;
  Uri? _upiUri;
  String _upiReference = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _newIdempotencyKey();
    _amountController.text = _formatInputAmount(widget.summary.amountDuePaise);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    final summary = widget.summary;
    final hasOutstanding = summary.amountDuePaise > 0;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed:
              () =>
                  context.canPop()
                      ? context.pop()
                      : context.go('/customers/${customer.id}'),
        ),
        title: const Text('Collect payment'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Text(
              customer.name,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${customer.customerCode}\n${customer.addressSummary}',
              style: const TextStyle(color: Color(0xFF486581), height: 1.4),
            ),
            const SizedBox(height: 14),
            Card(
              color: const Color(0xFFE5F5EE),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Server-confirmed outstanding',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      BillingMoney.formatPaise(summary.amountDuePaise),
                      key: const ValueKey('collection-outstanding'),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    if (summary.creditPaise > 0)
                      Text(
                        'Customer credit: ${BillingMoney.formatPaise(summary.creditPaise)}',
                      ),
                    if (!summary.serverConfirmed)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Waiting for the server. Collection is temporarily disabled.',
                        ),
                      ),
                    if (summary.requiresProjectionSetup)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'This legacy balance needs a reviewed collection-projection migration before a payment can be confirmed.',
                          key: ValueKey('collection-projection-required'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (!hasOutstanding)
              const EmptyStateCard(
                icon: Icons.check_circle_outline,
                title: 'Nothing to collect',
                message: 'This customer has no positive outstanding balance.',
              )
            else
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      key: const ValueKey('collection-amount'),
                      controller: _amountController,
                      enabled: !_submitting,
                      decoration: const InputDecoration(
                        labelText: 'Amount received (₹)',
                        prefixText: '₹ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => _clearUpiRequest(),
                      validator: _validateAmount,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<PaymentMethod>(
                      key: const ValueKey('collection-method'),
                      value: _method,
                      decoration: const InputDecoration(
                        labelText: 'Payment method',
                      ),
                      items: [
                        for (final method in PaymentMethod.values)
                          DropdownMenuItem(
                            value: method,
                            child: Text(method.label),
                          ),
                      ],
                      onChanged:
                          _submitting
                              ? null
                              : (method) {
                                if (method == null) return;
                                setState(() {
                                  _method = method;
                                  _upiUri = null;
                                  _upiReference = '';
                                  if (method != PaymentMethod.upi) {
                                    _referenceController.clear();
                                  }
                                });
                              },
                    ),
                    if (summary.bills.length > 1) ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        key: const ValueKey('preferred-bill'),
                        value: _preferredBillId,
                        decoration: const InputDecoration(
                          labelText: 'Allocation preference',
                          helperText:
                              'Oldest outstanding bill is used by default.',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Oldest outstanding first'),
                          ),
                          for (final bill in summary.bills)
                            if (bill.allocatablePaise > 0)
                              DropdownMenuItem(
                                value: bill.billId,
                                child: Text(
                                  '${bill.billingMonth} — ${BillingMoney.formatPaise(bill.allocatablePaise)}',
                                ),
                              ),
                        ],
                        onChanged:
                            _submitting
                                ? null
                                : (value) => setState(
                                  () => _preferredBillId = value ?? '',
                                ),
                      ),
                    ],
                    if (_method.requiresReference) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const ValueKey('collection-reference'),
                        controller: _referenceController,
                        enabled: !_submitting,
                        decoration: InputDecoration(
                          labelText:
                              _method == PaymentMethod.upi
                                  ? 'UPI transaction / receipt reference'
                                  : 'Bank transaction reference',
                        ),
                        maxLength: 120,
                        validator:
                            (value) =>
                                _method == PaymentMethod.upi && _upiUri == null
                                    ? null
                                    : value == null || value.trim().length < 3
                                    ? 'Enter a reference of at least 3 characters.'
                                    : null,
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const ValueKey('collection-notes'),
                      controller: _notesController,
                      enabled: !_submitting,
                      decoration: InputDecoration(
                        labelText:
                            _method.requiresNotes
                                ? 'Payment method description'
                                : 'Notes (optional)',
                      ),
                      maxLength: 300,
                      minLines: 2,
                      maxLines: 4,
                      validator:
                          (value) =>
                              _method.requiresNotes &&
                                      (value == null || value.trim().length < 3)
                                  ? 'Describe the payment method.'
                                  : null,
                    ),
                    if (_method == PaymentMethod.upi) ...[
                      _UpiRequestPanel(
                        settings: widget.upiSettings,
                        uri: _upiUri,
                        reference: _upiReference,
                        onGenerate:
                            _submitting ||
                                    !summary.serverConfirmed ||
                                    summary.requiresProjectionSetup
                                ? null
                                : _generateUpiRequest,
                      ),
                      const SizedBox(height: 14),
                    ],
                    Card(
                      color: const Color(0xFFFFF8E8),
                      child: const ListTile(
                        leading: Icon(Icons.verified_user_outlined),
                        title: Text('Receipt must be verified manually'),
                        subtitle: Text(
                          'Displaying or scanning a QR code never confirms payment. Confirm only after you have actually seen that funds or cash were received.',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      key: const ValueKey('confirm-payment'),
                      onPressed:
                          _submitting ||
                                  !summary.serverConfirmed ||
                                  summary.requiresProjectionSetup ||
                                  (_method == PaymentMethod.upi &&
                                      _upiUri == null)
                              ? null
                              : _confirm,
                      icon:
                          _submitting
                              ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _submitting
                            ? 'Confirming with server…'
                            : 'Confirm payment received',
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

  String? _validateAmount(String? raw) {
    try {
      final value = parseRupeesToPaise(raw ?? '');
      if (value <= 0) return 'Enter a positive amount.';
      if (value > widget.summary.amountDuePaise) {
        return 'Amount cannot exceed the current outstanding.';
      }
      return null;
    } on FormatException {
      return 'Enter rupees with no more than two decimal places.';
    }
  }

  void _clearUpiRequest() {
    if (_upiUri == null && _upiReference.isEmpty) return;
    setState(() {
      _upiUri = null;
      _upiReference = '';
    });
  }

  void _generateUpiRequest() {
    if (!_formKey.currentState!.validate()) return;
    final settings = widget.upiSettings.asData?.value;
    if (settings == null) {
      _showError('UPI settings are still loading.');
      return;
    }
    try {
      final reference = UpiPaymentUriBuilder.deterministicReference(
        settings: settings,
        customerId: widget.customer.id,
        idempotencyKey: _idempotencyKey,
      );
      final uri = UpiPaymentUriBuilder.build(
        settings: settings,
        amountPaise: parseRupeesToPaise(_amountController.text),
        paymentReference: reference,
        note: 'PaperRoute collection ${widget.customer.customerCode}',
      );
      setState(() {
        _upiReference = reference;
        _referenceController.text = reference;
        _upiUri = uri;
      });
    } on Object catch (error) {
      _showError(error.toString());
    }
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;
    final amountPaise = parseRupeesToPaise(_amountController.text);
    final accepted = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Confirm receipt of payment?'),
            content: Text(
              'Confirm that ${BillingMoney.formatPaise(amountPaise)} was actually received by ${_method.label.toLowerCase()}. This creates an immutable ledger entry.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Go back'),
              ),
              FilledButton(
                key: const ValueKey('manual-receipt-confirmation'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('I verified receipt'),
              ),
            ],
          ),
    );
    if (accepted != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(collectionsRepositoryProvider)
          .confirmPayment(
            actor: widget.user,
            customerId: widget.customer.id,
            input: PaymentConfirmationInput(
              amountPaise: amountPaise,
              method: _method,
              idempotencyKey: _idempotencyKey,
              externalReference: _referenceController.text,
              notes: _notesController.text,
              preferredBillId: _preferredBillId,
            ),
          );
      if (!result.serverConfirmed || !result.payment.serverConfirmed) {
        throw StateError(
          'The server has not confirmed this payment. It is not recorded as received.',
        );
      }
      if (!mounted) return;
      widget.onConfirmed?.call(result);
      if (widget.onConfirmed == null) {
        context.pushReplacement(
          '/collections/${Uri.encodeComponent(widget.customer.id)}/${Uri.encodeComponent(result.payment.id)}',
        );
      }
    } on Object catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _newIdempotencyKey() {
    _idempotencyKey = const Uuid().v4().replaceAll('-', '');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _UpiRequestPanel extends StatelessWidget {
  const _UpiRequestPanel({
    required this.settings,
    required this.uri,
    required this.reference,
    required this.onGenerate,
  });

  final AsyncValue<UpiSettings> settings;
  final Uri? uri;
  final String reference;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: settings.when(
        loading: () => const LinearProgressIndicator(),
        error:
            (error, _) => Text(
              'UPI settings could not be loaded: $error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        data: (value) {
          if (!value.enabled || !value.isConfigured) {
            return const EmptyStateCard(
              icon: Icons.qr_code_2_outlined,
              title: 'UPI collection is unavailable',
              message:
                  'The Head must configure and enable the business UPI details first.',
            );
          }
          if (uri == null) {
            return OutlinedButton.icon(
              key: const ValueKey('generate-upi-request'),
              onPressed: onGenerate,
              icon: const Icon(Icons.qr_code_2_outlined),
              label: const Text('Generate amount-specific UPI QR'),
            );
          }
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  const Text(
                    'Payment requested — not confirmed',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    label: 'Amount-specific UPI payment QR code',
                    child: QrImageView(
                      key: const ValueKey('upi-payment-qr'),
                      data: uri.toString(),
                      size: 220,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    reference,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ask the customer to pay, then verify receipt independently before confirming below.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF486581), height: 1.4),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

int parseRupeesToPaise(String raw) {
  final normalized = raw.trim().replaceAll(',', '').replaceAll('₹', '');
  if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(normalized)) {
    throw const FormatException('Invalid currency amount.');
  }
  final parts = normalized.split('.');
  final rupees = int.parse(parts[0]);
  final paise = parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'));
  return rupees * 100 + paise;
}

String _formatInputAmount(int paise) {
  if (paise <= 0) return '';
  final whole = paise ~/ 100;
  final fraction = paise % 100;
  return fraction == 0
      ? whole.toString()
      : '$whole.${fraction.toString().padLeft(2, '0')}';
}
