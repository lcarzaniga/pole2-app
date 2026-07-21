/// Domain results for M8.2A permanent deletion of one *removed* possession.
///
/// Pure and platform-agnostic (no `dart:io`, no Drift): the coordinator, the
/// filesystem-cleanup facade and the UI all speak in these terms, so the flow
/// is fully unit-testable and web-safe.
library;

/// The outcome of a permanent-deletion attempt, from the caller's point of view.
///
/// The distinction between [deleted] and [deletedWithPendingFileCleanup] is
/// observed, not assumed: it reflects the [FileCleanupReport] the filesystem
/// phase actually produced, so partial-cleanup copy is honest.
enum PermanentDeleteStatus {
  /// Rows deleted and every owned orphan byte reclaimed (or already gone).
  deleted,

  /// Rows deleted, but at least one orphan file could not be removed now. The
  /// data is gone from the database; the bytes will be reclaimed later
  /// ("Libera spazio", M8.2B). Never an error state.
  deletedWithPendingFileCleanup,

  /// The possession exists but is not removed (`deletedAt == null`): permanent
  /// deletion is offered only from "Rimossi". Nothing was changed.
  rejectedNotRemoved,

  /// No such possession — including the idempotent second call for an id that
  /// was already permanently deleted. Never reported as a *new* success.
  notFound,

  /// A backup export is in progress; deletion was refused. Nothing was changed.
  blockedByBackup,

  /// A restore is in progress or pending across a restart; deletion was
  /// refused. Nothing was changed.
  blockedByRestore,

  /// The database phase threw before committing. Nothing was changed — the
  /// possession and all its data are intact.
  failedBeforeCommit,
}

/// What the filesystem phase actually did, so the UI reflects an observed
/// result rather than an assumption.
///
/// [preserved] counts candidate paths a defensive re-check found still
/// referenced right before deletion — a safety hold, never a failure, so it
/// does not set [hasFailures].
class FileCleanupReport {
  const FileCleanupReport({
    this.deleted = 0,
    this.missing = 0,
    this.failed = 0,
    this.preserved = 0,
    this.failedPaths = const [],
  });

  /// Files whose bytes were removed.
  final int deleted;

  /// Candidate files that were already absent from disk (nothing to remove).
  final int missing;

  /// Candidate files a delete attempt could not remove (still on disk).
  final int failed;

  /// Candidate paths the pre-deletion safety re-check found still referenced,
  /// so they were deliberately left untouched.
  final int preserved;

  /// The paths behind [failed], for diagnostics/logging (never shown raw).
  final List<String> failedPaths;

  /// True when at least one file could not be removed and remains on disk.
  bool get hasFailures => failed > 0;

  int get considered => deleted + missing + failed + preserved;

  FileCleanupReport copyWith({
    int? deleted,
    int? missing,
    int? failed,
    int? preserved,
    List<String>? failedPaths,
  }) => FileCleanupReport(
    deleted: deleted ?? this.deleted,
    missing: missing ?? this.missing,
    failed: failed ?? this.failed,
    preserved: preserved ?? this.preserved,
    failedPaths: failedPaths ?? this.failedPaths,
  );
}

/// The full result: a [status] plus, when the database phase committed, the
/// [cleanup] report describing what happened to the owned files.
class PermanentDeleteResult {
  const PermanentDeleteResult(this.status, {this.cleanup});

  final PermanentDeleteStatus status;
  final FileCleanupReport? cleanup;
}
