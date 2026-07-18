import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../domain/safe_path.dart';
import 'restore_marker.dart';

/// Managed media roots under the documents dir (currently just photos).
const List<String> kManagedRoots = ['photos'];
const String kLiveDbName = 'project_kobe.sqlite';
const int kMaxRestoreAttempts = 2;

enum RestoreOutcomeKind { committed, rolledBack, fatal, none }

class RestoreOutcome {
  const RestoreOutcome(this.kind, [this.operationId]);
  final RestoreOutcomeKind kind;
  final String? operationId;
}

/// Performs the crash-safe swap during the pre-database bootstrap. Every step is
/// idempotent and driven by the durable [RestoreMarker] phase, so a process
/// death at any point either resumes forward or rolls back to the emergency
/// snapshot. Uses only `dart:io` + `sqlite3` — the normal Drift database is
/// never opened here. Pure w.r.t. app state: it operates entirely under
/// [documentsDir], so it is unit-testable with temp directories.
class RestoreSwapper {
  RestoreSwapper(this.documentsDir);

  final Directory documentsDir;

  File get _markerFile =>
      File(p.join(documentsDir.path, 'restore_pending.json'));
  File get _receiptFile =>
      File(p.join(documentsDir.path, 'restore_result.json'));

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

  /// Resolves any pending restore. Returns what happened (none if no marker).
  RestoreOutcome run() {
    final marker0 = RestoreMarker.readOrNull(_markerFile);
    if (marker0 == null) {
      // Corrupt or absent marker: if a marker *file* exists but won't parse,
      // remove it (unresolvable) and leave live data untouched.
      if (_markerFile.existsSync()) {
        _safeDelete(_markerFile);
        _writeReceipt('rolledBack', 'unknown');
        return const RestoreOutcome(RestoreOutcomeKind.rolledBack);
      }
      return const RestoreOutcome(RestoreOutcomeKind.none);
    }

    // Validate the marker's paths stay inside approved app-private roots.
    if (!_pathsSafe(marker0)) {
      _safeDelete(_markerFile);
      _writeReceipt('rolledBack', marker0.operationId);
      return RestoreOutcome(RestoreOutcomeKind.rolledBack, marker0.operationId);
    }

    // Durable attempt increment + boot-loop guard.
    var marker = marker0.copyWith(attemptCount: marker0.attemptCount + 1);
    RestoreMarker.writeAtomic(_markerFile, marker);
    if (marker.attemptCount > kMaxRestoreAttempts &&
        marker.phase != RestorePhase.committed) {
      return _rollback(marker);
    }

    try {
      return _resume(marker);
    } catch (_) {
      return _rollback(marker);
    }
  }

  RestoreOutcome _resume(RestoreMarker marker) {
    final staging = Directory(p.join(documentsDir.path, marker.stagingRelPath));
    final recovery = Directory(
      p.join(documentsDir.path, marker.recoveryRelPath),
    );
    final prepared = Directory(p.join(staging.path, 'prepared'));

    switch (marker.phase) {
      case RestorePhase.prepared:
        if (!_preparedIntact(prepared, marker)) return _rollback(marker);
        marker = _advance(marker, RestorePhase.oldDataMoving);
        continue moving;
      moving:
      case RestorePhase.oldDataMoving:
        recovery.createSync(recursive: true);
        _snapshotCurrent(recovery);
        marker = _advance(marker, RestorePhase.oldDataMoved);
        continue installing;
      installing:
      case RestorePhase.oldDataMoved:
        marker = _advance(marker, RestorePhase.newDataInstalling);
        continue install2;
      install2:
      case RestorePhase.newDataInstalling:
        _installPrepared(prepared);
        marker = _advance(marker, RestorePhase.newDataInstalled);
        continue verify;
      verify:
      case RestorePhase.newDataInstalled:
        if (!_verifyInstalled(marker)) return _rollback(marker);
        marker = _advance(marker, RestorePhase.verified);
        continue commit;
      commit:
      case RestorePhase.verified:
        _writeReceipt('success', marker.operationId);
        _advance(marker, RestorePhase.committed);
        _safeDelete(_markerFile); // recovery kept until confirmed launch
        return RestoreOutcome(RestoreOutcomeKind.committed, marker.operationId);
      case RestorePhase.committed:
        _safeDelete(_markerFile);
        return RestoreOutcome(RestoreOutcomeKind.committed, marker.operationId);
      case RestorePhase.rollbackRequired:
      case RestorePhase.rolledBack:
        return _rollback(marker);
    }
  }

  RestoreMarker _advance(RestoreMarker marker, RestorePhase phase) {
    final next = marker.copyWith(phase: phase);
    RestoreMarker.writeAtomic(_markerFile, next);
    return next;
  }

  // ---- Steps (each idempotent) ----

  void _snapshotCurrent(Directory recovery) {
    final dbDir = Directory(p.join(recovery.path, 'db'))
      ..createSync(recursive: true);
    for (final suffix in ['', '-wal', '-shm']) {
      _moveIfExists(
        File(p.join(documentsDir.path, '$kLiveDbName$suffix')),
        File(p.join(dbDir.path, '$kLiveDbName$suffix')),
      );
    }
    final mediaDir = Directory(p.join(recovery.path, 'media'))
      ..createSync(recursive: true);
    for (final root in kManagedRoots) {
      _moveDirIfExists(
        Directory(p.join(documentsDir.path, root)),
        Directory(p.join(mediaDir.path, root)),
      );
    }
  }

  void _installPrepared(Directory prepared) {
    _moveIfExists(
      File(p.join(prepared.path, kLiveDbName)),
      File(p.join(documentsDir.path, kLiveDbName)),
    );
    // Any stale WAL/SHM from the old DB must not survive the body swap.
    for (final suffix in ['-wal', '-shm']) {
      _safeDelete(File(p.join(documentsDir.path, '$kLiveDbName$suffix')));
    }
    final managed = Directory(p.join(prepared.path, 'managed_files'));
    if (managed.existsSync()) {
      for (final entry in managed.listSync()) {
        final name = p.basename(entry.path);
        if (entry is Directory) {
          _moveDirIfExists(entry, Directory(p.join(documentsDir.path, name)));
        } else if (entry is File) {
          _moveIfExists(entry, File(p.join(documentsDir.path, name)));
        }
      }
    }
  }

  bool _verifyInstalled(RestoreMarker marker) {
    final db = File(p.join(documentsDir.path, kLiveDbName));
    if (!db.existsSync()) return false;
    if (_sha256(db) != marker.preparedDbSha256) return false;
    if (!_dbHealthy(db)) return false;
    for (final f in marker.managedFiles) {
      final file = File(p.join(documentsDir.path, f.relativePath));
      if (!file.existsSync() || _sha256(file) != f.sha256) return false;
    }
    return true;
  }

  /// Component-guarded rollback: a live component is only removed-and-restored
  /// when the emergency snapshot actually holds a copy of it. So before the old
  /// data was moved (or during a partial snapshot) the untouched originals are
  /// never destroyed; after old data was moved, any partially-installed new data
  /// is discarded and the exact originals are put back.
  RestoreOutcome _rollback(RestoreMarker marker) {
    try {
      final recovery = Directory(
        p.join(documentsDir.path, marker.recoveryRelPath),
      );
      final recDb = File(p.join(recovery.path, 'db', kLiveDbName));
      if (recDb.existsSync()) {
        for (final suffix in ['', '-wal', '-shm']) {
          _safeDelete(File(p.join(documentsDir.path, '$kLiveDbName$suffix')));
          _moveIfExists(
            File(p.join(recovery.path, 'db', '$kLiveDbName$suffix')),
            File(p.join(documentsDir.path, '$kLiveDbName$suffix')),
          );
        }
      }
      for (final root in kManagedRoots) {
        final recMedia = Directory(p.join(recovery.path, 'media', root));
        if (recMedia.existsSync()) {
          _safeDeleteDir(Directory(p.join(documentsDir.path, root)));
          _moveDirIfExists(
            recMedia,
            Directory(p.join(documentsDir.path, root)),
          );
        }
      }
      _writeReceipt('rolledBack', marker.operationId);
      _safeDelete(_markerFile);
      return RestoreOutcome(RestoreOutcomeKind.rolledBack, marker.operationId);
    } catch (_) {
      // Even rollback failed: stop, keep marker + recovery for manual safety.
      return RestoreOutcome(RestoreOutcomeKind.fatal, marker.operationId);
    }
  }

  // ---- Helpers ----

  bool _preparedIntact(Directory prepared, RestoreMarker marker) {
    final db = File(p.join(prepared.path, kLiveDbName));
    return db.existsSync() && _sha256(db) == marker.preparedDbSha256;
  }

  bool _pathsSafe(RestoreMarker m) {
    bool ok(String rel) {
      final norm = normalizeRelativePath(rel);
      if (norm == null) return false;
      return norm.startsWith('restore_staging/') ||
          norm.startsWith('recovery/');
    }

    if (!ok(m.stagingRelPath) || !ok(m.recoveryRelPath)) return false;
    for (final f in m.managedFiles) {
      if (normalizeRelativePath(f.relativePath) == null) return false;
    }
    return true;
  }

  bool _dbHealthy(File db) {
    try {
      final d = sqlite3.open(db.path, mode: OpenMode.readOnly);
      try {
        final uv = d.select('PRAGMA user_version').first.values.first as int;
        if (uv != 7) return false;
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

  void _moveIfExists(File src, File dst) {
    if (!src.existsSync()) return;
    dst.parent.createSync(recursive: true);
    if (dst.existsSync()) _safeDelete(dst);
    src.renameSync(dst.path);
  }

  void _moveDirIfExists(Directory src, Directory dst) {
    if (!src.existsSync()) return;
    dst.parent.createSync(recursive: true);
    if (dst.existsSync()) _safeDeleteDir(dst);
    src.renameSync(dst.path);
  }

  void _safeDelete(File f) {
    try {
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  void _safeDeleteDir(Directory d) {
    try {
      if (d.existsSync()) d.deleteSync(recursive: true);
    } catch (_) {}
  }

  void _writeReceipt(String status, String operationId) {
    try {
      final tmp = File('${_receiptFile.path}.tmp');
      tmp.writeAsStringSync(
        '{"status":"$status","operationId":"$operationId",'
        '"atUtc":"${DateTime.now().toUtc().toIso8601String()}"}',
        flush: true,
      );
      tmp.renameSync(_receiptFile.path);
    } catch (_) {}
  }

  String _sha256(File f) =>
      crypto.sha256.convert(f.readAsBytesSync()).toString();
}
