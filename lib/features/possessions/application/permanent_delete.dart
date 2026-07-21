import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/daos/possessions_dao.dart';
import '../../backup/domain/safe_path.dart';
import '../../backup/restore/restore_activity.dart';
import '../../backup/restore/restore_pending.dart';
import 'permanent_delete_cleanup.dart';
import 'permanent_delete_result.dart';
import 'possession_providers.dart';

/// UI-facing entry point for M8.2A permanent deletion: reads the operation
/// guards from the (read-only) facades, then delegates to the pure
/// [runPermanentDelete] core.
///
/// Web-safe: it speaks only to facades ([isRestorePendingOnDisk],
/// [isRestoreBusy]/[isBackupBusy]) and the pure-Drift DAO, never to the native
/// backup/restore stack directly.
Future<PermanentDeleteResult> permanentlyDeletePossession(
  WidgetRef ref,
  String id,
) async {
  final restoreBlocked = await isRestorePendingOnDisk() || isRestoreBusy(ref);
  return runPermanentDelete(
    dao: ref.read(possessionsDaoProvider),
    id: id,
    blockedByRestore: restoreBlocked,
    blockedByBackup: isBackupBusy(ref),
  );
}

/// The pure coordinator core: guards → the transactional database phase → the
/// post-commit filesystem cleanup, mapped to a single [PermanentDeleteResult].
/// Takes plain values (no [WidgetRef]) so it is fully unit-testable.
///
/// The database commit is the atomic safety boundary: if the process dies (or
/// cleanup fails) after it, the leftover files are already unreferenced orphans
/// — reclaimable later — never a still-referenced file and never corruption.
Future<PermanentDeleteResult> runPermanentDelete({
  required PossessionsDao dao,
  required String id,
  bool blockedByRestore = false,
  bool blockedByBackup = false,
}) async {
  // 1) Guards — refuse and change nothing while a restore or backup is in
  // flight (or a restore is pending across a restart). Restore takes priority.
  if (blockedByRestore) {
    return const PermanentDeleteResult(PermanentDeleteStatus.blockedByRestore);
  }
  if (blockedByBackup) {
    return const PermanentDeleteResult(PermanentDeleteStatus.blockedByBackup);
  }

  // 2) Database phase — a single transaction that either commits or throws.
  final PermanentDeleteDbResult db;
  try {
    db = await dao.permanentlyDelete(id);
  } catch (_) {
    return const PermanentDeleteResult(
      PermanentDeleteStatus.failedBeforeCommit,
    );
  }

  switch (db.outcome) {
    case PermanentDeleteDbOutcome.notFound:
      return const PermanentDeleteResult(PermanentDeleteStatus.notFound);
    case PermanentDeleteDbOutcome.notRemoved:
      return const PermanentDeleteResult(
        PermanentDeleteStatus.rejectedNotRemoved,
      );
    case PermanentDeleteDbOutcome.deleted:
      break;
  }

  // 3) Filesystem phase — post-commit, best-effort. Take a fresh view of the
  // surviving relative paths and use it both to filter shared paths out and as
  // the re-check the cleanup repeats immediately before each byte deletion.
  final surviving = <String>{
    for (final raw in await dao.survivingFileRelativePaths())
      ?normalizeRelativePath(raw),
  };
  final candidates = <String>[];
  for (final raw in db.removedFilePaths) {
    final n = normalizeRelativePath(raw);
    if (n == null || !n.startsWith('photos/')) continue;
    if (surviving.contains(n)) continue; // a surviving row maps it → preserve
    candidates.add(n);
  }

  final report = await cleanupOrphanFiles(
    normalizedPaths: candidates,
    stillReferenced: (n) async => surviving.contains(n),
  );

  return PermanentDeleteResult(
    report.hasFailures
        ? PermanentDeleteStatus.deletedWithPendingFileCleanup
        : PermanentDeleteStatus.deleted,
    cleanup: report,
  );
}
