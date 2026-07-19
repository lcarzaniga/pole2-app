import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/providers/database_provider.dart';
import 'package:project_kobe/features/backup/presentation/backup_screen.dart';
import 'package:project_kobe/l10n/app_localizations.dart';
import 'package:project_kobe/shared/layout/safe_insets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps [child] in a MaterialApp whose MediaQuery reports a bottom system inset
/// of [bottomPadding] (a nav bar) and a keyboard of [bottomInset], so the
/// safe-area logic can be exercised deterministically.
Widget _insetApp({
  required Widget child,
  double bottomPadding = 0,
  double bottomInset = 0,
}) {
  return MaterialApp(
    locale: const Locale('it'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, inner) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: EdgeInsets.only(bottom: bottomPadding),
        viewPadding: EdgeInsets.only(bottom: bottomPadding),
        viewInsets: EdgeInsets.only(bottom: bottomInset),
      ),
      child: inner!,
    ),
    home: child,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('safe-inset helper', () {
    testWidgets('reads the bottom system inset from MediaQuery.padding', (
      tester,
    ) async {
      late double read;
      await tester.pumpWidget(
        _insetApp(
          bottomPadding: 48,
          child: Builder(
            builder: (context) {
              read = safeBottomInset(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(read, 48);
    });

    testWidgets('zero inset (gesture nav) adds no extra gap', (tester) async {
      late EdgeInsets padded;
      await tester.pumpWidget(
        _insetApp(
          child: Builder(
            builder: (context) {
              padded = padWithSafeBottom(context, const EdgeInsets.all(16));
              return const SizedBox();
            },
          ),
        ),
      );
      // No system inset → base is preserved exactly (no double gap).
      expect(padded, const EdgeInsets.all(16));
    });

    testWidgets('adds the inset to the bottom only, preserving other edges', (
      tester,
    ) async {
      late EdgeInsets padded;
      await tester.pumpWidget(
        _insetApp(
          bottomPadding: 60,
          child: Builder(
            builder: (context) {
              padded = padWithSafeBottom(
                context,
                const EdgeInsets.fromLTRB(8, 12, 8, 16),
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(padded, const EdgeInsets.fromLTRB(8, 12, 8, 76)); // 16 + 60
    });
  });

  group('scrollable last action clears the navigation bar', () {
    const key = Key('last-action');

    Widget list(BuildContext context) => ListView(
      padding: padWithSafeBottom(context, EdgeInsets.zero),
      children: [
        const SizedBox(height: 2000), // forces a scroll
        FilledButton(key: key, onPressed: () {}, child: const Text('Azione')),
      ],
    );

    testWidgets('with a 100px nav inset the last action ends above it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _insetApp(
          bottomPadding: 100,
          child: Scaffold(body: Builder(builder: list)),
        ),
      );
      await tester.drag(find.byType(Scrollable), const Offset(0, -3000));
      await tester.pumpAndSettle();

      // Fully scrolled: the button's bottom sits at viewportBottom - inset.
      expect(
        tester.getBottomLeft(find.byKey(key)).dy,
        lessThanOrEqualTo(700.0),
      );
    });

    testWidgets('with a zero inset the last action reaches the very bottom', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _insetApp(
          child: Scaffold(body: Builder(builder: list)),
        ),
      );
      await tester.drag(find.byType(Scrollable), const Offset(0, -3000));
      await tester.pumpAndSettle();

      // No inset → the button reaches the bottom (no excessive reserved gap).
      expect(tester.getBottomLeft(find.byKey(key)).dy, greaterThan(790.0));
    });

    testWidgets(
      'an open keyboard does not hide the last action (no double pad)',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Keyboard covers the nav area: padding.bottom collapses to 0 (no double),
        // and the Scaffold lifts the body above the keyboard.
        await tester.pumpWidget(
          _insetApp(
            bottomInset: 300,
            child: Scaffold(body: Builder(builder: list)),
          ),
        );
        await tester.drag(find.byType(Scrollable), const Offset(0, -3000));
        await tester.pumpAndSettle();

        // The action is reachable above the keyboard region (top 500px).
        expect(
          tester.getBottomLeft(find.byKey(key)).dy,
          lessThanOrEqualTo(500.0),
        );
      },
    );
  });

  testWidgets(
    'Backup: the "Ripristina da backup" action sits above the nav bar',
    (tester) async {
      tester.view.physicalSize = const Size(400, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await tester.pumpWidget(
        _insetApp(
          bottomPadding: 100,
          child: ProviderScope(
            overrides: [
              databaseProvider.overrideWith((ref) {
                ref.onDispose(db.close);
                return db;
              }),
            ],
            child: const BackupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll the content to its end so the restore action is at rest position.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -4000));
      await tester.pumpAndSettle();

      final action = find.text('Ripristina da backup');
      expect(action, findsOneWidget);
      // Completely above the unsafe 100px region (screen 640 → 540).
      expect(tester.getBottomLeft(action).dy, lessThanOrEqualTo(540.0));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
