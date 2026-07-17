import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/brand/hex_background.dart';
import '../application/place_providers.dart';

/// The contents of one place: the active possessions currently kept there.
/// A calm answer to "what did I put here?". Tapping an item opens its existing
/// detail screen. Editing the place (rename) is deliberately a secondary,
/// clearly separated action in the app bar — the contents are the focus.
class PlaceContentsScreen extends ConsumerWidget {
  const PlaceContentsScreen({super.key, required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = ref.watch(placeByIdProvider(placeId));
    final l10n = AppLocalizations.of(context);
    final current = place.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(current?.name ?? l10n.placeLabel),
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

/// A calm rename dialog for the place — the one editing action offered here,
/// kept secondary. Deleting a place stays in the assignment picker, where its
/// consequences (possessions resolving to "no place") are explained.
Future<void> _renamePlace(
    BuildContext context, WidgetRef ref, Place place) async {
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
          ? _Calm(l10n.placeContentsEmpty)
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) => _PossessionTile(possession: list[i]),
            ),
    );
  }
}

/// A small local tile, consistent with the Home list, so this slice stays
/// isolated (the Home view's own tile is left untouched).
class _PossessionTile extends StatelessWidget {
  const _PossessionTile({required this.possession});

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
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
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
