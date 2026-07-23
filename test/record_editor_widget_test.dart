import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
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

/// Fakes the image_picker platform so "Scatta una foto" can be exercised.
class _FakeImagePicker extends ImagePickerPlatform
    with MockPlatformInterfaceMixin {
  XFile? Function()? onGet;
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => onGet?.call();
}

// A 1×1 PNG (decodes fine even when named .jpg — Image decodes by content).
const _png = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x62,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

void main() {
  late AppDatabase db;
  late String possessionId;
  late _FakeImagePicker picker;
  late Directory dir;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    possessionId = (await db.possessionsDao.createPossession(
      title: 'Caldaia',
    )).id;
    picker = _FakeImagePicker();
    ImagePickerPlatform.instance = picker;
    dir = Directory.systemTemp.createTempSync('pole2_ed_');
  });
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
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
    expect(find.text('Aggiungi allegato'), findsNothing);
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
    expect(find.text('Aggiungi allegato'), findsOneWidget);
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

  group('attachments (M9.1)', () {
    testWidgets('"Aggiungi allegato" opens a three-source sheet', (
      tester,
    ) async {
      await tester.pumpWidget(_app(db, possessionId: possessionId));
      await tester.pumpAndSettle();
      // Attachments live under a structured category.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Garanzia'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aggiungi allegato'));
      await tester.pumpAndSettle();

      expect(find.text('Aggiungi un allegato'), findsOneWidget); // sheet title
      expect(find.text('Scatta una foto'), findsOneWidget);
      expect(find.text('Scegli una foto'), findsOneWidget);
      expect(find.text('Scegli un documento'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('capturing a photo adds a "Foto" attachment with a thumbnail', (
      tester,
    ) async {
      final f = File('${dir.path}/cap.jpg')..writeAsBytesSync(_png);
      picker.onGet = () => XFile(f.path);

      await tester.pumpWidget(_app(db, possessionId: possessionId));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Garanzia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aggiungi allegato'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scatta una foto'));
      await tester.pumpAndSettle();

      // The new image shows the default "Foto" label and a thumbnail.
      expect(find.text('Foto'), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
      await _unmount(tester);
    });
  });
}
