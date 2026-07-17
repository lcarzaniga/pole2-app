import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/brand/hex_background.dart';
import '../../possessions/application/possession_providers.dart';
import '../application/place_providers.dart';
import 'place_picker.dart';
import 'widgets/possession_place_tile.dart';

/// A place as a browsable physical space: everything stored here, with calm
/// per-item tidying (open, move to another place, remove from this place).
/// Renaming stays a secondary app-bar action; the contents are the focus.
class PlaceContentsScreen extends ConsumerWidget {
  const PlaceContentsScreen({super.key, required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final place = ref.watch(placeByIdProvider(placeId));
    final current = place.value;
    final count = ref.watch(possessionsByPlaceProvider(placeId)).value?.length;

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
                  if (count != null)
                    Text(
                      l10n.placeItemCount(count),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
        actions: [
          if (current != null)
            IconButton(
              tooltip: l10n.menuRename,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _renamePlace(context, ref, current),
            ),
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
    final items = ref.watch(possessionsByPlaceProvider(placeId));
    final l10n = AppLocalizations.of(context);

    return items.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _Calm(l10n.errorNothingLost),
      data: (list) => list.isEmpty
          ? const _EmptyPlace()
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) {
                final possession = list[i];
                return PossessionPlaceTile(
                  possession: possession,
                  onOpen: () => context.pushNamed(
                    Routes.possessionName,
                    pathParameters: {'id': possession.id},
                  ),
                  onMove: () => _moveItem(context, ref, possession, placeId),
                  onRemove: () =>
                      _removeItem(context, ref, possession, placeId),
                );
              },
            ),
    );
  }
}

/// Move a possession to another place via the shared picker. The current place
/// is disabled in the picker, so it can't be a no-op. Reactive: the item leaves
/// this screen the moment its place changes; a calm snackbar offers undo.
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

/// Remove a possession's place assignment (placeId → null). A reversible
/// metadata change — no alarming dialog, just a calm snackbar with undo. The
/// possession itself is never deleted or archived.
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

/// A calm rename dialog for the place — the one editing action offered here,
/// kept secondary. Deleting a place stays in the assignment picker, where its
/// consequences (possessions resolving to "no place") are explained.
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

/// A calm empty state: no urgency, no suggestion to delete the place — just
/// what it is and how to fill it.
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
              l10n.placeContentsEmpty,
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
