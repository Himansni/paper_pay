import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/auth/presentation/auth_providers.dart';
import 'package:paper_route/features/auth/presentation/widgets/auth_fields.dart';
import 'package:paper_route/features/auth/presentation/widgets/auth_scaffold.dart';

class AccessPendingPage extends ConsumerStatefulWidget {
  const AccessPendingPage({this.user, super.key});

  final AppUser? user;

  @override
  ConsumerState<AccessPendingPage> createState() => _AccessPendingPageState();
}

class _AccessPendingPageState extends ConsumerState<AccessPendingPage> {
  final _formKey = GlobalKey<FormState>();
  final _businessController = TextEditingController();
  final _invitationController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user?.displayName ?? '';
  }

  @override
  void dispose() {
    _businessController.dispose();
    _invitationController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .acceptEmployeeInvitation(
            businessId: _businessController.text.trim(),
            invitationId: _invitationController.text.trim(),
            displayName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
          );
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInactive = widget.user?.status == AccountStatus.inactive;
    if (isInactive) {
      return AuthScaffold(
        title: 'Account inactive',
        subtitle:
            'Your Head Distributor has disabled this account. Contact them to restore access.',
        child: FilledButton.tonal(
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
          child: const Text('Sign out'),
        ),
      );
    }

    final signedInEmail =
        widget.user?.email ??
        ref.watch(authSessionProvider).asData?.value?.email ??
        '';

    return AuthScaffold(
      title: 'Activate your access',
      subtitle:
          signedInEmail.isNotEmpty
              ? 'Signed in as $signedInEmail.\nEnter the business ID and one-time invitation code shared by your Head Distributor.'
              : 'Enter the business ID and one-time invitation code shared by your Head Distributor.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _businessController,
              validator: (value) => AuthFields.required(value, 'Business ID'),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Business ID'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _invitationController,
              validator:
                  (value) => AuthFields.required(value, 'Invitation code'),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Invitation code'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              validator: (value) => AuthFields.required(value, 'Full name'),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              validator: (value) => AuthFields.required(value, 'Phone number'),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number'),
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
              onPressed: _isBusy ? null : _activate,
              child: Text(_isBusy ? 'Checking invitation…' : 'Activate access'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed:
                  _isBusy
                      ? null
                      : () => ref.read(authRepositoryProvider).signOut(),
              child: const Text('Use a different account'),
            ),
          ],
        ),
      ),
    );
  }
}
