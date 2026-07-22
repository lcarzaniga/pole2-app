import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/database/tables/enums.dart';
import 'package:project_kobe/core/providers/database_provider.dart';
import 'package:project_kobe/features/possessions/presentation/record_editor_screen.dart';
import 'package:project_kobe/l10n/app_localizations.dart';

/// M9 UX correction — the category-driven record editor: an always-visible
/// category selector, Nota-only-minimal, structured categories reveal the extra
/// fields, and a calm safeguard when switching back to Nota.
Widget _app(AppDatabase db, {required String possessionId, String? recordId}) {
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
      home: RecordEditorScreen(possessionId: possessionId, recordId: recordId),
    ),
  );
}

ChoiceChip _chip(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));

/// Unmounts the tree so the ProviderScope disposes and Drift's stream-close
/// timer drains before the test ends (avoids a pending-timer assertion).
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;
  late String possessionId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    possessionId = (await db.possessionsDao.createPossession(
      title: 'Caldaia',
    )).id;
  });

  testWidgets('new editor defaults to Nota with the selector always visible', (
    tester,
  ) async {
    await tester.pumpWidget(_app(db, possessionId: possessionId));
    await tester.pumpAndSettle();

    // Every category is offered, and Nota is the selected default.
    for (final label in [
      'Nota',
      'Acquisto / ricevuta',
      'Garanzia',
      'Manuale / documentazione',
      'Manutenzione',
      'Assicurazione / certificato',
      'Altro',
    ]) {
      expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
    }
    expect(_chip(tester, 'Nota').selected, isTrue);

    // A plain note hides every structured field.
    expect(find.text('Aggiungi una scadenza'), findsNothing);
    expect(find.text('Aggiungi un documento'), findsNothing);
    expect(find.text('Data'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('selecting a structured category reveals the optional fields', (
    tester,
  ) async {
    await tester.pumpWidget(_app(db, possessionId: possessionId));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Garanzia'));
    await tester.pumpAndSettle();

    expect(_chip(tester, 'Garanzia').selected, isTrue);
    expect(find.text('Data'), findsOneWidget);
    expect(find.text('Aggiungi una scadenza'), findsOneWidget);
    expect(find.text('Aggiungi un documento'), findsOneWidget);
    await _unmount(tester);
  });

  group('switching back to Nota with structured data', () {
    Future<String> warrantyWithEnd() =>
        db.evidenceDao.createRecordWithAttachments(
          possessionId: possessionId,
          kind: EventKind.warranty,
          at: DateTime(2026, 7, 22),
          endsAt: DateTime(2028, 7, 22),
          notes: 'Garanzia lavatrice',
        );

    testWidgets('asks to confirm; cancelling keeps the category + data', (
      tester,
    ) async {
      final id = await warrantyWithEnd();
      await tester.pumpWidget(
        _app(db, possessionId: possessionId, recordId: id),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(_chip(tester, 'Garanzia').selected, isTrue);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Nota'));
      await tester.pumpAndSettle();
      // A confirmation dialog appears.
      expect(find.text('Passare a Nota?'), findsOneWidget);

      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      // Still a warranty; its structured fields (and end date) are intact.
      expect(_chip(tester, 'Garanzia').selected, isTrue);
      expect(_chip(tester, 'Nota').selected, isFalse);
      expect(find.textContaining('Scade il'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('confirming removes the structured data and switches to Nota', (
      tester,
    ) async {
      final id = await warrantyWithEnd();
      await tester.pumpWidget(
        _app(db, possessionId: possessionId, recordId: id),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Nota'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rimuovi e continua'));
      await tester.pumpAndSettle();

      // Now a plain note: structured fields are hidden.
      expect(_chip(tester, 'Nota').selected, isTrue);
      expect(_chip(tester, 'Garanzia').selected, isFalse);
      expect(find.text('Aggiungi una scadenza'), findsNothing);
      expect(find.textContaining('Scade il'), findsNothing);
      expect(find.text('Data'), findsNothing);
      await _unmount(tester);
    });
  });
}
