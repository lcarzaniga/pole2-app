import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_icon_size.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/brand_colors.dart';
import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/brand/turtle_launcher.dart';
import '../../../shared/brand/turtle_shell_menu.dart';
import '../../../shared/format.dart';
import '../../../shared/phrasing.dart';
import '../application/event_providers.dart';

/// The Home once things exist: an optional calm deadline summary, a list, and
/// the turtle as a persistent bottom anchor for keeping more.
class PossessionsHomeView extends StatelessWidget {
  const PossessionsHomeView({
    super.key,
    required this.possessions,
    required this.onQuickAction,
  });

  final List<Possession> possessions;
  final ValueChanged<QuickAction> onQuickAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _DeadlineSummary(),
        Expanded(
          child: Stack(
            children: [
              ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xxxxl * 3,
                ),
                itemCount: possessions.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) =>
                    _PossessionCard(possession: possessions[i]),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxxxl * 2),
                    child: Center(
                      child: TurtleLauncher(size: 84, onAction: onQuickAction),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A calm, one-line awareness cue — not a dashboard. Shows only what helps the
/// user be ready. Absent when nothing is coming up.
class _DeadlineSummary extends ConsumerWidget {
  const _DeadlineSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(upcomingRemindersProvider).value ?? const [];
    final upcoming = all.where((r) => daysUntil(r.event.at) >= 0).toList()
      ..sort((a, b) => a.event.at.compareTo(b.event.at));
    if (upcoming.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final nearest = upcoming.first;
    final soon = daysUntil(nearest.event.at) <= 14;

    final text = upcoming.length == 1
        ? '${nearest.event.title ?? ''} ${relativeDay(l10n, nearest.event.at)}'
            .trim()
        : l10n.upcomingDatesCount(upcoming.length);

    final bg = soon ? context.brand.attention : context.brand.shellTint;
    final fg =
        soon ? context.brand.onAttention : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      child: Material(
        color: bg,
        borderRadius: AppRadii.borderMd,
        child: InkWell(
          borderRadius: AppRadii.borderMd,
          onTap: () => context.pushNamed(Routes.possessionName,
              pathParameters: {'id': nearest.event.possessionId}),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.event_outlined, size: AppIconSize.sm, color: fg),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(text,
                      style: theme.textTheme.labelLarge?.copyWith(color: fg)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PossessionCard extends StatelessWidget {
  const _PossessionCard({required this.possession});

  final Possession possession;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        title: Text(possession.title, style: theme.textTheme.titleMedium),
        subtitle: possession.category == null
            ? null
            : Text(
                possession.category!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
        trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        onTap: () => context.pushNamed(
          Routes.possessionName,
          pathParameters: {'id': possession.id},
        ),
      ),
    );
  }
}
