import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/app/app.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/providers/database_provider.dart';
import 'package:project_kobe/features/information/application/installed_build.dart';
import 'package:project_kobe/features/information/presentation/information_screen.dart';
import 'package:project_kobe/shared/brand/turtle_shell_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Drives the *real* app (router included) so the route, the overflow entry and
/// the Back behaviour are exercised together rather than in isolation.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Home → Informazioni e supporto → Back returns to Home', (
    tester,
  ) async {
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
          installedBuildProvider.overrideWith(
            (ref) async =>
                const InstalledBuild(version: '1.0.16', buildNumber: '2021'),
          ),
        ],
        child: const KobeApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Open the overflow and go.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Informazioni e supporto'));
    await tester.pumpAndSettle();

    expect(find.byType(InformationScreen), findsOneWidget);
    expect(find.text('Versione 1.0.16 · build 2021'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Back returns naturally to Home — the app bar's own back affordance.
    final backButton = find.byType(BackButton);
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.byType(InformationScreen), findsNothing);
    // Home is itself again: the launcher is present and still blooms exactly
    // the two creation methods (M7.0 is untouched by this milestone).
    await tester.tap(find.bySemanticsLabel('Conserva qualcosa'));
    await tester.pumpAndSettle();
    expect(find.byType(TurtleShellMenu), findsOneWidget);
    expect(find.text('Dalla foto'), findsOneWidget);
    expect(find.text('Dal nome'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
