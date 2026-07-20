import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/features/update/update_decision.dart';
import 'package:project_kobe/features/update/update_prompt.dart';
import 'package:project_kobe/l10n/app_localizations.dart';

/// Pumps a button that opens [open] and records its result, so the real dialogs
/// (localized, laid out) are exercised without any Drift/router/navigation.
Future<void> _harness<T>(
  WidgetTester tester,
  Future<T> Function(BuildContext) open,
  void Function(T) onResult,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('it')],
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => onResult(await open(context)),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'the three-way backup choice shows all options and returns create',
    (tester) async {
      BackupChoice? result;
      await _harness<BackupChoice>(
        tester,
        askBackupBeforeUpdate,
        (r) => result = r,
      );
      expect(
        find.text('Prima di aggiornare, vuoi creare un backup?'),
        findsOneWidget,
      );
      expect(find.text('Crea backup'), findsOneWidget);
      expect(find.text('Continua senza backup'), findsOneWidget);
      expect(find.text('Annulla'), findsOneWidget);

      await tester.tap(find.text('Crea backup'));
      await tester.pumpAndSettle();
      expect(result, BackupChoice.create);
    },
  );

  testWidgets('the three-way choice returns without / cancel', (tester) async {
    BackupChoice? result;
    await _harness<BackupChoice>(
      tester,
      askBackupBeforeUpdate,
      (r) => result = r,
    );
    await tester.tap(find.text('Continua senza backup'));
    await tester.pumpAndSettle();
    expect(result, BackupChoice.without);

    await _harness<BackupChoice>(
      tester,
      askBackupBeforeUpdate,
      (r) => result = r,
    );
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(result, BackupChoice.cancel);
  });

  testWidgets('continue-without needs the explicit second acknowledgment', (
    tester,
  ) async {
    bool? result;
    await _harness<bool>(tester, askContinueWithoutBackup, (r) => result = r);
    expect(
      find.text('Vuoi continuare senza creare un backup?'),
      findsOneWidget,
    );

    // "Indietro" → false (does not proceed).
    await tester.tap(find.text('Indietro'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    // "Continua" → true (proceeds).
    await _harness<bool>(tester, askContinueWithoutBackup, (r) => result = r);
    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('the restore-busy notice shows the calm copy and closes', (
    tester,
  ) async {
    await _harness<void>(tester, showUpdateRestoreBusy, (_) {});
    expect(find.textContaining('Un ripristino è in corso'), findsOneWidget);
    await tester.tap(find.text('Chiudi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Un ripristino è in corso'), findsNothing);
  });
}
