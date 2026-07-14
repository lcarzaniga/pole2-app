import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/app/app.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/providers/database_provider.dart';
import 'package:project_kobe/features/possessions/presentation/create_possession_screen.dart';
import 'package:project_kobe/l10n/app_localizations.dart';
import 'package:project_kobe/l10n/app_localizations_it.dart';
import 'package:project_kobe/shared/brand/launcher_familiarity.dart';
import 'package:project_kobe/shared/brand/turtle_shell_menu.dart';
import 'package:project_kobe/shared/photo_capture.dart';
import 'package:project_kobe/shared/platform/photo_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('shell action ordering', () {
    test('exactly six actions in the stable order, primary first', () {
      expect(quickActionOrder.length, 6);
      expect(quickActionOrder.toSet().length, 6); // no duplicates
      expect(quickActionOrder.first, QuickAction.object);
      expect(quickActionOrder, const [
        QuickAction.object,
        QuickAction.photo,
        QuickAction.document,
        QuickAction.reminder,
        QuickAction.note,
        QuickAction.detail,
      ]);
    });

    test('each action has a consistent "Un/Una …" label', () {
      final l10n = AppLocalizationsIt();
      for (final a in quickActionOrder) {
        expect(quickActionLabel(l10n, a), startsWith('Un'));
      }
    });
  });

  group('idle cue decision', () {
    test('runs only when at rest, active, unfamiliar, motion allowed', () {
      expect(
          shouldShowIdleCue(
              opens: 0, reduceMotion: false, appActive: true, shellOpen: false),
          isTrue);
    });

    test('never runs under Reduce Motion', () {
      expect(
          shouldShowIdleCue(
              opens: 0, reduceMotion: true, appActive: true, shellOpen: false),
          isFalse);
    });

    test('never runs while backgrounded or while the shell is open', () {
      expect(
          shouldShowIdleCue(
              opens: 0, reduceMotion: false, appActive: false, shellOpen: false),
          isFalse);
      expect(
          shouldShowIdleCue(
              opens: 0, reduceMotion: false, appActive: true, shellOpen: true),
          isFalse);
    });

    test('stops once the user is familiar', () {
      expect(
          shouldShowIdleCue(
              opens: kFamiliarThreshold,
              reduceMotion: false,
              appActive: true,
              shellOpen: false),
          isFalse);
    });

    test('delay stretches as the user learns, within calm bounds', () {
      final early = idleCueDelay(0, random: Random(1)).inSeconds;
      final later = idleCueDelay(3, random: Random(1)).inSeconds;
      expect(early, inInclusiveRange(25, 37));
      expect(later, inInclusiveRange(38, 52));
    });
  });

  group('photo capture outcomes', () {
    final l10n = AppLocalizationsIt();

    test('success and cancellation are silent (no message)', () {
      expect(photoOutcomeMessage(l10n, PhotoOutcome.success), isNull);
      expect(photoOutcomeMessage(l10n, PhotoOutcome.cancelled), isNull);
    });

    test('denied permission produces calm, localized recovery copy', () {
      expect(photoOutcomeMessage(l10n, PhotoOutcome.permissionDenied),
          l10n.cameraDeniedSnack);
      expect(photoOutcomeMessage(l10n, PhotoOutcome.permissionDenied),
          contains('fotocamera'));
    });

    test('failure reassures that nothing was lost', () {
      expect(photoOutcomeMessage(l10n, PhotoOutcome.failed),
          l10n.captureFailedSnack);
      expect(photoOutcomeMessage(l10n, PhotoOutcome.failed),
          contains('Nulla è andato perso'));
    });
  });

  testWidgets('the source chooser offers camera and gallery', (tester) async {
    PhotoSource? chosen;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('it')],
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async =>
                  chosen = await showPhotoSourceSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Scatta una foto'), findsOneWidget);
    expect(find.text('Scegli dalla galleria'), findsOneWidget);

    // Choosing gallery returns that source; dismissing would return null.
    await tester.tap(find.text('Scegli dalla galleria'));
    await tester.pumpAndSettle();
    expect(chosen, PhotoSource.gallery);
  });

  testWidgets('"Un oggetto" opens the existing creation flow', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWith((ref) {
          ref.onDispose(db.close);
          return db;
        }),
      ],
      child: const KobeApp(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.bySemanticsLabel('Conserva qualcosa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // shell opens

    await tester.tap(find.text('Un oggetto'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // navigation

    expect(find.byType(CreatePossessionScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
