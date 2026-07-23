import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/theme/app_icon_size.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../update/update_prompt.dart';
import '../../update/update_service.dart';

/// "Controlla aggiornamenti" — the manual counterpart to the startup check.
///
/// Direct distribution only (the caller gates on `Distribution.allowsSelfUpdate`).
/// It reuses the existing fetch + prompt exactly as the automatic gate does, so
/// the direct updater is not weakened or duplicated: the only difference is that
/// a person asked for it, so an up-to-date result is *reported* rather than
/// silently ignored, and a dismissed version is not suppressed.
class UpdateCheckRow extends ConsumerStatefulWidget {
  const UpdateCheckRow({super.key});

  @override
  ConsumerState<UpdateCheckRow> createState() => _UpdateCheckRowState();
}

class _UpdateCheckRowState extends ConsumerState<UpdateCheckRow> {
  bool _busy = false;

  Future<void> _check() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    String? message;
    try {
      final client = http.Client();
      final release = await fetchLatestRelease(client);
      client.close();

      final info = await PackageInfo.fromPlatform();
      final currentVc = int.tryParse(info.buildNumber) ?? 0;

      if (release == null) {
        message = l10n.settingsUpdateCheckFailed;
      } else if (!release.isNewerThan(currentVc)) {
        message = l10n.settingsUpdateUpToDate;
      } else if (mounted) {
        // A newer release exists → the same prompt the startup gate shows.
        await showUpdateDialog(context, ref, release);
      }
    } catch (_) {
      message = l10n.settingsUpdateCheckFailed;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (message != null) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: AppRadii.borderLg,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _busy ? null : _check,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.system_update_outlined,
                  size: AppIconSize.md,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settingsUpdateCheck,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _busy
                            ? l10n.settingsUpdateChecking
                            : l10n.settingsUpdateCheckSub,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_busy)
                  const SizedBox.square(
                    dimension: AppIconSize.md,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
