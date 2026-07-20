import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// True when a restore has been confirmed and is awaiting the pre-DB swap on the
/// next launch — i.e. the durable `restore_pending.json` marker exists in the
/// app documents directory (written by `RestoreController.confirm`, consumed by
/// the bootstrap swapper).
///
/// Read-only and best-effort: it never writes or deletes, and any error is
/// treated as "not pending" so the check can never *erroneously* block an
/// update. The updater also consults the in-memory restore/backup providers for
/// the live session; this covers the across-restart case.
Future<bool> isRestorePendingOnDisk() async {
  try {
    final docs = await getApplicationDocumentsDirectory();
    return File(p.join(docs.path, 'restore_pending.json')).existsSync();
  } catch (_) {
    return false;
  }
}
