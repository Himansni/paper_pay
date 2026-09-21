import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/agency_registration/domain/agency_registration.dart';
import 'package:paper_route/features/agency_registration/presentation/agency_registration_providers.dart';
import 'package:paper_route/features/agency_registration/presentation/create_agency_account_page.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/auth/presentation/auth_providers.dart';
import 'package:paper_route/features/auth/presentation/widgets/auth_fields.dart';
import 'package:paper_route/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:uuid/uuid.dart';

class AgencySetupPage extends ConsumerStatefulWidget {
  const AgencySetupPage({required this.user, super.key});

  final AppUser user;

  @override
  ConsumerState<AgencySetupPage> createState() => _AgencySetupPageState();
}

class _AgencySetupPageState extends ConsumerState<AgencySetupPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ownerName;
  late final TextEditingController _ownerPhone;
  late final TextEditingController _agencyName;
  late final TextEditingController _agencyPhone;
  late final TextEditingController _agencyAddress;
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _busy = false;
  String? _requestId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(agencyRegistrationDraftProvider);
    _ownerName = TextEditingController(
      text: draft?.ownerDisplayName ?? widget.user.displayName,
    );
    _ownerPhone = TextEditingController(text: draft?.ownerPhone ?? '');
    _agencyName = TextEditingController(text: draft?.agencyName ?? '');
    _agencyPhone = TextEditingController(text: draft?.agencyPhone ?? '');
    _agencyAddress = TextEditingController(text: draft?.agencyAddress ?? '');
    _termsAccepted = draft?.termsAccepted ?? false;
    _privacyAccepted = draft?.privacyAccepted ?? false;
    _requestId = draft?.requestId;
  }

  @override
  void dispose() {
    _ownerName.dispose();
    _ownerPhone.dispose();
    _agencyName.dispose();
    _agencyPhone.dispose();
    _agencyAddress.dispose();
    super.dispose();
  }

  Future<void> _provision() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted || !_privacyAccepted) {
      setState(() => _error = 'Accept the current Terms and Privacy Notice.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _requestId ??= const Uuid().v4();
    });
    final draft = AgencyRegistrationDraft(
      ownerDisplayName: _ownerName.text.trim(),
      ownerPhone: _ownerPhone.text.trim(),
      agencyName: _agencyName.text.trim(),
      agencyPhone: _agencyPhone.text.trim(),
      agencyAddress: _agencyAddress.text.trim(),
      termsAccepted: _termsAccepted,
      privacyAccepted: _privacyAccepted,
      requestId: _requestId,
    );
    ref.read(agencyRegistrationDraftProvider.notifier).save(draft);
    try {
      await ref
          .read(agencyRegistrationRepositoryProvider)
          .provisionAgencyOwner(draft: draft);
      ref.read(agencyRegistrationDraftProvider.notifier).clear();
      ref.read(agencyRegistrationIntentProvider.notifier).clear();
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Set up your agency',
      subtitle:
          'Signed in as ${widget.user.email}. PaperRoute will generate the business ID and trusted Head authority.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(_ownerName, 'Owner full name', 2),
            _gap,
            _field(_ownerPhone, 'Owner phone', 7, phone: true),
            _gap,
            _field(_agencyName, 'Agency name', 2),
            _gap,
            _field(_agencyPhone, 'Agency phone', 7, phone: true),
            _gap,
            _field(_agencyAddress, 'Agency address', 5, maxLines: 3),
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
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _provision,
              child: Text(_busy ? 'Creating agency…' : 'Create my agency'),
            ),
            TextButton(
              onPressed:
                  _busy
                      ? null
                      : () => ref.read(authRepositoryProvider).signOut(),
              child: const Text('Use a different account'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    int minimum, {
    bool phone = false,
    int maxLines = 1,
  }) => TextFormField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: phone ? TextInputType.phone : TextInputType.text,
    textCapitalization: TextCapitalization.words,
    validator: (value) {
      final required = AuthFields.required(value, label);
      if (required != null) return required;
      return value!.trim().length >= minimum
          ? null
          : '$label must contain at least $minimum characters';
    },
    decoration: InputDecoration(labelText: label),
  );

  static const _gap = SizedBox(height: 12);
}
