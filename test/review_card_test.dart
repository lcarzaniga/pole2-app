import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/features/places/presentation/widgets/review_card.dart';
import 'package:project_kobe/features/possessions/application/possession_providers.dart';
import 'package:project_kobe/l10n/app_localizations.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Widget wrap(Widget child) => ProviderScope(
    overrides: [
      // No on-disk docs path in tests → the thumb shows its placeholder.
      appDocumentsPathProvider.overrideWith((ref) async => null),
    ],
    child: MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('it')],
      home: Scaffold(body: child),
    ),
  );

  testWidgets('shows the object and all four labelled actions', (tester) async {
    final p = await db.possessionsDao.createPossession(
      title: 'Trapano',
      category: 'Utensili',
    );

    await tester.pumpWidget(
      wrap(
        ReviewCard(
          possession: p,
          placeName: 'Garage',
          count: 3,
          enabled: true,
          onKeep: () {},
          onMove: () {},
          onUnassign: () {},
          onArchive: () {},
          onMore: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Trapano'), findsOneWidget);
    expect(find.text('Utensili'), findsOneWidget);
    expect(find.text('Garage'), findsOneWidget);
    expect(
      find.text('3 cose qui'),
      findsOneWidget,
    ); // gentle count, no fraction
    expect(
      find.byIcon(Icons.inventory_2_outlined),
      findsOneWidget,
    ); // placeholder
    // All four actions present and labelled.
    expect(find.text('Tieni qui'), findsOneWidget);
    expect(find.text('Sposta'), findsOneWidget);
    expect(find.text('Togli dal luogo'), findsOneWidget);
    expect(find.text('Metti da parte'), findsOneWidget);
  });

  testWidgets('each action fires its callback exactly once when enabled', (
    tester,
  ) async {
    final p = await db.possessionsDao.createPossession(title: 'Trapano');
    var kept = 0, moved = 0, unassigned = 0, archived = 0;

    await tester.pumpWidget(
      wrap(
        ReviewCard(
          possession: p,
          placeName: 'Garage',
          count: 1,
          enabled: true,
          onKeep: () => kept++,
          onMove: () => moved++,
          onUnassign: () => unassigned++,
          onArchive: () => archived++,
          onMore: () {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Tieni qui'));
    await tester.tap(find.text('Sposta'));
    await tester.tap(find.text('Togli dal luogo'));
    await tester.tap(find.text('Metti da parte'));
    expect([kept, moved, unassigned, archived], [1, 1, 1, 1]);
  });

  testWidgets('when disabled (busy), a tap cannot fire — no double action', (
    tester,
  ) async {
    final p = await db.possessionsDao.createPossession(title: 'Trapano');
    var kept = 0;

    await tester.pumpWidget(
      wrap(
        ReviewCard(
          possession: p,
          placeName: 'Garage',
          count: 1,
          enabled: false, // async mutation pending
          onKeep: () => kept++,
          onMove: () {},
          onUnassign: () {},
          onArchive: () {},
          onMore: () {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Tieni qui'));
    expect(kept, 0); // disabled button ignores taps
  });

  testWidgets('completion shows the calm copy and a working Fine action', (
    tester,
  ) async {
    var done = 0;
    await tester.pumpWidget(wrap(ReviewComplete(onDone: () => done++)));
    await tester.pump();

    expect(find.text("Hai guardato tutto quello che c'è qui."), findsOneWidget);
    expect(find.text('Fine'), findsOneWidget);
    await tester.tap(find.text('Fine'));
    expect(done, 1);
  });
}
