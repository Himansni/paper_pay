import 'package:flutter/material.dart';
import 'package:paper_route/features/auth/presentation/widgets/auth_scaffold.dart';

class SetupRequiredPage extends StatelessWidget {
  const SetupRequiredPage({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Firebase setup required',
      subtitle:
          'The app shell is ready, but it has not been connected to your Firebase project yet.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SetupStep(number: '1', text: 'Create a Firebase project.'),
          const _SetupStep(
            number: '2',
            text: 'Enable Email/Password Authentication and Firestore.',
          ),
          const _SetupStep(
            number: '3',
            text: 'Run flutterfire configure from this project folder.',
          ),
          const SizedBox(height: 16),
          Text(
            'See docs/FIREBASE_SETUP.md for exact instructions.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Technical details'),
              children: [
                SelectableText(
                  message!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 14, child: Text(number)),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
