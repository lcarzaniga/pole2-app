import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/brand/hex_background.dart';
import '../../../shared/format.dart';
import '../application/backup_controller.dart';
import '../domain/backup_limits.dart';
import '../restore/restore_controller.dart';
import '../restore/restore_preparer.dart' show RestoreSummary;

/// "Backup e ripristino": create a portable, integrity-checked backup of the
/// database + photos (encrypted by default), and restore one (M6.1).
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _encrypt = true;
  bool _showPasswordError = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(backupControllerProvider.notifier);
    if (_encrypt) {
      final pw = _password.text;
      if (pw.length < kMinPasswordLength || pw != _confirm.text) {
        setState(() => _showPasswordError = true);
        return;
      }
    }
    setState(() => _showPasswordError = false);
    await controller.createBackup(
      encrypt: _encrypt,
      password: _encrypt ? _password.text : null,
    );
    if (!mounted) return;
    final state = ref.read(backupControllerProvider);
    final messenger = ScaffoldMessenger.of(context);
    String? msg;
    switch (state.status) {
      case BackupStatus.completed:
        msg = l10n.backupSuccess;
      case BackupStatus.failed:
        msg = switch (state.errorCode) {
          'incomplete' => l10n.backupIncomplete(state.incompleteObject ?? ''),
          'lowSpace' => l10n.backupLowSpace,
          _ => l10n.backupFailure,
        };
      case BackupStatus.cancelled:
        msg = null; // calm no-op
      default:
        msg = null;
    }
    if (msg != null) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)),
        );
    }
    controller.reset();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)),
      );
  }

  String _restoreError(AppLocalizations l10n, String? code) => switch (code) {
    'newerFormat' || 'newerSchema' => l10n.restoreErrNewer,
    'passwordOrCorrupt' => l10n.restoreErrPassword,
    'missingActiveMedia' => l10n.restoreErrIncompleteMedia,
    'lowSpace' => l10n.restoreErrLowSpace,
    'accessDenied' => l10n.restoreErrAccess,
    'unreadableSource' || 'copyFailed' => l10n.restoreErrUnreadable,
    'emptyBackup' => l10n.restoreErrEmpty,
    'notABackup' => l10n.restoreErrNotBackup,
    _ => l10n.restoreErrGeneric,
  };

  Future<void> _askRestorePassword() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final pw = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.restorePasswordTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.restorePasswordPrompt),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.backupPasswordLabel),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(l10n.saveButton),
          ),
        ],
      ),
    );
    controller.dispose();
    final notifier = ref.read(restoreControllerProvider.notifier);
    if (pw == null || pw.isEmpty) {
      notifier.cancel();
    } else {
      await notifier.submitPassword(pw);
    }
  }

  Future<void> _confirmRestore(RestoreSummary s) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.restoreSummaryTitle),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.restoreSummaryCreated(
                formatDate(
                  DateTime.tryParse(s.createdAtUtc)?.toLocal() ??
                      DateTime.now(),
                  l10n.localeName,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.restoreSummaryCounts(
                s.possessions,
                s.photos,
                s.places,
                s.people,
              ),
            ),
            if (s.migratedInStaging) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.restoreMigratedNote, style: theme.textTheme.bodySmall),
            ],
            for (final _ in s.warnings) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.backupDormantMissingWarning,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(l10n.restoreReplaceWarning, style: theme.textTheme.bodyMedium),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.restoreConfirm),
          ),
        ],
      ),
    );
    final notifier = ref.read(restoreControllerProvider.notifier);
    if (ok == true) {
      await notifier.confirm();
    } else {
      notifier.cancel();
    }
  }

  Future<void> _showCloseForRestore() async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.restoreCloseTitle),
        content: Text(l10n.restoreCloseBody),
        actions: [
          FilledButton(
            onPressed: () =>
                ref.read(restoreControllerProvider.notifier).closeApp(),
            child: Text(l10n.restoreCloseButton),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(backupControllerProvider);
    final restore = ref.watch(restoreControllerProvider);
    final lastBackup = ref.watch(lastBackupProvider).value;
    final busy = state.isBusy;

    // Drive the multi-step restore flow (password → summary → close) from state
    // transitions, so the coordinator stays UI-free and survives rebuilds.
    ref.listen<RestoreState>(restoreControllerProvider, (prev, next) {
      if (prev?.status == next.status) return;
      switch (next.status) {
        case RestoreStatus.awaitingPassword:
          _askRestorePassword();
        case RestoreStatus.readyForConfirmation:
          _confirmRestore(next.summary!);
        case RestoreStatus.awaitingReopen:
          _showCloseForRestore();
        case RestoreStatus.failed:
          _snack(_restoreError(l10n, next.errorCode));
        default:
          break;
      }
    });

    final pwError = _showPasswordError
        ? (_password.text.length < kMinPasswordLength
              ? l10n.backupPasswordTooShort
              : l10n.backupPasswordMismatch)
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupTitle)),
      body: HexBackground(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(l10n.backupIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.backupReassure,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ---- Backup ----
            Text(l10n.backupSectionTitle, style: theme.textTheme.titleMedium),
            if (lastBackup != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.backupLastDate(formatDate(lastBackup, l10n.localeName)),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _encrypt,
              onChanged: busy ? null : (v) => setState(() => _encrypt = v),
              title: Text(l10n.backupEncryptToggle),
            ),
            if (_encrypt) ...[
              TextField(
                controller: _password,
                obscureText: true,
                enabled: !busy,
                decoration: InputDecoration(
                  labelText: l10n.backupPasswordLabel,
                  errorText: pwError,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _confirm,
                obscureText: true,
                enabled: !busy,
                decoration: InputDecoration(
                  labelText: l10n.backupPasswordConfirmLabel,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.backupPasswordWarning,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              Text(
                l10n.backupPlaintextWarning,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: busy ? null : _create,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                busy
                    ? (state.status == BackupStatus.saving
                          ? l10n.backupSaving
                          : l10n.backupWorking)
                    : l10n.backupCreate,
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
            const Divider(),
            const SizedBox(height: AppSpacing.md),

            // ---- Restore (M6.1) ----
            Text(l10n.restoreSectionTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.restoreIntro,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: (busy || restore.isBusy)
                  ? null
                  : () => ref.read(restoreControllerProvider.notifier).start(),
              icon: restore.isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.settings_backup_restore),
              label: Text(
                restore.isBusy ? l10n.restorePreparing : l10n.restoreAction,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
