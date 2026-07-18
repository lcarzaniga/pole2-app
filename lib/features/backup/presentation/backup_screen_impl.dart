import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/brand/hex_background.dart';
import '../../../shared/format.dart';
import '../application/backup_controller.dart';
import '../domain/backup_limits.dart';

/// "Backup e ripristino": create a portable, integrity-checked backup of the
/// database + photos (encrypted by default). Restore is intentionally visible
/// but disabled in M6.0 — it arrives in the next update.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(backupControllerProvider);
    final lastBackup = ref.watch(lastBackupProvider).value;
    final busy = state.isBusy;

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

            // ---- Restore (disabled in M6.0) ----
            Text(l10n.restoreSectionTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            Opacity(
              opacity: 0.6,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: false,
                leading: const Icon(Icons.settings_backup_restore),
                title: Text(l10n.restoreAction),
                subtitle: Text(l10n.restoreComingSoon),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
