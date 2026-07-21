import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/app/theme/app_theme.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/providers/database_provider.dart';
import 'package:project_kobe/features/home/presentation/home_screen.dart';
import 'package:project_kobe/features/information/application/installed_build.dart';
import 'package:project_kobe/features/information/presentation/information_screen.dart';
import 'package:project_kobe/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _installed = InstalledBuild(version: '1.0.16', buildNumber: '2021');

/// The Information screen alone, with a known installed build and (optionally)
/// a system navigation inset. No live Drift stream is involved, so this settles.
Widget _infoApp({
  InstalledBuild build = _installed,
  bool failVersion = false,
  double bottomPadding = 0,
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [
      installedBuildProvider.overrideWith((ref) async {
        if (failVersion) throw Exception('version unavailable');
        return build;
      }),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
          padding: EdgeInsets.only(bottom: bottomPadding),
          viewPadding: EdgeInsets.only(bottom: bottomPadding),
        ),
        child: child!,
      ),
      home: const InformationScreen(),
    ),
  );
}

/// Scrolls the "Licenze open source" row into view (it is the last item, below
/// the fold on a phone) and returns its label finder.
Future<Finder> _revealLicenses(WidgetTester tester) async {
  final finder = find.text('Licenze open source');
  await tester.scrollUntilVisible(
    finder,
    80,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  return finder;
}

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

/// A real phone portrait, so rows sit where they do on a device rather than in
/// the 800×600 default landscape.
void _phone(WidgetTester tester, {Size size = const Size(360, 780)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Scrolls a link into view, then taps it — the lower rows are below the fold
/// on a phone, exactly as for a real user.
Future<void> _tapLink(WidgetTester tester, String label) async {
  final finder = find.bySemanticsLabel('$label. Si apre nel browser.');
  await tester.scrollUntilVisible(
    finder,
    80,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('identity and installed build', () {
    testWidgets('shows the name, the motto and the local-first promise', (
      tester,
    ) async {
      await tester.pumpWidget(_infoApp());
      await tester.pumpAndSettle();

      expect(find.text('Informazioni e supporto'), findsOneWidget);
      expect(
        find.text('Custodisci ciò che conta, conta ciò che custodisci.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'I dati di Pole² restano sul tuo dispositivo, salvo i backup '
          'che scegli di esportare.',
        ),
        findsOneWidget,
      );

      await _teardown(tester);
    });

    testWidgets('renders the version read at runtime, not a literal', (
      tester,
    ) async {
      await tester.pumpWidget(_infoApp());
      await tester.pumpAndSettle();
      expect(find.text('Versione 1.0.16 · build 2021'), findsOneWidget);
      await _teardown(tester);
    });

    testWidgets('a different installed build renders differently', (
      tester,
    ) async {
      // Proves the line is derived, not hard-coded: same code, other numbers.
      await tester.pumpWidget(
        _infoApp(
          build: const InstalledBuild(version: '9.9.9', buildNumber: '4242'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Versione 9.9.9 · build 4242'), findsOneWidget);
      expect(find.text('Versione 1.0.16 · build 2021'), findsNothing);
      await _teardown(tester);
    });

    testWidgets('an unavailable version stays calm, never an error', (
      tester,
    ) async {
      await tester.pumpWidget(_infoApp(failVersion: true));
      await tester.pumpAndSettle();
      expect(find.text('Versione non disponibile'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _teardown(tester);
    });
  });

  group('the five links', () {
    testWidgets('are all present, each with icon + text', (tester) async {
      await tester.pumpWidget(_infoApp());
      await tester.pumpAndSettle();

      for (final label in const [
        'Sito di Pole²',
        'Guida',
        'Novità',
        'Supporto',
        'Privacy',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // The "leaves the app" affordance is a shape, present once per row —
      // never colour alone.
      expect(find.byIcon(Icons.open_in_new), findsNWidgets(5));

      await _teardown(tester);
    });

    testWidgets('each row is spoken with its purpose and that it leaves the '
        'app', (tester) async {
      await tester.pumpWidget(_infoApp());
      await tester.pumpAndSettle();

      for (final label in const [
        'Sito di Pole²',
        'Guida',
        'Novità',
        'Supporto',
        'Privacy',
      ]) {
        expect(
          find.bySemanticsLabel('$label. Si apre nel browser.'),
          findsOneWidget,
          reason: label,
        );
      }

      await _teardown(tester);
    });

    testWidgets('every row offers at least a 48 dp target', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_infoApp());
      await tester.pumpAndSettle();

      final rows = find.byType(InkWell);
      expect(rows, findsNWidgets(5));
      for (var i = 0; i < 5; i++) {
        expect(
          tester.getSize(rows.at(i)).height,
          greaterThanOrEqualTo(48.0),
          reason: 'row $i',
        );
      }

      await _teardown(tester);
    });

    testWidgets('tapping a link asks the system for exactly that URL', (
      tester,
    ) async {
      const channel = MethodChannel('pole2/links');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final asked = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        asked.add(call.arguments['url'] as String);
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      _phone(tester);
      await tester.pumpWidget(_infoApp());
      await tester.pumpAndSettle();

      await _tapLink(tester, 'Guida');
      expect(asked, ['https://pole2.app/guida/']);

      // The support link carries the *runtime* version/build and nothing else.
      await _tapLink(tester, 'Supporto');
      expect(asked.last, 'https://pole2.app/supporto/?v=1.0.16&b=2021');

      await _teardown(tester);
    });

    testWidgets('the URLs the screen would open are exactly the five '
        'canonical ones', (tester) async {
      const channel = MethodChannel('pole2/links');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final asked = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        asked.add(call.arguments['url'] as String);
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      _phone(tester);
      await tester.pumpWidget(_infoApp());
      await tester.pumpAndSettle();

      for (final label in const [
        'Sito di Pole²',
        'Guida',
        'Novità',
        'Supporto',
        'Privacy',
      ]) {
        await _tapLink(tester, label);
      }

      expect(asked, const [
        'https://pole2.app/',
        'https://pole2.app/guida/',
        'https://pole2.app/novita/',
        'https://pole2.app/supporto/?v=1.0.16&b=2021',
        'https://pole2.app/privacy/',
      ]);
      // No device id, model, installation id or personal data anywhere.
      for (final url in asked) {
        final uri = Uri.parse(url);
        expect(uri.host, 'pole2.app');
        expect(uri.userInfo, isEmpty);
        expect(
          uri.queryParameters.keys.every((k) => k == 'v' || k == 'b'),
          isTrue,
          reason: url,
        );
      }

      await _teardown(tester);
    });

    testWidgets('a device with no browser gets a calm sentence, not a crash', (
      tester,
    ) async {
      const channel = MethodChannel('pole2/links');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'no_handler'),
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      _phone(tester);
      await tester.pumpWidget(_infoApp());
      await tester.pumpAndSettle();

      await _tapLink(tester, 'Guida');

      expect(
        find.textContaining('Non c\'è un browser su questo dispositivo'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await _teardown(tester);
    });

    testWidgets(
      'a platform without the channel fails calmly too (web/desktop)',
      (tester) async {
        // What an unregistered channel actually raises on a real web/desktop
        // build. (Simulated rather than left unregistered: with no handler at
        // all the test binding never replies, so the future would simply hang —
        // which tests the harness, not the app.)
        const channel = MethodChannel('pole2/links');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          channel,
          (call) async => throw MissingPluginException('no pole2/links here'),
        );
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

        _phone(tester);
        await tester.pumpWidget(_infoApp());
        await tester.pumpAndSettle();

        await _tapLink(tester, 'Privacy');

        expect(
          find.textContaining('Non è stato possibile aprire il link'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await _teardown(tester);
      },
    );
  });

  group('layout', () {
    testWidgets('the last row clears a 56 dp three-button navigation bar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_infoApp(bottomPadding: 56));
      await tester.pumpAndSettle();

      // The scroll view's own bottom padding absorbs the system inset, so the
      // final row can be scrolled fully above the navigation bar.
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(
        (listView.padding as EdgeInsets).bottom,
        greaterThanOrEqualTo(56.0),
      );

      await _teardown(tester);
    });

    testWidgets('no overflow at 320 dp with large text', (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            installedBuildProvider.overrideWith((ref) async => _installed),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('it'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              // A large accessibility text scale on the narrowest screen.
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: const TextScaler.linear(1.6),
              ),
              child: child!,
            ),
            home: const InformationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Nothing overflowed while laying out at 1.6× on the narrowest screen…
      expect(tester.takeException(), isNull);
      // …and the lower rows remain reachable by scrolling, not clipped away.
      await tester.scrollUntilVisible(
        find.text('Supporto'),
        80,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Supporto'), findsOneWidget);

      await _teardown(tester);
    });
  });

  group('navigation from Home', () {
    testWidgets('the overflow lists it last, after Backup e ripristino', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await tester.pumpWidget(
        ProviderScope(
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
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // The intended order: Luoghi · Persone · Archivio · Backup · Informazioni.
      final items = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(PopupMenuItem<String>),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .toList();
      expect(items, const [
        'Luoghi',
        'Persone',
        'Archivio',
        'Backup e ripristino',
        'Informazioni e supporto',
      ]);

      await _teardown(tester);
    });
  });

  group('open-source licenses (M8.1)', () {
    const kLicenseSemantics = 'Licenze open source. Rimane nell\'app.';

    testWidgets('offers the entry — icon+text, chevron (not open-in-new), '
        'stays-in-app semantics and a ≥48 dp target', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_infoApp());
      await tester.pumpAndSettle();

      final label = await _revealLicenses(tester);
      expect(label, findsOneWidget);
      expect(
        find.text('Le librerie che rendono possibile Pole²'),
        findsOneWidget,
      );

      // Icon present; a chevron (in-app), never the browser "open in new".
      final row = find.ancestor(of: label, matching: find.byType(InkWell));
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.chevron_right)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.byIcon(Icons.open_in_new)),
        findsNothing,
      );
      // The whole row is a comfortable touch target.
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48.0));

      await _teardown(tester);
    });

    testWidgets('has the accessible stays-in-app button label', (tester) async {
      final handle = tester.ensureSemantics();
      _phone(tester);
      await tester.pumpWidget(_infoApp());
      await tester.pumpAndSettle();
      await _revealLicenses(tester);

      expect(find.bySemanticsLabel(kLicenseSemantics), findsOneWidget);
      handle.dispose();
      await _teardown(tester);
    });

    testWidgets('opens Flutter\'s native license page in-app (no browser), '
        'branded as Pole²', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_infoApp());
      await tester.pumpAndSettle();
      await _revealLicenses(tester);

      await tester.tap(find.bySemanticsLabel(kLicenseSemantics));
      await tester.pump(); // start the push
      await tester.pump(const Duration(milliseconds: 500)); // finish transition

      // The framework-native surface, not a browser handoff.
      expect(find.byType(LicensePage), findsOneWidget);
      // Pole² branding: the legalese line appears only on the license page.
      expect(
        find.textContaining('mantengono ciascuna la propria licenza'),
        findsOneWidget,
      );

      await _teardown(tester);
    });

    testWidgets('Back from the license page returns to Informazioni', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_infoApp());
      await tester.pumpAndSettle();
      await _revealLicenses(tester);

      await tester.tap(find.bySemanticsLabel(kLicenseSemantics));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LicensePage), findsOneWidget);

      // The device Back (system pop) returns to Informazioni.
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LicensePage), findsNothing);
      expect(find.text('Informazioni e supporto'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('reachable and non-overflowing at 320 dp with large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_infoApp(textScale: 1.6));
      await tester.pumpAndSettle();

      await _revealLicenses(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Licenze open source'), findsOneWidget);

      await _teardown(tester);
    });

    testWidgets('the last row clears the bottom navigation inset', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_infoApp(bottomPadding: 56));
      await tester.pumpAndSettle();

      // The licenses row is the final child; the list's own bottom padding
      // absorbs the inset so it scrolls fully above the system bar.
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(
        (listView.padding as EdgeInsets).bottom,
        greaterThanOrEqualTo(56.0),
      );
      await _revealLicenses(tester);
      expect(find.text('Licenze open source'), findsOneWidget);

      await _teardown(tester);
    });
  });
}
