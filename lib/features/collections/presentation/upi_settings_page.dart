import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/presentation/async_state_cards.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/collections/domain/collection_models.dart';
import 'package:paper_route/features/collections/domain/upi_payment_uri.dart';
import 'package:paper_route/features/collections/presentation/collections_providers.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Head-only configuration for generating UPI payment requests. These values
/// identify the payee but never contain banking credentials or confirm receipt.
class UpiSettingsPage extends ConsumerWidget {
  const UpiSettingsPage({required this.user, this.onSaved, super.key});

  final AppUser user;
  final ValueChanged<UpiSettingsInput>? onSaved;

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
                'Employees may use enabled UPI details while collecting, but cannot manage business UPI settings.',
          ),
        ),
      );
    }
    final businessId = user.businessId!;
    final settings = ref.watch(upiSettingsProvider(businessId));
    return Scaffold(
      appBar: _appBar(context),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Text(
              'UPI collection settings',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'These details only construct standard UPI payment requests. PaperRoute never stores a bank PIN, password, or OTP.',
              style: TextStyle(color: Color(0xFF486581), height: 1.4),
            ),
            const SizedBox(height: 18),
            settings.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, _) => AsyncErrorCard(
                    message: 'Could not load UPI settings. $error',
                    onRetry:
                        () => ref.invalidate(upiSettingsProvider(businessId)),
                  ),
              data:
                  (value) => _UpiSettingsForm(
                    key: ValueKey(
                      '${value.upiId}:${value.payeeName}:${value.referencePrefix}:${value.enabled}:${value.updatedAt}',
                    ),
                    user: user,
                    settings: value,
                    onSaved: onSaved,
                  ),
            ),
          ],
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
    title: const Text('UPI settings'),
  );
}

class _UpiSettingsForm extends ConsumerStatefulWidget {
  const _UpiSettingsForm({
    required this.user,
    required this.settings,
    required this.onSaved,
    super.key,
  });

  final AppUser user;
  final UpiSettings settings;
  final ValueChanged<UpiSettingsInput>? onSaved;

  @override
  ConsumerState<_UpiSettingsForm> createState() => _UpiSettingsFormState();
}

class _UpiSettingsFormState extends ConsumerState<_UpiSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _upiIdController;
  late final TextEditingController _payeeNameController;
  late final TextEditingController _prefixController;
  late bool _enabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _upiIdController = TextEditingController(text: widget.settings.upiId);
    _payeeNameController = TextEditingController(
      text: widget.settings.payeeName,
    );
    _prefixController = TextEditingController(
      text: widget.settings.referencePrefix,
    );
    _enabled = widget.settings.enabled;
  }

  @override
  void dispose() {
    _upiIdController.dispose();
    _payeeNameController.dispose();
    _prefixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Uri? staticUri;
    if (widget.settings.enabled && widget.settings.isConfigured) {
      try {
        staticUri = UpiPaymentUriBuilder.buildStatic(settings: widget.settings);
      } on Object {
        staticUri = null;
      }
    }
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextFormField(
                    key: const ValueKey('upi-id'),
                    controller: _upiIdController,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Business UPI ID',
                      hintText: 'paperroute@bank',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const ValueKey('upi-payee-name'),
                    controller: _payeeNameController,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Payee / display name',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const ValueKey('upi-reference-prefix'),
                    controller: _prefixController,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Payment reference prefix',
                      helperText:
                          '2–20 letters, numbers, hyphens, or underscores.',
                    ),
                    maxLength: 20,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  SwitchListTile.adaptive(
                    key: const ValueKey('upi-enabled'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable UPI collection requests'),
                    subtitle: const Text(
                      'QR display still requires manual receipt confirmation.',
                    ),
                    value: _enabled,
                    onChanged:
                        _saving
                            ? null
                            : (value) => setState(() => _enabled = value),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const ValueKey('save-upi-settings'),
                    onPressed: _saving ? null : _save,
                    icon:
                        _saving
                            ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving…' : 'Save UPI settings'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (staticUri != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Text(
                      'Static business QR fallback',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    QrImageView(
                      key: const ValueKey('static-business-upi-qr'),
                      data: staticUri.toString(),
                      size: 220,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This QR contains no amount and does not confirm that a payment was received.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF486581), height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final input = UpiSettingsInput(
      upiId: _upiIdController.text,
      payeeName: _payeeNameController.text,
      referencePrefix: _prefixController.text,
      enabled: _enabled,
    );
    // Saving settings and its audit record is separate from every customer
    // payment; no outstanding balance changes here.
    try {
      input.validate();
    } on Object catch (error) {
      _showError(error.toString());
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(collectionsRepositoryProvider)
          .updateUpiSettings(actor: widget.user, input: input);
      if (!mounted) return;
      widget.onSaved?.call(input.normalized());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('UPI collection settings updated.')),
      );
    } on Object catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
