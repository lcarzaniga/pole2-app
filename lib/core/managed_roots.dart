/// The app-managed media roots under the documents directory (M9).
///
/// Every physical media file the app writes lives under exactly one of these
/// top-level roots (relative paths like `photos/<id>.jpg`, `documents/<id>.pdf`).
/// This single, pure (no `dart:io`) list is the source of truth shared by:
/// - the restore snapshot / rollback / recovery (`restore_swapper.dart`);
/// - orphan detection and "Libera spazio" (`storage_cleanup_io.dart`);
/// - permanent single/batch deletion byte cleanup (`permanent_delete.dart`);
/// - the staged media-import promotion + reconciliation (`photo_import*`).
///
/// Backups already archive every file referenced by a restorable row regardless
/// of its root, so adding a root here is what makes it survive
/// restore/rollback and be eligible for orphan cleanup.
library;

const String kPhotosRoot = 'photos';
const String kDocumentsRoot = 'documents';

/// All managed media roots, in a stable order.
const List<String> kManagedMediaRoots = [kPhotosRoot, kDocumentsRoot];

/// True when [normalizedRel] (a normalized forward-slash relative path) sits
/// strictly inside one of the managed roots (e.g. `photos/x`, `documents/y`).
bool isUnderManagedRoot(String normalizedRel) {
  for (final root in kManagedMediaRoots) {
    if (normalizedRel.startsWith('$root/')) return true;
  }
  return false;
}
