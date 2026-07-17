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
import '../../places/application/place_providers.dart';
import '../application/event_providers.dart';
import '../application/possession_query.dart';

/// The Home once things exist: an optional calm deadline summary, calm
/// search / sort / filter controls, the list, and the turtle as a persistent
/// bottom anchor for keeping more. Filtering and sorting are applied to the
/// already-loaded list via [applyPossessionQuery] — no extra data path.
class PossessionsHomeView extends ConsumerStatefulWidget {
  const PossessionsHomeView({
    super.key,
    required this.possessions,
    required this.onQuickAction,
  });

  final List<Possession> possessions;
  final ValueChanged<QuickAction> onQuickAction;

  @override
  ConsumerState<PossessionsHomeView> createState() =>
      _PossessionsHomeViewState();
}

class _PossessionsHomeViewState extends ConsumerState<PossessionsHomeView> {
  final _search = TextEditingController();
  PossessionQuery _query = const PossessionQuery();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final places = ref.watch(placeListProvider).value ?? const <Place>[];
    final visible = applyPossessionQuery(widget.possessions, _query);

    return Column(
      children: [
        const _DeadlineSummary(),
        _Controls(
          controller: _search,
          query: _query,
          places: places,
          onChanged: (q) => setState(() => _query = q),
        ),
        Expanded(
          child: Stack(
            children: [
              if (visible.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Text(
                      l10n.searchNoResults,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.xxxxl * 3,
                  ),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) =>
                      _PossessionCard(possession: visible[i]),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxxxl * 2),
                    child: Center(
                      child: TurtleLauncher(
                          size: 100, onAction: widget.onQuickAction),
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

/// The calm search field plus quiet sort and place-filter controls. Sits above
/// the list; collapses to nothing more than a search box until the user reaches
/// for sort or filter.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.query,
    required this.places,
    required this.onChanged,
  });

  final TextEditingController controller;
  final PossessionQuery query;
  final List<Place> places;
  final ValueChanged<PossessionQuery> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final filtering = !query.place.isAll;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.sm, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onChanged: (v) => onChanged(query.copyWith(search: v)),
              decoration: InputDecoration(
                isDense: true,
                hintText: l10n.searchHint,
                prefixIcon: Icon(Icons.search, size: AppIconSize.md),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.searchClear,
                        icon: Icon(Icons.close, size: AppIconSize.sm),
                        onPressed: () {
                          controller.clear();
                          onChanged(query.copyWith(search: ''));
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          PopupMenuButton<PossessionSort>(
            tooltip: l10n.sortTooltip,
            icon: Icon(Icons.sort, color: scheme.onSurfaceVariant),
            initialValue: query.sort,
            onSelected: (s) => onChanged(query.copyWith(sort: s)),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: PossessionSort.newest,
                checked: query.sort == PossessionSort.newest,
                child: Text(l10n.sortNewest),
              ),
              CheckedPopupMenuItem(
                value: PossessionSort.name,
                checked: query.sort == PossessionSort.name,
                child: Text(l10n.sortName),
              ),
            ],
          ),
          PopupMenuButton<PlaceFilter>(
            tooltip: l10n.filterTooltip,
            icon: Icon(Icons.filter_list,
                color: filtering ? scheme.primary : scheme.onSurfaceVariant),
            onSelected: (f) => onChanged(query.copyWith(place: f)),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: const PlaceFilter.all(),
                checked: query.place == const PlaceFilter.all(),
                child: Text(l10n.filterAllPlaces),
              ),
              CheckedPopupMenuItem(
                value: const PlaceFilter.none(),
                checked: query.place == const PlaceFilter.none(),
                child: Text(l10n.filterNoPlace),
              ),
              if (places.isNotEmpty) const PopupMenuDivider(),
              for (final p in places)
                CheckedPopupMenuItem(
                  value: PlaceFilter.place(p.id),
                  checked: query.place == PlaceFilter.place(p.id),
                  child: Text(p.name),
                ),
            ],
          ),
        ],
      ),
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
