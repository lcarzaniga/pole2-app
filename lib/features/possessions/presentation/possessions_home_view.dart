import 'dart:math' as math;

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
import '../../people/application/people_providers.dart';
import '../../places/application/place_providers.dart';
import '../../places/application/place_tree.dart';
import '../application/event_providers.dart';
import '../application/possession_query.dart';

/// All places sorted by their full path, so the filter menu reads top-down
/// (Casa, Casa › Camera, Casa › Studio, …) and duplicates stay distinguishable.
List<Place> _placesByPath(PlaceTree tree) {
  final all = tree.allPlaces.toList()
    ..sort(
      (a, b) => tree
          .pathLabel(a.id)
          .toLowerCase()
          .compareTo(tree.pathLabel(b.id).toLowerCase()),
    );
  return all;
}

/// A calm, compact path for a chip: `Casa › … › Armadio` when deep, so it never
/// overflows a narrow screen. The full path stays available for accessibility.
String _compactPath(PlaceTree tree, String id) {
  final names = tree.pathTo(id).map((p) => p.name).toList();
  if (names.length <= 2) return names.join(' › ');
  return '${names.first} › … › ${names.last}';
}

/// The Home once things exist: an optional calm deadline summary, calm
/// search / sort / custody controls, the list, and the turtle as a persistent
/// bottom anchor for keeping more. Filtering and sorting are applied to the
/// already-loaded list via [applyPossessionQuery] — no extra data path. The
/// active-loan relationship comes from one grouped stream (never per-card).
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
    final tree = ref.watch(placeTreeProvider);
    final loansByPossession = ref.watch(homeLoansByPossessionProvider);
    final loanPeople = ref.watch(loanPeopleProvider);

    // Resolve the effective filter: if the selected Place was deleted or the
    // last loan to the selected person ended, fall back calmly to "Tutti"
    // (scheduled, never a state mutation during build).
    final custody = resolveCustody(
      _query.custody,
      validPlaceIds: {for (final p in tree.allPlaces) p.id},
      loanPersonIds: {for (final p in loanPeople) p.id},
    );
    if (custody != _query.custody) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _query = _query.copyWith(custody: custody));
      });
    }

    final subtree = custody.isPlace && custody.id != null
        ? tree.subtreeIds(custody.id!)
        : null;
    // possession id → active borrower party id, for the person filter and to
    // keep lent things out of "Senza luogo".
    final loanPersonByPossession = <String, String>{
      for (final e in loansByPossession.entries) e.key: e.value.party.id,
    };

    final visible = applyPossessionQuery(
      widget.possessions,
      _query.copyWith(custody: custody),
      placeSubtreeIds: subtree,
      loanPersonByPossession: loanPersonByPossession,
    );

    // Kobe the persistent anchor — a visual target with responsive caps so it
    // never dominates a narrow screen and its bloomed shell always fits. The
    // list reserves clearance below itself equal to the turtle plus a gap, so
    // items never sit under it (and above the system navigation).
    final width = MediaQuery.of(context).size.width;
    final turtleSize = math.max(
      130.0,
      math.min(
        200.0,
        math.min(width * 0.5, TurtleShellMenu.maxTurtleForWidth(width)),
      ),
    );
    final listBottomPad = turtleSize + AppSpacing.xxxxl;

    return Column(
      children: [
        const _DeadlineSummary(),
        _Controls(
          controller: _search,
          query: _query.copyWith(custody: custody),
          tree: tree,
          loanPeople: loanPeople,
          onChanged: (q) => setState(() => _query = q),
        ),
        if (!custody.isAll)
          _ActiveFilterChip(
            custody: custody,
            tree: tree,
            loanPeople: loanPeople,
            onClear: () => setState(
              () =>
                  _query = _query.copyWith(custody: const CustodyFilter.all()),
            ),
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
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    listBottomPad,
                  ),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) {
                    final p = visible[i];
                    return _PossessionCard(
                      possession: p,
                      borrowerName: loansByPossession[p.id]?.party.name,
                    );
                  },
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                    child: Center(
                      child: TurtleLauncher(
                        size: turtleSize,
                        onAction: widget.onQuickAction,
                      ),
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

/// The calm search field plus quiet sort and the unified "Dove si trova" custody
/// filter. Sits above the list; collapses to nothing more than a search box
/// until the user reaches for sort or filter.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.controller,
    required this.query,
    required this.tree,
    required this.loanPeople,
    required this.onChanged,
  });

  final TextEditingController controller;
  final PossessionQuery query;
  final PlaceTree tree;
  final List<Party> loanPeople;
  final ValueChanged<PossessionQuery> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final filtering = !query.custody.isAll;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        0,
      ),
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
          PopupMenuButton<CustodyFilter>(
            tooltip: l10n.filterTooltip, // "Dove si trova"
            icon: Icon(
              Icons.filter_list,
              color: filtering ? scheme.primary : scheme.onSurfaceVariant,
            ),
            onSelected: (f) => onChanged(query.copyWith(custody: f)),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: const CustodyFilter.all(),
                checked: query.custody.isAll,
                child: Text(l10n.custodyAll),
              ),
              CheckedPopupMenuItem(
                value: const CustodyFilter.noLocation(),
                checked: query.custody.isNoLocation,
                child: Text(l10n.filterNoPlace),
              ),
              if (tree.allPlaces.isNotEmpty) ...[
                _sectionHeader(context, l10n.placesMenu),
                for (final p in _placesByPath(tree))
                  CheckedPopupMenuItem(
                    value: CustodyFilter.place(p.id),
                    checked: query.custody == CustodyFilter.place(p.id),
                    child: Tooltip(
                      message: tree.pathLabel(p.id),
                      child: Text(
                        tree.pathLabel(p.id),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
              ],
              if (loanPeople.isNotEmpty) ...[
                _sectionHeader(context, l10n.peopleMenu),
                for (final person in loanPeople)
                  CheckedPopupMenuItem(
                    value: CustodyFilter.person(person.id),
                    checked: query.custody == CustodyFilter.person(person.id),
                    child: Text(
                      person.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// A non-selectable section label inside the filter menu.
  PopupMenuItem<CustodyFilter> _sectionHeader(
    BuildContext context,
    String label,
  ) {
    final theme = Theme.of(context);
    return PopupMenuItem<CustodyFilter>(
      enabled: false,
      height: AppSpacing.xl,
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The current custody filter as a calm, dismissible chip — "Senza luogo",
/// "In: Casa › … › Armadio", or "Con: Carlo". Colour is never the only cue; the
/// full place path / person name stays available to accessibility.
class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({
    required this.custody,
    required this.tree,
    required this.loanPeople,
    required this.onClear,
  });

  final CustodyFilter custody;
  final PlaceTree tree;
  final List<Party> loanPeople;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    late final String label;
    late final String semantics;
    late final IconData icon;
    if (custody.isNoLocation) {
      label = l10n.filterNoPlace;
      semantics = label;
      icon = Icons.location_off_outlined;
    } else if (custody.isPlace && custody.id != null) {
      label = l10n.custodyInPlace(_compactPath(tree, custody.id!));
      semantics = l10n.custodyInPlace(tree.pathLabel(custody.id!));
      icon = Icons.place_outlined;
    } else {
      final name = loanPeople
          .firstWhere(
            (p) => p.id == custody.id,
            orElse: () => loanPeople.isNotEmpty
                ? loanPeople.first
                : Party(
                    id: '',
                    name: '',
                    createdAt: DateTime(2000),
                    updatedAt: DateTime(2000),
                  ),
          )
          .name;
      label = l10n.custodyWithPerson(name);
      semantics = label;
      icon = Icons.person_outline;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          label: semantics,
          child: InputChip(
            avatar: Icon(icon, size: AppIconSize.sm),
            label: Text(label, overflow: TextOverflow.ellipsis),
            onDeleted: onClear,
          ),
        ),
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
    final fg = soon
        ? context.brand.onAttention
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      child: Material(
        color: bg,
        borderRadius: AppRadii.borderMd,
        child: InkWell(
          borderRadius: AppRadii.borderMd,
          onTap: () => context.pushNamed(
            Routes.possessionName,
            pathParameters: {'id': nearest.event.possessionId},
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(Icons.event_outlined, size: AppIconSize.sm, color: fg),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.labelLarge?.copyWith(color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single Home card — now purely presentational. The active-loan borrower is
/// resolved once by the list from the grouped stream and passed in, so there is
/// no per-card provider subscription.
class _PossessionCard extends StatelessWidget {
  const _PossessionCard({required this.possession, this.borrowerName});

  final Possession possession;
  final String? borrowerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    // A lent thing stays on Home with a subtle, non-alarming custody line that
    // replaces the category subtitle (never the title).
    Widget? subtitle;
    if (borrowerName != null) {
      subtitle = Row(
        children: [
          Icon(
            Icons.people_alt_outlined,
            size: AppIconSize.sm,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              l10n.lentToPerson(borrowerName!),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    } else if (possession.category != null) {
      subtitle = Text(
        possession.category!,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        title: Text(possession.title, style: theme.textTheme.titleMedium),
        subtitle: subtitle,
        trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        onTap: () => context.pushNamed(
          Routes.possessionName,
          pathParameters: {'id': possession.id},
        ),
      ),
    );
  }
}
