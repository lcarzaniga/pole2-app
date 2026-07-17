import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/features/places/presentation/widgets/possession_place_tile.dart';
import 'package:project_kobe/features/possessions/application/possession_providers.dart';
import 'package:project_kobe/l10n/app_localizations.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Widget wrap(Widget child) => ProviderScope(
    overrides: [
      // No on-disk docs path in tests → the tile shows its placeholder.
      appDocumentsPathProvider.overrideWith((ref) async => null),
    ],
    child: MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('it')],
      home: Scaffold(body: child),
    ),
  );

  testWidgets('tap opens; the menu offers move and remove', (tester) async {
    final p = await db.possessionsDao.createPossession(
      title: 'Trapano',
      category: 'Utensili',
    );
    var opened = 0, moved = 0, removed = 0;

    await tester.pumpWidget(
      wrap(
        PossessionPlaceTile(
          possession: p,
          onOpen: () => opened++,
          onMove: () => moved++,
          onRemove: () => removed++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trapano'), findsOneWidget);
    expect(find.text('Utensili'), findsOneWidget);
    // No cover → the neutral placeholder icon, never a broken image.
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);

    await tester.tap(find.text('Trapano'));
    expect(opened, 1);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Sposta in un altro luogo'), findsOneWidget);
    expect(find.text('Rimuovi dal luogo'), findsOneWidget);

    await tester.tap(find.text('Rimuovi dal luogo'));
    await tester.pumpAndSettle();
    expect(removed, 1);
    expect(moved, 0);
  });
}
