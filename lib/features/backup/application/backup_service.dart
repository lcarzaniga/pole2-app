import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import '../crypto/argon2_profile.dart';
import '../crypto/backup_container.dart';
import '../data/backup_archiver.dart';
import '../data/backup_enumerator.dart';
import '../data/backup_snapshot_service.dart';
import '../domain/backup_manifest.dart';
import 'backup_validator.dart';

/// Phases reported as a backup is produced.
enum BackupPhase {
  snapshotting,
  enumerating,
  archiving,
  encrypting,
  validating,
}

/// A produced, validated backup ready to be copied to a user destination.
class BuiltBackup {
  const BuiltBackup({
    required this.file,
    required this.stagingDir,
    required this.manifest,
    required this.suggestedName,
    required this.warnings,
  });

  final File file;
  final Directory stagingDir;
  final BackupManifest manifest;
  final String suggestedName;
  final List<String> warnings;
}

/// The full export pipeline — snapshot → enumerate → archive → encrypt →
/// self-validate — with no UI or SAF concerns, so it is unit-testable end to end
/// against an in-memory/temp database. Never touches the live database files.
class BackupService {
  BackupService({
    required this.db,
    required this.tempDir,
    required this.documentsDir,
    required this.appVersion,
    required this.versionCode,
    required this.schemaVersion,
    this.argon2 = Argon2Profile.production,
  });

  final AppDatabase db;
  final Directory tempDir;
  final Directory documentsDir;
  final String appVersion;
  final int versionCode;
  final int schemaVersion;
  final Argon2Profile argon2;

  /// Produces and validates a backup. On success returns [BuiltBackup] (whose
  /// [stagingDir] the caller must clean up after saving). On any failure the
  /// staging directory is cleaned and the error rethrown. The live DB and photo
  /// files are never modified.
  Future<BuiltBackup> build({
    required bool encrypt,
    String? password,
    void Function(BackupPhase phase)? onPhase,
  }) async {
    final snapshotService = BackupSnapshotService(db);
    final staging = snapshotService.createStagingDir(tempDir);
    try {
      onPhase?.call(BackupPhase.snapshotting);
      final snapshot = await snapshotService.createSnapshot(staging);

      onPhase?.call(BackupPhase.enumerating);
      final plan = const BackupEnumerator().enumerate(
        snapshotDb: snapshot,
        documentsDir: documentsDir,
      );

      onPhase?.call(BackupPhase.archiving);
      final zip = File(p.join(staging.path, 'payload.zip'));
      final manifest = await const BackupArchiver().build(
        snapshotDb: snapshot,
        plan: plan,
        outZip: zip,
        workDir: staging,
        appVersion: appVersion,
        versionCode: versionCode,
        schemaVersion: schemaVersion,
        encrypted: encrypt,
      );

      onPhase?.call(BackupPhase.encrypting);
      final out = File(p.join(staging.path, _suggestedName()));
      final appHeader = <String, dynamic>{
        'app': {'versionName': appVersion, 'versionCode': versionCode},
        'platform': 'android',
        'createdAtUtc': manifest.createdAtUtc,
      };
      if (encrypt) {
        if (password == null) {
          throw ArgumentError('password required for encrypted backup');
        }
        await BackupContainer.writeEncrypted(
          zipFile: zip,
          out: out,
          password: password,
          profile: argon2,
          appHeader: appHeader,
        );
      } else {
        await BackupContainer.writePlaintext(
          zipFile: zip,
          out: out,
          appHeader: appHeader,
        );
      }
      // Free the intermediate ZIP; keep only the final container.
      try {
        zip.deleteSync();
      } catch (_) {}

      onPhase?.call(BackupPhase.validating);
      final validateDir = Directory(p.join(staging.path, 'verify'))
        ..createSync(recursive: true);
      final result = await BackupValidator(
        appSchemaVersion: schemaVersion,
      ).validate(backup: out, password: password, workDir: validateDir);
      try {
        validateDir.deleteSync(recursive: true);
      } catch (_) {}
      if (!result.ok) {
        throw StateError('self-validation failed: ${result.errors.join(",")}');
      }

      return BuiltBackup(
        file: out,
        stagingDir: staging,
        manifest: manifest,
        suggestedName: _suggestedName(),
        warnings: [...manifest.warnings, ...result.warnings],
      );
    } catch (_) {
      snapshotService.cleanup(staging);
      rethrow;
    }
  }

  String _suggestedName() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}';
    return 'Pole2-$stamp.pole2backup';
  }
}
