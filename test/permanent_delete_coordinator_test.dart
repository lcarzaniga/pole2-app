import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/features/possessions/application/permanent_delete.dart';
import 'package:project_kobe/features/possessions/application/permanent_delete_result.dart';

/// M8.2A — the coordinator core [runPermanentDelete]: guards → the transactional
/// database phase → the post-commit filesystem cleanup, mapped to one observed
/// [PermanentDeleteResult]. Exercises real Drift + `dart:io`; kept WidgetRef-free
/// so it runs as a plain async test (the thin provider wrapper is trivial glue).
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

  late AppDatabase db;
  late Directory docs;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    docs = Directory.systemTemp.createTempSync('pole2_pdc_');
    Directory(p.join(docs.path, 'photos')).createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProvider(docs.path);
  });
  tearDown(() async {
    await db.close();
    try {
      Process.runSync('chmod', ['-R', 'u+rwx', docs.path]);
      docs.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<String> removedWithCover(String rel) async {
    final dao = db.possessionsDao;
    final pos = await dao.createPossession(title: 'Trapano');
    await dao.setCover(
      pos.id,
      relativePath: rel,
      mimeType: 'image/jpeg',
      byteSize: 1,
    );
    File(p.join(docs.path, rel)).writeAsStringSync('bytes');
    await dao.softDelete(pos.id);
    return pos.id;
  }

  test('a removed possession is deleted and its file reclaimed', () async {
    final id = await removedWithCover('photos/a.jpg');
    final r = await runPermanentDelete(dao: db.possessionsDao, id: id);
    expect(r.status, PermanentDeleteStatus.deleted);
    expect(r.cleanup!.deleted, 1);
    expect(await db.possessionsDao.watchById(id).first, isNull);
    expect(File(p.join(docs.path, 'photos/a.jpg')).existsSync(), isFalse);
  });

  test('a second call for the same id is idempotent (notFound)', () async {
    final id = await removedWithCover('photos/a.jpg');
    final first = await runPermanentDelete(dao: db.possessionsDao, id: id);
    expect(first.status, PermanentDeleteStatus.deleted);
    final second = await runPermanentDelete(dao: db.possessionsDao, id: id);
    expect(second.status, PermanentDeleteStatus.notFound);
  });

  test('an active (non-removed) possession is rejected', () async {
    final pos = await db.possessionsDao.createPossession(title: 'Live');
    final r = await runPermanentDelete(dao: db.possessionsDao, id: pos.id);
    expect(r.status, PermanentDeleteStatus.rejectedNotRemoved);
    expect(await db.possessionsDao.watchById(pos.id).first, isNotNull);
  });

  test('a pending restore blocks deletion and changes nothing', () async {
    final id = await removedWithCover('photos/a.jpg');
    final r = await runPermanentDelete(
      dao: db.possessionsDao,
      id: id,
      blockedByRestore: true,
    );
    expect(r.status, PermanentDeleteStatus.blockedByRestore);
    expect(await db.possessionsDao.watchById(id).first, isNotNull);
    expect(File(p.join(docs.path, 'photos/a.jpg')).existsSync(), isTrue);
  });

  test('a running backup blocks deletion and changes nothing', () async {
    final id = await removedWithCover('photos/a.jpg');
    final r = await runPermanentDelete(
      dao: db.possessionsDao,
      id: id,
      blockedByBackup: true,
    );
    expect(r.status, PermanentDeleteStatus.blockedByBackup);
    expect(await db.possessionsDao.watchById(id).first, isNotNull);
  });

  test('restore block takes priority over a backup block', () async {
    final id = await removedWithCover('photos/a.jpg');
    final r = await runPermanentDelete(
      dao: db.possessionsDao,
      id: id,
      blockedByRestore: true,
      blockedByBackup: true,
    );
    expect(r.status, PermanentDeleteStatus.blockedByRestore);
  });

  test(
    'a failed file cleanup still deletes the rows (pending cleanup)',
    () async {
      final id = await removedWithCover('photos/a.jpg');
      final photosDir = p.join(docs.path, 'photos');
      Process.runSync('chmod', ['0555', photosDir]);
      final r = await runPermanentDelete(dao: db.possessionsDao, id: id);
      Process.runSync('chmod', ['0755', photosDir]);
      expect(r.status, PermanentDeleteStatus.deletedWithPendingFileCleanup);
      expect(r.cleanup!.failed, 1);
      // Rows are gone regardless; only the bytes lingered.
      expect(await db.possessionsDao.watchById(id).first, isNull);
      expect(File(p.join(docs.path, 'photos/a.jpg')).existsSync(), isTrue);
    },
    skip: _runningAsRoot ? 'chmod does not restrict root' : false,
  );
}
