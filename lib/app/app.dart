import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Root widget: wires theme, routing and localization into a single
/// [MaterialApp.router].
///
/// Localization is Italian-only for now. English is not yet a complete
/// translation, so it is deliberately NOT exposed as a supported locale: the
/// app is pinned to Italian regardless of the device language. This guarantees
/// a fully Italian interface with no possibility of mixed Italian/English text.
/// (See [supportedLocale] and the note in `lib/l10n/app_en.arb`.)
class KobeApp extends ConsumerWidget {
  const KobeApp({super.key});

  /// The single locale the app currently supports and is pinned to.
  static const Locale supportedLocale = Locale('it');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      // Use the callback's context (below MaterialApp's Localizations), not the
      // outer one — the outer context has no AppLocalizations and would throw.
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // Italian only. Pinning both the supported list and the active locale
      // means any device language resolves entirely to Italian — never English.
      supportedLocales: const [supportedLocale],
      locale: supportedLocale,
      routerConfig: router,
    );
  }
}
