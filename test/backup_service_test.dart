import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/database/tables/enums.dart';
import 'package:project_kobe/features/backup/application/backup_service.dart';
import 'package:project_kobe/features/backup/application/backup_validator.dart';
import 'package:project_kobe/features/backup/crypto/argon2_profile.dart';
import 'package:project_kobe/features/backup/data/backup_plan.dart';

void main() {
  late AppDatabase db;
  late Directory work;
  late Directory docs;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    work = Directory.systemTemp.createTempSync('pole2_bktmp');
    docs = Directory.systemTemp.createTempSync('pole2_bkdocs');
    Directory('${docs.path}/photos').createSync(recursive: true);
  });
  tearDown(() {
    db.close();
    work.deleteSync(recursive: true);
    docs.deleteSync(recursive: true);
  });

  // Bounds-valid but fast (the pipeline self-validates, and the validator
  // rejects sub-8-MiB KDF params).
  const fastValid = Argon2Profile(
    memoryKiB: 8 * 1024,
    iterations: 1,
    parallelism: 1,
  );

  BackupService service({Argon2Profile? profile}) => BackupService(
    db: db,
    tempDir: work,
    documentsDir: docs,
    appVersion: '1.0.11',
    versionCode: 2016,
    schemaVersion: db.schemaVersion,
    argon2: profile ?? fastValid,
  );

  void writePhoto(String rel, [int size = 32]) {
    File('${docs.path}/$rel')
      ..createSync(recursive: true)
      ..writeAsBytesSync(List<int>.filled(size, 1));
  }

  Future<void> addCover(String id, String rel) async {
    writePhoto(rel);
    await db.possessionsDao.setCover(
      id,
      relativePath: rel,
      mimeType: 'image/jpeg',
      byteSize: 32,
    );
  }

  test(
    'plaintext backup builds, self-validates, and lists referenced files',
    () async {
      final p = await db.possessionsDao.createPossession(title: 'Trapano');
      await addCover(p.id, 'photos/a.jpg');
      // an extra gallery photo
      writePhoto('photos/b.jpg');
      await db.possessionsDao.addPhoto(
        p.id,
        relativePath: 'photos/b.jpg',
        mimeType: 'image/jpeg',
        byteSize: 32,
      );

      final built = await service().build(encrypt: false);
      addTearDown(() => built.stagingDir.deleteSync(recursive: true));

      expect(built.file.existsSync(), isTrue);
      expect(built.manifest.encrypted, isFalse);
      expect(built.manifest.counts.possessions, 1);
      expect(built.manifest.files.length, 2); // cover + gallery
      expect(built.warnings, isEmpty);

      final res = await BackupValidator(
        appSchemaVersion: db.schemaVersion,
      ).validate(backup: built.file, workDir: _sub(work, 'v1'));
      expect(res.ok, isTrue);
      expect(res.schemaVersion, db.schemaVersion);
    },
  );

  test('encrypted backup round-trips through the validator', () async {
    final p = await db.possessionsDao.createPossession(title: 'Bici');
    await addCover(p.id, 'photos/x.jpg');

    final built = await service().build(
      encrypt: true,
      password: 'a-strong-passphrase',
    );
    addTearDown(() => built.stagingDir.deleteSync(recursive: true));
    expect(built.manifest.encrypted, isTrue);

    final ok = await BackupValidator(appSchemaVersion: db.schemaVersion)
        .validate(
          backup: built.file,
          password: 'a-strong-passphrase',
          workDir: _sub(work, 'v2'),
        );
    expect(ok.ok, isTrue);

    final wrong = await BackupValidator(appSchemaVersion: db.schemaVersion)
        .validate(
          backup: built.file,
          password: 'not-the-password',
          workDir: _sub(work, 'v3'),
        );
    expect(wrong.ok, isFalse);
    expect(wrong.errors, contains('passwordOrCorrupt'));
  });

  test('empty database backs up with no physical files', () async {
    final built = await service().build(encrypt: false);
    addTearDown(() => built.stagingDir.deleteSync(recursive: true));
    expect(built.manifest.files, isEmpty);
    expect(built.manifest.counts.physicalFiles, 0);
  });

  test(
    'a missing ACTIVE cover file blocks the backup, naming the object',
    () async {
      final p = await db.possessionsDao.createPossession(title: 'Orologio');
      // Register a cover whose physical file does NOT exist.
      await db.possessionsDao.setCover(
        p.id,
        relativePath: 'photos/missing.jpg',
        mimeType: 'image/jpeg',
        byteSize: 32,
      );
      expect(
        () => service().build(encrypt: false),
        throwsA(
          isA<BackupIncompleteException>().having(
            (e) => e.message,
            'object',
            'Orologio',
          ),
        ),
      );
    },
  );

  test(
    'a missing SOFT-DELETED gallery file warns but still backs up',
    () async {
      final p = await db.possessionsDao.createPossession(title: 'Lampada');
      await addCover(p.id, 'photos/cover.jpg');
      // Add a gallery photo, then soft-delete its row and delete the file.
      writePhoto('photos/gone.jpg');
      final ph = await db.possessionsDao.addPhoto(
        p.id,
        relativePath: 'photos/gone.jpg',
        mimeType: 'image/jpeg',
        byteSize: 32,
      );
      await db.possessionsDao.removePhoto(p.id, ph.id);
      File('${docs.path}/photos/gone.jpg').deleteSync();

      final built = await service().build(encrypt: false);
      addTearDown(() => built.stagingDir.deleteSync(recursive: true));
      expect(built.warnings, isNotEmpty); // dormant missing → warning
      // Only the cover is physically included.
      expect(built.manifest.files.map((f) => f.originalRelativePath), [
        'photos/cover.jpg',
      ]);
    },
  );

  test('orphan photo files (no DB row) are excluded', () async {
    final p = await db.possessionsDao.createPossession(title: 'Chiavi');
    await addCover(p.id, 'photos/keep.jpg');
    writePhoto('photos/orphan.jpg'); // on disk, referenced by nothing

    final built = await service().build(encrypt: false);
    addTearDown(() => built.stagingDir.deleteSync(recursive: true));
    expect(built.manifest.files.map((f) => f.originalRelativePath), [
      'photos/keep.jpg',
    ]);
  });

  test(
    'archived and transferred possessions and their photos are included',
    () async {
      final a = await db.possessionsDao.createPossession(title: 'Vecchio');
      await addCover(a.id, 'photos/old.jpg');
      await db.possessionsDao.setStatus(a.id, PossessionStatus.archived);
      final b = await db.possessionsDao.createPossession(title: 'Regalato');
      await addCover(b.id, 'photos/gift.jpg');
      await db.eventsDao.give(
        possessionId: b.id,
        personName: 'Marco',
        transferredAt: DateTime(2026, 7, 1),
      );

      final built = await service().build(encrypt: false);
      addTearDown(() => built.stagingDir.deleteSync(recursive: true));
      expect(built.manifest.counts.possessions, 2);
      expect(built.manifest.files.length, 2); // both covers included
    },
  );
}

Directory _sub(Directory parent, String name) =>
    Directory('${parent.path}/$name')..createSync(recursive: true);
