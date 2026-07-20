import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../backup/presentation/backup_launch.dart';
import '../backup/restore/restore_activity.dart';
import '../backup/restore/restore_pending.dart';
import 'android_installer.dart';
import 'model/update_release.dart';
import 'update_decision.dart';
import 'update_downloader.dart';

/// SharedPreferences key: the highest versionCode the user has said "Più tardi"
/// to. The prompt stays hidden until a strictly-newer versionCode is published.
const String kUpdateDismissedKey = 'update_dismissed_vc';

/// The calm, optional update prompt.
///
/// "Aggiorna" runs a preflight (restore guard → optional backup proposal) and
/// then download → SHA-256 verify → install; "Più tardi" persists the dismissed
/// versionCode. Nothing here ever hard-locks the app: even a `mandatory` release
/// keeps "Più tardi"/"Annulla" and the app fully usable — Pole² must never block
/// access to local data because of an update.
Future<void> showUpdateDialog(
  BuildContext context,
  WidgetRef ref,
  UpdateRelease release,
) async {
  final l10n = AppLocalizations.of(context);
  final accept = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.updateAvailableTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.updateAvailableBody(release.versionName)),
            if (release.notes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              for (final n in release.notes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('•  $n'),
                ),
            ],
          ],
        ),
      ),
      actions: [
        // "Più tardi" is always offered — even for a `mandatory` release — so an
        // update can never remove access to the user's local data.
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.updateLater),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.updateNow),
        ),
      ],
    ),
  );

  if (accept == false) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kUpdateDismissedKey, release.versionCode);
    return;
  }
  if (accept != true || !context.mounted) return;

  // Restore/backup preflight: the in-memory check covers the live session; the
  // durable marker covers a restore pending across a restart. Both are behind
  // io/stub facades so no native Drift code enters the web graph.
  final restorePending =
      isRestoreOrBackupBusy(ref) || await isRestorePendingOnDisk();
  if (!context.mounted) return;

  final proceed = await runUpdatePreflight(
    restorePending: restorePending,
    release: release,
    onBlockedByRestore: () => showUpdateRestoreBusy(context),
    askBackupChoice: () => askBackupBeforeUpdate(context),
    runBackup: () => _runBackupForUpdate(context),
    askContinueWithout: () => askContinueWithoutBackup(context),
  );
  if (!proceed || !context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DownloadDialog(release: release),
  );
}

/// Calm, non-blocking notice when a restore is pending. The app stays usable.
Future<void> showUpdateRestoreBusy(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.updateAvailableTitle),
      content: Text(l10n.updateRestoreBusy),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).maybePop(),
          child: Text(l10n.closeButton),
        ),
      ],
    ),
  );
}

/// The three-way "create a backup first?" proposal, shown only for a risk-flagged
/// release. Returns the user's [BackupChoice] (cancel if dismissed).
Future<BackupChoice> askBackupBeforeUpdate(BuildContext context) async {
  if (!context.mounted) return BackupChoice.cancel;
  final l10n = AppLocalizations.of(context);
  final choice = await showDialog<BackupChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.updateBackupTitle),
      content: SingleChildScrollView(child: Text(l10n.updateBackupBody)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(BackupChoice.cancel),
          child: Text(l10n.cancelButton),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(BackupChoice.without),
          child: Text(l10n.updateBackupContinueWithout),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(BackupChoice.create),
          child: Text(l10n.updateBackupCreate),
        ),
      ],
    ),
  );
  return choice ?? BackupChoice.cancel;
}

/// The single secondary acknowledgment before skipping the backup. Returns true
/// only if the user explicitly confirms "Continua".
Future<bool> askContinueWithoutBackup(BuildContext context) async {
  if (!context.mounted) return false;
  final l10n = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.updateWithoutTitle),
      content: SingleChildScrollView(child: Text(l10n.updateWithoutBody)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.updateWithoutBack),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.updateWithoutContinue),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Opens the *existing* Backup screen in "launched for update" mode, reusing the
/// one BackupController. Returns true only when a backup was saved successfully;
/// a cancelled picker, a back-out, or a failure returns false (→ back to the
/// three-way choice), and never starts the download.
Future<bool> _runBackupForUpdate(BuildContext context) async {
  if (!context.mounted) return false;
  final saved = await context.pushNamed<bool>(
    Routes.backupName,
    extra: kBackupLaunchedForUpdate,
  );
  return saved == true;
}

class _DownloadDialog extends StatefulWidget {
  const _DownloadDialog({required this.release});
  final UpdateRelease release;
  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  final UpdateDownloader _downloader = UpdateDownloader();
  StreamSubscription<DownloadState>? _sub;
  DownloadState _state = const DownloadState(DownloadStage.downloading);

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    setState(() => _state = const DownloadState(DownloadStage.downloading));
    _sub?.cancel();
    _sub = _downloader.run(widget.release).listen((s) {
      if (!mounted) return;
      setState(() => _state = s);
      // Installer launched, or user cancelled → close the dialog. A restore
      // block keeps the dialog open with its calm message + Chiudi.
      if (s.stage == DownloadStage.installing ||
          s.stage == DownloadStage.cancelled) {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    late final Widget content;
    late final List<Widget> actions;

    switch (_state.stage) {
      case DownloadStage.downloading:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: _state.progress == 0 ? null : _state.progress,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.updateDownloading),
          ],
        );
        actions = [
          TextButton(
            onPressed: _downloader.cancel,
            child: Text(l10n.cancelButton),
          ),
        ];
      case DownloadStage.verifying:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.updateVerifying),
          ],
        );
        actions = const [];
      case DownloadStage.blockedByRestore:
        content = Text(l10n.updateRestoreBusy);
        actions = [
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l10n.closeButton),
          ),
        ];
      case DownloadStage.installing:
        content = Text(l10n.updateInstalling);
        actions = const [];
      case DownloadStage.permissionNeeded:
        content = Text(l10n.updatePermissionNeeded);
        actions = [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () async {
              await AndroidInstaller.openInstallSettings();
              _start(); // re-check permission and retry
            },
            child: Text(l10n.updateAllow),
          ),
        ];
      case DownloadStage.error:
        final msg = switch (_state.reason) {
          'sha256' => l10n.updateErrorSha,
          'install' => l10n.updateErrorInstall,
          _ => l10n.updateErrorDownload,
        };
        content = Text(msg, style: TextStyle(color: scheme.error));
        actions = [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l10n.closeButton),
          ),
          FilledButton(onPressed: _start, child: Text(l10n.updateRetry)),
        ];
      case DownloadStage.cancelled:
        content = const SizedBox.shrink();
        actions = const [];
    }

    return AlertDialog(
      title: Text(l10n.updateAvailableTitle),
      content: SingleChildScrollView(child: content),
      actions: actions,
    );
  }
}
