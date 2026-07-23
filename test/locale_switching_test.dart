import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/app/app.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/providers/database_provider.dart';
import 'package:project_kobe/features/settings/application/language_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1.0.26 checkpoint E — English is now a real, complete locale, so the whole
/// resolution matrix is exercised against the actual [KobeApp].
///
/// The Italian and English strings asserted here are the real shipped copy for
/// the Home empty state, so a regression in either ARB fails loudly.
const _itHome = 'Una casa serena per le tue cose';
const _enHome = 'A calm home for your things';

Future<void> _pump(
  WidgetTester tester,
  AppDatabase db, {
  required Locale device,
}) async {
  tester.platformDispatcher.localeTestValue = device;
  tester.platformDispatcher.localesTestValue = [device];
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
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Automatico on an Italian device shows Italian', (tester) async {
    await _pump(
      tester,
      AppDatabase.forTesting(NativeDatabase.memory()),
      device: const Locale('it'),
    );
    expect(find.text(_itHome), findsWidgets);
    expect(find.text(_enHome), findsNothing);
    await _unmount(tester);
  });

  testWidgets('Automatico on a non-Italian device shows English', (
    tester,
  ) async {
    // German device → English, the universal fallback (not Italian).
    await _pump(
      tester,
      AppDatabase.forTesting(NativeDatabase.memory()),
      device: const Locale('de', 'DE'),
    );
    expect(find.text(_enHome), findsWidgets);
    expect(find.text(_itHome), findsNothing);
    await _unmount(tester);
  });

  testWidgets('a stored manual Italiano overrides an English device', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({LanguagePreference.key: 'it'});
    await _pump(
      tester,
      AppDatabase.forTesting(NativeDatabase.memory()),
      device: const Locale('en', 'US'),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text(_itHome), findsWidgets);
    await _unmount(tester);
  });

  testWidgets('a stored manual English overrides an Italian device', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({LanguagePreference.key: 'en'});
    await _pump(
      tester,
      AppDatabase.forTesting(NativeDatabase.memory()),
      device: const Locale('it', 'IT'),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text(_enHome), findsWidgets);
    await _unmount(tester);
  });

  testWidgets('changing the preference switches language immediately', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) {
          ref.onDispose(db.close);
          return db;
        }),
      ],
    );
    addTearDown(container.dispose);

    tester.platformDispatcher.localeTestValue = const Locale('it');
    tester.platformDispatcher.localesTestValue = const [Locale('it')];
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const KobeApp()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(_itHome), findsWidgets);

    // Switch to English — no restart, no navigation, just a rebuild.
    await container
        .read(languagePreferenceProvider.notifier)
        .set(AppLanguage.en);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(_enHome), findsWidgets);
    expect(find.text(_itHome), findsNothing);

    // …and back to Automatico follows the (Italian) device again.
    await container
        .read(languagePreferenceProvider.notifier)
        .set(AppLanguage.auto);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(_itHome), findsWidgets);

    await _unmount(tester);
  });
}
