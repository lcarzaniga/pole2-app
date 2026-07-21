import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_session.dart';
import '../../backup/application/backup_controller.dart';
import '../../backup/restore/restore_controller.dart';
import '../../backup/restore/restore_pending.dart';
import '../../possessions/application/permanent_delete_activity.dart';
import '../../possessions/application/possession_providers.dart';
import 'storage_cleanup.dart';
import 'storage_cleanup_result.dart';

/// Where the "Libera spazio" flow is.
enum StoragePhase {
  idle,
  scanning,
  scanned,
  cleaning,
  done,
  scanFailed,
  blocked,
}

/// Immutable UI state for the storage-cleanup flow.
class StorageCleanupState {
  const StorageCleanupState({
    this.phase = StoragePhase.idle,
    this.candidates = const [],
    this.scannedBytes = 0,
    this.report,
    this.blockedReason,
  });

  final StoragePhase phase;
  final List<OrphanCandidate> candidates;
  final int scannedBytes;
  final StorageCleanupReport? report;

  /// 'backup' | 'restore' | 'permanentDelete' when [phase] is
  /// [StoragePhase.blocked].
  final String? blockedReason;

  bool get isBusy =>
      phase == StoragePhase.scanning || phase == StoragePhase.cleaning;
  bool get hasCandidates => candidates.isNotEmpty;
}

/// Which concurrent operation, if any, blocks a storage scan/cleanup — restore
/// takes priority, then backup, then a permanent deletion. Pure and ordered, so
/// the guard precedence is unit-testable without providers.
String? storageBlockedReason({
  required bool restore,
  required bool backup,
  required bool permanentDelete,
}) {
  if (restore) return 'restore';
  if (backup) return 'backup';
  if (permanentDelete) return 'permanentDelete';
  return null;
}

/// The session cutoff for the scan — process start by default; overridable in
/// tests to simulate "before/after this session".
final storageSessionCutoffProvider = Provider<DateTime>((_) => appSessionStart);

final storageCleanupControllerProvider =
    NotifierProvider<StorageCleanupController, StorageCleanupState>(
      StorageCleanupController.new,
    );

/// Single-flight coordinator for M8.2C: a read-only scan, then (on explicit
/// confirmation) a bounded best-effort delete through the native cleanup layer.
/// Refuses while a backup, restore (live or durable-pending) or permanent
/// deletion is active; ignores repeated taps via [StorageCleanupState.isBusy].
class StorageCleanupController extends Notifier<StorageCleanupState> {
  @override
  StorageCleanupState build() => const StorageCleanupState();

  DateTime get _cutoff => ref.read(storageSessionCutoffProvider);

  Future<List<String>> _stored() =>
      ref.read(possessionsDaoProvider).survivingFileRelativePaths();

  Future<String?> _blocked() async {
    final restore =
        await isRestorePendingOnDisk() ||
        ref.read(restoreControllerProvider).isBusy;
    return storageBlockedReason(
      restore: restore,
      backup: ref.read(backupControllerProvider).isBusy,
      permanentDelete: ref.read(permanentDeleteBusyProvider),
    );
  }

  /// Read-only scan. Deletes nothing.
  Future<void> scan() async {
    if (state.isBusy) return;
    final blocked = await _blocked();
    if (blocked != null) {
      state = StorageCleanupState(
        phase: StoragePhase.blocked,
        blockedReason: blocked,
      );
      return;
    }
    state = const StorageCleanupState(phase: StoragePhase.scanning);
    try {
      final res = await scanOrphanPhotos(
        storedRelativePaths: _stored,
        sessionCutoff: _cutoff,
      );
      if (res.aborted || !res.supported) {
        state = const StorageCleanupState(phase: StoragePhase.scanFailed);
        return;
      }
      state = StorageCleanupState(
        phase: StoragePhase.scanned,
        candidates: res.candidates,
        scannedBytes: res.totalBytes,
      );
    } catch (_) {
      state = const StorageCleanupState(phase: StoragePhase.scanFailed);
    }
  }

  /// Deletes the scanned candidates after the same guards. Only valid from the
  /// [StoragePhase.scanned] state with a non-empty candidate list.
  Future<void> cleanup() async {
    if (state.phase != StoragePhase.scanned ||
        state.candidates.isEmpty ||
        state.isBusy) {
      return;
    }
    final blocked = await _blocked();
    if (blocked != null) {
      state = StorageCleanupState(
        phase: StoragePhase.blocked,
        blockedReason: blocked,
      );
      return;
    }
    final candidates = state.candidates;
    state = const StorageCleanupState(phase: StoragePhase.cleaning);
    try {
      final report = await deleteOrphans(
        candidates: candidates,
        storedRelativePaths: _stored,
        sessionCutoff: _cutoff,
      );
      state = StorageCleanupState(phase: StoragePhase.done, report: report);
    } catch (_) {
      // Best-effort: never crash. Report nothing reclaimed.
      state = const StorageCleanupState(
        phase: StoragePhase.done,
        report: StorageCleanupReport(),
      );
    }
  }

  /// Back to the initial state (cancel a shown result, or dismiss done/blocked).
  void reset() => state = const StorageCleanupState();
}
