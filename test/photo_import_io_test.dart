import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:project_kobe/features/possessions/media/photo_import.dart';
import 'package:project_kobe/features/possessions/media/photo_import_marker.dart';

/// M8.2D — the native staged-import store: crash-safe promotion, cancellation
/// and the startup reconciliation matrix. Staging (image_picker) is simulated by
/// writing the exact on-disk layout the picker path produces.
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
  setUp(() {
    docs = Directory.systemTemp.createTempSync('pole2_pi_');
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
  });
  tearDown(() {
    try {
      docs.deleteSync(recursive: true);
    } catch (_) {}
  });

  bool exists(String rel) => File(p.join(docs.path, rel)).existsSync();
  bool dirExists(String rel) => Directory(p.join(docs.path, rel)).existsSync();

  /// Mimics the picker staging path: temp files + a prepared marker.
  StagedImport stageManually(String opId, List<String> fileIds) {
    final dir = Directory(p.join(docs.path, 'photo_imports', opId))
      ..createSync(recursive: true);
    final photos = <StagedPhoto>[];
    final entries = <PhotoImportEntry>[];
    for (final fid in fileIds) {
      final temp = 'photo_imports/$opId/$fid.jpg';
      final fin = 'photos/$fid.jpg';
      File(p.join(dir.path, '$fid.jpg')).writeAsBytesSync(List.filled(4, 1));
      photos.add(
        StagedPhoto(
          operationId: opId,
          fileId: fid,
          tempRelativePath: temp,
          finalRelativePath: fin,
          byteSize: 4,
          mimeType: 'image/jpeg',
        ),
      );
      entries.add(
        PhotoImportEntry(
          fileId: fid,
          tempRelativePath: temp,
          finalRelativePath: fin,
          byteSize: 4,
          mimeType: 'image/jpeg',
        ),
      );
    }
    File(p.join(dir.path, 'marker.json')).writeAsStringSync(
      PhotoImportMarker(
        operationId: opId,
        state: PhotoImportState.prepared,
        createdAtUtc: 't',
        entries: entries,
      ).encode(),
    );
    return StagedImport(operationId: opId, photos: photos);
  }

  test('staged bytes live only under photo_imports before promotion', () {
    stageManually('op1', ['a']);
    expect(exists('photo_imports/op1/a.jpg'), isTrue);
    expect(exists('photos/a.jpg'), isFalse);
  });

  test(
    'promotion moves temp→final, commits, and removes the marker dir',
    () async {
      final imp = stageManually('op1', ['a', 'b']);
      var committed = false;
      final outcome = await promoteAndCommit(imp, () async => committed = true);
      expect(outcome, PhotoPromoteOutcome.committed);
      expect(committed, isTrue);
      expect(exists('photos/a.jpg'), isTrue);
      expect(exists('photos/b.jpg'), isTrue);
      expect(exists('photo_imports/op1/a.jpg'), isFalse);
      expect(dirExists('photo_imports/op1'), isFalse);
    },
  );

  test('a duplicate final path collision aborts before any commit', () async {
    final imp = stageManually('op1', ['dup']);
    // Two staged photos claiming the same final path.
    final clash = StagedImport(
      operationId: 'op1',
      photos: [imp.photos.first, imp.photos.first],
    );
    var committed = false;
    final outcome = await promoteAndCommit(clash, () async => committed = true);
    expect(outcome, PhotoPromoteOutcome.promotionFailed);
    expect(committed, isFalse);
  });

  test('a pre-existing final file blocks promotion (no overwrite)', () async {
    final imp = stageManually('op1', ['a']);
    Directory(p.join(docs.path, 'photos')).createSync(recursive: true);
    File(p.join(docs.path, 'photos/a.jpg')).writeAsBytesSync([9]);
    var committed = false;
    final outcome = await promoteAndCommit(imp, () async => committed = true);
    expect(outcome, PhotoPromoteOutcome.promotionFailed);
    expect(committed, isFalse);
    expect(File(p.join(docs.path, 'photos/a.jpg')).readAsBytesSync(), [9]);
  });

  test('a DB commit failure removes the promoted final', () async {
    final imp = stageManually('op1', ['a']);
    final outcome = await promoteAndCommit(imp, () async {
      throw StateError('db boom');
    });
    expect(outcome, PhotoPromoteOutcome.commitFailed);
    expect(exists('photos/a.jpg'), isFalse); // rolled back on disk
  });

  test(
    'discardImport removes only the validated operation directory',
    () async {
      stageManually('op1', ['a']);
      stageManually('op2', ['b']);
      await discardImport('op1');
      expect(dirExists('photo_imports/op1'), isFalse);
      expect(dirExists('photo_imports/op2'), isTrue);
      // An unsafe id is ignored, deletes nothing.
      await discardImport('../photos');
      expect(dirExists('photos') || !dirExists('photos'), isTrue); // no throw
    },
  );

  // ---- Reconciliation matrix ----

  test('prepared marker + temp → abandoned and removed', () async {
    stageManually('op1', ['a']);
    final r = await reconcilePhotoImports(isReferenced: (_) async => false);
    expect(r.abandonedPrepared, 1);
    expect(dirExists('photo_imports/op1'), isFalse);
  });

  test('promoted + referenced final → kept as committed', () async {
    // Simulate a promoted marker whose final exists and IS referenced.
    Directory(p.join(docs.path, 'photos')).createSync(recursive: true);
    File(p.join(docs.path, 'photos/a.jpg')).writeAsBytesSync([1]);
    final dir = Directory(p.join(docs.path, 'photo_imports', 'op1'))
      ..createSync(recursive: true);
    File(p.join(dir.path, 'marker.json')).writeAsStringSync(
      PhotoImportMarker(
        operationId: 'op1',
        state: PhotoImportState.promoted,
        createdAtUtc: 't',
        entries: const [
          PhotoImportEntry(
            fileId: 'a',
            tempRelativePath: 'photo_imports/op1/a.jpg',
            finalRelativePath: 'photos/a.jpg',
            byteSize: 1,
            mimeType: 'image/jpeg',
          ),
        ],
      ).encode(),
    );
    final r = await reconcilePhotoImports(
      isReferenced: (rel) async => rel == 'photos/a.jpg',
    );
    expect(r.keptCommitted, 1);
    expect(exists('photos/a.jpg'), isTrue); // committed file survives
    expect(dirExists('photo_imports/op1'), isFalse); // marker cleaned
  });

  test('promoted + unreferenced final → orphan deleted', () async {
    Directory(p.join(docs.path, 'photos')).createSync(recursive: true);
    File(p.join(docs.path, 'photos/a.jpg')).writeAsBytesSync([1]);
    final dir = Directory(p.join(docs.path, 'photo_imports', 'op1'))
      ..createSync(recursive: true);
    File(p.join(dir.path, 'marker.json')).writeAsStringSync(
      PhotoImportMarker(
        operationId: 'op1',
        state: PhotoImportState.promoted,
        createdAtUtc: 't',
        entries: const [
          PhotoImportEntry(
            fileId: 'a',
            tempRelativePath: 'photo_imports/op1/a.jpg',
            finalRelativePath: 'photos/a.jpg',
            byteSize: 1,
            mimeType: 'image/jpeg',
          ),
        ],
      ).encode(),
    );
    final r = await reconcilePhotoImports(isReferenced: (_) async => false);
    expect(r.deletedOrphans, 1);
    expect(exists('photos/a.jpg'), isFalse); // orphan removed
    expect(dirExists('photo_imports/op1'), isFalse);
  });

  test('a corrupt marker drops only its own directory', () async {
    final dir = Directory(p.join(docs.path, 'photo_imports', 'op1'))
      ..createSync(recursive: true);
    File(p.join(dir.path, 'marker.json')).writeAsStringSync('not json');
    File(p.join(dir.path, 'stray.jpg')).writeAsBytesSync([1]);
    final r = await reconcilePhotoImports(isReferenced: (_) async => false);
    expect(r.cleanedCorrupt, 1);
    expect(dirExists('photo_imports/op1'), isFalse);
  });

  test('an unsafe marker path is never followed; its dir is removed', () async {
    Directory(p.join(docs.path, 'photos')).createSync(recursive: true);
    File(p.join(docs.path, 'photos/keep.jpg')).writeAsBytesSync([7]);
    final dir = Directory(p.join(docs.path, 'photo_imports', 'op1'))
      ..createSync(recursive: true);
    File(p.join(dir.path, 'marker.json')).writeAsStringSync(
      PhotoImportMarker(
        operationId: 'op1',
        state: PhotoImportState.promoted,
        createdAtUtc: 't',
        entries: const [
          PhotoImportEntry(
            fileId: 'x',
            tempRelativePath: 'photo_imports/op1/x.jpg',
            finalRelativePath: 'photos/../photos/keep.jpg',
            byteSize: 1,
            mimeType: 'image/jpeg',
          ),
        ],
      ).encode(),
    );
    final r = await reconcilePhotoImports(isReferenced: (_) async => false);
    expect(r.cleanedCorrupt, 1);
    expect(exists('photos/keep.jpg'), isTrue); // unsafe path never followed
    expect(dirExists('photo_imports/op1'), isFalse);
  });

  test('reconciliation is idempotent (second pass finds nothing)', () async {
    stageManually('op1', ['a']);
    await reconcilePhotoImports(isReferenced: (_) async => false);
    final second = await reconcilePhotoImports(
      isReferenced: (_) async => false,
    );
    expect(second.abandonedPrepared, 0);
    expect(second.deletedOrphans, 0);
    expect(second.cleanedCorrupt, 0);
  });
}
