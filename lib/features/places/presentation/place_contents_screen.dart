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
/// Read-only — a calm answer to "what did I put here?". Tapping an item opens
/// its existing detail screen. No management actions live here.
class PlaceContentsScreen extends ConsumerWidget {
  const PlaceContentsScreen({super.key, required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = ref.watch(placeByIdProvider(placeId));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(place.value?.name ?? l10n.placeLabel)),
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
