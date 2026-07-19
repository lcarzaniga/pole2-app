import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/layout/safe_insets.dart';
import '../../../shared/brand/hex_background.dart';
import '../application/place_providers.dart';

/// The root browser: every top-level place with its subtree total, a calm way to
/// add a root, and entry into each tree. The smallest home for hierarchy
/// management — deeper structure is managed inside each place.
class PlacesBrowserScreen extends ConsumerWidget {
  const PlacesBrowserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final roots = ref.watch(rootPlacesProvider);
    final tree = ref.watch(placeTreeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.placesTitle),
        actions: [
          IconButton(
            tooltip: l10n.placeAddRoot,
            icon: const Icon(Icons.add),
            onPressed: () => _addRoot(context, ref),
          ),
        ],
      ),
      body: HexBackground(
        child: roots.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _Calm(l10n.errorNothingLost),
          data: (list) => list.isEmpty
              ? _Empty(onAdd: () => _addRoot(context, ref))
              : ListView.separated(
                  padding: padWithSafeBottom(
                    context,
                    const EdgeInsets.all(AppSpacing.lg),
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) {
                    final p = list[i];
                    return _RootTile(
                      place: p,
                      total: tree.subtreeCount(p.id),
                      onOpen: () => context.pushNamed(
                        Routes.placeName,
                        pathParameters: {'id': p.id},
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

Future<void> _addRoot(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.placeAddRoot),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: l10n.newRootPlaceHint),
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
  if (name != null && name.isNotEmpty) {
    await ref.read(placesDaoProvider).create(name: name);
  }
}

class _RootTile extends StatelessWidget {
  const _RootTile({
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
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        leading: Icon(Icons.home_outlined, color: scheme.primary),
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
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

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
              l10n.placesEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.placesEmptyHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(l10n.placeAddRoot),
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
