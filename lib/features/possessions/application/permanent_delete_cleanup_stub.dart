import 'permanent_delete_result.dart';

/// Web/other-platform stub: there is no managed photo store here, so there is
/// nothing to clean. Imports nothing native.
Future<FileCleanupReport> cleanupOrphanFiles({
  required List<String> normalizedPaths,
  required Future<bool> Function(String normalizedPath) stillReferenced,
}) async => const FileCleanupReport();
