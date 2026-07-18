import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/tables/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/brand/hex_background.dart';
import '../../../shared/format.dart';
import '../../places/presentation/widgets/possession_thumb.dart';
import '../../possessions/application/archive_query.dart';
import '../../possessions/application/possession_providers.dart';

/// Archivio: a calm destination to consult and restore things that have left
/// normal use — either **Conservati** (kept aside via lifecycle status) or
/// **Rimossi** (soft-deleted). The two stay explicitly separate; nothing here
/// permanently deletes.
class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.archiveTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.archiveKeptTab),
              Tab(text: l10n.archiveRemovedTab),
            ],
          ),
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
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
  });

  final StreamProvider<List<Possession>> provider;
  final String search;
  final bool removed;
  final String emptyTitle;
  final String emptyHint;

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
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: visible.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) {
            final p = visible[i];
            return _ArchiveRow(
              possession: p,
              removed: removed,
              onOpen: () => context.pushNamed(
                Routes.possessionName,
                pathParameters: {'id': p.id},
              ),
              onRestore: () => _restore(context, ref, p),
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
class _ArchiveRow extends StatelessWidget {
  const _ArchiveRow({
    required this.possession,
    required this.removed,
    required this.onOpen,
    required this.onRestore,
  });

  final Possession possession;
  final bool removed;
  final VoidCallback onOpen;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    // In Rimossi an "active" removed thing has no lifecycle label of its own, so
    // show "Rimosso"; otherwise show its lifecycle label (e.g. "Messo da parte").
    final label = removed && possession.status == PossessionStatus.active
        ? l10n.removedStatusLabel
        : lifecycleLabel(l10n, possession.status);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        leading: PossessionThumb(possession: possession),
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
        trailing: IconButton(
          tooltip: l10n.archiveRestore,
          icon: const Icon(Icons.restore),
          onPressed: onRestore,
        ),
        isThreeLine: true,
        onTap: onOpen,
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
