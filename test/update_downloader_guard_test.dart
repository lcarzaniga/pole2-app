import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:project_kobe/features/update/model/update_release.dart';
import 'package:project_kobe/features/update/update_downloader.dart';

/// Minimal fake so `getTemporaryDirectory()` resolves to a real temp dir.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.temp);
  final String temp;
  @override
  Future<String?> getTemporaryPath() async => temp;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // "abc" hashes to this — the release's declared sha256, so verification passes.
  const body = 'abc';
  const sha =
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';

  const channel = MethodChannel('pole2/installer');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<String> installed;
  late Directory tmp; // the fake temporary directory root
  // Where the downloader writes the APK: <temp>/updates/pole2-<vc>.apk.
  late String updatesDir;
  late String apkPath;

  UpdateRelease release() => UpdateRelease(
    versionName: '1.0.17',
    versionCode: 2022,
    apkUrl: 'https://pole2.app/pole2-2022.apk',
    sha256: sha,
    notes: const [],
    mandatory: false,
  );

  http.Client goodClient() => MockClient((_) async => http.Response(body, 200));

  setUp(() {
    installed = <String>[];
    tmp = Directory.systemTemp.createTempSync('kobe_dl');
    updatesDir = p.join(tmp.path, 'updates');
    apkPath = p.join(updatesDir, 'pole2-2022.apk');
    addTearDown(() {
      // Restore permissions first (a test may make `updates` read-only) so the
      // recursive delete always succeeds.
      Process.runSync('chmod', ['-R', 'u+rwx', tmp.path]);
      tmp.deleteSync(recursive: true);
    });
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);

    // The OS install gate: permission granted; record install() calls.
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'canInstall':
          return true;
        case 'install':
          installed.add((call.arguments as Map)['path'] as String);
          return null;
      }
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'with no restore pending, a verified APK reaches the installer',
    () async {
      final d = UpdateDownloader(
        isRestorePending: () async => false,
        clientFactory: goodClient,
      );
      final stages = [for (final s in await d.run(release()).toList()) s.stage];
      expect(stages, contains(DownloadStage.installing));
      expect(stages, isNot(contains(DownloadStage.blockedByRestore)));
      expect(installed, [apkPath]);
    },
  );

  test(
    'blocked pre-install deletes the verified APK and never installs',
    () async {
      // False on the pre-download check, true on the pre-install check: the APK
      // is downloaded and verified, then the defensive guard fires.
      var calls = 0;
      final d = UpdateDownloader(
        isRestorePending: () async => ++calls >= 2,
        clientFactory: goodClient,
      );
      final stages = [for (final s in await d.run(release()).toList()) s.stage];

      expect(stages, contains(DownloadStage.verifying));
      expect(stages.last, DownloadStage.blockedByRestore);
      expect(stages, isNot(contains(DownloadStage.installing)));
      // (1) the verified temp APK is deleted; (2) the installer is never called.
      expect(
        File(apkPath).existsSync(),
        isFalse,
        reason: 'APK must be deleted',
      );
      expect(installed, isEmpty);
    },
  );

  test(
    'a cleanup failure at the pre-install guard still blocks safely',
    () async {
      // Reach the pre-install guard, then make `updates` read-only right before
      // the delete so deleteSync throws — the block must hold regardless.
      var calls = 0;
      final d = UpdateDownloader(
        isRestorePending: () async {
          if (++calls >= 2) {
            Process.runSync('chmod', ['0500', updatesDir]); // undeletable now
          }
          return calls >= 2;
        },
        clientFactory: goodClient,
      );
      final stages = [for (final s in await d.run(release()).toList()) s.stage];

      expect(
        stages.last,
        DownloadStage.blockedByRestore,
      ); // no crash, still blocks
      expect(stages, isNot(contains(DownloadStage.installing)));
      expect(installed, isEmpty);
      // The delete genuinely failed (the file survives), proving the catch path.
      Process.runSync('chmod', ['0700', updatesDir]);
      expect(File(apkPath).existsSync(), isTrue);
    },
  );

  test('the initial pre-download guard creates no temporary file', () async {
    final d = UpdateDownloader(
      isRestorePending: () async => true, // pending before any download
      clientFactory: goodClient,
    );
    final stages = [for (final s in await d.run(release()).toList()) s.stage];

    expect(stages, [DownloadStage.blockedByRestore]);
    expect(installed, isEmpty);
    // Nothing was written: the `updates` directory was never even created.
    expect(Directory(updatesDir).existsSync(), isFalse);
  });

  test(
    'a SHA-256 mismatch never installs and never reaches the guard',
    () async {
      final d = UpdateDownloader(
        isRestorePending: () async => false,
        clientFactory: () => MockClient((_) async => http.Response('xyz', 200)),
      );
      final states = await d.run(release()).toList();
      expect(states.last.stage, DownloadStage.error);
      expect(states.last.reason, 'sha256');
      expect(installed, isEmpty);
      expect(File(apkPath).existsSync(), isFalse); // mismatch also cleans up
    },
  );
}
