import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/database/tables/enums.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('createPossession stores a title-only possession, defaulting to active',
      () async {
    final created = await db.possessionsDao.createPossession(title: 'Dishwasher');

    expect(created.title, 'Dishwasher');
    expect(created.status, PossessionStatus.active);
    expect(created.category, isNull);
    expect(created.deletedAt, isNull);
  });

  test('watchAll emits newly created possessions, newest first', () async {
    final dao = db.possessionsDao;

    expect(await dao.watchAll().first, isEmpty);

    await dao.createPossession(title: 'First');
    // Ensure a distinct createdAt so the newest-first ordering is deterministic.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await dao.createPossession(title: 'Second');

    final titles = (await dao.watchAll().first).map((p) => p.title).toList();
    expect(titles, ['Second', 'First']);
  });

  test('rename updates the title', () async {
    final dao = db.possessionsDao;
    final p = await dao.createPossession(title: 'Old');
    await dao.rename(p.id, 'New');
    expect((await dao.watchById(p.id).first)!.title, 'New');
  });

  test('archiving drops from the active list but preserves the record',
      () async {
    final dao = db.possessionsDao;
    final p = await dao.createPossession(title: 'Old bike');

    await dao.setStatus(p.id, PossessionStatus.archived);
    expect(await dao.watchAll().first, isEmpty);

    final record = await dao.watchById(p.id).first;
    expect(record, isNotNull); // still there
    expect(record!.status, PossessionStatus.archived);
  });

  test('remove soft-deletes; restore brings it back to the active list',
      () async {
    final dao = db.possessionsDao;
    final p = await dao.createPossession(title: 'Kettle');

    await dao.softDelete(p.id);
    expect(await dao.watchAll().first, isEmpty);
    expect((await dao.watchById(p.id).first)!.deletedAt, isNotNull);

    await dao.restore(p.id);
    final list = await dao.watchAll().first;
    expect(list.map((e) => e.title), ['Kettle']);
    expect((await dao.watchById(p.id).first)!.deletedAt, isNull);
  });

  test('setCover registers a file and points the possession at it', () async {
    final dao = db.possessionsDao;
    final p = await dao.createPossession(title: 'Camera');

    await dao.setCover(p.id,
        relativePath: 'photos/x.jpg', mimeType: 'image/jpeg', byteSize: 1234);

    final cover = (await dao.watchById(p.id).first)!.coverFileId;
    expect(cover, isNotNull);
    final file = await dao.watchFile(cover!).first;
    expect(file!.relativePath, 'photos/x.jpg');
    expect(file.byteSize, 1234);
  });
}
