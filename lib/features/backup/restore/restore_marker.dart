import 'dart:convert';
import 'dart:io';

/// The crash-safe restore state machine's phases. The swap is not a single
/// atomic operation, so the marker records exactly how far it got; the bootstrap
/// resumes or rolls back from here idempotently.
enum RestorePhase {
  prepared,
  oldDataMoving,
  oldDataMoved,
  newDataInstalling,
  newDataInstalled,
  verified,
  rollbackRequired,
  rolledBack,
  committed,
}

/// One managed file expected in the restored installation.
class RestoreManagedFile {
  const RestoreManagedFile({
    required this.relativePath,
    required this.sha256,
    required this.byteSize,
  });

  final String relativePath; // canonical, e.g. photos/uuid.jpg
  final String sha256;
  final int byteSize;

  Map<String, dynamic> toJson() => {
    'relativePath': relativePath,
    'sha256': sha256,
    'byteSize': byteSize,
  };

  static RestoreManagedFile fromJson(Map<String, dynamic> j) =>
      RestoreManagedFile(
        relativePath: j['relativePath'] as String,
        sha256: j['sha256'] as String,
        byteSize: (j['byteSize'] as num).toInt(),
      );
}

/// The durable pending-restore marker. Contains **no password** and only paths
/// relative to the app documents directory (validated on read). Written
/// atomically (temp file + rename).
class RestoreMarker {
  const RestoreMarker({
    required this.operationId,
    required this.stagingRelPath,
    required this.recoveryRelPath,
    required this.createdAtUtc,
    required this.phase,
    required this.attemptCount,
    required this.preparedDbSha256,
    required this.managedFiles,
    this.markerVersion = 1,
  });

  final int markerVersion;
  final String operationId;
  final String stagingRelPath;
  final String recoveryRelPath;
  final String createdAtUtc;
  final RestorePhase phase;
  final int attemptCount;
  final String preparedDbSha256;
  final List<RestoreManagedFile> managedFiles;

  RestoreMarker copyWith({RestorePhase? phase, int? attemptCount}) =>
      RestoreMarker(
        markerVersion: markerVersion,
        operationId: operationId,
        stagingRelPath: stagingRelPath,
        recoveryRelPath: recoveryRelPath,
        createdAtUtc: createdAtUtc,
        phase: phase ?? this.phase,
        attemptCount: attemptCount ?? this.attemptCount,
        preparedDbSha256: preparedDbSha256,
        managedFiles: managedFiles,
      );

  Map<String, dynamic> toJson() => {
    'markerVersion': markerVersion,
    'operationId': operationId,
    'stagingRelPath': stagingRelPath,
    'recoveryRelPath': recoveryRelPath,
    'createdAtUtc': createdAtUtc,
    'phase': phase.name,
    'attemptCount': attemptCount,
    'preparedDbSha256': preparedDbSha256,
    'managedFiles': managedFiles.map((f) => f.toJson()).toList(),
  };

  static RestoreMarker fromJson(Map<String, dynamic> j) => RestoreMarker(
    markerVersion: (j['markerVersion'] as num?)?.toInt() ?? 1,
    operationId: j['operationId'] as String,
    stagingRelPath: j['stagingRelPath'] as String,
    recoveryRelPath: j['recoveryRelPath'] as String,
    createdAtUtc: j['createdAtUtc'] as String,
    phase: RestorePhase.values.byName(j['phase'] as String),
    attemptCount: (j['attemptCount'] as num).toInt(),
    preparedDbSha256: j['preparedDbSha256'] as String,
    managedFiles: (j['managedFiles'] as List)
        .map((e) => RestoreManagedFile.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  /// Atomically writes [marker] to [markerFile] (temp + rename). Throws on IO
  /// failure so callers never proceed believing a marker exists when it doesn't.
  static void writeAtomic(File markerFile, RestoreMarker marker) {
    final tmp = File('${markerFile.path}.tmp');
    tmp.writeAsStringSync(jsonEncode(marker.toJson()), flush: true);
    tmp.renameSync(markerFile.path);
  }

  /// Reads the marker, or null if absent. Returns null (not throw) on a corrupt
  /// marker so the bootstrap can treat it as "unresolvable" and clean up.
  static RestoreMarker? readOrNull(File markerFile) {
    if (!markerFile.existsSync()) return null;
    try {
      return fromJson(
        jsonDecode(markerFile.readAsStringSync()) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Written the moment the pre-DB swap has installed and verified the restored
/// data (raw sqlite level) — but **before** the normal Drift app launch has
/// proven it can open, migrate and query. Its presence on a later startup means
/// "the restored app never confirmed" → roll back. No password/personal content.
class RestoreUnconfirmed {
  const RestoreUnconfirmed({
    required this.operationId,
    required this.recoveryRelPath,
    required this.installedDbSha256,
    required this.createdAtUtc,
    this.markerVersion = 1,
  });

  final int markerVersion;
  final String operationId;
  final String recoveryRelPath;
  final String installedDbSha256;
  final String createdAtUtc;

  Map<String, dynamic> toJson() => {
    'markerVersion': markerVersion,
    'operationId': operationId,
    'recoveryRelPath': recoveryRelPath,
    'installedDbSha256': installedDbSha256,
    'createdAtUtc': createdAtUtc,
  };

  static RestoreUnconfirmed fromJson(Map<String, dynamic> j) =>
      RestoreUnconfirmed(
        markerVersion: (j['markerVersion'] as num?)?.toInt() ?? 1,
        operationId: j['operationId'] as String,
        recoveryRelPath: j['recoveryRelPath'] as String,
        installedDbSha256: j['installedDbSha256'] as String,
        createdAtUtc: j['createdAtUtc'] as String,
      );

  static void writeAtomic(File f, RestoreUnconfirmed m) {
    final tmp = File('${f.path}.tmp');
    tmp.writeAsStringSync(jsonEncode(m.toJson()), flush: true);
    tmp.renameSync(f.path);
  }

  /// Returns the marker, null if absent, or throws-free 'corrupt' sentinel via
  /// [corrupt] flag: callers must distinguish "absent" from "present but bad".
  static RestoreUnconfirmed? readOrNull(File f) {
    if (!f.existsSync()) return null;
    try {
      return fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

/// Written by the *normal* app launch once Drift has opened the restored data
/// and a real query has succeeded. Authorizes deleting the emergency recovery
/// snapshot on the next startup.
///
/// Confirmation is performed as an **atomic rename** of the unconfirmed marker
/// to `restore_confirmed.json` (see `RestoreSwapper.confirmInstalled`) — so it
/// carries exactly the same fields the unconfirmed marker had, and confirmed and
/// unconfirmed state can never coexist through the normal path.
class RestoreConfirmed {
  const RestoreConfirmed({
    required this.operationId,
    required this.recoveryRelPath,
    required this.installedDbSha256,
    required this.createdAtUtc,
    this.markerVersion = 1,
  });

  final int markerVersion;
  final String operationId;
  final String recoveryRelPath;
  final String installedDbSha256;
  final String createdAtUtc;

  Map<String, dynamic> toJson() => {
    'markerVersion': markerVersion,
    'operationId': operationId,
    'recoveryRelPath': recoveryRelPath,
    'installedDbSha256': installedDbSha256,
    'createdAtUtc': createdAtUtc,
  };

  static RestoreConfirmed fromJson(Map<String, dynamic> j) => RestoreConfirmed(
    markerVersion: (j['markerVersion'] as num?)?.toInt() ?? 1,
    operationId: j['operationId'] as String,
    recoveryRelPath: j['recoveryRelPath'] as String,
    installedDbSha256: j['installedDbSha256'] as String,
    createdAtUtc: j['createdAtUtc'] as String,
  );

  static void writeAtomic(File f, RestoreConfirmed m) {
    final tmp = File('${f.path}.tmp');
    tmp.writeAsStringSync(jsonEncode(m.toJson()), flush: true);
    tmp.renameSync(f.path);
  }

  static RestoreConfirmed? readOrNull(File f) {
    if (!f.existsSync()) return null;
    try {
      return fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
