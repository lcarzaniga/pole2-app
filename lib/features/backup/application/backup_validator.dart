import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../crypto/argon2_profile.dart';
import '../crypto/backup_container.dart';
import '../domain/backup_limits.dart';
import '../domain/backup_manifest.dart';
import '../domain/safe_path.dart';

/// Outcome of validating a completed `.pole2backup` — never mutates live data.
class BackupValidationResult {
  const BackupValidationResult({
    required this.ok,
    required this.errors,
    required this.warnings,
    this.manifest,
    this.schemaVersion,
    this.needsMigration = false,
  });

  final bool ok;
  final List<String> errors;
  final List<String> warnings;
  final BackupManifest? manifest;
  final int? schemaVersion;
  final bool needsMigration;

  factory BackupValidationResult.fail(String error) =>
      BackupValidationResult(ok: false, errors: [error], warnings: const []);
}

/// Validates a local backup file end-to-end (container → decrypt → ZIP guards →
/// manifest → staged DB inspection → file-reference checks). Pure w.r.t. the
/// live app: it only reads the given file and writes into [workDir]. Reused by
/// M6.1 restore. All extraction is size/count/ratio/path guarded.
class BackupValidator {
  const BackupValidator({this.appSchemaVersion = 7});

  final int appSchemaVersion;

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

  Future<BackupValidationResult> validate({
    required File backup,
    String? password,
    required Directory workDir,
  }) async {
    final warnings = <String>[];

    // 1) Container header + version.
    BackupHeader header;
    try {
      header = await BackupContainer.readHeader(backup);
    } on BackupUnsupportedVersionException {
      return BackupValidationResult.fail('newerFormat');
    } on BackupFormatException {
      return BackupValidationResult.fail('badFormat');
    }
    if (header.formatVersion != kBackupFormatVersion) {
      return BackupValidationResult.fail('newerFormat');
    }

    // KDF-parameter bounds are checked here (a DoS guard) before we ever run
    // Argon2id, so a forged header can't force a huge/never-ending derivation.
    if (header.encrypted) {
      final kdf = header.json['kdf'];
      if (kdf is! Map<String, dynamic> ||
          !Argon2Profile.fromJson(kdf).isWithinAcceptedBounds) {
        return BackupValidationResult.fail('unsafeKdf');
      }
    }

    // 2) Decrypt/copy the payload into a plaintext ZIP (auth-checked).
    final zipFile = File(p.join(workDir.path, 'payload.zip'));
    try {
      await BackupContainer.extractToZip(
        input: backup,
        outZip: zipFile,
        password: password,
      );
    } on BackupPasswordOrCorruptException {
      return BackupValidationResult.fail('passwordOrCorrupt');
    } on BackupFormatException {
      return BackupValidationResult.fail('badFormat');
    }

    // 3) Extract the ZIP with all guards.
    final extractDir = Directory(p.join(workDir.path, 'extracted'))
      ..createSync(recursive: true);
    final extracted = <String, File>{}; // normalized name -> file
    final zipLen = await zipFile.length();
    try {
      final input = InputFileStream(zipFile.path);
      final Archive archive;
      try {
        archive = ZipDecoder().decodeStream(input);
      } catch (_) {
        return BackupValidationResult.fail('corruptZip');
      }
      var count = 0;
      var total = 0;
      for (final entry in archive) {
        if (!entry.isFile) continue;
        if (entry.isSymbolicLink) {
          return BackupValidationResult.fail('unsafeEntry');
        }
        count++;
        if (count > kMaxZipEntries) {
          return BackupValidationResult.fail('tooManyEntries');
        }
        final norm = normalizeRelativePath(entry.name);
        if (norm == null) {
          return BackupValidationResult.fail('pathTraversal');
        }
        if (extracted.containsKey(norm)) {
          return BackupValidationResult.fail('duplicateEntry');
        }
        final size = entry.size;
        if (size < 0 || size > kMaxEntryBytes) {
          return BackupValidationResult.fail('entryTooLarge');
        }
        total += size;
        if (total > kMaxTotalUncompressedBytes) {
          return BackupValidationResult.fail('totalTooLarge');
        }
        final dest = File(p.join(extractDir.path, norm));
        dest.parent.createSync(recursive: true);
        final out = OutputFileStream(dest.path);
        entry.writeContent(out);
        out.closeSync();
        extracted[norm] = dest;
      }
      // Decompression-ratio guard.
      if (zipLen > 0 && total / zipLen > kMaxCompressionRatio) {
        return BackupValidationResult.fail('ratioExceeded');
      }
    } finally {}

    // 4) Manifest + database presence.
    final manifestFile = extracted[kManifestPath];
    final dbFile = extracted[kDatabaseArchivePath];
    if (manifestFile == null) {
      return BackupValidationResult.fail('missingManifest');
    }
    if (dbFile == null) {
      return BackupValidationResult.fail('missingDatabase');
    }
    BackupManifest manifest;
    try {
      manifest = BackupManifest.fromJson(
        jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>,
      );
    } catch (_) {
      return BackupValidationResult.fail('badManifest');
    }
    if (manifest.backupFormatVersion != kBackupFormatVersion) {
      return BackupValidationResult.fail('newerFormat');
    }

    // 5) Manifest ↔ archive consistency (no undeclared/missing/dup entries).
    final declared = <String>{kManifestPath, manifest.database.archivePath};
    final seenFileKeys = <String>{};
    for (final f in manifest.files) {
      if (!declared.add(f.archivePath)) {
        return BackupValidationResult.fail('duplicateEntry');
      }
      final key = '${f.fileId}|${f.originalRelativePath}';
      if (!seenFileKeys.add(key)) {
        return BackupValidationResult.fail('duplicateEntry');
      }
    }
    for (final name in extracted.keys) {
      if (!declared.contains(name)) {
        return BackupValidationResult.fail('undeclaredEntry');
      }
    }
    for (final path in declared) {
      if (!extracted.containsKey(path)) {
        return BackupValidationResult.fail('missingDeclaredEntry');
      }
    }

    // 6) Hashes.
    if (await _sha256(dbFile) != manifest.database.sha256) {
      return BackupValidationResult.fail('checksumMismatch');
    }
    for (final f in manifest.files) {
      final file = extracted[f.archivePath];
      if (file == null || await _sha256(file) != f.sha256) {
        return BackupValidationResult.fail('checksumMismatch');
      }
    }

    // 7) Staged database inspection (read-only).
    int schema;
    try {
      final db = sqlite3.open(dbFile.path, mode: OpenMode.readOnly);
      try {
        schema = db.select('PRAGMA user_version').first.values.first as int;
        final integrity =
            db.select('PRAGMA integrity_check').first.values.first as String;
        if (integrity.toLowerCase() != 'ok') {
          return BackupValidationResult.fail('integrityFailed');
        }
        final names = <String>{
          for (final r in db.select(
            "SELECT name FROM sqlite_master WHERE type='table'",
          ))
            r['name'] as String,
        };
        if (!_requiredTables.every(names.contains)) {
          return BackupValidationResult.fail('missingTable');
        }
        // Reject unexpected executable schema objects (allowlist: none).
        final risky = db.select(
          "SELECT type,name FROM sqlite_master WHERE type IN ('trigger','view')",
        );
        if (risky.isNotEmpty) {
          return BackupValidationResult.fail('unsafeSchema');
        }
      } finally {
        db.close();
      }
    } catch (_) {
      return BackupValidationResult.fail('integrityFailed');
    }
    if (schema > appSchemaVersion) {
      return BackupValidationResult.fail('newerSchema');
    }
    final needsMigration = schema < appSchemaVersion;

    // 8) File-reference validation against the staged DB + manifest.
    final refError = _validateReferences(dbFile, manifest, warnings);
    if (refError != null) return BackupValidationResult.fail(refError);

    return BackupValidationResult(
      ok: true,
      errors: const [],
      warnings: [...manifest.warnings, ...warnings],
      manifest: manifest,
      schemaVersion: schema,
      needsMigration: needsMigration,
    );
  }

  /// Confirms every restorable reference resolves to an included, safe file:
  /// active cover/gallery missing → error; dormant (soft-deleted / evidence)
  /// missing → warning (no silent loss).
  String? _validateReferences(
    File dbFile,
    BackupManifest manifest,
    List<String> warnings,
  ) {
    final byRelPath = <String, BackupFileEntry>{
      for (final f in manifest.files) f.originalRelativePath: f,
    };
    final db = sqlite3.open(dbFile.path, mode: OpenMode.readOnly);
    try {
      final relById = <String, String>{};
      for (final r in db.select('SELECT id, relative_path FROM files')) {
        relById[r['id'] as String] = r['relative_path'] as String;
      }
      bool present(String fileId) {
        final raw = relById[fileId];
        if (raw == null) return false;
        final norm = normalizeRelativePath(raw);
        if (norm == null) return false;
        return byRelPath.containsKey(norm);
      }

      for (final r in db.select(
        'SELECT cover_file_id FROM possessions WHERE cover_file_id IS NOT NULL',
      )) {
        if (!present(r['cover_file_id'] as String)) return 'missingActiveMedia';
      }
      for (final r in db.select(
        'SELECT file_id, deleted_at FROM possession_photos',
      )) {
        final ok = present(r['file_id'] as String);
        if (!ok) {
          if (r['deleted_at'] == null) return 'missingActiveMedia';
          warnings.add('dormantMediaMissing');
        }
      }
      for (final r in db.select(
        'SELECT file_id FROM evidence_items '
        'WHERE file_id IS NOT NULL AND deleted_at IS NULL',
      )) {
        if (!present(r['file_id'] as String)) {
          warnings.add('dormantMediaMissing');
        }
      }
      return null;
    } catch (_) {
      return 'integrityFailed';
    } finally {
      db.close();
    }
  }

  Future<String> _sha256(File f) async =>
      (await crypto.sha256.bind(f.openRead()).first).toString();
}
