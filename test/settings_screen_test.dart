import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/platform/distribution.dart';
import 'package:project_kobe/core/providers/database_provider.dart';
import 'package:project_kobe/features/information/application/installed_build.dart';
import 'package:project_kobe/features/settings/application/language_preference.dart';
import 'package:project_kobe/features/settings/presentation/settings_screen.dart';
import 'package:project_kobe/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1.0.26 checkpoint A — the Settings screen: every row is real, the language
/// choice applies immediately, and the Play boundary hides the direct updater.
Widget _app(AppDatabase db, {Distribution? distribution}) {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/backup',
        name: 'backup',
        builder: (_, _) => const Scaffold(body: Text('BACKUP SCREEN')),
      ),
      GoRoute(
        path: '/information',
        name: 'information',
        builder: (_, _) => const Scaffold(body: Text('INFO SCREEN')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWith((ref) {
        ref.onDispose(db.close);
        return db;
      }),
      installedBuildProvider.overrideWith(
        (ref) async =>
            const InstalledBuild(version: '1.0.26', buildNumber: '2031'),
      ),
      if (distribution != null)
        distributionProvider.overrideWithValue(distribution),
    ],
    child: MaterialApp.router(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the four sections with functional rows', (tester) async {
    await tester.pumpWidget(
      _app(AppDatabase.forTesting(NativeDatabase.memory())),
    );
    await tester.pumpAndSettle();

    // Lingua
    expect(find.text('Lingua'), findsOneWidget);
    expect(find.text('Automatico'), findsOneWidget);
    expect(find.text('Italiano'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    // Dati e spazio
    expect(find.text('Dati e spazio'), findsOneWidget);
    expect(find.text('Backup, ripristino e spazio'), findsOneWidget);
    // Aggiornamenti — installed version is read at runtime
    expect(find.text('Aggiornamenti'), findsOneWidget);
    expect(find.text('Versione 1.0.26 · build 2031'), findsOneWidget);

    // Informazioni sits below the fold; scroll to prove it exists.
    await tester.scrollUntilVisible(
      find.text('Supporto, privacy, sito e licenze'),
      200,
    );
    expect(find.text('Supporto, privacy, sito e licenze'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('Dati e spazio navigates to the existing backup screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(AppDatabase.forTesting(NativeDatabase.memory())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backup, ripristino e spazio'));
    await tester.pumpAndSettle();
    expect(find.text('BACKUP SCREEN'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('Informazioni navigates to the existing information screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(AppDatabase.forTesting(NativeDatabase.memory())),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Supporto, privacy, sito e licenze'),
      200,
    );
    await tester.tap(find.text('Supporto, privacy, sito e licenze'));
    await tester.pumpAndSettle();
    expect(find.text('INFO SCREEN'), findsOneWidget);
    await _unmount(tester);
  });

  group('language selection', () {
    testWidgets('defaults to Automatico and records a choice immediately', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await tester.pumpWidget(_app(db));
      await tester.pumpAndSettle();

      RadioListTile<AppLanguage> tile(String label) =>
          tester.widget<RadioListTile<AppLanguage>>(
            find.widgetWithText(RadioListTile<AppLanguage>, label),
          );

      // Three options, Automatico selected by default.
      final group = tester.widget<RadioGroup<AppLanguage>>(
        find.byType(RadioGroup<AppLanguage>),
      );
      expect(group.groupValue, AppLanguage.auto);
      expect(tile('Automatico').value, AppLanguage.auto);
      expect(tile('Italiano').value, AppLanguage.it);
      expect(tile('English').value, AppLanguage.en);

      // Choosing English applies at once — no dialog, no confirmation.
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      final after = tester.widget<RadioGroup<AppLanguage>>(
        find.byType(RadioGroup<AppLanguage>),
      );
      expect(after.groupValue, AppLanguage.en);
      expect(find.byType(AlertDialog), findsNothing);

      // …and is persisted for the next start.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LanguagePreference.key), 'en');

      await _unmount(tester);
    });
  });

  group('distribution boundary', () {
    testWidgets('direct builds offer the manual update check', (tester) async {
      await tester.pumpWidget(
        _app(
          AppDatabase.forTesting(NativeDatabase.memory()),
          distribution: Distribution.direct,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Controlla aggiornamenti'), findsOneWidget);
      expect(
        find.text('Gli aggiornamenti arrivano dal Play Store.'),
        findsNothing,
      );
      await _unmount(tester);
    });

    testWidgets('Play builds hide it and explain where updates come from', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          AppDatabase.forTesting(NativeDatabase.memory()),
          distribution: Distribution.play,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Controlla aggiornamenti'), findsNothing);
      expect(
        find.text('Gli aggiornamenti arrivano dal Play Store.'),
        findsOneWidget,
      );
      // The installed version is still shown — it is not updater-specific.
      expect(find.text('Versione 1.0.26 · build 2031'), findsOneWidget);
      await _unmount(tester);
    });

    test('the define maps to the right distribution', () {
      expect(distributionFromDefine('direct'), Distribution.direct);
      expect(distributionFromDefine('play'), Distribution.play);
      expect(distributionFromDefine('PLAY'), Distribution.play);
      // Anything unexpected stays on today's behaviour.
      expect(distributionFromDefine(''), Distribution.direct);
      expect(distributionFromDefine('nonsense'), Distribution.direct);
      expect(Distribution.direct.allowsSelfUpdate, isTrue);
      expect(Distribution.play.allowsSelfUpdate, isFalse);
    });
  });
}
