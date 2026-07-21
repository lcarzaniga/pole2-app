import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:project_kobe/features/possessions/application/permanent_delete_cleanup.dart';

/// M8.2A — the post-commit filesystem cleanup: proves it removes only proven,
/// safe, still-unreferenced orphans under `photos/`, and reports an observed
/// deleted / missing / failed / preserved result.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.docs);
  final String docs;
  @override
  Future<String?> getApplicationDocumentsPath() async => docs;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;
  late Directory photos;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('pole2_pd_');
    photos = Directory(p.join(docs.path, 'photos'))
      ..createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
  });
  tearDown(() {
    try {
      photos.parent; // no-op keep
      // restore writability then remove
      Process.runSync('chmod', ['-R', 'u+rwx', docs.path]);
    } catch (_) {}
    try {
      docs.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<bool> never(String _) async => false;

  File writeFile(String rel, [String body = 'x']) {
    final f = File(p.join(docs.path, rel));
    f.writeAsStringSync(body);
    return f;
  }

  test('an exclusive orphan file is deleted', () async {
    final f = writeFile('photos/a.jpg');
    final r = await cleanupOrphanFiles(
      normalizedPaths: ['photos/a.jpg'],
      stillReferenced: never,
    );
    expect(r.deleted, 1);
    expect(r.hasFailures, isFalse);
    expect(f.existsSync(), isFalse);
  });

  test('a missing file is counted, not failed', () async {
    final r = await cleanupOrphanFiles(
      normalizedPaths: ['photos/gone.jpg'],
      stillReferenced: never,
    );
    expect(r.missing, 1);
    expect(r.deleted, 0);
    expect(r.hasFailures, isFalse);
  });

  test('a file the re-check finds still referenced is preserved', () async {
    final f = writeFile('photos/keep.jpg');
    final r = await cleanupOrphanFiles(
      normalizedPaths: ['photos/keep.jpg'],
      stillReferenced: (path) async => true, // still referenced
    );
    expect(r.preserved, 1);
    expect(r.deleted, 0);
    expect(f.existsSync(), isTrue); // never touched
  });

  test('an unsafe path is preserved, never resolved', () async {
    final r = await cleanupOrphanFiles(
      normalizedPaths: ['../secret.jpg'],
      stillReferenced: never,
    );
    expect(r.preserved, 1);
    expect(r.deleted, 0);
  });

  test('a path outside photos/ is preserved', () async {
    writeFile('other.jpg');
    final r = await cleanupOrphanFiles(
      normalizedPaths: ['other.jpg'],
      stillReferenced: never,
    );
    expect(r.preserved, 1);
    expect(r.deleted, 0);
    expect(File(p.join(docs.path, 'other.jpg')).existsSync(), isTrue);
  });

  test(
    'a delete failure is recorded and the file survives',
    () async {
      final f = writeFile('photos/locked.jpg');
      // Make the parent directory non-writable so unlink fails.
      Process.runSync('chmod', ['0555', photos.path]);
      final r = await cleanupOrphanFiles(
        normalizedPaths: ['photos/locked.jpg'],
        stillReferenced: never,
      );
      Process.runSync('chmod', ['0755', photos.path]);
      expect(r.failed, 1);
      expect(r.failedPaths, ['photos/locked.jpg']);
      expect(r.hasFailures, isTrue);
      expect(f.existsSync(), isTrue);
    },
    skip: _runningAsRoot ? 'chmod does not restrict root' : false,
  );

  test('an empty candidate list does nothing', () async {
    final r = await cleanupOrphanFiles(
      normalizedPaths: const [],
      stillReferenced: never,
    );
    expect(r.considered, 0);
    expect(r.hasFailures, isFalse);
  });
}

bool get _runningAsRoot {
  try {
    return Process.runSync('id', ['-u']).stdout.toString().trim() == '0';
  } catch (_) {
    return false;
  }
}
