import '../../../shared/platform/photo_types.dart' show PhotoOutcome;

/// A photograph captured/imported into the app-private **temporary** import area
/// but not yet part of `photos/` or the database (M8.2D).
///
/// It carries everything a later, crash-safe promotion needs: the owning
/// [operationId], a Pole²-generated [fileId], the current [tempRelativePath]
/// (under `photo_imports/<operationId>/`), the pre-generated [finalRelativePath]
/// (under `photos/`), the observed [byteSize] and the [mimeType]. It is a
/// deliberately distinct type — never a persisted [StoredPhoto].
class StagedPhoto {
  const StagedPhoto({
    required this.operationId,
    required this.fileId,
    required this.tempRelativePath,
    required this.finalRelativePath,
    required this.byteSize,
    required this.mimeType,
  });

  final String operationId;
  final String fileId;
  final String tempRelativePath;
  final String finalRelativePath;
  final int byteSize;
  final String mimeType;
}

/// One capture/import operation — one or more [photos] staged together under a
/// single [operationId] (and a single durable marker).
class StagedImport {
  const StagedImport({required this.operationId, required this.photos});

  final String operationId;
  final List<StagedPhoto> photos;

  bool get isEmpty => photos.isEmpty;
}

/// The result of a staging attempt — capture outcome plus the [import] on
/// success. Cancellation/denied/failure carry no import (same calm model as
/// [PhotoOutcome]).
class PhotoStageResult {
  const PhotoStageResult.success(StagedImport this.import)
    : outcome = PhotoOutcome.success;
  const PhotoStageResult.cancelled()
    : outcome = PhotoOutcome.cancelled,
      import = null;
  const PhotoStageResult.permissionDenied()
    : outcome = PhotoOutcome.permissionDenied,
      import = null;
  const PhotoStageResult.failed()
    : outcome = PhotoOutcome.failed,
      import = null;

  final PhotoOutcome outcome;
  final StagedImport? import;
}

/// How a promote-then-commit attempt ended.
enum PhotoPromoteOutcome {
  /// Files promoted to `photos/` and the database transaction committed.
  committed,

  /// Promotion (path validation or rename) failed before any DB change; the
  /// staged/promoted files were reconciled. No database change.
  promotionFailed,

  /// The database transaction failed after promotion; the promoted final files
  /// were removed (or left recoverable for startup). No database change.
  commitFailed,
}

/// One committed relationship the DB transaction must create for a promoted
/// file: the pre-generated [fileId] and its [relativePath] under `photos/`.
class StagedPhotoCommit {
  const StagedPhotoCommit({
    required this.fileId,
    required this.relativePath,
    required this.mimeType,
    required this.byteSize,
    this.asCover = false,
  });

  final String fileId;
  final String relativePath;
  final String mimeType;
  final int byteSize;
  final bool asCover;

  StagedPhotoCommit copyWith({bool? asCover}) => StagedPhotoCommit(
    fileId: fileId,
    relativePath: relativePath,
    mimeType: mimeType,
    byteSize: byteSize,
    asCover: asCover ?? this.asCover,
  );
}

/// Extracts the DB-commit descriptors for a staged import. [coverFirst] marks
/// the first photo as the cover (used by the create-with-photo flow).
List<StagedPhotoCommit> commitsFor(
  StagedImport import, {
  bool coverFirst = false,
}) {
  return [
    for (var i = 0; i < import.photos.length; i++)
      StagedPhotoCommit(
        fileId: import.photos[i].fileId,
        relativePath: import.photos[i].finalRelativePath,
        mimeType: import.photos[i].mimeType,
        byteSize: import.photos[i].byteSize,
        asCover: coverFirst && i == 0,
      ),
  ];
}

/// What a startup reconciliation pass did — observed, for logging/tests.
class PhotoImportReconcileReport {
  const PhotoImportReconcileReport({
    this.abandonedPrepared = 0,
    this.keptCommitted = 0,
    this.deletedOrphans = 0,
    this.cleanedCorrupt = 0,
  });

  final int abandonedPrepared;
  final int keptCommitted;
  final int deletedOrphans;
  final int cleanedCorrupt;
}
