import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import 'possession_thumb.dart';

/// One object under review, presented calmly with its four choices. Purely
/// presentational — every action is a callback and the whole action row is
/// gated by [enabled] (false while an async mutation is pending, so a rapid
/// second tap can't fire). This keeps it testable without any Drift stream.
///
/// The object info scrolls if text is very large; the four actions stay pinned
/// at the bottom inside a [SafeArea] so they're never pushed off a small screen.
class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.possession,
    required this.placeName,
    required this.count,
    required this.enabled,
    required this.onKeep,
    required this.onMove,
    required this.onUnassign,
    required this.onArchive,
  });

  final Possession possession;
  final String? placeName;
  final int count;
  final bool enabled;
  final VoidCallback onKeep;
  final VoidCallback onMove;
  final VoidCallback onUnassign;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  // A gentle count — never a fraction or a bar. Just what's here.
                  Text(
                    l10n.placeReviewGentleCount(count),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (placeName != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      placeName!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  PossessionThumb(possession: possession, size: 112),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    possession.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  if (possession.category != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      possession.category!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: enabled ? onKeep : null,
                  icon: const Icon(Icons.check),
                  label: Text(l10n.placeReviewKeep),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _SecondaryAction(
                  onPressed: enabled ? onMove : null,
                  icon: Icons.drive_file_move_outlined,
                  label: l10n.placeReviewMove,
                ),
                const SizedBox(height: AppSpacing.sm),
                _SecondaryAction(
                  onPressed: enabled ? onUnassign : null,
                  icon: Icons.remove_circle_outline,
                  label: l10n.placeReviewUnassign,
                ),
                const SizedBox(height: AppSpacing.sm),
                _SecondaryAction(
                  onPressed: enabled ? onArchive : null,
                  icon: Icons.archive_outlined,
                  label: l10n.placeReviewArchive,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    );
  }
}

/// The calm end of a walk: everything here has been looked at. No score, no
/// percentage, no celebration — just an acknowledgement and one way out.
class ReviewComplete extends StatelessWidget {
  const ReviewComplete({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.placeReviewAllSeen,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: onDone,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(l10n.placeReviewDone),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
