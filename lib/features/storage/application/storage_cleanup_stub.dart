import 'storage_cleanup_result.dart';

/// Web/other-platform stub: there is no managed photo store here, so the scan is
/// unsupported and there is nothing to delete. Imports nothing native.
Future<StorageScanResult> scanOrphanPhotos({
  required Future<List<String>> Function() storedRelativePaths,
  required DateTime sessionCutoff,
}) async => const StorageScanResult(supported: false);

Future<StorageCleanupReport> deleteOrphans({
  required List<OrphanCandidate> candidates,
  required Future<List<String>> Function() storedRelativePaths,
  required DateTime sessionCutoff,
}) async => const StorageCleanupReport();
