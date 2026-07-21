import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';

/// M8.2D — the DAO side of promotion: committing promoted staged photos with a
/// pre-generated fileId, atomically, into Files/PossessionPhotos/cover.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> count(dynamic q) async => (await q.get()).length as int;
  fkCheck() async => db.customSelect('PRAGMA foreign_key_check').get();

  test(
    'commitStagedPhotos inserts Files, photo rows and the first cover',
    () async {
      final p = await db.possessionsDao.createPossession(title: 'Trapano');
      await db.possessionsDao.commitStagedPhotos(p.id, [
        (
          fileId: 'f1',
          relativePath: 'photos/f1.jpg',
          mimeType: 'image/jpeg',
          byteSize: 3,
          asCover: false,
        ),
        (
          fileId: 'f2',
          relativePath: 'photos/f2.jpg',
          mimeType: 'image/jpeg',
          byteSize: 3,
          asCover: false,
        ),
      ]);

      expect(await count(db.select(db.files)), 2);
      final photos = await db.possessionsDao.watchPhotos(p.id).first;
      expect(photos.map((x) => x.file.relativePath), [
        'photos/f1.jpg',
        'photos/f2.jpg',
      ]);
      // First photo became the cover (possession had none).
      final poss = await db.possessionsDao.watchById(p.id).first;
      expect(poss!.coverFileId, 'f1');
      expect(await fkCheck(), isEmpty);
    },
  );

  test('asCover promotes a specific staged photo to cover', () async {
    final p = await db.possessionsDao.createPossession(title: 'X');
    await db.possessionsDao.commitStagedPhotos(p.id, [
      (
        fileId: 'a',
        relativePath: 'photos/a.jpg',
        mimeType: 'image/jpeg',
        byteSize: 1,
        asCover: false,
      ),
    ]);
    await db.possessionsDao.commitStagedPhotos(p.id, [
      (
        fileId: 'b',
        relativePath: 'photos/b.jpg',
        mimeType: 'image/jpeg',
        byteSize: 1,
        asCover: true,
      ),
    ]);
    final poss = await db.possessionsDao.watchById(p.id).first;
    expect(poss!.coverFileId, 'b'); // explicit cover wins
  });

  test(
    'createPossessionWithCover creates possession + cover atomically',
    () async {
      final created = await db.possessionsDao.createPossessionWithCover(
        title: 'Bici',
        cover: (
          fileId: 'c1',
          relativePath: 'photos/c1.jpg',
          mimeType: 'image/jpeg',
          byteSize: 5,
        ),
      );
      final poss = await db.possessionsDao.watchById(created.id).first;
      expect(poss, isNotNull);
      expect(poss!.title, 'Bici');
      expect(poss.coverFileId, 'c1');
      expect(await count(db.select(db.files)), 1);
      final photos = await db.possessionsDao.watchPhotos(created.id).first;
      expect(photos.single.file.relativePath, 'photos/c1.jpg');
      expect(await fkCheck(), isEmpty);
    },
  );

  test(
    'createPossessionWithCover with no cover just creates the possession',
    () async {
      final created = await db.possessionsDao.createPossessionWithCover(
        title: 'Solo',
      );
      expect(await count(db.select(db.files)), 0);
      final poss = await db.possessionsDao.watchById(created.id).first;
      expect(poss!.coverFileId, isNull);
    },
  );
}
