import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_radii.dart';
import '../../../../core/database/app_database.dart';
import '../../../../shared/platform/photo_store.dart';
import '../../../possessions/application/possession_providers.dart';

/// A small square cover thumbnail when the possession has one, else a calm
/// neutral placeholder — never an error or a broken image. Shared by the Place
/// contents tile and the "Riordina questo luogo" review card.
class PossessionThumb extends ConsumerWidget {
  const PossessionThumb({super.key, required this.possession, this.size = 48});

  final Possession possession;
  final double size;

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
          width: size,
          height: size,
          child: coverImage(
            docsPath: docs,
            relativePath: file.relativePath,
            height: size,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadii.borderSm,
      ),
      child: Icon(Icons.inventory_2_outlined, color: scheme.onSurfaceVariant),
    );
  }
}
