/// Pure, platform-agnostic results for M8.2C "Libera spazio" (no `dart:io`, no
/// Drift), so the scanner/planner, the coordinator and the UI all speak the same
/// terms and the flow is fully unit-testable and web-safe.
library;

/// One reclaimable orphan photograph: a **normalized** relative path under
/// `photos/` and its observed byte size at scan time.
class OrphanCandidate {
  const OrphanCandidate({required this.relativePath, required this.byteSize});
  final String relativePath;
  final int byteSize;
}

/// The read-only scan outcome.
///
/// [aborted] is set when a stored `Files.relativePath` is unsafe or cannot be
/// normalized reliably — the scan stops calmly rather than risk misclassifying a
/// still-referenced file. [supported] is false on web/other platforms.
class StorageScanResult {
  const StorageScanResult({
    this.candidates = const [],
    this.aborted = false,
    this.supported = true,
  });

  final List<OrphanCandidate> candidates;
  final bool aborted;
  final bool supported;

  bool get isEmpty => candidates.isEmpty;
  int get count => candidates.length;

  /// Sum of candidate sizes, de-duplicated by path and saturating on overflow
  /// (sizes are non-negative; a pathological total never wraps to a nonsense
  /// number).
  int get totalBytes {
    final seen = <String>{};
    var sum = 0;
    for (final c in candidates) {
      if (!seen.add(c.relativePath)) continue; // never double-count a path
      if (c.byteSize <= 0) continue;
      final next = sum + c.byteSize;
      sum = next < sum ? sum : next; // saturate rather than overflow
    }
    return sum;
  }
}

/// What the deletion phase actually did — observed, never assumed.
///
/// [preserved] counts candidates a re-check deliberately left untouched (now
/// referenced, unsafe, a symlink/dir, or modified this session): a safety hold,
/// never a failure. [reclaimedBytes] is the actual freed total (re-measured at
/// delete time), not the earlier estimate; missing files free nothing.
class StorageCleanupReport {
  const StorageCleanupReport({
    this.deleted = 0,
    this.missing = 0,
    this.failed = 0,
    this.preserved = 0,
    this.reclaimedBytes = 0,
    this.failedPaths = const [],
  });

  final int deleted;
  final int missing;
  final int failed;
  final int preserved;
  final int reclaimedBytes;
  final List<String> failedPaths;

  bool get hasFailures => failed > 0;
  int get considered => deleted + missing + failed + preserved;
}
