import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';

/// Creates a **consistent** point-in-time SQLite snapshot of the live database
/// while the app keeps running, using `VACUUM INTO`. The single output file
/// folds in committed WAL content, so we never copy the live `.sqlite`/`-wal`/
/// `-shm` by hand and never risk a torn snapshot. The live DB is never touched.
class BackupSnapshotService {
  BackupSnapshotService(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Prefix for M6.0 staging directories under the temp dir — used both to
  /// create fresh ones and to sweep stale ones on startup.
  static const stagingPrefix = 'pole2_backup_';

  /// Creates a unique staging directory under [tempDir] for this backup job.
  Directory createStagingDir(Directory tempDir) {
    final dir = Directory(p.join(tempDir.path, '$stagingPrefix${_uuid.v4()}'));
    dir.createSync(recursive: true);
    return dir;
  }

  /// Runs `VACUUM INTO` a fresh file inside [stagingDir]. The destination is an
  /// app-generated UUID path (no user-controlled SQL), must not pre-exist, and
  /// is single-quote escaped defensively. Returns the snapshot file. On any
  /// failure the partial file is removed and the live DB is left untouched.
  Future<File> createSnapshot(Directory stagingDir) async {
    final dest = File(p.join(stagingDir.path, 'pole2.sqlite'));
    if (dest.existsSync()) dest.deleteSync();
    final escaped = dest.path.replaceAll("'", "''");
    try {
      // VACUUM (INTO) cannot run inside a transaction; customStatement runs it
      // directly on the connection.
      await _db.customStatement("VACUUM INTO '$escaped'");
    } catch (e) {
      if (dest.existsSync()) {
        try {
          dest.deleteSync();
        } catch (_) {}
      }
      rethrow;
    }
    return dest;
  }

  /// Best-effort removal of a job's staging directory (success/cancel/failure).
  void cleanup(Directory stagingDir) {
    try {
      if (stagingDir.existsSync()) stagingDir.deleteSync(recursive: true);
    } catch (_) {}
  }

  /// Sweeps stale M6.0 staging directories left by a killed process. Safe to
  /// call at startup; never touches anything outside the temp dir prefix.
  static void sweepStaleStaging(Directory tempDir) {
    try {
      for (final e in tempDir.listSync()) {
        if (e is Directory && p.basename(e.path).startsWith(stagingPrefix)) {
          try {
            e.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}
