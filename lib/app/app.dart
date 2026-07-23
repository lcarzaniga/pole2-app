import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/application/language_preference.dart';
import '../l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Root widget: wires theme, routing and localization into a single
/// [MaterialApp.router].
///
/// Pole² ships two languages. The person's choice (Impostazioni → Lingua) is a
/// device preference read from [languagePreferenceProvider]:
///
///  * **Automatico** passes `locale: null`, so Flutter hands the device locale
///    to [resolveAppLocale], which applies the single rule — `it` (any region)
///    stays Italian, **everything else becomes English**.
///  * **Italiano / English** pass that locale explicitly, overriding the device.
///
/// Because the preference is watched, changing it rebuilds [MaterialApp] and the
/// whole interface switches language immediately — no restart.
///
/// English is the universal fallback. That is only honest while `app_en.arb` is
/// complete: any untranslated key would silently fall back to the Italian
/// template. Completeness is therefore asserted by a test, never assumed — and
/// no build is published until it passes (English content lands in a later
/// checkpoint of this milestone).
class KobeApp extends ConsumerWidget {
  const KobeApp({super.key});

  /// The locales Pole² ships: Italian (the semantic source) and English (the
  /// universal fallback).
  static const List<Locale> supportedLocales = kSupportedLocales;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final language = ref.watch(languagePreferenceProvider);

    return MaterialApp.router(
      // Use the callback's context (below MaterialApp's Localizations), not the
      // outer one — the outer context has no AppLocalizations and would throw.
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: supportedLocales,
      // null while "Automatico" → the device locale reaches the callback below.
      locale: language.locale,
      localeResolutionCallback: (deviceLocale, _) =>
          resolveAppLocale(deviceLocale),
      routerConfig: router,
    );
  }
}
