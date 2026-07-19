import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/app/theme/app_theme.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/providers/database_provider.dart';
import 'package:project_kobe/features/home/presentation/home_screen.dart';
import 'package:project_kobe/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _framed(AppDatabase db) => ProviderScope(
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
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: const HomeScreen(),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'a lent card shows "Prestato a {name}"; a non-lent card keeps its category',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.possessionsDao.createPossession(
        title: 'Trapano',
        category: 'Utensili',
      );
      final book = await db.possessionsDao.createPossession(title: 'Libro');
      await db.eventsDao.lend(
        possessionId: book.id,
        personName: 'Carlo',
        lentAt: DateTime.now(),
      );

      await tester.pumpWidget(_framed(db));
      await tester.pumpAndSettle();

      expect(find.text('Prestato a Carlo'), findsOneWidget); // grouped, no N+1
      expect(find.text('Utensili'), findsOneWidget); // non-lent keeps category

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('the filter lists only people who currently have a loan', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final book = await db.possessionsDao.createPossession(title: 'Libro');
    await db.eventsDao.lend(
      possessionId: book.id,
      personName: 'Carlo',
      lentAt: DateTime.now(),
    );
    // Marco exists but has only a returned loan → not a current borrower.
    final tool = await db.possessionsDao.createPossession(title: 'Sega');
    final loan = await db.eventsDao.lend(
      possessionId: tool.id,
      personName: 'Marco',
      lentAt: DateTime.now(),
    );
    await db.eventsDao.returnLoan(
      possessionId: tool.id,
      loanEventId: loan!.id,
      returnedAt: DateTime.now(),
    );

    await tester.pumpWidget(_framed(db));
    await tester.pumpAndSettle();

    // Open "Dove si trova".
    await tester.tap(find.byTooltip('Dove si trova'));
    await tester.pumpAndSettle();

    expect(find.text('Tutti'), findsOneWidget);
    expect(find.text('Senza luogo'), findsOneWidget);
    expect(find.text('Carlo'), findsOneWidget); // current borrower listed
    expect(find.text('Marco'), findsNothing); // returned → not offered

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'selecting a person shows only that loan, with an active-filter chip',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final book = await db.possessionsDao.createPossession(title: 'Libro');
      await db.eventsDao.lend(
        possessionId: book.id,
        personName: 'Carlo',
        lentAt: DateTime.now(),
      );
      await db.possessionsDao.createPossession(title: 'Chiavi'); // unassigned

      await tester.pumpWidget(_framed(db));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Dove si trova'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Carlo').last, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Only the lent thing remains; the chip reads "Con: Carlo".
      expect(find.text('Libro'), findsOneWidget);
      expect(find.text('Chiavi'), findsNothing);
      expect(find.text('Con: Carlo'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('returning the last loan falls the person filter back to Tutti', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final book = await db.possessionsDao.createPossession(title: 'Libro');
    final loan = await db.eventsDao.lend(
      possessionId: book.id,
      personName: 'Carlo',
      lentAt: DateTime.now(),
    );
    await db.possessionsDao.createPossession(title: 'Chiavi');

    await tester.pumpWidget(_framed(db));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dove si trova'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carlo').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Con: Carlo'), findsOneWidget);

    // Return the loan → Carlo is no longer a valid filter → fall back to all.
    await db.eventsDao.returnLoan(
      possessionId: book.id,
      loanEventId: loan!.id,
      returnedAt: DateTime.now(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Con: Carlo'), findsNothing); // chip cleared
    expect(find.text('Libro'), findsOneWidget); // both things visible again
    expect(find.text('Chiavi'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('Kobe still blooms exactly Dalla foto / Dal nome', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.possessionsDao.createPossession(title: 'Libro');

    await tester.pumpWidget(_framed(db));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Conserva qualcosa'));
    await tester.pumpAndSettle();
    expect(find.text('Dalla foto'), findsOneWidget);
    expect(find.text('Dal nome'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
