import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_icon_size.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/daos/places_dao.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/layout/safe_insets.dart';
import '../../../shared/brand/hex_background.dart';
import '../../possessions/application/possession_providers.dart';
import '../application/place_providers.dart';
import 'place_parent_picker.dart';
import 'place_picker.dart';
import 'widgets/possession_place_tile.dart';

/// A place as a browsable node in the containment tree: its breadcrumb, its
/// child places, and the possessions kept **directly** here. Child places and
/// direct objects are kept visually distinct so the user always knows which
/// physical level holds each thing (descendants are never flattened in).
class PlaceContentsScreen extends ConsumerWidget {
  const PlaceContentsScreen({super.key, required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final place = ref.watch(placeByIdProvider(placeId));
    final current = place.value;
    final tree = ref.watch(placeTreeProvider);
    final total = tree.subtreeCount(placeId);

    return Scaffold(
      appBar: AppBar(
        title: current == null
            ? Text(l10n.placeLabel)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    current.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    l10n.placeTotalCount(total),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
        actions: [
          if (current != null) ...[
            IconButton(
              tooltip: l10n.placeAddChild,
              icon: const Icon(Icons.create_new_folder_outlined),
              onPressed: () => _addChild(context, ref, placeId),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'rename' => _renamePlace(context, ref, current),
                'move' => _movePlace(context, ref, current),
                _ => null,
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'rename', child: Text(l10n.menuRename)),
                PopupMenuItem(value: 'move', child: Text(l10n.placeMove)),
              ],
            ),
          ],
        ],
      ),
      body: HexBackground(
        child: place.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _Calm(l10n.errorNothingLost),
          // A deleted or missing place resolves calmly, never a raw error.
          data: (p) =>
              p == null ? _Calm(l10n.goneMessage) : _Contents(placeId: placeId),
        ),
      ),
    );
  }
}

class _Contents extends ConsumerWidget {
  const _Contents({required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tree = ref.watch(placeTreeProvider);
    final children = tree.childrenOf(placeId);
    final items =
        ref.watch(possessionsByPlaceProvider(placeId)).value ??
        const <Possession>[];

    if (children.isEmpty && items.isEmpty) {
      return ListView(
        padding: padWithSafeBottom(context, EdgeInsets.zero),
        children: [
          _Breadcrumb(placeId: placeId),
          const SizedBox(height: AppSpacing.xxl),
          const _EmptyPlace(),
        ],
      );
    }

    return ListView(
      padding: padWithSafeBottom(
        context,
        const EdgeInsets.only(bottom: AppSpacing.xl),
      ),
      children: [
        _Breadcrumb(placeId: placeId),
        if (children.isNotEmpty) ...[
          _SectionHeader(l10n.placeChildrenSection),
          for (final child in children)
            _ChildTile(
              place: child,
              total: tree.subtreeCount(child.id),
              onOpen: () => context.pushNamed(
                Routes.placeName,
                pathParameters: {'id': child.id},
              ),
            ),
        ],
        _SectionHeader(l10n.placeDirectItemsSection),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              l10n.placeNoDirectItems,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.pushNamed(
                  Routes.placeReviewName,
                  pathParameters: {'id': placeId},
                ),
                icon: const Icon(Icons.checklist),
                label: Text(l10n.placeReviewStart),
              ),
            ),
          ),
          for (final possession in items)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: PossessionPlaceTile(
                possession: possession,
                onOpen: () => context.pushNamed(
                  Routes.possessionName,
                  pathParameters: {'id': possession.id},
                ),
                onMove: () => _moveItem(context, ref, possession, placeId),
                onRemove: () => _removeItem(context, ref, possession, placeId),
              ),
            ),
        ],
      ],
    );
  }
}

/// The tappable path from root to here (the current place is not a link).
class _Breadcrumb extends ConsumerWidget {
  const _Breadcrumb({required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tree = ref.watch(placeTreeProvider);
    final path = tree.pathTo(placeId);
    if (path.length <= 1) return const SizedBox(height: AppSpacing.sm);

    return Semantics(
      label: tree.pathLabel(placeId),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          0,
        ),
        child: Row(
          children: [
            for (var i = 0; i < path.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    size: AppIconSize.sm,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              if (i == path.length - 1)
                Text(path[i].name, style: theme.textTheme.labelLarge)
              else
                InkWell(
                  onTap: () => context.pushNamed(
                    Routes.placeName,
                    pathParameters: {'id': path[i].id},
                  ),
                  child: Text(
                    path[i].name,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ChildTile extends StatelessWidget {
  const _ChildTile({
    required this.place,
    required this.total,
    required this.onOpen,
  });

  final Place place;
  final int total;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(Icons.folder_outlined, color: scheme.primary),
          title: Text(place.name, style: theme.textTheme.titleMedium),
          subtitle: Text(
            l10n.placeSubtreeCount(total),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          onTap: onOpen,
        ),
      ),
    );
  }
}

/// Move a possession to another place via the shared hierarchical picker.
Future<void> _moveItem(
  BuildContext context,
  WidgetRef ref,
  Possession possession,
  String fromPlaceId,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final dao = ref.read(possessionsDaoProvider);

  final choice = await showPlacePicker(
    context,
    currentPlaceId: fromPlaceId,
    disableCurrent: true,
  );
  if (choice == null || choice.placeId == fromPlaceId) return;

  await dao.setPlace(possession.id, choice.placeId);
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          choice.placeId == null
              ? l10n.placeRemovedFromSnack
              : l10n.placeMovedSnack,
        ),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => dao.setPlace(possession.id, fromPlaceId),
        ),
      ),
    );
}

/// Remove a possession's place assignment (placeId → null) with a calm undo.
Future<void> _removeItem(
  BuildContext context,
  WidgetRef ref,
  Possession possession,
  String fromPlaceId,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final dao = ref.read(possessionsDaoProvider);

  await dao.setPlace(possession.id, null);
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(l10n.placeRemovedFromSnack),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => dao.setPlace(possession.id, fromPlaceId),
        ),
      ),
    );
}

/// Create a child place under the current one.
Future<void> _addChild(
  BuildContext context,
  WidgetRef ref,
  String parentId,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final dao = ref.read(placesDaoProvider);
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.placeNewChildTitle),
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
          child: Text(l10n.addPlaceButton),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null || name.isEmpty) return;
  try {
    await dao.create(name: name, parentId: parentId);
  } on PlaceParentNotFoundException {
    // The parent was removed while the dialog was open — never create at root
    // behind the user's back; explain it calmly instead.
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(l10n.placeParentGone),
        ),
      );
  }
}

/// Move this place under another (or to root) via the parent picker, rejecting
/// invalid targets calmly at the DAO.
Future<void> _movePlace(
  BuildContext context,
  WidgetRef ref,
  Place place,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final dao = ref.read(placesDaoProvider);

  final choice = await showPlaceParentPicker(context, movingId: place.id);
  if (choice == null) return;
  final result = await dao.move(place.id, choice.parentId);
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          result == PlaceMoveResult.moved
              ? l10n.placeMovedToSnack
              : l10n.placeMoveInvalid,
        ),
      ),
    );
}

Future<void> _renamePlace(
  BuildContext context,
  WidgetRef ref,
  Place place,
) async {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: place.name);
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
    await ref.read(placesDaoProvider).edit(place.id, name: name);
  }
}

/// A calm empty state for a place with no children and nothing directly here.
class _EmptyPlace extends StatelessWidget {
  const _EmptyPlace();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.placeEmptyTree,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.placeEmptyHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Calm extends StatelessWidget {
  const _Calm(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
