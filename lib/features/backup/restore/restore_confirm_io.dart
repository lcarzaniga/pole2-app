import 'package:path_provider/path_provider.dart';

import 'restore_swapper.dart';

/// Confirms a freshly restored install once the **normal** Drift app has proven
/// it can open, migrate and query the restored database. Called after the app
/// reaches a stable post-bootstrap state, with [probe] running a minimal
/// known-safe read through the normal `AppDatabase`/Drift provider (returning
/// `true` on success, `false`/throwing on any failure).
///
/// See [RestoreSwapper.confirmInstalled] for the exact semantics. Never throws.
Future<void> confirmRestoreIfPending({
  required Future<bool> Function() probe,
}) async {
  try {
    final docs = await getApplicationDocumentsDirectory();
    await RestoreSwapper(docs).confirmInstalled(probe);
  } catch (_) {
    // Never let confirmation break a working app.
  }
}
