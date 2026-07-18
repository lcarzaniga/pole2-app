import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../possessions/application/possession_providers.dart';
import '../application/place_providers.dart';
import '../application/place_tree.dart';

enum _PlaceMenu { rename, delete }

/// The result of the place picker. `placeId == null` means the user chose
/// "no place" (clear the assignment). The picker returns `null` only when
/// dismissed without choosing — the caller then changes nothing.
class PlaceChoice {
  const PlaceChoice(this.placeId);
  final String? placeId;
}

/// A calm, **hierarchical** bottom sheet to assign a place: drill into the tree,
/// pick any level, clear the assignment ("no place"), or create a new root place
/// inline. Search flattens to full-path results so duplicate names stay clear.
/// Reusable across screens; still returns exactly one place id (or null).
///
/// When [disableCurrent] is true the [currentPlaceId] row is shown but not
/// selectable — used by "move", so choosing the place a thing is already in
/// can't produce a confusing no-op.
Future<PlaceChoice?> showPlacePicker(
  BuildContext context, {
  String? currentPlaceId,
  bool disableCurrent = false,
}) {
  return showModalBottomSheet<PlaceChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PlacePickerSheet(
      currentPlaceId: currentPlaceId,
      disableCurrent: disableCurrent,
    ),
  );
}

class _PlacePickerSheet extends ConsumerStatefulWidget {
  const _PlacePickerSheet({this.currentPlaceId, this.disableCurrent = false});

  final String? currentPlaceId;
  final bool disableCurrent;

  @override
  ConsumerState<_PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends ConsumerState<_PlacePickerSheet> {
  final _newController = TextEditingController();
  final _searchController = TextEditingController();
  final _expanded = <String>{};
  String _search = '';
  bool _creating = false;

  @override
  void dispose() {
    _newController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _choose(String? placeId) =>
      Navigator.of(context).pop(PlaceChoice(placeId));

  Future<void> _createRootAndSelect() async {
    final name = _newController.text.trim();
    if (name.isEmpty || _creating) return;
    setState(() => _creating = true);
    final id = await ref.read(placesDaoProvider).create(name: name);
    if (mounted) _choose(id);
  }

  Future<void> _renamePlace(Place p) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: p.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.placeRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l10n.saveButton),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty) {
      await ref.read(placesDaoProvider).edit(p.id, name: name);
    }
  }

  Future<void> _deletePlace(Place p) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final tree = ref.read(placeTreeProvider);
    // A place with active children is never deleted (no cascade); move them out
    // first. Explained calmly, nothing destroyed.
    if (tree.childrenOf(p.id).isNotEmpty) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(l10n.placeDeleteHasChildren),
          ),
        );
      return;
    }
    final count = await ref.read(possessionsDaoProvider).countByPlace(p.id);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.placeDeleteTitle(p.name)),
        content: Text(
          count > 0 ? l10n.placeDeleteAssigned(count) : l10n.placeDeleteNone,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.placeDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref.read(placesDaoProvider).deleteLeaf(p.id);
    if (!ok && mounted) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(l10n.placeDeleteHasChildren),
          ),
        );
    }
  }

  /// The visible tree rows (place + depth), respecting expansion; cycle-safe.
  List<({Place place, int depth, bool hasChildren})> _visibleRows(
    PlaceTree tree,
  ) {
    final rows = <({Place place, int depth, bool hasChildren})>[];
    final seen = <String>{};
    void visit(Place p, int depth) {
      if (!seen.add(p.id)) return;
      final kids = tree.childrenOf(p.id);
      rows.add((place: p, depth: depth, hasChildren: kids.isNotEmpty));
      if (_expanded.contains(p.id)) {
        for (final k in kids) {
          visit(k, depth + 1);
        }
      }
    }

    for (final r in tree.roots) {
      visit(r, 0);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final tree = ref.watch(placeTreeProvider);
    final searching = _search.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                l10n.placePickerTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _search = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.searchHint,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // "No place" — clear the assignment.
                  ListTile(
                    leading: Icon(
                      Icons.not_listed_location_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                    title: Text(l10n.noPlace),
                    trailing: widget.currentPlaceId == null
                        ? Icon(Icons.check, color: scheme.primary)
                        : null,
                    onTap: () => _choose(null),
                  ),
                  const Divider(height: 1),
                  if (searching)
                    ..._searchResults(tree, scheme, l10n)
                  else
                    for (final row in _visibleRows(tree))
                      _treeRow(row, scheme, l10n),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newController,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _createRootAndSelect(),
                      decoration: InputDecoration(
                        // Inline creation makes a root place — shown explicitly,
                        // never a silent guess. Nesting is done from a place's
                        // own "Aggiungi sottoluogo".
                        labelText: l10n.newRootPlaceHint,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: _newController.text.trim().isEmpty || _creating
                        ? null
                        : _createRootAndSelect,
                    child: Text(l10n.addPlaceButton),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _searchResults(
    PlaceTree tree,
    ColorScheme scheme,
    AppLocalizations l10n,
  ) {
    final needle = _search.trim().toLowerCase();
    final matches =
        tree.allPlaces.where((p) {
          final path = tree.pathLabel(p.id).toLowerCase();
          return path.contains(needle);
        }).toList()..sort(
          (a, b) => tree
              .pathLabel(a.id)
              .toLowerCase()
              .compareTo(tree.pathLabel(b.id).toLowerCase()),
        );
    if (matches.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            l10n.searchNoResults,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ];
    }
    return [
      for (final p in matches)
        ListTile(
          leading: Icon(Icons.place_outlined, color: scheme.primary),
          title: Text(tree.pathLabel(p.id)),
          trailing: p.id == widget.currentPlaceId
              ? Icon(Icons.check, color: scheme.primary)
              : null,
          enabled: !(p.id == widget.currentPlaceId && widget.disableCurrent),
          onTap: p.id == widget.currentPlaceId && widget.disableCurrent
              ? null
              : () => _choose(p.id),
        ),
    ];
  }

  Widget _treeRow(
    ({Place place, int depth, bool hasChildren}) row,
    ColorScheme scheme,
    AppLocalizations l10n,
  ) {
    final p = row.place;
    final isCurrent = p.id == widget.currentPlaceId;
    final locked = isCurrent && widget.disableCurrent;
    final isExpanded = _expanded.contains(p.id);

    return ListTile(
      enabled: !locked,
      contentPadding: EdgeInsets.only(
        left: AppSpacing.lg + row.depth * AppSpacing.lg,
        right: AppSpacing.sm,
      ),
      leading: row.hasChildren
          ? IconButton(
              tooltip: isExpanded
                  ? l10n.searchClear
                  : l10n.placeChildrenSection,
              icon: Icon(
                isExpanded ? Icons.expand_more : Icons.chevron_right,
                color: scheme.onSurfaceVariant,
              ),
              onPressed: () => setState(() {
                if (!_expanded.remove(p.id)) _expanded.add(p.id);
              }),
            )
          : Icon(
              Icons.place_outlined,
              color: locked ? scheme.onSurfaceVariant : scheme.primary,
            ),
      title: Text(p.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCurrent) Icon(Icons.check, color: scheme.primary),
          PopupMenuButton<_PlaceMenu>(
            icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
            tooltip: l10n.placeManageTooltip,
            onSelected: (m) => switch (m) {
              _PlaceMenu.rename => _renamePlace(p),
              _PlaceMenu.delete => _deletePlace(p),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _PlaceMenu.rename,
                child: Text(l10n.menuRename),
              ),
              PopupMenuItem(
                value: _PlaceMenu.delete,
                child: Text(
                  l10n.placeDelete,
                  style: TextStyle(color: scheme.error),
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: locked ? null : () => _choose(p.id),
    );
  }
}
