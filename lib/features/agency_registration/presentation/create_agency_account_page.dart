import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/agency_registration/domain/agency_registration.dart';
import 'package:paper_route/features/agency_registration/presentation/agency_registration_providers.dart';
import 'package:paper_route/features/auth/presentation/widgets/auth_fields.dart';
import 'package:paper_route/features/auth/presentation/widgets/auth_scaffold.dart';

class CreateAgencyAccountPage extends ConsumerStatefulWidget {
  const CreateAgencyAccountPage({super.key});

  @override
  ConsumerState<CreateAgencyAccountPage> createState() =>
      _CreateAgencyAccountPageState();
}

class _CreateAgencyAccountPageState
    extends ConsumerState<CreateAgencyAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _ownerName = TextEditingController();
  final _ownerPhone = TextEditingController();
  final _agencyName = TextEditingController();
  final _agencyPhone = TextEditingController();
  final _agencyAddress = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _hidePassword = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ownerName.dispose();
    _ownerPhone.dispose();
    _agencyName.dispose();
    _agencyPhone.dispose();
    _agencyAddress.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  AgencyRegistrationDraft get _draft => AgencyRegistrationDraft(
    ownerDisplayName: _ownerName.text.trim(),
    ownerPhone: _ownerPhone.text.trim(),
    agencyName: _agencyName.text.trim(),
    agencyPhone: _agencyPhone.text.trim(),
    agencyAddress: _agencyAddress.text.trim(),
    termsAccepted: _termsAccepted,
    privacyAccepted: _privacyAccepted,
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted || !_privacyAccepted) {
      setState(() => _error = 'Accept the current Terms and Privacy Notice.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = _draft;
      await ref
          .read(agencyRegistrationRepositoryProvider)
          .createOwnerIdentity(
            email: _email.text,
            password: _password.text,
            displayName: draft.ownerDisplayName,
          );
      ref.read(agencyRegistrationDraftProvider.notifier).save(draft);
      ref
          .read(agencyRegistrationIntentProvider.notifier)
          .choose(AgencyRegistrationIntent.createAgency);
      if (mounted) context.go('/');
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create agency account',
      subtitle:
          'Create a verified owner identity first. Agency authority is granted only after secure provisioning.',
      canPop: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _text(_ownerName, 'Owner full name', Icons.person_outline_rounded),
            _gap,
            _text(
              _ownerPhone,
              'Owner phone',
              Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              minimum: 7,
            ),
            _gap,
            _text(_agencyName, 'Agency name', Icons.store_outlined),
            _gap,
            _text(
              _agencyPhone,
              'Agency phone',
              Icons.phone_in_talk_outlined,
              keyboardType: TextInputType.phone,
              minimum: 7,
            ),
            _gap,
            _text(
              _agencyAddress,
              'Agency address',
              Icons.location_on_outlined,
              minimum: 5,
              maxLines: 3,
            ),
            _gap,
            TextFormField(
              controller: _email,
              validator: AuthFields.email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Owner email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            _gap,
            TextFormField(
              controller: _password,
              validator: AuthFields.password,
              obscureText: _hidePassword,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Create password',
                helperText: 'At least 8 characters',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed:
                      () => setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            LegalAcceptanceFields(
              termsAccepted: _termsAccepted,
              privacyAccepted: _privacyAccepted,
              onTermsChanged: (value) => setState(() => _termsAccepted = value),
              onPrivacyChanged:
                  (value) => setState(() => _privacyAccepted = value),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Creating identity…' : 'Create account'),
            ),
            TextButton(
              onPressed: _busy ? null : () => context.go('/'),
              child: const Text('I already have an account'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _text(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int minimum = 2,
    int maxLines = 1,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,
    textCapitalization: TextCapitalization.words,
    validator: (value) {
      final required = AuthFields.required(value, label);
      if (required != null) return required;
      return value!.trim().length >= minimum
          ? null
          : '$label must contain at least $minimum characters';
    },
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
  );

  static const _gap = SizedBox(height: 14);
}

class LegalAcceptanceFields extends StatelessWidget {
  const LegalAcceptanceFields({
    required this.termsAccepted,
    required this.privacyAccepted,
    required this.onTermsChanged,
    required this.onPrivacyChanged,
    super.key,
  });

  final bool termsAccepted;
  final bool privacyAccepted;
  final ValueChanged<bool> onTermsChanged;
  final ValueChanged<bool> onPrivacyChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: termsAccepted,
          onChanged: (value) => onTermsChanged(value ?? false),
          title: const Text('I accept the Terms of Service'),
          subtitle: TextButton(
            onPressed:
                () => _showLegal(
                  context,
                  'Terms of Service',
                  AgencyLegalDocuments.termsAsset,
                ),
            child: const Text('Read terms-v1'),
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: privacyAccepted,
          onChanged: (value) => onPrivacyChanged(value ?? false),
          title: const Text('I accept the Privacy Notice'),
          subtitle: TextButton(
            onPressed:
                () => _showLegal(
                  context,
                  'Privacy Notice',
                  AgencyLegalDocuments.privacyAsset,
                ),
            child: const Text('Read privacy-v1'),
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  Future<void> _showLegal(
    BuildContext context,
    String title,
    String asset,
  ) async {
    final content = await DefaultAssetBundle.of(context).loadString(asset);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(child: Text(content)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}
