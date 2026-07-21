import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/format.dart';
import '../application/storage_cleanup_controller.dart';

/// "Spazio sul dispositivo" — a calm maintenance section (M8.2C) inside "Backup
/// e ripristino". It scans the app-private `photos/` for proven orphan
/// photographs, shows how much can be freed, and deletes only on explicit
/// confirmation. It never touches possessions, history, restorable media,
/// backups, recovery snapshots or external files.
class StorageCleanupSection extends ConsumerWidget {
  const StorageCleanupSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(storageCleanupControllerProvider);
    final controller = ref.read(storageCleanupControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.storageSectionTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.storageBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // A status/live-region line so TalkBack announces scan/clean outcomes.
        _StatusLine(state: state),
        const SizedBox(height: AppSpacing.md),
        _Actions(state: state, controller: controller),
      ],
    );
  }
}

/// The single, calm status line. A [Semantics] live region so assistive tech
/// announces progress and results as they change. Colour is never the only
/// signal — the meaning is always in the words.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});
  final StorageCleanupState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final locale = l10n.localeName;

    final String? text = switch (state.phase) {
      StoragePhase.scanning => l10n.storageScanning,
      StoragePhase.scanned =>
        state.hasCandidates
            ? l10n.storageCandidates(formatBytes(state.scannedBytes, locale))
            : l10n.storageNoCandidates,
      StoragePhase.cleaning => l10n.storageCleaning,
      StoragePhase.done => _doneText(l10n, locale),
      StoragePhase.scanFailed => l10n.storageScanFailed,
      StoragePhase.blocked => _blockedText(l10n),
      StoragePhase.idle => null,
    };
    // Emphasize the actionable "you can free …" line; everything else is calm.
    final emphasize =
        state.phase == StoragePhase.scanned && state.hasCandidates;

    if (text == null) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: emphasize ? scheme.onSurface : scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String _doneText(AppLocalizations l10n, String locale) {
    final r = state.report;
    final size = formatBytes(r?.reclaimedBytes ?? 0, locale);
    return (r?.hasFailures ?? false)
        ? l10n.storagePartial(size)
        : l10n.storageDone(size);
  }

  String _blockedText(AppLocalizations l10n) => switch (state.blockedReason) {
    'backup' => l10n.storageBlockedBackup,
    'restore' => l10n.storageBlockedRestore,
    'permanentDelete' => l10n.storageBlockedPermanentDelete,
    _ => l10n.storageScanFailed,
  };
}

/// The action row. In the "scanned with candidates" state it shows the explicit
/// confirmation pair (Annulla / Libera spazio); otherwise a single scan action.
/// Every button clears a 48 dp minimum height.
class _Actions extends StatelessWidget {
  const _Actions({required this.state, required this.controller});
  final StorageCleanupState state;
  final StorageCleanupController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    if (state.phase == StoragePhase.scanned && state.hasCandidates) {
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton(
            onPressed: controller.reset,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            child: Text(l10n.storageCleanCancel),
          ),
          FilledButton.icon(
            onPressed: controller.cleanup,
            icon: const Icon(Icons.cleaning_services_outlined),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: scheme.error,
            ),
            label: Text(l10n.storageCleanAction),
          ),
        ],
      );
    }

    final busy =
        state.phase == StoragePhase.scanning ||
        state.phase == StoragePhase.cleaning;
    return OutlinedButton.icon(
      onPressed: busy ? null : controller.scan,
      icon: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.storage_outlined),
      label: Text(l10n.storageScanAction),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    );
  }
}
