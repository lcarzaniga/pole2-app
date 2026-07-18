import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/features/backup/application/backup_service.dart';
import 'package:project_kobe/features/backup/application/backup_validator.dart';
import 'package:project_kobe/features/backup/crypto/argon2_profile.dart';
import 'package:project_kobe/features/backup/crypto/backup_container.dart';
import 'package:project_kobe/features/backup/domain/backup_limits.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('pole2_val'));
  tearDown(() => dir.deleteSync(recursive: true));

  const appHeader = {
    'app': {'versionName': '1.0.11', 'versionCode': 2016},
    'platform': 'android',
    'createdAtUtc': '2026-07-18T00:00:00.000Z',
  };
  const requiredTables = [
    'files',
    'possessions',
    'places',
    'identifiers',
    'attributes',
    'evidence_items',
    'possession_evidence',
    'events',
    'parties',
    'possession_photos',
  ];

  int fileCounter = 0;
  Future<String> sha256(File f) async =>
      (await crypto.sha256.bind(f.openRead()).first).toString();

  Directory sub(String name) =>
      Directory('${dir.path}/$name')..createSync(recursive: true);

  /// Builds a plaintext `.pole2backup` from a set of {archivePath: File}, with a
  /// manifest that declares [manifestFiles] (defaults to the db entry only).
  Future<File> wrap(
    Map<String, File> entries, {
    Map<String, dynamic>? manifest,
  }) async {
    final zip = File('${dir.path}/z$fileCounter.zip');
    final enc = ZipFileEncoder()..create(zip.path);
    for (final e in entries.entries) {
      await enc.addFile(e.value, e.key);
    }
    if (manifest != null) {
      final mf = File('${dir.path}/m$fileCounter.json')
        ..writeAsStringSync(jsonEncode(manifest));
      await enc.addFile(mf, kManifestPath);
    }
    await enc.close();
    final out = File('${dir.path}/b${fileCounter++}.pole2backup');
    await BackupContainer.writePlaintext(
      zipFile: zip,
      out: out,
      appHeader: appHeader,
    );
    return out;
  }

  /// Creates a sqlite db file with the given tables + user_version (+ trigger).
  File craftDb({
    List<String> tables = requiredTables,
    int userVersion = 7,
    bool withTrigger = false,
  }) {
    // Columns the validator's reference-check queries touch, so an empty-but-
    // valid backup passes; other tables just need to exist by name.
    const schemas = {
      'files': 'id TEXT, relative_path TEXT',
      'possessions': 'id TEXT, cover_file_id TEXT',
      'possession_photos': 'id TEXT, file_id TEXT, deleted_at TEXT',
      'evidence_items': 'id TEXT, file_id TEXT, deleted_at TEXT',
    };
    final path = '${dir.path}/db$fileCounter.sqlite';
    final db = sqlite3.open(path);
    for (final t in tables) {
      db.execute('CREATE TABLE $t (${schemas[t] ?? 'id TEXT'})');
    }
    if (withTrigger) {
      db.execute('CREATE TRIGGER t AFTER INSERT ON files BEGIN SELECT 1; END');
    }
    db.execute('PRAGMA user_version = $userVersion');
    db.close();
    return File(path);
  }

  /// A full valid plaintext backup wrapping [dbFile] with a correct manifest.
  Future<File> backupFromDb(
    File dbFile, {
    int schemaVersion = 7,
    Map<String, File> extraFiles = const {},
  }) async {
    final manifest = {
      'backupFormatVersion': kBackupFormatVersion,
      'appVersion': '1.0.11',
      'versionCode': 2016,
      'databaseSchemaVersion': schemaVersion,
      'createdAtUtc': '2026-07-18T00:00:00.000Z',
      'platform': 'android',
      'encrypted': false,
      'database': {
        'archivePath': kDatabaseArchivePath,
        'byteSize': dbFile.lengthSync(),
        'sha256': await sha256(dbFile),
      },
      'files': [
        for (final e in extraFiles.entries)
          {
            'fileId': null,
            'archivePath': e.key,
            'originalRelativePath': e.key.substring(kFilesPrefix.length),
            'byteSize': e.value.lengthSync(),
            'sha256': await sha256(e.value),
            'referenceKinds': <String>[],
          },
      ],
      'counts': {
        'possessions': 0,
        'places': 0,
        'people': 0,
        'events': 0,
        'photos': 0,
        'physicalFiles': extraFiles.length,
      },
      'warnings': <String>[],
      'totalUncompressedBytes': dbFile.lengthSync(),
    };
    return wrap({
      kDatabaseArchivePath: dbFile,
      ...extraFiles,
    }, manifest: manifest);
  }

  Future<BackupValidationResult> validate(
    File f, {
    String? password,
    int app = 7,
  }) => BackupValidator(
    appSchemaVersion: app,
  ).validate(backup: f, password: password, workDir: sub('w$fileCounter'));

  test('a valid crafted backup passes', () async {
    final res = await validate(await backupFromDb(craftDb()));
    expect(res.ok, isTrue);
    expect(res.schemaVersion, 7);
    expect(res.needsMigration, isFalse);
  });

  test('unknown magic → badFormat', () async {
    final f = File('${dir.path}/x.pole2backup')
      ..writeAsBytesSync(List<int>.filled(64, 9));
    final res = await validate(f);
    expect(res.errors, contains('badFormat'));
  });

  test('a newer container format is rejected', () async {
    final good = await backupFromDb(craftDb());
    final bytes = good.readAsBytesSync();
    bytes[7] = 2; // bump format version byte
    good.writeAsBytesSync(bytes);
    final res = await validate(good);
    expect(res.errors, contains('newerFormat'));
  });

  test('a newer database schema is rejected', () async {
    final res = await validate(
      await backupFromDb(craftDb(userVersion: 9), schemaVersion: 9),
      app: 7,
    );
    expect(res.errors, contains('newerSchema'));
  });

  test('an older supported schema validates and flags migration', () async {
    final res = await validate(await backupFromDb(craftDb()), app: 8);
    expect(res.ok, isTrue);
    expect(res.needsMigration, isTrue);
  });

  test('a missing required table is rejected', () async {
    final tables = List<String>.from(requiredTables)..remove('events');
    final res = await validate(await backupFromDb(craftDb(tables: tables)));
    expect(res.errors, contains('missingTable'));
  });

  test('an unexpected trigger is rejected', () async {
    final res = await validate(await backupFromDb(craftDb(withTrigger: true)));
    expect(res.errors, contains('unsafeSchema'));
  });

  test('a path-traversal entry is rejected', () async {
    final evil = File('${dir.path}/evil')..writeAsBytesSync([1, 2, 3]);
    final res = await validate(await wrap({'../evil': evil}));
    expect(res.errors, contains('pathTraversal'));
  });

  test('a missing manifest is rejected', () async {
    final res = await validate(await wrap({kDatabaseArchivePath: craftDb()}));
    expect(res.errors, contains('missingManifest'));
  });

  test('an undeclared extra entry is rejected', () async {
    final extra = File('${dir.path}/extra.jpg')..writeAsBytesSync([9, 9, 9]);
    // Manifest declares only the db, but the zip also contains files/extra.jpg.
    final f = await backupFromDb(craftDb()); // valid, then rebuild with extra
    // Rebuild: manifest without the extra but zip with it.
    final db = craftDb();
    final manifest = {
      'backupFormatVersion': kBackupFormatVersion,
      'appVersion': '1.0.11',
      'versionCode': 2016,
      'databaseSchemaVersion': 7,
      'createdAtUtc': '2026-07-18T00:00:00.000Z',
      'platform': 'android',
      'encrypted': false,
      'database': {
        'archivePath': kDatabaseArchivePath,
        'byteSize': db.lengthSync(),
        'sha256': await sha256(db),
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
      'totalUncompressedBytes': db.lengthSync(),
    };
    final res = await validate(
      await wrap({
        kDatabaseArchivePath: db,
        '${kFilesPrefix}extra.jpg': extra,
      }, manifest: manifest),
    );
    expect(f.existsSync(), isTrue);
    expect(res.errors, contains('undeclaredEntry'));
  });

  test('a checksum mismatch is rejected', () async {
    final db = craftDb();
    final manifest = {
      'backupFormatVersion': kBackupFormatVersion,
      'appVersion': '1.0.11',
      'versionCode': 2016,
      'databaseSchemaVersion': 7,
      'createdAtUtc': '2026-07-18T00:00:00.000Z',
      'platform': 'android',
      'encrypted': false,
      'database': {
        'archivePath': kDatabaseArchivePath,
        'byteSize': db.lengthSync(),
        'sha256': 'deadbeef', // wrong on purpose
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
      'totalUncompressedBytes': db.lengthSync(),
    };
    final res = await validate(
      await wrap({kDatabaseArchivePath: db}, manifest: manifest),
    );
    expect(res.errors, contains('checksumMismatch'));
  });

  test('a wrong password on an encrypted backup is generic', () async {
    final appDb = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(appDb.close);
    final docs = Directory.systemTemp.createTempSync('pole2_encdocs');
    addTearDown(() => docs.deleteSync(recursive: true));
    final built = await BackupService(
      db: appDb,
      tempDir: sub('enc'),
      documentsDir: docs,
      appVersion: '1.0.11',
      versionCode: 2016,
      schemaVersion: appDb.schemaVersion,
      argon2: const Argon2Profile(
        memoryKiB: 8 * 1024,
        iterations: 1,
        parallelism: 1,
      ),
    ).build(encrypt: true, password: 'the-real-passphrase');
    addTearDown(() => built.stagingDir.deleteSync(recursive: true));
    final res = await validate(built.file, password: 'the-wrong-passphrase');
    expect(res.errors, contains('passwordOrCorrupt'));
  });
}
