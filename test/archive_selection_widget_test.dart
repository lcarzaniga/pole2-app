import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/providers/database_provider.dart';
import 'package:project_kobe/features/archive/presentation/archive_screen.dart';
import 'package:project_kobe/l10n/app_localizations.dart';

/// M8.2B — selection mode in Archivio → Rimossi (batch permanent deletion UX).
Widget _app(
  AppDatabase db, {
  double bottomPadding = 0,
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWith((ref) {
        ref.onDispose(db.close);
        return db;
      }),
    ],
    child: MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: EdgeInsets.only(bottom: bottomPadding),
          viewPadding: EdgeInsets.only(bottom: bottomPadding),
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: const ArchiveScreen(),
    ),
  );
}

Future<String> _removed(AppDatabase db, String title) async {
  final p = await db.possessionsDao.createPossession(title: title);
  await db.possessionsDao.softDelete(p.id);
  return p.id;
}

Future<void> _openRimossiSelection(WidgetTester tester) async {
  await tester.tap(find.text('Rimossi'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Seleziona'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Seleziona reveals checkboxes; toggling updates the count', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await _removed(db, 'Alfa');
    await _removed(db, 'Beta');

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    // Entry point is discoverable (not only long-press).
    await tester.tap(find.text('Rimossi'));
    await tester.pumpAndSettle();
    expect(find.text('Seleziona'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);

    await tester.tap(find.text('Seleziona'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(find.text('0 selezionati'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('1 selezionato'), findsOneWidget);

    // Deselect returns to zero.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('0 selezionati'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Seleziona tutto (no search) selects all; one confirmation; cancel changes nothing',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await _removed(db, 'Alfa');
      await _removed(db, 'Beta');
      await _removed(db, 'Gamma');

      await tester.pumpWidget(_app(db));
      await tester.pumpAndSettle();
      await _openRimossiSelection(tester);

      await tester.tap(find.text('Seleziona tutto'));
      await tester.pumpAndSettle();
      expect(find.text('3 selezionati'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_forever_outlined));
      await tester.pumpAndSettle();
      // Exactly one confirmation, with the count.
      expect(find.text('Eliminare definitivamente 3 oggetti?'), findsOneWidget);

      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      // Nothing deleted, still selecting.
      expect(find.text('Eliminare definitivamente 3 oggetti?'), findsNothing);
      expect(find.text('3 selezionati'), findsOneWidget);
      expect(find.text('Alfa'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'with a search, select-all is labelled "risultati" and selects only the displayed rows',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await _removed(db, 'Alfa');
      await _removed(db, 'Beta');
      await _removed(db, 'Gamma');

      await tester.pumpWidget(_app(db));
      await tester.pumpAndSettle();
      await _openRimossiSelection(tester);

      await tester.enterText(find.byType(TextField), 'alf');
      await tester.pumpAndSettle();
      expect(find.text('Alfa'), findsOneWidget);
      expect(find.text('Beta'), findsNothing);

      expect(find.text('Seleziona tutti i risultati'), findsOneWidget);
      expect(find.text('Seleziona tutto'), findsNothing);

      await tester.tap(find.text('Seleziona tutti i risultati'));
      await tester.pumpAndSettle();
      expect(find.text('1 selezionato'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('switching tab exits selection without deleting', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await _removed(db, 'Alfa');
    await _removed(db, 'Beta');

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();
    await _openRimossiSelection(tester);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('1 selezionato'), findsOneWidget);

    // Leave to Conservati → selection ends.
    await tester.tap(find.text('Conservati'));
    await tester.pumpAndSettle();
    expect(find.text('1 selezionato'), findsNothing);

    // Back to Rimossi → not selecting, both items still present.
    await tester.tap(find.text('Rimossi'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Seleziona'), findsOneWidget);
    expect(find.text('Alfa'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('a row that disappears reactively leaves the selection', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await _removed(db, 'Alfa');
    final bId = await _removed(db, 'Beta');

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();
    await _openRimossiSelection(tester);
    await tester.tap(find.text('Seleziona tutto'));
    await tester.pumpAndSettle();
    expect(find.text('2 selezionati'), findsOneWidget);

    // Restore Beta elsewhere → its row vanishes and leaves the selection.
    await db.possessionsDao.restoreRemoved(bId);
    await tester.pumpAndSettle();
    expect(find.text('1 selezionato'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('no deletion action when nothing is selected', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await _removed(db, 'Alfa');

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();
    await _openRimossiSelection(tester);

    expect(find.text('0 selezionati'), findsOneWidget);
    final del = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.delete_forever_outlined),
    );
    expect(del.onPressed, isNull); // disabled at zero selection

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('long-press enters selection and selects that row', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await _removed(db, 'Alfa');
    await _removed(db, 'Beta');

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rimossi'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Alfa'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(find.text('1 selezionato'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    '320 dp: checkbox target ≥48 dp and the list clears the bottom inset',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await _removed(db, 'Alfa');

      await tester.pumpWidget(_app(db, bottomPadding: 80));
      await tester.pumpAndSettle();
      await _openRimossiSelection(tester);

      final cb = tester.getSize(find.byType(Checkbox).first);
      expect(cb.height, greaterThanOrEqualTo(48.0));
      expect(cb.width, greaterThanOrEqualTo(48.0));

      final list = tester.widget<ListView>(find.byType(ListView));
      expect((list.padding as EdgeInsets).bottom, greaterThanOrEqualTo(80.0));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
