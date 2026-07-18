import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../domain/backup_limits.dart';
import '../domain/backup_manifest.dart';
import 'backup_plan.dart';

/// Builds the inner ZIP (`manifest.json` + `database/pole2.sqlite` +
/// `files/...`) on disk, streaming each file through `ZipFileEncoder.addFile`
/// (no whole-archive buffering) and hashing each with a streamed SHA-256.
/// Deterministic entry order: manifest, database, then files by archive path.
class BackupArchiver {
  const BackupArchiver();

  Future<BackupManifest> build({
    required File snapshotDb,
    required BackupPlan plan,
    required File outZip,
    required Directory workDir,
    required String appVersion,
    required int versionCode,
    required int schemaVersion,
    required bool encrypted,
    String platform = 'android',
  }) async {
    final dbSize = await snapshotDb.length();
    final dbHash = await _sha256File(snapshotDb);

    final fileEntries = <BackupFileEntry>[];
    var total = dbSize;
    for (final f in plan.files) {
      final size = await f.source.length();
      final hash = await _sha256File(f.source);
      total += size;
      fileEntries.add(
        BackupFileEntry(
          fileId: f.fileId,
          archivePath: f.archivePath,
          originalRelativePath: f.relativePath,
          byteSize: size,
          sha256: hash,
          referenceKinds: f.referenceKinds,
        ),
      );
    }

    final manifest = BackupManifest(
      backupFormatVersion: kBackupFormatVersion,
      appVersion: appVersion,
      versionCode: versionCode,
      databaseSchemaVersion: schemaVersion,
      createdAtUtc: DateTime.now().toUtc().toIso8601String(),
      platform: platform,
      encrypted: encrypted,
      database: BackupDatabaseEntry(
        archivePath: kDatabaseArchivePath,
        byteSize: dbSize,
        sha256: dbHash,
      ),
      files: fileEntries,
      counts: BackupCounts(
        possessions: plan.counts['possessions'] ?? 0,
        places: plan.counts['places'] ?? 0,
        people: plan.counts['people'] ?? 0,
        events: plan.counts['events'] ?? 0,
        photos: plan.counts['photos'] ?? 0,
        physicalFiles: plan.counts['physicalFiles'] ?? fileEntries.length,
      ),
      warnings: plan.warnings,
      totalUncompressedBytes: total,
    );

    // Write manifest to a temp file so it too is streamed into the ZIP.
    final manifestFile = File(p.join(workDir.path, 'manifest.json'));
    await manifestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
    );

    final encoder = ZipFileEncoder();
    encoder.create(outZip.path);
    try {
      await encoder.addFile(manifestFile, kManifestPath);
      await encoder.addFile(snapshotDb, kDatabaseArchivePath);
      for (final f in plan.files) {
        await encoder.addFile(f.source, f.archivePath);
      }
    } finally {
      await encoder.close();
    }
    try {
      manifestFile.deleteSync();
    } catch (_) {}
    return manifest;
  }

  Future<String> _sha256File(File f) async {
    final digest = await crypto.sha256.bind(f.openRead()).first;
    return digest.toString();
  }
}
