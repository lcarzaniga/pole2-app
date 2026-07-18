import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../application/place_providers.dart';

/// The chosen destination for a place move. [parentId] null → move to root.
/// The picker returns null only when dismissed (no change).
class PlaceParentChoice {
  const PlaceParentChoice(this.parentId);
  final String? parentId;
}

/// A calm sheet to pick a new parent for [movingId]: any active place shown with
/// its full path, plus "root". The moving place and its whole subtree are
/// excluded (you can't move a place under itself or a descendant), and
/// soft-deleted places never appear. Flat + path-labelled, so duplicate names
/// stay unambiguous and there are no nested modals to get lost in.
Future<PlaceParentChoice?> showPlaceParentPicker(
  BuildContext context, {
  required String movingId,
}) {
  return showModalBottomSheet<PlaceParentChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ParentPickerSheet(movingId: movingId),
  );
}

class _ParentPickerSheet extends ConsumerWidget {
  const _ParentPickerSheet({required this.movingId});

  final String movingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final tree = ref.watch(placeTreeProvider);

    // Ineligible targets: the place itself and everything in its subtree.
    final excluded = tree.subtreeIds(movingId);
    final eligible =
        tree.allPlaces.where((p) => !excluded.contains(p.id)).toList()..sort(
          (a, b) => tree
              .pathLabel(a.id)
              .toLowerCase()
              .compareTo(tree.pathLabel(b.id).toLowerCase()),
        );

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
              child: Text(l10n.placeMove, style: theme.textTheme.titleMedium),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: Icon(Icons.home_outlined, color: scheme.primary),
                    title: Text(l10n.placeMoveToRoot),
                    onTap: () => Navigator.of(
                      context,
                    ).pop(const PlaceParentChoice(null)),
                  ),
                  const Divider(height: 1),
                  for (final p in eligible)
                    ListTile(
                      leading: Icon(
                        Icons.place_outlined,
                        color: scheme.primary,
                      ),
                      title: Text(tree.pathLabel(p.id)),
                      onTap: () =>
                          Navigator.of(context).pop(PlaceParentChoice(p.id)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
