import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/tables/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/layout/safe_insets.dart';
import '../../../shared/brand/hex_background.dart';
import '../../../shared/format.dart';
import '../../places/presentation/widgets/possession_thumb.dart';
import '../../possessions/application/archive_query.dart';
import '../../possessions/application/event_providers.dart';
import '../../possessions/application/permanent_delete.dart';
import '../../possessions/application/permanent_delete_result.dart';
import '../../possessions/application/possession_providers.dart';
import '../../possessions/presentation/reacquire_sheet.dart';

/// Archivio: a calm destination to consult and restore things that have left
/// normal use — either **Conservati** (kept aside via lifecycle status) or
/// **Rimossi** (soft-deleted). The two stay explicitly separate.
///
/// Only **Rimossi** offers permanent deletion, and only through an explicit
/// selection mode (M8.2B): a "Seleziona" action (or long-press) reveals
/// checkboxes and a contextual bar with the count, "Seleziona tutto" /
/// "Seleziona tutti i risultati", and one irreversible "Elimina definitivamente"
/// — the safe equivalent of emptying the trash, never a one-tap command.
class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

const int _removedTabIndex = 1;

class _ArchiveScreenState extends ConsumerState<ArchiveScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _search = '';

  late final TabController _tabController;
  bool _selecting = false;
  final Set<String> _selected = <String>{};
  bool _deleting = false; // single-flight against rapid repeated taps

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Leaving Rimossi (tab switch) exits selection without deleting. Also rebuilds
  /// so the "Seleziona" entry appears only on the Rimossi tab.
  void _onTabChanged() {
    if (!mounted) return;
    setState(() {
      if (_tabController.index != _removedTabIndex && _selecting) {
        _exitSelectionState();
      }
    });
  }

  void _exitSelectionState() {
    _selecting = false;
    _selected.clear();
  }

  void _enterSelection([String? initialId]) {
    setState(() {
      _selecting = true;
      if (initialId != null) _selected.add(initialId);
    });
  }

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _selectAll(Iterable<String> ids) {
    setState(() {
      _selected
        ..clear()
        ..addAll(ids);
    });
  }

  /// Drops from the selection any id whose row has disappeared from the
  /// underlying data (restored or deleted elsewhere) — a reactive prune that
  /// never runs during build.
  void _pruneToExisting(Set<String> existing) {
    if (!_selecting) return;
    if (_selected.every(existing.contains)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _selected.removeWhere((id) => !existing.contains(id)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Watched here (as well as inside the Rimossi section) to drive select-all
    // and the reactive prune. Riverpod dedups the subscription.
    final removedAll = ref.watch(removedListProvider).value ?? const [];
    final existingIds = {for (final p in removedAll) p.id};
    _pruneToExisting(existingIds);

    final visibleIds = [
      for (final p in filterArchiveBySearch(removedAll, _search)) p.id,
    ];
    final onRemovedTab = _tabController.index == _removedTabIndex;
    final selecting = _selecting && onRemovedTab;

    return Scaffold(
      appBar: selecting
          ? _selectionAppBar(context, l10n, visibleIds, existingIds)
          : _normalAppBar(
              context,
              l10n,
              showSelect: onRemovedTab && removedAll.isNotEmpty,
            ),
      body: HexBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _search = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.archiveSearchHint,
                  isDense: true,
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.searchClear,
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                // No swiping between tabs while selecting: it would silently
                // discard the selection. The explicit close (X) is the exit.
                physics: selecting
                    ? const NeverScrollableScrollPhysics()
                    : null,
                children: [
                  _Section(
                    provider: archivedListProvider,
                    search: _search,
                    removed: false,
                    emptyTitle: l10n.archiveKeptEmpty,
                    emptyHint: l10n.archiveKeptEmptyHint,
                  ),
                  _Section(
                    provider: removedListProvider,
                    search: _search,
                    removed: true,
                    emptyTitle: l10n.archiveRemovedEmpty,
                    emptyHint: l10n.archiveRemovedEmptyHint,
                    selecting: selecting,
                    selectedIds: _selected,
                    onToggle: _toggle,
                    onLongPressSelect: (id) =>
                        selecting ? _toggle(id) : _enterSelection(id),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _normalAppBar(
    BuildContext context,
    AppLocalizations l10n, {
    required bool showSelect,
  }) {
    return AppBar(
      title: Text(l10n.archiveTitle),
      actions: [
        if (showSelect)
          TextButton(
            onPressed: () => _enterSelection(),
            child: Text(l10n.selectAction),
          ),
      ],
      bottom: _tabBar(l10n),
    );
  }

  PreferredSizeWidget _selectionAppBar(
    BuildContext context,
    AppLocalizations l10n,
    List<String> visibleIds,
    Set<String> existingIds,
  ) {
    final searching = _search.isNotEmpty;
    // No search → the safe "empty Rimossi": every removed item. With search →
    // only the currently displayed results.
    final selectAllTarget = searching ? visibleIds : existingIds;
    final canDelete = _selected.isNotEmpty && !_deleting;
    return AppBar(
      leading: IconButton(
        tooltip: l10n.selectionClose,
        icon: const Icon(Icons.close),
        onPressed: () => setState(_exitSelectionState),
      ),
      title: Text(l10n.selectionCount(_selected.length)),
      actions: [
        TextButton(
          onPressed: () => _selectAll(selectAllTarget),
          child: Text(searching ? l10n.selectAllResults : l10n.selectAll),
        ),
        IconButton(
          tooltip: l10n.permanentDeleteAction,
          icon: const Icon(Icons.delete_forever_outlined),
          onPressed: canDelete ? () => _confirmAndDelete(context) : null,
        ),
      ],
      bottom: _tabBar(l10n),
    );
  }

  TabBar _tabBar(AppLocalizations l10n) => TabBar(
    controller: _tabController,
    tabs: [
      Tab(text: l10n.archiveKeptTab),
      Tab(text: l10n.archiveRemovedTab),
    ],
  );

  /// One calm, explicit, irreversible confirmation for the whole batch, then the
  /// guarded coordinator. Ignores rapid repeated taps via [_deleting].
  Future<void> _confirmAndDelete(BuildContext context) async {
    if (_deleting) return;
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          icon: const Icon(Icons.delete_forever_outlined),
          title: Text(l10n.permanentDeleteManyTitle(ids.length)),
          content: Text(l10n.permanentDeleteManyBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.permanentDeleteCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              child: Text(l10n.permanentDeleteConfirm),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    _deleting = true;
    final PermanentDeleteResult result;
    try {
      result = await permanentlyDeletePossessions(ref, ids);
    } finally {
      _deleting = false;
    }
    if (!mounted) return;

    final n = ids.length;
    final message = switch (result.status) {
      PermanentDeleteStatus.deleted => l10n.permanentDeleteManyDoneSnack(n),
      PermanentDeleteStatus.deletedWithPendingFileCleanup =>
        l10n.permanentDeleteManyPartialSnack(n),
      PermanentDeleteStatus.staleSelection => l10n.permanentDeleteStaleSnack,
      PermanentDeleteStatus.blockedByBackup =>
        l10n.permanentDeleteBlockedBackup,
      PermanentDeleteStatus.blockedByRestore =>
        l10n.permanentDeleteBlockedRestore,
      PermanentDeleteStatus.rejectedNotRemoved ||
      PermanentDeleteStatus.notFound ||
      PermanentDeleteStatus.failedBeforeCommit =>
        l10n.permanentDeleteManyFailedSnack,
    };

    setState(_exitSelectionState);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }
}

class _Section extends ConsumerWidget {
  const _Section({
    required this.provider,
    required this.search,
    required this.removed,
    required this.emptyTitle,
    required this.emptyHint,
    this.selecting = false,
    this.selectedIds = const {},
    this.onToggle,
    this.onLongPressSelect,
  });

  final StreamProvider<List<Possession>> provider;
  final String search;
  final bool removed;
  final String emptyTitle;
  final String emptyHint;
  final bool selecting;
  final Set<String> selectedIds;
  final void Function(String id)? onToggle;
  final void Function(String id)? onLongPressSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(provider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _Message(title: l10n.errorNothingLost),
      data: (all) {
        if (all.isEmpty) {
          return _Message(title: emptyTitle, hint: emptyHint);
        }
        final visible = filterArchiveBySearch(all, search);
        if (visible.isEmpty) {
          return _Message(title: l10n.archiveSearchNoResults);
        }
        return ListView.separated(
          padding: padWithSafeBottom(
            context,
            const EdgeInsets.all(AppSpacing.lg),
          ),
          itemCount: visible.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) {
            final p = visible[i];
            return _ArchiveRow(
              possession: p,
              removed: removed,
              selecting: selecting,
              selected: selectedIds.contains(p.id),
              onOpen: () => context.pushNamed(
                Routes.possessionName,
                pathParameters: {'id': p.id},
              ),
              onRestore: () => _restore(context, ref, p),
              onToggleSelect: onToggle == null ? null : () => onToggle!(p.id),
              onLongPressSelect: onLongPressSelect == null
                  ? null
                  : () => onLongPressSelect!(p.id),
            );
          },
        );
      },
    );
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    Possession p,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final dao = ref.read(possessionsDaoProvider);

    // A *given* (transferred, non-removed) thing doesn't "restore" — it comes
    // back to the user through the distinct reacquisition flow, which records the
    // return honestly and lets the user choose where it goes.
    if (!removed && p.status == PossessionStatus.transferred) {
      final transfer = await ref
          .read(eventsDaoProvider)
          .watchTransfer(p.id)
          .first;
      if (transfer != null && context.mounted) {
        await showReacquireSheet(
          context,
          possessionId: p.id,
          transfer: transfer,
        );
      }
      return;
    }

    if (removed) {
      await dao.restoreRemoved(p.id);
    } else {
      await dao.restoreArchived(p.id);
    }
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            removed ? l10n.removedRestoredSnack : l10n.archiveRestoredSnack,
          ),
        ),
      );
  }
}

/// One archive row: cover thumbnail, title, category, a calm lifecycle label,
/// the last-updated date, and a restore control. Tapping the body opens the
/// (read-only) detail. Not colour-only — the status is a text chip.
///
/// While selecting (Rimossi only) a leading checkbox appears, the whole row
/// toggles the selection, the restore control is withheld, and the tile carries
/// a `selected` state so assistive tech announces it.
class _ArchiveRow extends ConsumerWidget {
  const _ArchiveRow({
    required this.possession,
    required this.removed,
    required this.onOpen,
    required this.onRestore,
    this.selecting = false,
    this.selected = false,
    this.onToggleSelect,
    this.onLongPressSelect,
  });

  final Possession possession;
  final bool removed;
  final VoidCallback onOpen;
  final VoidCallback onRestore;
  final bool selecting;
  final bool selected;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onLongPressSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    // In Rimossi an "active" removed thing has no lifecycle label of its own, so
    // show "Rimosso"; otherwise show its lifecycle label (e.g. "Messo da parte").
    final label = removed && possession.status == PossessionStatus.active
        ? l10n.removedStatusLabel
        : lifecycleLabel(l10n, possession.status);

    // For a given thing, add the recipient as secondary context ("Dato a …").
    final transferred = possession.status == PossessionStatus.transferred;
    final transfer = transferred
        ? ref.watch(activeTransferProvider(possession.id)).value
        : null;
    final recipient = transfer?.partyId == null
        ? null
        : ref.watch(partyProvider(transfer!.partyId!)).value;

    final thumb = PossessionThumb(possession: possession);
    final leading = selecting
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: selected,
                onChanged: onToggleSelect == null
                    ? null
                    : (_) => onToggleSelect!(),
              ),
              thumb,
            ],
          )
        : thumb;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        selected: selecting && selected,
        leading: leading,
        title: Text(possession.title, style: theme.textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (possession.category != null)
              Text(
                possession.category!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            _StatusChip(label: label),
            if (transferred && recipient != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.givenToPerson(recipient.name),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.archiveUpdatedOn(
                formatDate(possession.updatedAt, l10n.localeName),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        // Restore is withheld while selecting; a given thing reacquires.
        trailing: selecting
            ? null
            : IconButton(
                tooltip: transferred && !removed
                    ? l10n.reacquireAction
                    : l10n.archiveRestore,
                icon: Icon(
                  transferred && !removed
                      ? Icons.keyboard_return
                      : Icons.restore,
                ),
                onPressed: onRestore,
              ),
        isThreeLine: true,
        onTap: selecting ? onToggleSelect : onOpen,
        onLongPress: onLongPressSelect,
      ),
    );
  }
}

/// A small, calm status chip — carries the lifecycle wording as text (never
/// colour alone) so it's readable and accessible.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
