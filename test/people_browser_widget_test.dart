import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/providers/database_provider.dart';
import 'package:project_kobe/features/people/presentation/people_browser_screen.dart';
import 'package:project_kobe/l10n/app_localizations.dart';

Widget _app(AppDatabase db, {double bottomPadding = 0}) {
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
        ),
        child: child!,
      ),
      home: const PeopleBrowserScreen(),
    ),
  );
}

void main() {
  testWidgets(
    'shows a person with their current counts and safe-bottom padding',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final p = await db.possessionsDao.createPossession(title: 'Trapano');
      await db.eventsDao.lend(
        possessionId: p.id,
        personName: 'Carlo',
        lentAt: DateTime.now(),
      );

      await tester.pumpWidget(_app(db, bottomPadding: 80));
      await tester.pumpAndSettle();

      expect(find.text('Persone'), findsOneWidget);
      expect(find.text('Carlo'), findsOneWidget);
      expect(find.text('1 in prestito'), findsOneWidget);

      // The list reserves the 80px system-navigation inset at its bottom.
      final list = tester.widget<ListView>(find.byType(ListView));
      expect((list.padding as EdgeInsets).bottom, greaterThanOrEqualTo(80.0));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('empty People shows the calm invitation copy', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    expect(
      find.text('Le persone a cui presti o dai qualcosa compaiono qui.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
