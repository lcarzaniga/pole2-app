import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:project_kobe/features/storage/application/storage_cleanup.dart';
import 'package:project_kobe/features/storage/application/storage_cleanup_result.dart';

/// M8.2C — the native scan/delete engine. Real `photos/` on a temp dir; proves
/// the strict orphan definition, the session cutoff and the delete-time
/// re-checks.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.docs);
  final String docs;
  @override
  Future<String?> getApplicationDocumentsPath() async => docs;
}

bool get _runningAsRoot {
  try {
    return Process.runSync('id', ['-u']).stdout.toString().trim() == '0';
  } catch (_) {
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory docs;
  late Directory photos;
  // Cutoff in the future so ordinary files (mtime "now") count as pre-session.
  final future = DateTime.now().add(const Duration(days: 1));

  setUp(() {
    docs = Directory.systemTemp.createTempSync('pole2_sc_');
    photos = Directory(p.join(docs.path, 'photos'))
      ..createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
  });
  tearDown(() {
    try {
      Process.runSync('chmod', ['-R', 'u+rwx', docs.path]);
      docs.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<List<String>> stored(List<String> paths) async => paths;

  File write(String rel, {int bytes = 3}) {
    final f = File(p.join(docs.path, rel));
    f.writeAsBytesSync(List.filled(bytes, 0x41));
    return f;
  }

  test('empty photos directory yields no candidates', () async {
    final r = await scanOrphanPhotos(
      storedRelativePaths: () => stored([]),
      sessionCutoff: future,
    );
    expect(r.supported, isTrue);
    expect(r.aborted, isFalse);
    expect(r.candidates, isEmpty);
  });

  test('a true orphan is detected with its exact size', () async {
    write('photos/orphan.jpg', bytes: 7);
    final r = await scanOrphanPhotos(
      storedRelativePaths: () => stored([]),
      sessionCutoff: future,
    );
    expect(r.candidates.map((c) => c.relativePath), ['photos/orphan.jpg']);
    expect(r.candidates.single.byteSize, 7);
    expect(r.totalBytes, 7);
  });

  test('a referenced (cover/gallery/evidence) path is protected', () async {
    write('photos/cover.jpg', bytes: 5);
    write('photos/gallery.jpg', bytes: 5);
    write('photos/evidence.jpg', bytes: 5);
    write('photos/orphan.jpg', bytes: 9);
    final r = await scanOrphanPhotos(
      storedRelativePaths: () => stored([
        'photos/cover.jpg',
        'photos/gallery.jpg',
        'photos/evidence.jpg',
      ]),
      sessionCutoff: future,
    );
    expect(r.candidates.map((c) => c.relativePath), ['photos/orphan.jpg']);
  });

  test(
    'a file mapped by any Files row is protected even if it looks unused',
    () async {
      // The DB has a row for it; even without a possession we never delete it.
      write('photos/kept.jpg');
      final r = await scanOrphanPhotos(
        storedRelativePaths: () => stored(['photos/kept.jpg']),
        sessionCutoff: future,
      );
      expect(r.candidates, isEmpty);
    },
  );

  test('a current-session file (mtime >= cutoff) is excluded', () async {
    write('photos/fresh.jpg');
    // Cutoff in the past → the just-written file is "this session".
    final past = DateTime.now().subtract(const Duration(days: 1));
    final r = await scanOrphanPhotos(
      storedRelativePaths: () => stored([]),
      sessionCutoff: past,
    );
    expect(r.candidates, isEmpty);
  });

  test('an unsafe stored relativePath aborts the scan', () async {
    write('photos/orphan.jpg');
    final r = await scanOrphanPhotos(
      storedRelativePaths: () => stored(['../escape.jpg']),
      sessionCutoff: future,
    );
    expect(r.aborted, isTrue);
    expect(r.candidates, isEmpty);
  });

  test('a subdirectory is never a candidate', () async {
    Directory(p.join(photos.path, 'sub')).createSync();
    write('photos/sub/inside.jpg');
    final r = await scanOrphanPhotos(
      storedRelativePaths: () => stored([]),
      sessionCutoff: future,
    );
    // The directory entry is skipped; the nested file is not listed at top level.
    expect(r.candidates, isEmpty);
  });

  test(
    'a symlink entry is skipped, never followed or deleted',
    () async {
      final target = write('photos/real_target.jpg');
      Link(p.join(photos.path, 'link.jpg')).createSync(target.path);
      // real_target is referenced so only the link could tempt us.
      final r = await scanOrphanPhotos(
        storedRelativePaths: () => stored(['photos/real_target.jpg']),
        sessionCutoff: future,
      );
      expect(r.candidates, isEmpty);
      // The link must still be on disk after a delete pass over any candidates.
      expect(
        FileSystemEntity.isLinkSync(p.join(photos.path, 'link.jpg')),
        isTrue,
      );
    },
    skip: _runningAsRoot ? 'symlink perms differ under root' : false,
  );

  test('M9: a documents/ orphan is scanned and reclaimed; a referenced '
      'document is protected', () async {
    Directory(p.join(docs.path, 'documents')).createSync(recursive: true);
    write('documents/ricevuta.pdf', bytes: 8); // orphan
    write('documents/kept.pdf', bytes: 6); // referenced below
    final scan = await scanOrphanPhotos(
      storedRelativePaths: () => stored(['documents/kept.pdf']),
      sessionCutoff: future,
    );
    expect(scan.candidates.map((c) => c.relativePath), [
      'documents/ricevuta.pdf',
    ]);
    final report = await deleteOrphans(
      candidates: scan.candidates,
      storedRelativePaths: () => stored(['documents/kept.pdf']),
      sessionCutoff: future,
    );
    expect(report.deleted, 1);
    expect(report.reclaimedBytes, 8);
    expect(
      File(p.join(docs.path, 'documents/ricevuta.pdf')).existsSync(),
      isFalse,
    );
    expect(File(p.join(docs.path, 'documents/kept.pdf')).existsSync(), isTrue);
  });

  test('deletes the true orphan and reports exact reclaimed bytes', () async {
    write('photos/orphan.jpg', bytes: 11);
    final scan = await scanOrphanPhotos(
      storedRelativePaths: () => stored([]),
      sessionCutoff: future,
    );
    final report = await deleteOrphans(
      candidates: scan.candidates,
      storedRelativePaths: () => stored([]),
      sessionCutoff: future,
    );
    expect(report.deleted, 1);
    expect(report.reclaimedBytes, 11);
    expect(report.hasFailures, isFalse);
    expect(File(p.join(docs.path, 'photos/orphan.jpg')).existsSync(), isFalse);
  });

  test(
    'a reference appearing between scan and delete preserves the file',
    () async {
      write('photos/orphan.jpg', bytes: 4);
      final scan = await scanOrphanPhotos(
        storedRelativePaths: () => stored([]),
        sessionCutoff: future,
      );
      expect(scan.candidates, isNotEmpty);
      // Now the DB references it → deletion must preserve it.
      final report = await deleteOrphans(
        candidates: scan.candidates,
        storedRelativePaths: () => stored(['photos/orphan.jpg']),
        sessionCutoff: future,
      );
      expect(report.deleted, 0);
      expect(report.preserved, 1);
      expect(File(p.join(docs.path, 'photos/orphan.jpg')).existsSync(), isTrue);
    },
  );

  test(
    'a file modified after the cutoff is preserved at delete time',
    () async {
      write('photos/orphan.jpg', bytes: 4);
      final farFuture = DateTime.now().add(const Duration(days: 2));
      final scan = await scanOrphanPhotos(
        storedRelativePaths: () => stored([]),
        sessionCutoff: farFuture,
      );
      expect(scan.candidates, isNotEmpty);
      // Delete with a cutoff now in the past → the file is "this session".
      final past = DateTime.now().subtract(const Duration(days: 1));
      final report = await deleteOrphans(
        candidates: scan.candidates,
        storedRelativePaths: () => stored([]),
        sessionCutoff: past,
      );
      expect(report.preserved, 1);
      expect(report.deleted, 0);
      expect(File(p.join(docs.path, 'photos/orphan.jpg')).existsSync(), isTrue);
    },
  );

  test(
    'a missing candidate is harmless and not counted as reclaimed',
    () async {
      final report = await deleteOrphans(
        candidates: const [
          OrphanCandidate(relativePath: 'photos/gone.jpg', byteSize: 5),
        ],
        storedRelativePaths: () => stored([]),
        sessionCutoff: future,
      );
      expect(report.missing, 1);
      expect(report.deleted, 0);
      expect(report.reclaimedBytes, 0);
    },
  );

  test(
    'a duplicate candidate path is never double-counted or double-deleted',
    () async {
      write('photos/orphan.jpg', bytes: 6);
      final report = await deleteOrphans(
        candidates: const [
          OrphanCandidate(relativePath: 'photos/orphan.jpg', byteSize: 6),
          OrphanCandidate(relativePath: 'photos/orphan.jpg', byteSize: 6),
        ],
        storedRelativePaths: () => stored([]),
        sessionCutoff: future,
      );
      expect(report.deleted, 1);
      expect(report.preserved, 1); // the duplicate was skipped, not re-deleted
      expect(report.reclaimedBytes, 6);
    },
  );

  test('an unsafe candidate path is preserved, never resolved', () async {
    final report = await deleteOrphans(
      candidates: const [
        OrphanCandidate(relativePath: '../secret.jpg', byteSize: 5),
      ],
      storedRelativePaths: () => stored([]),
      sessionCutoff: future,
    );
    expect(report.preserved, 1);
    expect(report.deleted, 0);
  });

  test(
    'a delete failure is recorded and does not stop the rest',
    () async {
      write('photos/a.jpg', bytes: 3);
      write('photos/b.jpg', bytes: 3);
      // Lock a.jpg's deletion by making the photos dir read-only after scanning.
      final scan = await scanOrphanPhotos(
        storedRelativePaths: () => stored([]),
        sessionCutoff: future,
      );
      Process.runSync('chmod', ['0555', photos.path]);
      final report = await deleteOrphans(
        candidates: scan.candidates,
        storedRelativePaths: () => stored([]),
        sessionCutoff: future,
      );
      Process.runSync('chmod', ['0755', photos.path]);
      expect(
        report.failed,
        2,
      ); // both fail (dir not writable) but the pass finishes
      expect(report.hasFailures, isTrue);
      expect(report.failedPaths.length, 2);
    },
    skip: _runningAsRoot ? 'chmod does not restrict root' : false,
  );

  test('repeated cleanup is idempotent (second pass finds nothing)', () async {
    write('photos/orphan.jpg', bytes: 8);
    final scan1 = await scanOrphanPhotos(
      storedRelativePaths: () => stored([]),
      sessionCutoff: future,
    );
    await deleteOrphans(
      candidates: scan1.candidates,
      storedRelativePaths: () => stored([]),
      sessionCutoff: future,
    );
    final scan2 = await scanOrphanPhotos(
      storedRelativePaths: () => stored([]),
      sessionCutoff: future,
    );
    expect(scan2.candidates, isEmpty);
  });
}
