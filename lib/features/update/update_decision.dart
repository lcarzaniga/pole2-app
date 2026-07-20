import 'model/update_release.dart';

/// What the "Aggiorna" tap should do, once we know whether a restore is pending
/// and what the release declares. Pure — no I/O, no Flutter, no side effects.
enum UpdatePreflight {
  /// A restore is pending/in progress: do not download or install.
  blockedByRestore,

  /// A risk-flagged release: offer the backup-before-update choice first.
  backupChoice,

  /// An ordinary patch: go straight to the download (current one-tap flow).
  downloadDirectly,
}

/// The single, testable rule mapping (restore state, release) → next step.
UpdatePreflight decideUpdatePreflight({
  required bool restorePending,
  required UpdateRelease release,
}) {
  if (restorePending) return UpdatePreflight.blockedByRestore;
  if (release.needsBackupPrompt) return UpdatePreflight.backupChoice;
  return UpdatePreflight.downloadDirectly;
}

/// The user's answer to the three-way backup proposal.
enum BackupChoice { create, without, cancel }

/// Orchestrates the backup-before-update flow with every effect injected, so the
/// whole decision path is unit-testable without dialogs, navigation, or Drift.
///
/// Returns true iff the update should proceed to download. Guarantees:
///  - a restore-pending release never proceeds (and calls [onBlockedByRestore]);
///  - an ordinary release proceeds immediately (no extra prompt);
///  - a risk-flagged release proceeds only after a **successful** backup
///    ([runBackup] → true) or an explicit continue-without acknowledgment
///    ([askContinueWithout] → true);
///  - a cancelled/failed backup, or a declined acknowledgment, loops back to the
///    three-way choice and never starts the download;
///  - "Annulla" ends the flow without starting anything.
Future<bool> runUpdatePreflight({
  required bool restorePending,
  required UpdateRelease release,
  required Future<void> Function() onBlockedByRestore,
  required Future<BackupChoice> Function() askBackupChoice,
  required Future<bool> Function() runBackup,
  required Future<bool> Function() askContinueWithout,
}) async {
  switch (decideUpdatePreflight(
    restorePending: restorePending,
    release: release,
  )) {
    case UpdatePreflight.blockedByRestore:
      await onBlockedByRestore();
      return false;
    case UpdatePreflight.downloadDirectly:
      return true;
    case UpdatePreflight.backupChoice:
      while (true) {
        switch (await askBackupChoice()) {
          case BackupChoice.cancel:
            return false;
          case BackupChoice.without:
            if (await askContinueWithout()) return true;
            break; // declined → back to the three-way choice
          case BackupChoice.create:
            if (await runBackup()) return true;
            break; // cancelled/failed backup → back to the three-way choice
        }
      }
  }
}
