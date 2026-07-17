import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/platform/photo_store.dart';
import '../../../possessions/application/possession_providers.dart';

enum _TileAction { move, remove }

/// A possession as shown inside a Place — the Home Card/ListTile language plus a
/// small cover thumbnail and calm per-item actions (move / remove from place).
/// Behaviour is injected as callbacks so the tile is easy to test in isolation.
class PossessionPlaceTile extends ConsumerWidget {
  const PossessionPlaceTile({
    super.key,
    required this.possession,
    required this.onOpen,
    required this.onMove,
    required this.onRemove,
  });

  final Possession possession;
  final VoidCallback onOpen;
  final VoidCallback onMove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        leading: _Thumb(possession: possession),
        title: Text(possession.title, style: theme.textTheme.titleMedium),
        subtitle: possession.category == null
            ? null
            : Text(
                possession.category!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
        trailing: PopupMenuButton<_TileAction>(
          icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
          tooltip: l10n.itemActionsTooltip,
          onSelected: (a) => switch (a) {
            _TileAction.move => onMove(),
            _TileAction.remove => onRemove(),
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: _TileAction.move,
              child: Text(l10n.placeMoveAction),
            ),
            PopupMenuItem(
              value: _TileAction.remove,
              child: Text(l10n.placeRemoveAction),
            ),
          ],
        ),
        onTap: onOpen,
      ),
    );
  }
}

/// A small square cover thumbnail when the possession has one, else a calm
/// neutral placeholder — never an error or a broken image.
class _Thumb extends ConsumerWidget {
  const _Thumb({required this.possession});

  final Possession possession;

  static const double _size = 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final fileId = possession.coverFileId;
    final file = fileId == null
        ? null
        : ref.watch(fileByIdProvider(fileId)).value;
    final docs = ref.watch(appDocumentsPathProvider).value;

    if (file != null && docs != null) {
      return ClipRRect(
        borderRadius: AppRadii.borderSm,
        child: SizedBox(
          width: _size,
          height: _size,
          child: coverImage(
            docsPath: docs,
            relativePath: file.relativePath,
            height: _size,
          ),
        ),
      );
    }

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadii.borderSm,
      ),
      child: Icon(Icons.inventory_2_outlined, color: scheme.onSurfaceVariant),
    );
  }
}
