import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/auth/presentation/auth_providers.dart';
import 'package:paper_route/features/auth/presentation/widgets/auth_fields.dart';
import 'package:paper_route/features/auth/presentation/widgets/auth_scaffold.dart';

class InviteRegistrationPage extends ConsumerStatefulWidget {
  const InviteRegistrationPage({super.key});

  @override
  ConsumerState<InviteRegistrationPage> createState() =>
      _InviteRegistrationPageState();
}

class _InviteRegistrationPageState
    extends ConsumerState<InviteRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isBusy = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .registerInvitedEmployee(
            email: _emailController.text,
            password: _passwordController.text,
            displayName: _nameController.text,
          );
      if (mounted) context.go('/');
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create employee login',
      subtitle:
          'Use the exact email invited by your Head Distributor. Email verification is required before access is activated.',
      canPop: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              validator: (value) => AuthFields.required(value, 'Full name'),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailController,
              validator: AuthFields.email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Invited email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              validator: AuthFields.password,
              obscureText: _hidePassword,
              decoration: InputDecoration(
                labelText: 'Create password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                helperText: 'At least 8 characters',
                suffixIcon: IconButton(
                  onPressed:
                      () => setState(() => _hidePassword = !_hidePassword),
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isBusy ? null : _submit,
              child: Text(_isBusy ? 'Creating account…' : 'Create account'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isBusy ? null : () => context.go('/'),
              child: const Text('I already have an account'),
            ),
          ],
        ),
      ),
    );
  }
}
