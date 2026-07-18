import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> newPossession() async =>
      (await db.possessionsDao.createPossession(title: 'Camera')).id;

  Future<String?> coverOf(String id) async =>
      (await db.possessionsDao.watchById(id).first)!.coverFileId;

  int photoCount(List photos) => photos.length;

  Future add(String id, {bool asCover = false}) => db.possessionsDao.addPhoto(
    id,
    relativePath: 'photos/${DateTime.now().microsecondsSinceEpoch}.jpg',
    mimeType: 'image/jpeg',
    byteSize: 1,
    asCover: asCover,
  );

  test('a possession starts with zero photos and no cover', () async {
    final id = await newPossession();
    expect(photoCount(await db.possessionsDao.watchPhotos(id).first), 0);
    expect(await coverOf(id), isNull);
  });

  test('the first photo automatically becomes the cover', () async {
    final id = await newPossession();
    final p = await add(id);
    expect(photoCount(await db.possessionsDao.watchPhotos(id).first), 1);
    expect(await coverOf(id), p.fileId);
  });

  test('an additional photo does not replace the current cover', () async {
    final id = await newPossession();
    final first = await add(id);
    final second = await add(id);
    expect(photoCount(await db.possessionsDao.watchPhotos(id).first), 2);
    expect(await coverOf(id), first.fileId);
    expect(await coverOf(id), isNot(second.fileId));
  });

  test(
    'only one photo is ever the cover; setting another switches it',
    () async {
      final id = await newPossession();
      final first = await add(id);
      final second = await add(id);
      await db.possessionsDao.setCoverPhoto(id, second.fileId);
      expect(await coverOf(id), second.fileId);
      // The old cover remains a normal gallery photo (demoted, not removed).
      final photos = await db.possessionsDao.watchPhotos(id).first;
      expect(
        photos.map((p) => p.file.id),
        containsAll([first.fileId, second.fileId]),
      );
    },
  );

  test(
    'setCoverPhoto ignores a file that is not this possession\'s photo',
    () async {
      final a = await newPossession();
      final b = await newPossession();
      final aPhoto = await add(a);
      final bPhoto = await add(b);
      await db.possessionsDao.setCoverPhoto(a, bPhoto.fileId);
      expect(await coverOf(a), aPhoto.fileId); // unchanged
    },
  );

  test('replacing the cover (addPhoto asCover) promotes the new one', () async {
    final id = await newPossession();
    final first = await add(id);
    final replacement = await add(id, asCover: true);
    expect(await coverOf(id), replacement.fileId);
    // The previous cover is still in the gallery, not orphaned.
    final photos = await db.possessionsDao.watchPhotos(id).first;
    expect(photos.map((p) => p.file.id), contains(first.fileId));
  });

  test('removing a non-cover preserves the cover', () async {
    final id = await newPossession();
    final cover = await add(id);
    final extra = await add(id);
    await db.possessionsDao.removePhoto(id, extra.id);
    expect(await coverOf(id), cover.fileId);
    expect(photoCount(await db.possessionsDao.watchPhotos(id).first), 1);
  });

  test('removing the cover selects the deterministic replacement', () async {
    final id = await newPossession();
    final first = await add(id); // sortOrder 0
    final second = await add(id); // sortOrder 1
    await db.possessionsDao.setCoverPhoto(id, second.fileId);
    // Remove the cover (second) → the earliest remaining (first) takes over.
    await db.possessionsDao.removePhoto(id, second.id);
    expect(await coverOf(id), first.fileId);
  });

  test('removing the final photo returns to the empty-cover state', () async {
    final id = await newPossession();
    final only = await add(id);
    await db.possessionsDao.removePhoto(id, only.id);
    expect(await coverOf(id), isNull);
    expect(photoCount(await db.possessionsDao.watchPhotos(id).first), 0);
  });

  test('soft-removed photos are excluded from the gallery', () async {
    final id = await newPossession();
    final a = await add(id);
    await add(id);
    await db.possessionsDao.removePhoto(id, a.id);
    final photos = await db.possessionsDao.watchPhotos(id).first;
    expect(photos.any((p) => p.photo.id == a.id), isFalse);
    expect(photoCount(photos), 1);
  });

  test('restorePhoto undoes a removal, optionally as cover again', () async {
    final id = await newPossession();
    final cover = await add(id);
    final extra = await add(id);
    await db.possessionsDao.setCoverPhoto(id, cover.fileId);
    // Remove the cover → extra becomes cover.
    await db.possessionsDao.removePhoto(id, cover.id);
    expect(await coverOf(id), extra.fileId);
    // Undo as cover → back to exactly the prior state.
    await db.possessionsDao.restorePhoto(id, cover.id, asCover: true);
    expect(await coverOf(id), cover.fileId);
    expect(photoCount(await db.possessionsDao.watchPhotos(id).first), 2);
  });

  test('photos are ordered deterministically by insertion', () async {
    final id = await newPossession();
    final a = await add(id);
    final b = await add(id);
    final c = await add(id);
    final photos = await db.possessionsDao.watchPhotos(id).first;
    expect(photos.map((p) => p.photo.id).toList(), [a.id, b.id, c.id]);
  });

  test('a possession never shows another possession\'s photos', () async {
    final a = await newPossession();
    final b = await newPossession();
    await add(a);
    final bPhoto = await add(b);
    final aPhotos = await db.possessionsDao.watchPhotos(a).first;
    expect(aPhotos.any((p) => p.photo.id == bPhoto.id), isFalse);
    expect(photoCount(aPhotos), 1);
  });

  test(
    'addPhotos inserts a batch in order; first is cover only if none',
    () async {
      final id = await newPossession();
      final existing = await add(id); // becomes cover
      await db.possessionsDao.addPhotos(id, [
        (relativePath: 'photos/x.jpg', mimeType: 'image/jpeg', byteSize: 1),
        (relativePath: 'photos/y.jpg', mimeType: 'image/jpeg', byteSize: 1),
      ]);
      final photos = await db.possessionsDao.watchPhotos(id).first;
      expect(photoCount(photos), 3);
      // Cover unchanged — the batch did not steal it.
      expect(await coverOf(id), existing.fileId);
      // Batch preserved order after the existing photo.
      expect(photos.map((p) => p.file.relativePath).skip(1).toList(), [
        'photos/x.jpg',
        'photos/y.jpg',
      ]);
    },
  );

  test('a batch on an empty gallery makes the first photo the cover', () async {
    final id = await newPossession();
    await db.possessionsDao.addPhotos(id, [
      (relativePath: 'photos/x.jpg', mimeType: 'image/jpeg', byteSize: 1),
      (relativePath: 'photos/y.jpg', mimeType: 'image/jpeg', byteSize: 1),
    ]);
    final photos = await db.possessionsDao.watchPhotos(id).first;
    expect(await coverOf(id), photos.first.file.id);
  });
}
