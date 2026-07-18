import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/app_database.dart';
import '../application/backup_validator.dart';
import 'restore_marker.dart';
import 'restore_swapper.dart' show kLiveDbName;

/// A prepared, validated restore ready for the user to confirm. Nothing live has
/// been touched; everything needed for the swap sits in [stagingDir]/prepared.
class RestorePreparation {
  const RestorePreparation({
    required this.operationId,
    required this.stagingDir,
    required this.preparedDbSha256,
    required this.managedFiles,
    required this.summary,
  });

  final String operationId;
  final Directory stagingDir;
  final String preparedDbSha256;
  final List<RestoreManagedFile> managedFiles;
  final RestoreSummary summary;
}

/// Human-readable facts shown before confirmation.
class RestoreSummary {
  const RestoreSummary({
    required this.createdAtUtc,
    required this.appVersion,
    required this.encrypted,
    required this.possessions,
    required this.places,
    required this.people,
    required this.events,
    required this.photos,
    required this.physicalFiles,
    required this.approxBytes,
    required this.migratedInStaging,
    required this.warnings,
  });

  final String createdAtUtc;
  final String appVersion;
  final bool encrypted;
  final int possessions;
  final int places;
  final int people;
  final int events;
  final int photos;
  final int physicalFiles;
  final int approxBytes;
  final bool migratedInStaging;
  final List<String> warnings;
}

/// Raised when preparation cannot proceed; [code] is a coarse, localizable key.
class RestorePrepareException implements Exception {
  const RestorePrepareException(this.code);
  final String
  code; // e.g. passwordOrCorrupt, newerSchema, migrationFailed, ...
  @override
  String toString() => 'RestorePrepareException($code)';
}

/// Copies/decrypts/validates a selected backup into staging, migrates the staged
/// database to the app schema when older, re-validates, and assembles the
/// `prepared/` payload. Never migrates the original file in place; never touches
/// live data. Testable: everything happens under [source]'s staging directory.
class RestorePreparer {
  RestorePreparer({required this.appSchemaVersion});

  final int appSchemaVersion;

  /// [source] is the already-copied `.pole2backup` inside [stagingDir].
  Future<RestorePreparation> prepare({
    required File source,
    required Directory stagingDir,
    required String operationId,
    String? password,
  }) async {
    // Validate + extract into staging/extracted (reuses the M6.0 validator).
    final result = await BackupValidator(
      appSchemaVersion: appSchemaVersion,
    ).validate(backup: source, password: password, workDir: stagingDir);
    if (!result.ok) {
      throw RestorePrepareException(
        result.errors.isEmpty ? 'generic' : result.errors.first,
      );
    }
    final manifest = result.manifest!;

    final extracted = Directory(p.join(stagingDir.path, 'extracted'));
    final extractedDb = File(
      p.join(extracted.path, manifest.database.archivePath),
    );

    // Migrate the *staged* copy if the backup is an older supported schema.
    var migrated = false;
    if (result.needsMigration) {
      migrated = true;
      try {
        final db = AppDatabase(NativeDatabase(extractedDb));
        // Force open → runs the Drift migration chain up to the app schema.
        await db.customSelect('SELECT 1').get();
        await db.close();
      } catch (_) {
        throw const RestorePrepareException('migrationFailed');
      }
    }

    // Produce a single, clean prepared DB via VACUUM INTO (folds any WAL,
    // guarantees one file, and re-checks openability).
    final preparedDir = Directory(p.join(stagingDir.path, 'prepared'))
      ..createSync(recursive: true);
    final preparedDb = File(p.join(preparedDir.path, kLiveDbName));
    if (preparedDb.existsSync()) preparedDb.deleteSync();
    try {
      final src = sqlite3.open(extractedDb.path);
      try {
        final escaped = preparedDb.path.replaceAll("'", "''");
        src.execute("VACUUM INTO '$escaped'");
      } finally {
        src.close();
      }
    } catch (_) {
      throw const RestorePrepareException('migrationFailed');
    }

    // Re-validate the prepared DB (post-migration).
    if (!_dbHealthy(preparedDb)) {
      throw const RestorePrepareException('integrityFailed');
    }

    // Assemble prepared/managed_files from the validated extracted files.
    final managedDir = Directory(p.join(preparedDir.path, 'managed_files'))
      ..createSync(recursive: true);
    final managed = <RestoreManagedFile>[];
    for (final f in manifest.files) {
      final src = File(p.join(extracted.path, f.archivePath));
      final dst = File(p.join(managedDir.path, f.originalRelativePath));
      dst.parent.createSync(recursive: true);
      src.copySync(dst.path);
      managed.add(
        RestoreManagedFile(
          relativePath: f.originalRelativePath,
          sha256: f.sha256,
          byteSize: f.byteSize,
        ),
      );
    }

    return RestorePreparation(
      operationId: operationId,
      stagingDir: stagingDir,
      preparedDbSha256: _sha256(preparedDb),
      managedFiles: managed,
      summary: RestoreSummary(
        createdAtUtc: manifest.createdAtUtc,
        appVersion: manifest.appVersion,
        encrypted: manifest.encrypted,
        possessions: manifest.counts.possessions,
        places: manifest.counts.places,
        people: manifest.counts.people,
        events: manifest.counts.events,
        photos: manifest.counts.photos,
        physicalFiles: manifest.counts.physicalFiles,
        approxBytes: manifest.totalUncompressedBytes,
        migratedInStaging: migrated,
        warnings: [...manifest.warnings, ...result.warnings],
      ),
    );
  }

  // Local copy of the required-table check (independent of Drift).
  static const _requiredTables = {
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
  };

  bool _dbHealthy(File db) {
    try {
      final d = sqlite3.open(db.path, mode: OpenMode.readOnly);
      try {
        final uv = d.select('PRAGMA user_version').first.values.first as int;
        if (uv != appSchemaVersion) return false;
        final integrity =
            d.select('PRAGMA integrity_check').first.values.first as String;
        if (integrity.toLowerCase() != 'ok') return false;
        final names = <String>{
          for (final r in d.select(
            "SELECT name FROM sqlite_master WHERE type='table'",
          ))
            r['name'] as String,
        };
        return _requiredTables.every(names.contains);
      } finally {
        d.close();
      }
    } catch (_) {
      return false;
    }
  }

  String _sha256(File f) =>
      crypto.sha256.convert(f.readAsBytesSync()).toString();
}
