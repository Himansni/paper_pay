import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/agency_registration/presentation/agency_registration_providers.dart';
import 'package:paper_route/features/auth/presentation/auth_providers.dart';
import 'package:paper_route/features/auth/presentation/widgets/auth_fields.dart';
import 'package:paper_route/features/auth/presentation/widgets/auth_scaffold.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isBusy = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
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
          .signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agencyRegistrationEnabled = ref.watch(
      agencyRegistrationEnabledProvider,
    );
    return AuthScaffold(
      title: 'Welcome back',
      subtitle:
          'Sign in to manage newspaper delivery, billing, and collections.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              validator: AuthFields.email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              validator: (value) => AuthFields.required(value, 'Password'),
              obscureText: _hidePassword,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _isBusy ? null : _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed:
                    _isBusy ? null : () => context.go('/forgot-password'),
                child: const Text('Forgot password?'),
              ),
            ),
            if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: 14),
            ],
            FilledButton(
              onPressed: _isBusy ? null : _submit,
              child:
                  _isBusy
                      ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Sign in'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isBusy ? null : () => context.go('/join'),
              child: const Text('I have an employee invitation'),
            ),
            if (agencyRegistrationEnabled) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isBusy ? null : () => context.go('/create-agency'),
                child: const Text('Create agency account'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}
