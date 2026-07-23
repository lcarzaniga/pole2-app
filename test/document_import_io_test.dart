import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:project_kobe/features/possessions/media/document_pick.dart';
import 'package:project_kobe/features/possessions/media/photo_import.dart';

/// M9 — staging a SAF-copied local document through the shared staged-import
/// lifecycle into the `documents/` managed root: crash-safe promotion, rollback,
/// and reconciliation, plus display-name safety.
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
    docs = Directory.systemTemp.createTempSync('pole2_doc_');
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
  });
  tearDown(() {
    try {
      docs.deleteSync(recursive: true);
    } catch (_) {}
  });

  bool exists(String rel) => File(p.join(docs.path, rel)).existsSync();
  bool dirExists(String rel) => Directory(p.join(docs.path, rel)).existsSync();

  /// Writes a fake SAF-copied temp file in the app cache and returns its path.
  String fakeCopiedFile(String name, List<int> bytes) {
    final dir = Directory(p.join(docs.path, 'doc_pick'))
      ..createSync(recursive: true);
    final f = File(p.join(dir.path, name))..writeAsBytesSync(bytes);
    return f.path;
  }

  test(
    'stageLocalFile stages under photo_imports with a documents/ final',
    () async {
      final src = fakeCopiedFile('scan.pdf', [1, 2, 3, 4]);
      final staged = await stageLocalFile(
        src,
        finalRoot: 'documents',
        mimeType: 'application/pdf',
      );
      expect(staged.photos, hasLength(1));
      final d = staged.photos.single;
      expect(d.finalRelativePath, startsWith('documents/'));
      expect(d.finalRelativePath, endsWith('.pdf'));
      expect(
        d.tempRelativePath,
        startsWith('photo_imports/${staged.operationId}/'),
      );
      expect(d.byteSize, 4);
      // Bytes live only in staging before promotion; the source was consumed.
      expect(File(src).existsSync(), isFalse);
      expect(exists(d.tempRelativePath), isTrue);
      expect(exists(d.finalRelativePath), isFalse);
    },
  );

  test('stageLocalFiles stages several attachments into ONE operation and '
      'promoteAndCommit moves them all', () async {
    final srcs = [
      LocalFileToStage(
        srcPath: fakeCopiedFile('a.pdf', [1]),
        mimeType: 'application/pdf',
      ),
      LocalFileToStage(
        srcPath: fakeCopiedFile('b.jpg', [2, 2]),
        mimeType: 'image/jpeg',
      ),
      LocalFileToStage(
        srcPath: fakeCopiedFile('c.txt', [3, 3, 3]),
        mimeType: 'text/plain',
      ),
    ];
    final staged = await stageLocalFiles(srcs, finalRoot: 'documents');
    expect(staged.photos, hasLength(3));
    expect(staged.photos.map((ph) => ph.operationId).toSet(), hasLength(1));
    for (final ph in staged.photos) {
      expect(ph.finalRelativePath, startsWith('documents/'));
      expect(exists(ph.tempRelativePath), isTrue);
    }
    var committed = false;
    final outcome = await promoteAndCommit(
      staged,
      () async => committed = true,
    );
    expect(outcome, PhotoPromoteOutcome.committed);
    expect(committed, isTrue);
    for (final ph in staged.photos) {
      expect(exists(ph.finalRelativePath), isTrue);
    }
    expect(dirExists('photo_imports/${staged.operationId}'), isFalse);
  });

  test(
    'promotion moves the staged document into documents/ and commits',
    () async {
      final src = fakeCopiedFile('manual.pdf', [9, 9, 9]);
      final staged = await stageLocalFile(
        src,
        finalRoot: 'documents',
        mimeType: 'application/pdf',
      );
      final fin = staged.photos.single.finalRelativePath;
      var committed = false;
      final outcome = await promoteAndCommit(
        staged,
        () async => committed = true,
      );
      expect(outcome, PhotoPromoteOutcome.committed);
      expect(committed, isTrue);
      expect(exists(fin), isTrue);
      expect(dirExists('photo_imports/${staged.operationId}'), isFalse);
    },
  );

  test(
    'a DB commit failure rolls the promoted document back off disk',
    () async {
      final src = fakeCopiedFile('receipt.pdf', [1]);
      final staged = await stageLocalFile(
        src,
        finalRoot: 'documents',
        mimeType: 'application/pdf',
      );
      final fin = staged.photos.single.finalRelativePath;
      final outcome = await promoteAndCommit(staged, () async {
        throw StateError('db boom');
      });
      expect(outcome, PhotoPromoteOutcome.commitFailed);
      expect(exists(fin), isFalse); // no orphan on disk
    },
  );

  test('an interrupted (prepared, never promoted) document import is '
      'reconciled away', () async {
    final src = fakeCopiedFile('draft.pdf', [1, 2]);
    final staged = await stageLocalFile(
      src,
      finalRoot: 'documents',
      mimeType: 'application/pdf',
    );
    // Simulate a crash before promotion: staging dir remains.
    expect(dirExists('photo_imports/${staged.operationId}'), isTrue);
    final r = await reconcilePhotoImports(isReferenced: (_) async => false);
    expect(r.abandonedPrepared, 1);
    expect(dirExists('photo_imports/${staged.operationId}'), isFalse);
    expect(exists(staged.photos.single.finalRelativePath), isFalse);
  });

  test('M9.1: an image with an explicit ext is stored as documents/<id>.jpg '
      'regardless of the source path extension', () async {
    // image_picker temp files may carry any extension; the record flow forces
    // .jpg so the stored name agrees with the image/jpeg MIME.
    final src = fakeCopiedFile('image_picker_tmp.xyz', [1, 2, 3]);
    final staged = await stageLocalFiles([
      LocalFileToStage(srcPath: src, mimeType: 'image/jpeg', ext: '.jpg'),
    ], finalRoot: 'documents');
    final fin = staged.photos.single.finalRelativePath;
    expect(fin, startsWith('documents/'));
    expect(fin, endsWith('.jpg'));
    expect(staged.photos.single.mimeType, 'image/jpeg');
    final outcome = await promoteAndCommit(staged, () async {});
    expect(outcome, PhotoPromoteOutcome.committed);
    expect(exists(fin), isTrue);
  });

  test('sanitizeDocumentName defeats traversal and keeps a readable name', () {
    expect(sanitizeDocumentName('../../etc/passwd'), 'passwd');
    expect(sanitizeDocumentName('a/b/c.pdf'), 'c.pdf');
    expect(sanitizeDocumentName(r'C:\Users\x\Ricevuta.pdf'), 'Ricevuta.pdf');
    expect(sanitizeDocumentName('  '), 'documento');
    expect(sanitizeDocumentName(null), 'documento');
    expect(sanitizeDocumentName('..'), 'documento');
    expect(sanitizeDocumentName('report<>:"|?*.pdf'), 'report.pdf');
    // An over-long name is bounded but keeps its extension.
    final long = sanitizeDocumentName('${'x' * 300}.pdf');
    expect(long.length, lessThanOrEqualTo(120));
    expect(long, endsWith('.pdf'));
  });

  test('PickedDocument constructors carry the expected status', () {
    expect(
      const PickedDocument.cancelled().status,
      DocumentPickStatus.cancelled,
    );
    expect(
      const PickedDocument.unavailable().status,
      DocumentPickStatus.unavailable,
    );
    const picked = PickedDocument.picked(
      tempPath: '/tmp/x.pdf',
      displayName: 'x.pdf',
      mimeType: 'application/pdf',
      byteSize: 3,
    );
    expect(picked.status, DocumentPickStatus.picked);
    expect(picked.byteSize, 3);
  });
}
