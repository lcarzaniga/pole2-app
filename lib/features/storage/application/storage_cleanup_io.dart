import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../backup/domain/safe_path.dart';
import 'storage_cleanup_result.dart';

/// M8.2C — scans the app-private `photos/` root for **proven orphan** photographs
/// and (on confirmation) deletes them. Read-only scan; delete is one-by-one
/// `File.delete` with the full safety re-check repeated immediately before each
/// removal. Native (`dart:io`) only.
///
/// A physical regular file under `photos/` is reclaimable only when:
/// - no `Files` row maps its normalized `relativePath`;
/// - it existed before [sessionCutoff] (strictly older last-modified time);
/// - it is a normal file — not a directory or symbolic link;
/// - its canonical path stays inside the canonical `photos/` root;
/// - its relative path passes [normalizeRelativePath].
///
/// If any stored path is unsafe/unnormalizable the scan aborts calmly
/// ([StorageScanResult.aborted]) rather than risk misclassification. Database
/// `Files` rows are never touched: a file mapped by *any* row is protected even
/// if that row currently looks unreferenced.

Future<StorageScanResult> scanOrphanPhotos({
  required Future<List<String>> Function() storedRelativePaths,
  required DateTime sessionCutoff,
}) async {
  final Directory docs;
  try {
    docs = await getApplicationDocumentsDirectory();
  } catch (_) {
    return const StorageScanResult(aborted: true);
  }
  final photosRoot = Directory(p.join(docs.path, 'photos'));
  if (!photosRoot.existsSync()) return const StorageScanResult();

  // Protected set from the live DB — abort on any unsafe stored path.
  final protected = <String>{};
  for (final raw in await storedRelativePaths()) {
    final n = normalizeRelativePath(raw);
    if (n == null) return const StorageScanResult(aborted: true);
    protected.add(n);
  }

  final String canonicalRoot;
  try {
    canonicalRoot = photosRoot.resolveSymbolicLinksSync();
  } catch (_) {
    return const StorageScanResult(aborted: true);
  }

  final List<FileSystemEntity> entries;
  try {
    entries = photosRoot.listSync(followLinks: false);
  } catch (_) {
    return const StorageScanResult(aborted: true);
  }

  final byPath = <String, OrphanCandidate>{};
  for (final e in entries) {
    final c = _classify(
      absPath: e.path,
      docsPath: docs.path,
      canonicalRoot: canonicalRoot,
      protected: protected,
      sessionCutoff: sessionCutoff,
    );
    if (c != null) byPath[c.relativePath] = c; // de-dupe by normalized path
  }

  final candidates = byPath.values.toList()
    ..sort((a, b) => a.relativePath.compareTo(b.relativePath));
  return StorageScanResult(candidates: candidates);
}

/// Deletes [candidates] after re-checking each one live, immediately before the
/// `File.delete`. Never recursive; a failure never stops the rest; missing files
/// are harmless. Returns the observed counts and the *actual* reclaimed bytes.
Future<StorageCleanupReport> deleteOrphans({
  required List<OrphanCandidate> candidates,
  required Future<List<String>> Function() storedRelativePaths,
  required DateTime sessionCutoff,
}) async {
  final Directory docs;
  try {
    docs = await getApplicationDocumentsDirectory();
  } catch (_) {
    return StorageCleanupReport(preserved: candidates.length);
  }
  final photosRoot = Directory(p.join(docs.path, 'photos'));
  final String canonicalRoot;
  try {
    canonicalRoot = photosRoot.resolveSymbolicLinksSync();
  } catch (_) {
    return StorageCleanupReport(preserved: candidates.length);
  }

  // Fresh protected set — a reference that appeared since the scan wins.
  final protected = <String>{};
  for (final raw in await storedRelativePaths()) {
    final n = normalizeRelativePath(raw);
    if (n == null) return StorageCleanupReport(preserved: candidates.length);
    protected.add(n);
  }

  var deleted = 0, missing = 0, failed = 0, preserved = 0, reclaimed = 0;
  final failedPaths = <String>[];
  final seen = <String>{};

  for (final c in candidates) {
    final norm = normalizeRelativePath(c.relativePath);
    // Safe path, under photos/, and never processed twice.
    if (norm == null || !norm.startsWith('photos/') || !seen.add(norm)) {
      preserved++;
      continue;
    }
    if (protected.contains(norm)) {
      preserved++;
      continue;
    }
    final absPath = p.join(docs.path, norm);
    final type = FileSystemEntity.typeSync(absPath, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      missing++;
      continue;
    }
    if (type != FileSystemEntityType.file) {
      preserved++; // a directory or symlink — never touch
      continue;
    }
    // Canonical containment.
    final String canonical;
    try {
      canonical = File(absPath).resolveSymbolicLinksSync();
    } catch (_) {
      preserved++;
      continue;
    }
    if (!(p.equals(canonical, canonicalRoot) ||
        p.isWithin(canonicalRoot, canonical))) {
      preserved++;
      continue;
    }
    // Session cutoff + fresh length, re-measured now.
    final FileStat st;
    try {
      st = File(absPath).statSync();
    } catch (_) {
      preserved++;
      continue;
    }
    if (!st.modified.isBefore(sessionCutoff)) {
      preserved++; // created/modified this session
      continue;
    }
    final size = st.size < 0 ? 0 : st.size;
    try {
      File(absPath).deleteSync(); // non-recursive
      deleted++;
      final next = reclaimed + size;
      reclaimed = next < reclaimed ? reclaimed : next; // saturate
    } catch (_) {
      failed++;
      failedPaths.add(norm);
    }
  }

  return StorageCleanupReport(
    deleted: deleted,
    missing: missing,
    failed: failed,
    preserved: preserved,
    reclaimedBytes: reclaimed,
    failedPaths: failedPaths,
  );
}

/// Decides whether a single listed entry is a reclaimable orphan. Returns null
/// (skip) for anything that is not a proven, safe, pre-session regular file.
OrphanCandidate? _classify({
  required String absPath,
  required String docsPath,
  required String canonicalRoot,
  required Set<String> protected,
  required DateTime sessionCutoff,
}) {
  // Regular file only — directories and symlinks are skipped outright.
  if (FileSystemEntity.typeSync(absPath, followLinks: false) !=
      FileSystemEntityType.file) {
    return null;
  }
  final rel = p.relative(absPath, from: docsPath).replaceAll(r'\', '/');
  final norm = normalizeRelativePath(rel);
  if (norm == null || !norm.startsWith('photos/')) return null;
  if (protected.contains(norm)) return null;

  final String canonical;
  try {
    canonical = File(absPath).resolveSymbolicLinksSync();
  } catch (_) {
    return null;
  }
  if (!(p.equals(canonical, canonicalRoot) ||
      p.isWithin(canonicalRoot, canonical))) {
    return null;
  }

  final FileStat st;
  try {
    st = File(absPath).statSync();
  } catch (_) {
    return null;
  }
  if (!st.modified.isBefore(sessionCutoff)) return null; // this session
  final size = st.size < 0 ? 0 : st.size;
  return OrphanCandidate(relativePath: norm, byteSize: size);
}
