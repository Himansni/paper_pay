import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paper_route/features/agency_registration/domain/agency_registration.dart';
import 'package:paper_route/features/agency_registration/presentation/agency_registration_providers.dart';
import 'package:paper_route/features/agency_registration/presentation/agency_setup_page.dart';
import 'package:paper_route/features/auth/domain/app_user.dart';
import 'package:paper_route/features/auth/presentation/access_pending_page.dart';
import 'package:paper_route/features/auth/presentation/auth_providers.dart';
import 'package:paper_route/features/auth/presentation/widgets/auth_scaffold.dart';

class AgencyRegistrationGate extends ConsumerWidget {
  const AgencyRegistrationGate({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intent = ref.watch(agencyRegistrationIntentProvider);
    final options = ref.watch(agencyRegistrationOptionsProvider);
    return options.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (error, stackTrace) => AuthScaffold(
            title: 'Account setup unavailable',
            subtitle:
                'PaperRoute could not safely inspect this account. No agency data was changed.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('$error'),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed:
                      () => ref.invalidate(agencyRegistrationOptionsProvider),
                  child: const Text('Try again'),
                ),
                TextButton(
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  child: const Text('Use a different account'),
                ),
              ],
            ),
          ),
      data: (options) {
        if (options.eligibility ==
            AgencyRegistrationEligibility.alreadyProvisioned) {
          return AuthScaffold(
            title: 'Finishing agency setup',
            subtitle:
                'Your trusted agency records already exist. Waiting for the secure session to refresh.',
            child: FilledButton(
              onPressed:
                  () => ref.invalidate(agencyRegistrationOptionsProvider),
              child: const Text('Refresh'),
            ),
          );
        }
        if (options.eligibility == AgencyRegistrationEligibility.blocked) {
          return AuthScaffold(
            title: 'Account requires review',
            subtitle:
                'Trusted account state (${options.conflictReason ?? 'unknown'}) prevents owner provisioning. Existing access was not changed.',
            child: TextButton(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              child: const Text('Use a different account'),
            ),
          );
        }
        if (options.hasPendingEmployeeInvitation && intent == null) {
          return _RegistrationChoice(user: user);
        }
        if (intent == AgencyRegistrationIntent.acceptEmployeeInvitation) {
          return AccessPendingPage(user: user);
        }
        return AgencySetupPage(user: user);
      },
    );
  }
}

class _RegistrationChoice extends ConsumerWidget {
  const _RegistrationChoice({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuthScaffold(
      title: 'Choose how to continue',
      subtitle:
          'A pending employee invitation exists for ${user.email}. It does not give access until you accept it.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed:
                () => ref
                    .read(agencyRegistrationIntentProvider.notifier)
                    .choose(AgencyRegistrationIntent.acceptEmployeeInvitation),
            child: const Text('Accept employee invitation'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed:
                () => ref
                    .read(agencyRegistrationIntentProvider.notifier)
                    .choose(AgencyRegistrationIntent.createAgency),
            child: const Text('Create my own agency'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            child: const Text('Use a different account'),
          ),
        ],
      ),
    );
  }
}
