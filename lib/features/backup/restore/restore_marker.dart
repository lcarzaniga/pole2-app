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
