import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/auth/presentation/auth_providers.dart';
import 'package:paper_route/features/auth/presentation/widgets/auth_scaffold.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  const EmailVerificationPage({required this.user, super.key});

  final AppUser user;

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage> {
  bool _isBusy = false;
  String? _message;

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() {
      _isBusy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted) setState(() => _message = success);
    } on AppException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.read(authRepositoryProvider);
    return AuthScaffold(
      title: 'Verify your email',
      subtitle:
          'We sent a verification link to ${widget.user.email}. Open it, then return here to continue.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.mark_email_unread_outlined, size: 52),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed:
                _isBusy
                    ? null
                    : () => _run(
                      repository.reloadCurrentUser,
                      'Account refreshed.',
                    ),
            child: const Text('I have verified my email'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed:
                _isBusy
                    ? null
                    : () => _run(
                      repository.resendEmailVerification,
                      'A new verification email was sent.',
                    ),
            child: const Text('Resend email'),
          ),
          TextButton(
            onPressed: _isBusy ? null : repository.signOut,
            child: const Text('Use a different account'),
          ),
        ],
      ),
    );
  }
}
