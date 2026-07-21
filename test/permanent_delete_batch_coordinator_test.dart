import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/features/possessions/application/permanent_delete.dart';
import 'package:project_kobe/features/possessions/application/permanent_delete_result.dart';

/// M8.2B — the batch coordinator core [runPermanentDeleteMany]: guards → the
/// atomic batch DB phase → the post-commit filesystem cleanup, mapped to one
/// observed [PermanentDeleteResult].
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
    docs = Directory.systemTemp.createTempSync('pole2_pdb_');
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

  Future<String> removedWithCover(String title, String rel) async {
    final dao = db.possessionsDao;
    final pos = await dao.createPossession(title: title);
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

  test('deletes all selected and reclaims their files', () async {
    final a = await removedWithCover('A', 'photos/a.jpg');
    final b = await removedWithCover('B', 'photos/b.jpg');
    final r = await runPermanentDeleteMany(dao: db.possessionsDao, ids: [a, b]);
    expect(r.status, PermanentDeleteStatus.deleted);
    expect(r.cleanup!.deleted, 2);
    expect(await db.possessionsDao.watchById(a).first, isNull);
    expect(await db.possessionsDao.watchById(b).first, isNull);
    expect(File(p.join(docs.path, 'photos/a.jpg')).existsSync(), isFalse);
    expect(File(p.join(docs.path, 'photos/b.jpg')).existsSync(), isFalse);
  });

  test(
    'a stale selection changes nothing and reports staleSelection',
    () async {
      final a = await removedWithCover('A', 'photos/a.jpg');
      final b = await removedWithCover('B', 'photos/b.jpg');
      await db.possessionsDao.restoreRemoved(b); // b no longer removed
      final r = await runPermanentDeleteMany(
        dao: db.possessionsDao,
        ids: [a, b],
      );
      expect(r.status, PermanentDeleteStatus.staleSelection);
      expect(await db.possessionsDao.watchById(a).first, isNotNull);
      expect(File(p.join(docs.path, 'photos/a.jpg')).existsSync(), isTrue);
    },
  );

  test('a running backup blocks the batch and changes nothing', () async {
    final a = await removedWithCover('A', 'photos/a.jpg');
    final r = await runPermanentDeleteMany(
      dao: db.possessionsDao,
      ids: [a],
      blockedByBackup: true,
    );
    expect(r.status, PermanentDeleteStatus.blockedByBackup);
    expect(await db.possessionsDao.watchById(a).first, isNotNull);
  });

  test('a pending restore blocks the batch and changes nothing', () async {
    final a = await removedWithCover('A', 'photos/a.jpg');
    final r = await runPermanentDeleteMany(
      dao: db.possessionsDao,
      ids: [a],
      blockedByRestore: true,
    );
    expect(r.status, PermanentDeleteStatus.blockedByRestore);
    expect(await db.possessionsDao.watchById(a).first, isNotNull);
  });

  test(
    'a failed file cleanup still deletes the rows (pending cleanup)',
    () async {
      final a = await removedWithCover('A', 'photos/a.jpg');
      final photosDir = p.join(docs.path, 'photos');
      Process.runSync('chmod', ['0555', photosDir]);
      final r = await runPermanentDeleteMany(dao: db.possessionsDao, ids: [a]);
      Process.runSync('chmod', ['0755', photosDir]);
      expect(r.status, PermanentDeleteStatus.deletedWithPendingFileCleanup);
      expect(r.cleanup!.failed, 1);
      expect(await db.possessionsDao.watchById(a).first, isNull);
      expect(File(p.join(docs.path, 'photos/a.jpg')).existsSync(), isTrue);
    },
    skip: _runningAsRoot ? 'chmod does not restrict root' : false,
  );
}
