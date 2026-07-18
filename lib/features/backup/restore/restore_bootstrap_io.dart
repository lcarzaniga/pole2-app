import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'restore_swapper.dart';

/// Resolves a pending restore (swap or rollback) and cleans transient state.
/// Called once from `main()` before `runApp`. Best-effort and never throws — a
/// bootstrap failure must not prevent the app from starting.
Future<void> runRestoreBootstrap() async {
  try {
    final docs = await getApplicationDocumentsDirectory();
    final outcome = RestoreSwapper(docs).run();

    switch (outcome.kind) {
      case RestoreOutcomeKind.none:
      case RestoreOutcomeKind.rolledBack:
        // No pending restore (or it rolled back): safe to sweep leftover
        // staging and last time's recovery snapshot.
        _sweepStaging(docs);
        _cleanRecovery(docs);
      case RestoreOutcomeKind.committed:
        // A restore just committed: keep one recovery snapshot through this
        // launch; only sweep staging.
        _sweepStaging(docs);
      case RestoreOutcomeKind.fatal:
        // Keep staging + recovery + marker for manual safety; touch nothing.
        break;
    }
  } catch (_) {
    // Never block startup on a bootstrap error.
  }
}

void _sweepStaging(Directory docs) {
  final staging = Directory(p.join(docs.path, 'restore_staging'));
  try {
    if (staging.existsSync()) staging.deleteSync(recursive: true);
  } catch (_) {}
}

void _cleanRecovery(Directory docs) {
  final recovery = Directory(p.join(docs.path, 'recovery'));
  try {
    if (recovery.existsSync()) recovery.deleteSync(recursive: true);
  } catch (_) {}
}
