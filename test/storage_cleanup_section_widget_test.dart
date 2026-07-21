import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/features/storage/application/storage_cleanup_controller.dart';
import 'package:project_kobe/features/storage/application/storage_cleanup_result.dart';
import 'package:project_kobe/features/storage/presentation/storage_cleanup_section.dart';
import 'package:project_kobe/l10n/app_localizations.dart';

/// M8.2C — the "Spazio sul dispositivo" section UX. Uses a scripted fake
/// controller so the UI copy/flow is verified without real filesystem or DB.
class _FakeController extends StorageCleanupController {
  _FakeController(this._initial);
  final StorageCleanupState _initial;
  int scanCalls = 0;
  int cleanupCalls = 0;

  @override
  StorageCleanupState build() => _initial;

  @override
  Future<void> scan() async {
    scanCalls++;
    // Simulate: an empty scan yields "no candidates".
    state = const StorageCleanupState(phase: StoragePhase.scanned);
  }

  @override
  Future<void> cleanup() async {
    cleanupCalls++;
    state = const StorageCleanupState(
      phase: StoragePhase.done,
      report: StorageCleanupReport(deleted: 1, reclaimedBytes: 2048),
    );
  }
}

Widget _app(
  StorageCleanupState initial, {
  double bottomPadding = 0,
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [
      storageCleanupControllerProvider.overrideWith(
        () => _FakeController(initial),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: EdgeInsets.only(bottom: bottomPadding),
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: const Scaffold(
        body: SingleChildScrollView(child: StorageCleanupSection()),
      ),
    ),
  );
}

void main() {
  testWidgets('idle shows the calm title, body and scan action', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const StorageCleanupState()));
    await tester.pumpAndSettle();
    expect(find.text('Spazio sul dispositivo'), findsOneWidget);
    expect(
      find.text(
        'Pole² può cercare fotografie che non appartengono più ad alcun oggetto.',
      ),
      findsOneWidget,
    );
    expect(find.text('Controlla lo spazio'), findsOneWidget);
  });

  testWidgets('an empty scan reports no unused files', (tester) async {
    await tester.pumpWidget(_app(const StorageCleanupState()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Controlla lo spazio'));
    await tester.pumpAndSettle();
    expect(
      find.text('Non ci sono file inutilizzati da rimuovere.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'candidates show the size and a confirm pair; Libera spazio cleans',
    (tester) async {
      final scanned = const StorageCleanupState(
        phase: StoragePhase.scanned,
        candidates: [
          OrphanCandidate(relativePath: 'photos/a.jpg', byteSize: 1500000),
        ],
        scannedBytes: 1500000,
      );
      await tester.pumpWidget(_app(scanned));
      await tester.pumpAndSettle();

      // The "you can free ~X" copy and both confirm buttons.
      expect(find.textContaining('Puoi liberare circa'), findsOneWidget);
      expect(find.textContaining('1,5 MB'), findsOneWidget);
      expect(find.text('Annulla'), findsOneWidget);
      expect(find.text('Libera spazio'), findsOneWidget);

      await tester.tap(find.text('Libera spazio'));
      await tester.pumpAndSettle();
      expect(find.text('Spazio liberato: 2,0 KB.'), findsOneWidget);
    },
  );

  testWidgets('Annulla on the results changes nothing (back to scan action)', (
    tester,
  ) async {
    final scanned = const StorageCleanupState(
      phase: StoragePhase.scanned,
      candidates: [OrphanCandidate(relativePath: 'photos/a.jpg', byteSize: 10)],
      scannedBytes: 10,
    );
    await tester.pumpWidget(_app(scanned));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(find.text('Controlla lo spazio'), findsOneWidget);
    expect(find.text('Libera spazio'), findsNothing);
  });

  testWidgets('a blocked state shows the specific backup message', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const StorageCleanupState(
          phase: StoragePhase.blocked,
          blockedReason: 'backup',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Un backup è in corso. Attendi che finisca prima di liberare spazio.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('partial cleanup is disclosed honestly', (tester) async {
    await tester.pumpWidget(
      _app(
        const StorageCleanupState(
          phase: StoragePhase.done,
          report: StorageCleanupReport(
            deleted: 1,
            failed: 1,
            reclaimedBytes: 1000,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Alcuni file non sono stati rimossi'),
      findsOneWidget,
    );
  });

  testWidgets('320 dp + large text: scan action clears 48 dp, no overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(const StorageCleanupState(), bottomPadding: 48, textScale: 1.6),
    );
    await tester.pumpAndSettle();

    final btn = tester.getSize(
      find.widgetWithText(OutlinedButton, 'Controlla lo spazio'),
    );
    expect(btn.height, greaterThanOrEqualTo(48.0));
  });
}
