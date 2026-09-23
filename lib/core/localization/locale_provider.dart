import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocalePrefKey = 'user_preferred_locale';

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    _loadPersisted();
    return const Locale('en');
  }

  Future<void> _loadPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_kLocalePrefKey);
      if (savedCode == 'hi' || savedCode == 'en') {
        state = Locale(savedCode!);
      }
    } catch (_) {
      // Graceful fallback to default
    }
  }

  Future<void> setLocale(Locale newLocale) async {
    if (state == newLocale) return;
    state = newLocale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocalePrefKey, newLocale.languageCode);
    } catch (_) {}
  }

  Future<void> toggleLocale() async {
    final next = state.languageCode == 'en' ? const Locale('hi') : const Locale('en');
    await setLocale(next);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(() {
  return LocaleNotifier();
});

class LanguageToggleButton extends ConsumerWidget {
  const LanguageToggleButton({this.isDense = false, super.key});

  final bool isDense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final isHindi = currentLocale.languageCode == 'hi';

    if (isDense) {
      return TextButton.icon(
        onPressed: () => ref.read(localeProvider.notifier).toggleLocale(),
        icon: const Icon(Icons.translate, size: 18),
        label: Text(
          isHindi ? 'English' : 'हिन्दी',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }

    return ActionChip(
      avatar: const Icon(Icons.translate, size: 16),
      label: Text(
        isHindi ? 'हिन्दी (बदलें)' : 'English (Change)',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      onPressed: () => ref.read(localeProvider.notifier).toggleLocale(),
    );
  }
}
