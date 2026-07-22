import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/managed_roots.dart';
import '../../backup/domain/safe_path.dart';
import 'permanent_delete_result.dart';

/// Deletes the physical bytes of already-orphaned media under `photos/`, one
/// path at a time, **repeating the reference safety check immediately before
/// each deletion** ([stillReferenced]). Runs only after the database commit.
///
/// Never throws: every candidate resolves to exactly one counted outcome
/// (deleted / missing / failed / preserved), so the caller can report an
/// observed result. A path that cannot be normalized or is not under the
/// managed `photos/` root, or one the re-check finds still referenced, is
/// *preserved* (left untouched) — a safety hold, never a failure.
Future<FileCleanupReport> cleanupOrphanFiles({
  required List<String> normalizedPaths,
  required Future<bool> Function(String normalizedPath) stillReferenced,
}) async {
  if (normalizedPaths.isEmpty) return const FileCleanupReport();

  final String docs;
  try {
    docs = (await getApplicationDocumentsDirectory()).path;
  } catch (_) {
    // Storage unresolvable → remove nothing; report as pending, not lost.
    return FileCleanupReport(
      failed: normalizedPaths.length,
      failedPaths: List.of(normalizedPaths),
    );
  }

  var deleted = 0;
  var missing = 0;
  var failed = 0;
  var preserved = 0;
  final failedPaths = <String>[];

  for (final path in normalizedPaths) {
    // Defensive: only ever touch a safe path inside the managed photos/ root.
    final norm = normalizeRelativePath(path);
    if (norm == null || !isUnderManagedRoot(norm)) {
      preserved++;
      continue;
    }
    // Repeat the reference safety check right before deleting the bytes.
    bool referenced;
    try {
      referenced = await stillReferenced(norm);
    } catch (_) {
      referenced = true; // unknown → preserve; never risk a shared file
    }
    if (referenced) {
      preserved++;
      continue;
    }

    final file = File(p.join(docs, norm));
    try {
      if (!file.existsSync()) {
        missing++;
        continue;
      }
      file.deleteSync();
      deleted++;
    } catch (_) {
      failed++;
      failedPaths.add(norm);
    }
  }

  return FileCleanupReport(
    deleted: deleted,
    missing: missing,
    failed: failed,
    preserved: preserved,
    failedPaths: failedPaths,
  );
}

/// True for a real file under `photos/` (never the bare `photos` directory).
