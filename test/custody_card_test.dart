import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/features/possessions/presentation/widgets/custody_card.dart';
import 'package:project_kobe/l10n/app_localizations.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    locale: const Locale('it'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: const [Locale('it')],
    home: Scaffold(body: child),
  );

  testWidgets('shows the borrower, lent date and a return action', (
    tester,
  ) async {
    var edited = 0, returned = 0;
    await tester.pumpWidget(
      wrap(
        CustodyCard(
          borrowerName: 'Marco',
          lentAt: DateTime(2026, 7, 1),
          expectedReturn: DateTime(2026, 7, 20),
          hasReminder: true,
          onEdit: () => edited++,
          onReturn: () => returned++,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Prestato a Marco'), findsOneWidget);
    expect(find.text('Segna come restituito'), findsOneWidget);
    // Custody is conveyed by an icon + text, never colour alone.
    expect(find.byIcon(Icons.people_alt_outlined), findsOneWidget);

    await tester.tap(find.text('Segna come restituito'));
    expect(returned, 1);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    expect(edited, 1);
  });

  testWidgets('an open-ended loan omits the return line', (tester) async {
    await tester.pumpWidget(
      wrap(
        CustodyCard(
          borrowerName: 'Lucia',
          lentAt: DateTime(2026, 7, 1),
          expectedReturn: null,
          hasReminder: false,
          onEdit: () {},
          onReturn: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Prestato a Lucia'), findsOneWidget);
    expect(find.textContaining('Rientro previsto'), findsNothing);
  });
}
