import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The language the person chose for Pole². `auto` follows the device.
///
/// Stored **by name** so adding a value later can never reinterpret an existing
/// stored choice.
enum AppLanguage {
  /// Follow the system language (the default).
  auto,

  /// Always Italian, whatever the device says.
  it,

  /// Always English, whatever the device says.
  en;

  static AppLanguage fromStored(String? raw) => switch (raw) {
    'it' => AppLanguage.it,
    'en' => AppLanguage.en,
    // Unknown / missing / corrupt → the calm default, never a crash.
    _ => AppLanguage.auto,
  };

  /// The locale to hand [MaterialApp]. `null` means "let Flutter resolve the
  /// system locale" — which [resolveAppLocale] then narrows to it/en.
  Locale? get locale => switch (this) {
    AppLanguage.auto => null,
    AppLanguage.it => const Locale('it'),
    AppLanguage.en => const Locale('en'),
  };
}

/// The two locales Pole² ships. English is the universal fallback: anything
/// that is not Italian resolves to English.
const Locale kItalian = Locale('it');
const Locale kEnglish = Locale('en');
const List<Locale> kSupportedLocales = [kItalian, kEnglish];

/// The single locale rule, kept pure so it is unit-testable without a widget:
/// a device language of `it` (in any region) gets Italian; **everything else**
/// — including an unknown, empty or unsupported language — gets English.
Locale resolveAppLocale(Locale? deviceLocale) {
  if (deviceLocale == null) return kEnglish;
  return deviceLocale.languageCode.toLowerCase() == 'it' ? kItalian : kEnglish;
}

/// The person's language choice, persisted on **this device only**.
///
/// Deliberately a device preference, not user data: it is not written to (or
/// read from) a backup, exactly like the last-backup date and the dismissed
/// update version. Restoring your things onto another phone must not reach in
/// and change that phone's language.
class LanguagePreference extends Notifier<AppLanguage> {
  static const String key = 'language_preference';

  @override
  AppLanguage build() {
    _load();
    return AppLanguage.auto;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = AppLanguage.fromStored(prefs.getString(key));
    } catch (_) {
      // Storage unavailable → stay on the default; never block startup.
    }
  }

  /// Applies [next] immediately (the UI rebuilds on this state change) and
  /// persists it. The write is best-effort: a failed write never undoes the
  /// change the person just saw take effect.
  Future<void> set(AppLanguage next) async {
    if (state == next) return;
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, next.name);
    } catch (_) {}
  }
}

final languagePreferenceProvider =
    NotifierProvider<LanguagePreference, AppLanguage>(LanguagePreference.new);
