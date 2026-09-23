import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:paper_route/core/errors/app_exception.dart';
import 'package:paper_route/core/theme/app_theme.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/auth/presentation/auth_providers.dart';

class AccountSettingsPage extends ConsumerStatefulWidget {
  const AccountSettingsPage({required this.user, super.key});

  final AppUser user;

  @override
  ConsumerState<AccountSettingsPage> createState() =>
      _AccountSettingsPageState();
}

class _AccountSettingsPageState extends ConsumerState<AccountSettingsPage> {
  bool _isProcessing = false;

  Future<void> _startAccountDeletionFlow() async {
    final user = widget.user;
    final isHead = user.isHead;

    // Step 1: Explain Consequences
    final proceedToReauth = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete Account'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isHead
                        ? 'Closing your Agency Owner account will permanently deactivate your login credentials and close your agency.\n\n'
                            '• Active routes & employees: All active employees must be removed and active customer routes archived prior to deletion.\n'
                            '• Personal data: Your personal name, email, and phone will be permanently erased.\n'
                            '• Financial records: Past invoices, customer payment collections, and audit logs are legally required to be preserved for commercial accounting and tax compliance.'
                        : 'Deleting your Employee account will immediately revoke your access to the agency workspace.\n\n'
                            '• Personal data: Your name, email, and phone number will be permanently deleted from the agency roster.\n'
                            '• Financial records: Previous payments collected by you will remain recorded under an anonymized former employee record to preserve ledger accuracy.',
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This action is irreversible. Do you wish to proceed?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Continue'),
              ),
            ],
          ),
    );

    if (proceedToReauth != true || !mounted) return;

    // Step 2 & 3: Re-authentication and Explicit Confirmation
    final passwordController = TextEditingController();
    final confirmTextController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var isVerifying = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Confirm Identity & Deletion'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter your current account password to re-authenticate:',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter your password.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Type DELETE below to confirm permanent deletion:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: confirmTextController,
                        decoration: const InputDecoration(
                          hintText: 'DELETE',
                          prefixIcon: Icon(Icons.delete_forever_outlined),
                        ),
                        validator: (value) {
                          if (value?.trim() != 'DELETE') {
                            return 'Type DELETE to confirm.';
                          }
                          return null;
                        },
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isVerifying
                          ? null
                          : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const ValueKey('execute-account-deletion'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed:
                      isVerifying
                          ? null
                          : () async {
                            if (!formKey.currentState!.validate()) return;
                            setDialogState(() {
                              isVerifying = true;
                              errorMessage = null;
                            });

                            try {
                              // Verify password via re-authentication
                              await ref
                                  .read(authRepositoryProvider)
                                  .reauthenticate(
                                    password: passwordController.text,
                                  );
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext, true);
                              }
                            } on AppException catch (e) {
                              setDialogState(() {
                                isVerifying = false;
                                errorMessage = e.message;
                              });
                            } catch (e) {
                              setDialogState(() {
                                isVerifying = false;
                                errorMessage =
                                    'Re-authentication failed. Please check your password.';
                              });
                            }
                          },
                  child:
                      isVerifying
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text('Confirm Deletion'),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
    confirmTextController.dispose();

    if (confirmed != true || !mounted) return;

    // Step 4: Execute server-side account deletion
    setState(() => _isProcessing = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .requestAccountDeletion(confirmation: 'DELETE');
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Account Deleted'),
              content: const Text(
                'Your account has been deleted and your session has ended.',
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    context.go('/');
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    } on AppException catch (e) {
      if (mounted) {
        showDialog<void>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: const Text('Cannot Delete Account'),
                content: Text(e.message),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final roleLabel = user.isHead ? 'Agency Head' : 'Employee Collector';

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('Account settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppTheme.brand.withValues(
                            alpha: 0.15,
                          ),
                          child: Text(
                            user.displayName.isNotEmpty
                                ? user.displayName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.brand,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName.isEmpty
                                    ? 'PaperRoute User'
                                    : user.displayName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    user.email,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (user.isEmailVerified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.verified,
                                      size: 15,
                                      color: Colors.blue,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          size: 18,
                          color: AppTheme.mutedInk,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Role: $roleLabel',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Account Management',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: AppTheme.mutedInk),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.logout_rounded),
                    title: const Text('Sign out'),
                    subtitle: const Text('Log out of this device'),
                    onTap: () async {
                      await ref.read(authRepositoryProvider).signOut();
                      if (context.mounted) context.go('/');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Danger Zone',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: Colors.red.shade700),
            ),
            const SizedBox(height: 8),
            Card(
              color: Colors.red.shade50.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete Account',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Permanently delete your account and personal details',
                  style: TextStyle(fontSize: 12),
                ),
                trailing:
                    _isProcessing
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.chevron_right, color: Colors.red),
                onTap: _isProcessing ? null : _startAccountDeletionFlow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
