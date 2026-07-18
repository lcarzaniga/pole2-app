import 'dart:io';

/// A file that will go into the backup, resolved from the snapshot DB.
class PlannedFile {
  const PlannedFile({
    required this.fileId,
    required this.relativePath,
    required this.archivePath,
    required this.source,
    required this.referenceKinds,
  });

  final String fileId;
  final String relativePath; // canonical, e.g. photos/uuid.jpg
  final String archivePath; // files/photos/uuid.jpg
  final File source;
  final List<String> referenceKinds;
}

/// The result of enumerating a snapshot: what to archive, plus any warnings
/// (e.g. a dormant/soft-deleted photo whose file is missing and was skipped).
class BackupPlan {
  const BackupPlan({
    required this.files,
    required this.warnings,
    required this.counts,
  });

  final List<PlannedFile> files;
  final List<String> warnings;
  final Map<String, int> counts;
}

/// Raised when the backup cannot be made complete — an **active** cover/gallery
/// reference is missing on disk, or a stored path is unsafe. The message names
/// the affected object so the UI can explain it calmly.
class BackupIncompleteException implements Exception {
  const BackupIncompleteException(this.message);
  final String message;
  @override
  String toString() => 'BackupIncompleteException: $message';
}
