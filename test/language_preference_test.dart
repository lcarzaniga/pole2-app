import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/features/settings/application/language_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1.0.26 — the language preference and the single locale rule.
///
/// The rule is pure, so it is tested without a widget: `it` (any region) stays
/// Italian; **everything else**, including unknown/empty/null, becomes English.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('resolveAppLocale', () {
    test('Italian in any region resolves to Italian', () {
      expect(resolveAppLocale(const Locale('it')), kItalian);
      expect(resolveAppLocale(const Locale('it', 'IT')), kItalian);
      expect(resolveAppLocale(const Locale('it', 'CH')), kItalian);
      expect(
        resolveAppLocale(const Locale('IT')),
        kItalian,
      ); // case-insensitive
    });

    test('every other language resolves to English', () {
      for (final code in ['en', 'de', 'fr', 'es', 'pt', 'ja', 'ar', 'zh']) {
        expect(
          resolveAppLocale(Locale(code)),
          kEnglish,
          reason: '$code must fall back to English',
        );
      }
      expect(resolveAppLocale(const Locale('en', 'US')), kEnglish);
    });

    test('unknown, undetermined or null locales resolve to English', () {
      expect(resolveAppLocale(null), kEnglish); // no device locale at all
      expect(resolveAppLocale(const Locale('und')), kEnglish); // undetermined
      expect(resolveAppLocale(const Locale('zz')), kEnglish); // not a language
    });

    test('exactly two supported locales, Italian first', () {
      expect(kSupportedLocales, const [Locale('it'), Locale('en')]);
    });
  });

  group('AppLanguage', () {
    test('maps to the locale MaterialApp receives', () {
      expect(AppLanguage.auto.locale, isNull); // system-driven
      expect(AppLanguage.it.locale, kItalian);
      expect(AppLanguage.en.locale, kEnglish);
    });

    test('an unknown or missing stored value falls back to auto', () {
      expect(AppLanguage.fromStored(null), AppLanguage.auto);
      expect(AppLanguage.fromStored(''), AppLanguage.auto);
      expect(AppLanguage.fromStored('klingon'), AppLanguage.auto);
      expect(AppLanguage.fromStored('auto'), AppLanguage.auto);
      expect(AppLanguage.fromStored('it'), AppLanguage.it);
      expect(AppLanguage.fromStored('en'), AppLanguage.en);
    });
  });

  group('LanguagePreference persistence', () {
    ProviderContainer container() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    /// Riverpod builds lazily, so the FIRST read is what starts the async load
    /// from SharedPreferences. Read once to trigger it, then let the event loop
    /// settle, then return the loaded value.
    Future<AppLanguage> loaded(ProviderContainer c) async {
      c.read(languagePreferenceProvider); // trigger build() → _load()
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return c.read(languagePreferenceProvider);
    }

    test('defaults to auto when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final c = container();
      expect(c.read(languagePreferenceProvider), AppLanguage.auto);
      expect(await loaded(c), AppLanguage.auto);
    });

    test('reads a previously stored choice', () async {
      SharedPreferences.setMockInitialValues({LanguagePreference.key: 'en'});
      final c = container();
      expect(await loaded(c), AppLanguage.en);
    });

    test('a corrupt stored value degrades to auto, never throws', () async {
      SharedPreferences.setMockInitialValues({
        LanguagePreference.key: 'not-a-language',
      });
      final c = container();
      expect(await loaded(c), AppLanguage.auto);
    });

    test('set() applies immediately and persists across a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final c = container();
      await c.read(languagePreferenceProvider.notifier).set(AppLanguage.it);
      // Immediately visible to watchers (this is what repaints the UI).
      expect(c.read(languagePreferenceProvider), AppLanguage.it);
      // …and written through.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LanguagePreference.key), 'it');

      // A fresh container = a fresh app start.
      final restarted = ProviderContainer();
      addTearDown(restarted.dispose);
      expect(await loaded(restarted), AppLanguage.it);
    });

    test(
      'returning to Automatico is stored and follows the system again',
      () async {
        SharedPreferences.setMockInitialValues({LanguagePreference.key: 'en'});
        final c = container();
        expect(await loaded(c), AppLanguage.en);

        await c.read(languagePreferenceProvider.notifier).set(AppLanguage.auto);
        expect(c.read(languagePreferenceProvider), AppLanguage.auto);
        expect(c.read(languagePreferenceProvider).locale, isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(LanguagePreference.key), 'auto');
      },
    );
  });
}
