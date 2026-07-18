import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../domain/safe_path.dart';
import 'restore_marker.dart';

/// Managed media roots under the documents dir. **Invariant (M6.x): `photos/` is
/// the only real managed-file root** — every `Files.relativePath` the app writes
/// lives under it (see `photo_store_io.dart`). If a future milestone adds another
/// managed root, it MUST be added here so recovery/rollback preserves it; the
/// enumerator/rollback tests assert this stays in sync.
const List<String> kManagedRoots = ['photos'];
const String kLiveDbName = 'project_kobe.sqlite';
const int kMaxRestoreAttempts = 2;

enum RestoreOutcomeKind {
  /// Installed + verified at the sqlite level, awaiting the app's confirmation.
  installedUnconfirmed,

  /// Rolled back to the emergency snapshot.
  rolledBack,

  /// Could not safely resolve — everything preserved for manual recovery.
  fatal,

  /// Nothing to do (or recovery cleanup after a confirmed restore).
  none,
}

class RestoreOutcome {
  const RestoreOutcome(this.kind, [this.operationId]);
  final RestoreOutcomeKind kind;
  final String? operationId;
}

/// Resolves restore state before the normal database opens. Two-phase safety:
/// the pre-DB swap only installs + verifies at the sqlite level and records an
/// **unconfirmed** marker; the restore is confirmed only after the normal Drift
/// app launch runs a real query (see `restore_confirm.dart`). A startup that
/// finds an *unconfirmed* marker (the confirming launch never completed) rolls
/// back. Recovery is deleted only when a confirmed marker authorizes it, or a
/// completed rollback makes it obsolete — never merely because a marker is
/// absent. Pure `dart:io` + `sqlite3`; unit-testable under [documentsDir].
class RestoreSwapper {
  RestoreSwapper(this.documentsDir);

  final Directory documentsDir;

  File _f(String name) => File(p.join(documentsDir.path, name));
  File get _pendingFile => _f('restore_pending.json');
  File get _unconfirmedFile => _f('restore_unconfirmed.json');
  File get _confirmedFile => _f('restore_confirmed.json');
  File get _receiptFile => _f('restore_result.json');
  Directory get _stagingRoot =>
      Directory(p.join(documentsDir.path, 'restore_staging'));
  Directory get _recoveryRoot =>
      Directory(p.join(documentsDir.path, 'recovery'));

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

  RestoreOutcome run() {
    assert(kManagedRoots.isNotEmpty, 'at least one managed root required');

    // 1) A pending swap takes priority.
    if (_pendingFile.existsSync()) {
      final marker = RestoreMarker.readOrNull(_pendingFile);
      if (marker == null) {
        // Corrupt pending: if any restore data exists we must not guess which
        // dataset to drop — enter the safe/fatal path and delete nothing.
        if (_hasRestoreData()) {
          return const RestoreOutcome(RestoreOutcomeKind.fatal);
        }
        _safeDelete(_pendingFile);
        return const RestoreOutcome(RestoreOutcomeKind.none);
      }
      if (!_pathsSafe(marker.stagingRelPath, marker.recoveryRelPath)) {
        if (_hasRestoreData()) {
          return RestoreOutcome(RestoreOutcomeKind.fatal, marker.operationId);
        }
        _safeDelete(_pendingFile);
        return const RestoreOutcome(RestoreOutcomeKind.none);
      }
      var m = marker.copyWith(attemptCount: marker.attemptCount + 1);
      RestoreMarker.writeAtomic(_pendingFile, m);
      if (m.attemptCount > kMaxRestoreAttempts) {
        return _rollbackPending(m);
      }
      try {
        return _install(m);
      } catch (_) {
        return _rollbackPending(m);
      }
    }

    // 2) A confirmed restore takes precedence over any unconfirmed marker (the
    // atomic rename means they can't normally coexist; this defends against an
    // impossible/legacy dual-marker state). A matching confirmed install is
    // never rolled back; a conflicting one is left untouched (fatal).
    if (_confirmedFile.existsSync()) {
      final c = RestoreConfirmed.readOrNull(_confirmedFile);
      if (c == null) {
        // Corrupt confirmed marker: never guess when data is present.
        if (_hasRestoreData()) {
          return const RestoreOutcome(RestoreOutcomeKind.fatal);
        }
        _safeDelete(_confirmedFile);
        return const RestoreOutcome(RestoreOutcomeKind.none);
      }
      if (_unconfirmedFile.existsSync()) {
        final u = RestoreUnconfirmed.readOrNull(_unconfirmedFile);
        // Unreadable, or a different operation → genuinely ambiguous: preserve
        // everything and roll nothing back.
        if (u == null || u.operationId != c.operationId) {
          return RestoreOutcome(RestoreOutcomeKind.fatal, c.operationId);
        }
        // Same operation: the confirmed marker wins; the unconfirmed one is a
        // superseded leftover.
        _safeDelete(_unconfirmedFile);
      }
      if (_pathsSafe(null, c.recoveryRelPath)) {
        _deleteSnapshot(
          Directory(p.join(documentsDir.path, c.recoveryRelPath)),
        );
      }
      _safeDelete(_confirmedFile);
      return const RestoreOutcome(RestoreOutcomeKind.none);
    }

    // 3) An unconfirmed install (no confirmed marker) means the confirming
    // launch never completed → roll back to the preserved installation.
    if (_unconfirmedFile.existsSync()) {
      final u = RestoreUnconfirmed.readOrNull(_unconfirmedFile);
      if (u == null) {
        if (_hasRestoreData()) {
          return const RestoreOutcome(RestoreOutcomeKind.fatal);
        }
        _safeDelete(_unconfirmedFile);
        return const RestoreOutcome(RestoreOutcomeKind.none);
      }
      if (!_pathsSafe(null, u.recoveryRelPath)) {
        return RestoreOutcome(RestoreOutcomeKind.fatal, u.operationId);
      }
      return _rollbackUnconfirmed(u);
    }

    // 4) Nothing pending. Recovery is NEVER swept here (only a confirmed marker
    // or a completed rollback removes it); orphan recovery is preserved.
    return const RestoreOutcome(RestoreOutcomeKind.none);
  }

  /// Sweeps unmarked staging directories — safe only when no pending/unconfirmed
  /// swap is in flight. Never touches recovery.
  void sweepStaging() {
    if (_pendingFile.existsSync() || _unconfirmedFile.existsSync()) return;
    _safeDeleteDir(_stagingRoot);
  }

  /// Confirms a freshly installed restore once the *normal* app has proven it
  /// can query the restored database. [probe] runs a minimal read through the
  /// normal Drift provider (true on success).
  ///
  /// The state transition is a single **atomic rename** of the unconfirmed
  /// marker to `restore_confirmed.json` on the same filesystem — never
  /// "create confirmed, then delete unconfirmed" — so a process death can never
  /// leave both markers. The one-time success receipt is written only *after*
  /// the rename: if the process dies in between, the restore is already
  /// confirmed (a missing success message is acceptable; a wrong rollback is
  /// not). On failure (or nothing pending) state is left untouched so the next
  /// startup rolls back. Never throws — confirmation must never break the app.
  Future<void> confirmInstalled(Future<bool> Function() probe) async {
    try {
      final unconf = RestoreUnconfirmed.readOrNull(_unconfirmedFile);
      if (unconf == null) return; // nothing to confirm (or corrupt → startup)
      bool ok;
      try {
        ok = await probe();
      } catch (_) {
        ok = false;
      }
      if (!ok) return; // next launch will roll back

      // Authoritative, atomic state transition. The unconfirmed marker already
      // holds exactly the fields the confirmed marker needs.
      _unconfirmedFile.renameSync(_confirmedFile.path);
      // Best-effort receipt, strictly after the rename.
      _writeReceipt('success', unconf.operationId);
    } catch (_) {}
  }

  /// Returns the last restore result ('success' | 'rolledBack') exactly once,
  /// then deletes the receipt so the message never repeats. Never throws.
  String? consumeReceipt() {
    try {
      if (!_receiptFile.existsSync()) return null;
      String? status;
      try {
        status =
            (jsonDecode(_receiptFile.readAsStringSync())
                    as Map<String, dynamic>)['status']
                as String?;
      } catch (_) {
        status = null;
      }
      _safeDelete(_receiptFile);
      return status;
    } catch (_) {
      return null;
    }
  }

  // ---- Install (pre-DB), terminating in an *unconfirmed* marker ----

  RestoreOutcome _install(RestoreMarker marker) {
    final prepared = Directory(
      p.join(documentsDir.path, marker.stagingRelPath, 'prepared'),
    );
    final recovery = Directory(
      p.join(documentsDir.path, marker.recoveryRelPath),
    );

    switch (marker.phase) {
      case RestorePhase.prepared:
        if (!_preparedIntact(prepared, marker)) return _rollbackPending(marker);
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
        if (!_verifyInstalled(marker)) return _rollbackPending(marker);
        marker = _advance(marker, RestorePhase.verified);
        continue finish;
      finish:
      case RestorePhase.verified:
      case RestorePhase.committed:
        // Installed + verified at the sqlite level. Record the *unconfirmed*
        // state; the normal app launch confirms after a real Drift query. No
        // success receipt yet, and recovery is kept.
        RestoreUnconfirmed.writeAtomic(
          _unconfirmedFile,
          RestoreUnconfirmed(
            operationId: marker.operationId,
            recoveryRelPath: marker.recoveryRelPath,
            installedDbSha256: marker.preparedDbSha256,
            createdAtUtc: DateTime.now().toUtc().toIso8601String(),
          ),
        );
        _safeDelete(_pendingFile);
        return RestoreOutcome(
          RestoreOutcomeKind.installedUnconfirmed,
          marker.operationId,
        );
      case RestorePhase.rollbackRequired:
      case RestorePhase.rolledBack:
        return _rollbackPending(marker);
    }
  }

  RestoreMarker _advance(RestoreMarker marker, RestorePhase phase) {
    final next = marker.copyWith(phase: phase);
    RestoreMarker.writeAtomic(_pendingFile, next);
    return next;
  }

  // ---- Rollback ----

  RestoreOutcome _rollbackPending(RestoreMarker marker) {
    final out = _rollbackTo(marker.recoveryRelPath, marker.operationId);
    if (out.kind == RestoreOutcomeKind.rolledBack) _safeDelete(_pendingFile);
    return out;
  }

  RestoreOutcome _rollbackUnconfirmed(RestoreUnconfirmed u) {
    final out = _rollbackTo(u.recoveryRelPath, u.operationId);
    if (out.kind == RestoreOutcomeKind.rolledBack) {
      _safeDelete(_unconfirmedFile);
    }
    return out;
  }

  /// Component-guarded rollback: a live component is only removed-and-restored
  /// when the recovery snapshot actually holds a copy — so untouched originals
  /// (before/at a partial snapshot) are never destroyed. After a full restore
  /// the recovery snapshot is obsolete and removed.
  RestoreOutcome _rollbackTo(String recoveryRelPath, String operationId) {
    try {
      final recovery = Directory(p.join(documentsDir.path, recoveryRelPath));
      final recDb = File(p.join(recovery.path, 'db', kLiveDbName));
      if (recDb.existsSync()) {
        for (final suffix in ['', '-wal', '-shm']) {
          _safeDelete(_f('$kLiveDbName$suffix'));
          _moveIfExists(
            File(p.join(recovery.path, 'db', '$kLiveDbName$suffix')),
            _f('$kLiveDbName$suffix'),
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
      _writeReceipt('rolledBack', operationId);
      _deleteSnapshot(recovery); // snapshot consumed
      return RestoreOutcome(RestoreOutcomeKind.rolledBack, operationId);
    } catch (_) {
      return RestoreOutcome(RestoreOutcomeKind.fatal, operationId);
    }
  }

  // ---- Steps (idempotent) ----

  void _snapshotCurrent(Directory recovery) {
    final dbDir = Directory(p.join(recovery.path, 'db'))
      ..createSync(recursive: true);
    for (final suffix in ['', '-wal', '-shm']) {
      _moveIfExists(
        _f('$kLiveDbName$suffix'),
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
    _moveIfExists(File(p.join(prepared.path, kLiveDbName)), _f(kLiveDbName));
    for (final suffix in ['-wal', '-shm']) {
      _safeDelete(_f('$kLiveDbName$suffix'));
    }
    final managed = Directory(p.join(prepared.path, 'managed_files'));
    if (managed.existsSync()) {
      for (final entry in managed.listSync()) {
        final name = p.basename(entry.path);
        if (entry is Directory) {
          _moveDirIfExists(entry, Directory(p.join(documentsDir.path, name)));
        } else if (entry is File) {
          _moveIfExists(entry, _f(name));
        }
      }
    }
  }

  bool _verifyInstalled(RestoreMarker marker) {
    final db = _f(kLiveDbName);
    if (!db.existsSync()) return false;
    if (_sha256(db) != marker.preparedDbSha256) return false;
    if (!_dbHealthy(db)) return false;
    for (final f in marker.managedFiles) {
      final file = _f(f.relativePath);
      if (!file.existsSync() || _sha256(file) != f.sha256) return false;
    }
    return true;
  }

  // ---- Helpers ----

  bool _hasRestoreData() =>
      (_stagingRoot.existsSync() && _stagingRoot.listSync().isNotEmpty) ||
      (_recoveryRoot.existsSync() && _recoveryRoot.listSync().isNotEmpty);

  bool _preparedIntact(Directory prepared, RestoreMarker marker) {
    final db = File(p.join(prepared.path, kLiveDbName));
    return db.existsSync() && _sha256(db) == marker.preparedDbSha256;
  }

  bool _pathsSafe(String? stagingRel, String recoveryRel) {
    bool ok(String rel, String prefix) {
      final norm = normalizeRelativePath(rel);
      return norm != null && norm.startsWith(prefix);
    }

    if (stagingRel != null && !ok(stagingRel, 'restore_staging/')) return false;
    return ok(recoveryRel, 'recovery/');
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

  /// Deletes one recovery snapshot, then prunes now-empty parent directories up
  /// to and including the recovery root. Stops at the first non-empty directory
  /// so a sibling (orphan/another) snapshot is always preserved.
  void _deleteSnapshot(Directory snapshot) {
    _safeDeleteDir(snapshot);
    var dir = snapshot.parent;
    while (p.equals(dir.path, _recoveryRoot.path) ||
        p.isWithin(_recoveryRoot.path, dir.path)) {
      try {
        if (!dir.existsSync() || dir.listSync().isNotEmpty) break;
        dir.deleteSync();
      } catch (_) {
        break;
      }
      dir = dir.parent;
    }
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
