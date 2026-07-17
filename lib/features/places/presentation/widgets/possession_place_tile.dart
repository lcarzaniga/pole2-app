import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import 'possession_thumb.dart';

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
        leading: PossessionThumb(possession: possession),
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
