import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/app/app.dart';
import 'package:project_kobe/app/theme/app_theme.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/providers/database_provider.dart';
import 'package:project_kobe/features/home/presentation/home_screen.dart';
import 'package:project_kobe/l10n/app_localizations.dart';
import 'package:project_kobe/shared/brand/pole_wordmark.dart';
import 'package:project_kobe/shared/brand/turtle_mascot.dart';
import 'package:project_kobe/shared/brand/turtle_shell_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps Home with a real theme, an in-memory database, Italian localization,
/// and Reduce Motion on (so animations collapse to an instant).
Widget _framed(AppDatabase db) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWith((ref) {
        ref.onDispose(db.close);
        return db;
      }),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Reduce Motion on, but keep the real viewport size (copyWith, not a
      // zeroed MediaQueryData) — the shell geometry reads MediaQuery.size.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: const HomeScreen(),
    ),
  );
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

void main() {
  // The launcher persists a familiarity counter via shared_preferences; give
  // tests an in-memory mock so it never hits an unregistered plugin.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('The real app builds without error (router + onGenerateTitle)', (
    tester,
  ) async {
    // Pumps the actual KobeApp (not a stripped-down MaterialApp), so app-level
    // wiring like onGenerateTitle and the GoRouter is exercised. This catches
    // crashes that a bare MaterialApp harness would miss.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    // An Italian device, so the default "Automatico" preference resolves to
    // Italian (the rule lives in resolveAppLocale, covered in its own test).
    tester.platformDispatcher.localeTestValue = const Locale('it');
    tester.platformDispatcher.localesTestValue = const [Locale('it')];
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith((ref) {
            ref.onDispose(db.close);
            return db;
          }),
        ],
        child: const KobeApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    // The home app bar shows the Pole² brand wordmark (Work Sans, Text.rich).
    expect(find.byType(PoleWordmark), findsWidgets);

    // Two shipped locales; "Automatico" passes a null locale so the device
    // language reaches localeResolutionCallback.
    expect(KobeApp.supportedLocales, const [Locale('it'), Locale('en')]);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, isNull);
    expect(app.supportedLocales, const [Locale('it'), Locale('en')]);
    // On an Italian device the interface is Italian.
    expect(find.text('Una casa serena per le tue cose'), findsWidgets);
    expect(find.text('A calm home for your things'), findsNothing);

    await _teardown(tester);
  });

  testWidgets('With no possessions, Home shows the calm Italian empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _framed(AppDatabase.forTesting(NativeDatabase.memory())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PoleWordmark), findsOneWidget);
    expect(find.text('Una casa serena per le tue cose'), findsOneWidget);
    expect(find.text('Tutto resta su questo dispositivo'), findsOneWidget);
    expect(find.bySemanticsLabel('Conserva qualcosa'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('Tapping the turtle blooms exactly the two creation actions', (
    tester,
  ) async {
    // A real phone portrait (≈ Galaxy S23 logical size), so the centred bloom
    // and both labels sit inside safe bounds — the geometry we ship.
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _framed(AppDatabase.forTesting(NativeDatabase.memory())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Conserva qualcosa'));
    await tester.pumpAndSettle();

    // Exactly the two starting methods.
    expect(find.text('Dalla foto'), findsOneWidget);
    expect(find.text('Dal nome'), findsOneWidget);
    expect(find.byType(TurtleShellMenu), findsOneWidget);

    // None of the removed placeholder cells remain.
    for (final gone in const [
      'Un oggetto',
      'Una foto',
      'Un documento',
      'Un promemoria',
      'Una nota',
      'Un dettaglio',
    ]) {
      expect(find.text(gone), findsNothing);
    }

    // Complete spoken labels are present for assistive tech (not icon-only).
    expect(
      find.bySemanticsLabel('Crea un oggetto partendo da una foto'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Crea un oggetto partendo dal nome'),
      findsOneWidget,
    );

    // Tapping outside the bloom (the scrim) closes it.
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('Dalla foto'), findsNothing);
    expect(find.text('Dal nome'), findsNothing);

    await _teardown(tester);
  });

  testWidgets(
    'The two-cell bloom fits a narrow 320dp screen without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _framed(AppDatabase.forTesting(NativeDatabase.memory())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Conserva qualcosa'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Dalla foto'), findsOneWidget);
      expect(find.text('Dal nome'), findsOneWidget);

      await _teardown(tester);
    },
  );

  testWidgets(
    'Reduce Motion reveals the bloom instantly (no animation needed)',
    (tester) async {
      // _framed already sets disableAnimations: true.
      await tester.pumpWidget(
        _framed(AppDatabase.forTesting(NativeDatabase.memory())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Conserva qualcosa'));
      await tester
          .pump(); // a single frame — nothing to settle under Reduce Motion
      expect(find.text('Dalla foto'), findsOneWidget);
      expect(find.text('Dal nome'), findsOneWidget);

      await _teardown(tester);
    },
  );

  testWidgets('Populated Home uses the same two-action launcher', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.possessionsDao.createPossession(title: 'Trapano');

    await tester.pumpWidget(_framed(db));
    await tester.pumpAndSettle();
    // The list (not the empty state) is showing.
    expect(find.text('Trapano'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Conserva qualcosa'));
    await tester.pumpAndSettle();
    expect(find.text('Dalla foto'), findsOneWidget);
    expect(find.text('Dal nome'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('Home shows a calm deadline summary when a date is upcoming', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final p = await db.possessionsDao.createPossession(title: 'Frigorifero');
    await db.eventsDao.createReminder(
      possessionId: p.id,
      title: 'Scadenza garanzia',
      at: DateTime.now().add(const Duration(days: 12)),
    );

    await tester.pumpWidget(_framed(db));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The reminder's own title plus a localized "in 12 days".
    expect(find.textContaining('Scadenza garanzia'), findsWidgets);
    expect(find.textContaining('tra 12 giorni'), findsWidgets);

    await _teardown(tester);
  });

  testWidgets(
    'With a bottom nav inset, Kobe stays reachable and blooms two cells',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWith((ref) {
              ref.onDispose(db.close);
              return db;
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('it'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // A 56px three-button nav inset, Reduce Motion on for an instant bloom.
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                padding: const EdgeInsets.only(bottom: 56),
                viewPadding: const EdgeInsets.only(bottom: 56),
              ),
              child: child!,
            ),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The resting turtle sits above the 56px system-navigation region.
      final turtleBottom = tester.getRect(find.byType(TurtleMascot)).bottom;
      expect(turtleBottom, lessThanOrEqualTo(780.0 - 56.0));

      // And it still blooms exactly the two creation cells.
      await tester.tap(find.bySemanticsLabel('Conserva qualcosa'));
      await tester.pumpAndSettle();
      expect(find.text('Dalla foto'), findsOneWidget);
      expect(find.text('Dal nome'), findsOneWidget);

      await _teardown(tester);
    },
  );
}
