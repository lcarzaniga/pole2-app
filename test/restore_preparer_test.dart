import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/features/backup/application/backup_service.dart';
import 'package:project_kobe/features/backup/crypto/argon2_profile.dart';
import 'package:project_kobe/features/backup/crypto/backup_container.dart';
import 'package:project_kobe/features/backup/domain/backup_limits.dart';
import 'package:project_kobe/features/backup/restore/restore_preparer.dart';
import 'package:sqlite3/sqlite3.dart';

// A real v6 Pole² schema, so the v6→v7 Drift migration (adds places.parentId)
// runs during staged migration.
const _v6Schema = '''
CREATE TABLE "files" ("id" TEXT NOT NULL, "relative_path" TEXT NOT NULL, "mime_type" TEXT NOT NULL, "byte_size" INTEGER NOT NULL, "sha256" TEXT NULL, "created_at" TEXT NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "possessions" ("id" TEXT NOT NULL, "title" TEXT NOT NULL, "category" TEXT NULL, "notes" TEXT NULL, "status" TEXT NOT NULL DEFAULT 'active', "cover_file_id" TEXT NULL, "place_id" TEXT NULL, "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "deleted_at" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "parties" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "kind" TEXT NULL, "phone" TEXT NULL, "email" TEXT NULL, "notes" TEXT NULL, "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "deleted_at" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "evidence_items" ("id" TEXT NOT NULL, "kind" TEXT NOT NULL, "label" TEXT NULL, "file_id" TEXT NULL, "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "deleted_at" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "identifiers" ("id" TEXT NOT NULL, "possession_id" TEXT NOT NULL, "kind" TEXT NOT NULL, "label" TEXT NULL, "value" TEXT NOT NULL, "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "deleted_at" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "attributes" ("id" TEXT NOT NULL, "possession_id" TEXT NOT NULL, "label" TEXT NOT NULL, "value" TEXT NOT NULL, "value_type" TEXT NULL, "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "deleted_at" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "events" ("id" TEXT NOT NULL, "possession_id" TEXT NOT NULL, "kind" TEXT NOT NULL, "at" TEXT NOT NULL, "ends_at" TEXT NULL, "title" TEXT NULL, "notes" TEXT NULL, "amount_minor" INTEGER NULL, "currency" TEXT NULL, "party_id" TEXT NULL, "evidence_id" TEXT NULL, "status" TEXT NULL, "purchased_on" TEXT NULL, "acquisition_type" TEXT NULL, "remind_lead" TEXT NULL, "origin_place_id" TEXT NULL, "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "deleted_at" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "possession_evidence" ("possession_id" TEXT NOT NULL, "evidence_id" TEXT NOT NULL, "added_at" TEXT NOT NULL, PRIMARY KEY ("possession_id", "evidence_id"));
CREATE TABLE "places" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "notes" TEXT NULL, "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "deleted_at" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "possession_photos" ("id" TEXT NOT NULL, "possession_id" TEXT NOT NULL, "file_id" TEXT NOT NULL, "sort_order" INTEGER NOT NULL DEFAULT 0, "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "deleted_at" TEXT NULL, PRIMARY KEY ("id"));
''';

void main() {
  late Directory work;
  setUp(() => work = Directory.systemTemp.createTempSync('pole2_prep'));
  tearDown(() => work.deleteSync(recursive: true));

  Directory sub(String n) =>
      Directory('${work.path}/$n')..createSync(recursive: true);
  Future<String> sha(File f) async =>
      (await crypto.sha256.bind(f.openRead()).first).toString();

  // Build a real backup via the M6.0 pipeline from an in-memory DB + photos.
  Future<File> buildBackup({required bool encrypt, String? password}) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final docs = sub('docs');
    Directory('${docs.path}/photos').createSync(recursive: true);
    File('${docs.path}/photos/a.jpg').writeAsBytesSync(List.filled(40, 1));
    final p = await db.possessionsDao.createPossession(title: 'Trapano');
    await db.possessionsDao.setCover(
      p.id,
      relativePath: 'photos/a.jpg',
      mimeType: 'image/jpeg',
      byteSize: 40,
    );
    final built = await BackupService(
      db: db,
      tempDir: sub('tmp'),
      documentsDir: docs,
      appVersion: '1.0.12',
      versionCode: 2017,
      schemaVersion: db.schemaVersion,
      argon2: const Argon2Profile(
        memoryKiB: 8 * 1024,
        iterations: 1,
        parallelism: 1,
      ),
    ).build(encrypt: encrypt, password: password);
    await db.close();
    // Copy out of staging before it's cleaned by the caller.
    final out = File('${work.path}/backup.pole2backup');
    built.file.copySync(out.path);
    built.stagingDir.deleteSync(recursive: true);
    return out;
  }

  test(
    'prepares a v7 plaintext backup: healthy DB + managed files + summary',
    () async {
      final backup = await buildBackup(encrypt: false);
      final staging = sub('stg1');
      final source = File('${staging.path}/source.pole2backup');
      backup.copySync(source.path);

      final prep = await RestorePreparer(
        appSchemaVersion: 7,
      ).prepare(source: source, stagingDir: staging, operationId: 'op1');
      expect(prep.summary.possessions, 1);
      expect(prep.summary.photos, 1);
      expect(prep.summary.migratedInStaging, isFalse);
      expect(prep.managedFiles.single.relativePath, 'photos/a.jpg');
      // Prepared DB exists and its hash matches what the marker will record.
      final preparedDb = File('${staging.path}/prepared/project_kobe.sqlite');
      expect(preparedDb.existsSync(), isTrue);
      expect(await sha(preparedDb), prep.preparedDbSha256);
      // Prepared managed file is present.
      expect(
        File(
          '${staging.path}/prepared/managed_files/photos/a.jpg',
        ).existsSync(),
        isTrue,
      );
    },
  );

  test('prepares an encrypted backup with the correct password', () async {
    final backup = await buildBackup(
      encrypt: true,
      password: 'a-strong-pass-123',
    );
    final staging = sub('stg2');
    final source = File('${staging.path}/source.pole2backup');
    backup.copySync(source.path);

    final prep = await RestorePreparer(appSchemaVersion: 7).prepare(
      source: source,
      stagingDir: staging,
      operationId: 'op2',
      password: 'a-strong-pass-123',
    );
    expect(prep.summary.encrypted, isTrue);
    expect(prep.summary.possessions, 1);
  });

  test('a wrong password fails with the generic code', () async {
    final backup = await buildBackup(
      encrypt: true,
      password: 'the-real-pass-1',
    );
    final staging = sub('stg3');
    final source = File('${staging.path}/source.pole2backup');
    backup.copySync(source.path);

    expect(
      () => RestorePreparer(appSchemaVersion: 7).prepare(
        source: source,
        stagingDir: staging,
        operationId: 'op3',
        password: 'the-wrong-pass-1',
      ),
      throwsA(
        isA<RestorePrepareException>().having(
          (e) => e.code,
          'code',
          'passwordOrCorrupt',
        ),
      ),
    );
  });

  test('an older (v6) backup is migrated to v7 in staging', () async {
    // Craft a real v6 DB, wrap it in a plaintext container with a valid manifest.
    final v6 = File('${work.path}/v6.sqlite');
    final raw = sqlite3.open(v6.path);
    raw.execute(_v6Schema);
    raw.execute('PRAGMA user_version = 6');
    raw.close();

    final zip = File('${work.path}/payload.zip');
    final enc = ZipFileEncoder()..create(zip.path);
    final manifest = {
      'backupFormatVersion': kBackupFormatVersion,
      'appVersion': '1.0.9',
      'versionCode': 2014,
      'databaseSchemaVersion': 6,
      'createdAtUtc': '2026-07-18T00:00:00.000Z',
      'platform': 'android',
      'encrypted': false,
      'database': {
        'archivePath': kDatabaseArchivePath,
        'byteSize': v6.lengthSync(),
        'sha256': await sha(v6),
      },
      'files': <dynamic>[],
      'counts': {
        'possessions': 0,
        'places': 0,
        'people': 0,
        'events': 0,
        'photos': 0,
        'physicalFiles': 0,
      },
      'warnings': <String>[],
      'totalUncompressedBytes': v6.lengthSync(),
    };
    final mf = File('${work.path}/manifest.json')
      ..writeAsStringSync(jsonEncode(manifest));
    await enc.addFile(mf, kManifestPath);
    await enc.addFile(v6, kDatabaseArchivePath);
    await enc.close();

    final staging = sub('stg4');
    final source = File('${staging.path}/source.pole2backup');
    await BackupContainer.writePlaintext(
      zipFile: zip,
      out: source,
      appHeader: const {
        'app': {'versionName': '1.0.9', 'versionCode': 2014},
        'platform': 'android',
        'createdAtUtc': '2026-07-18T00:00:00.000Z',
      },
    );

    final prep = await RestorePreparer(
      appSchemaVersion: 7,
    ).prepare(source: source, stagingDir: staging, operationId: 'op4');
    expect(prep.summary.migratedInStaging, isTrue);
    final preparedDb = File('${staging.path}/prepared/project_kobe.sqlite');
    final d = sqlite3.open(preparedDb.path, mode: OpenMode.readOnly);
    final uv = d.select('PRAGMA user_version').first.values.first as int;
    d.close();
    expect(uv, 7); // migrated
  });
}
