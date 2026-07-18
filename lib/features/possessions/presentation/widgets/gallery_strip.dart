import 'package:flutter/material.dart';

import '../../../../app/theme/app_icon_size.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/database/daos/possessions_dao.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/platform/photo_store.dart';

/// A compact, horizontally scrolling thumbnail strip of a possession's gallery
/// photos, with a trailing "add another" tile. The [photos] are already in
/// display order (cover first). Tapping a thumbnail opens the full-screen viewer
/// at that photo; management (set cover / remove) lives in the viewer, keeping
/// the detail screen light. Purely presentational.
class GalleryStrip extends StatelessWidget {
  const GalleryStrip({
    super.key,
    required this.photos,
    required this.coverFileId,
    required this.docsPath,
    required this.onOpen,
    required this.onAdd,
    this.showAdd = true,
  });

  final List<PhotoWithFile> photos;
  final String? coverFileId;
  final String? docsPath;
  final void Function(int index) onOpen;
  final VoidCallback onAdd;

  /// Whether to show the trailing "add another" tile — false for an inactive
  /// possession, where adding photos is withheld until it is restored.
  final bool showAdd;

  static const double _size = 84;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: _size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: photos.length + (showAdd ? 1 : 0), // + trailing add tile
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          if (i == photos.length) {
            return _AddTile(
              size: _size,
              label: l10n.photoAddAnother,
              onTap: onAdd,
            );
          }
          final pf = photos[i];
          final isCover = pf.file.id == coverFileId;
          return _Thumb(
            size: _size,
            docsPath: docsPath,
            relativePath: pf.file.relativePath,
            isCover: isCover,
            semanticLabel: isCover ? l10n.photoIsCover : l10n.photoView,
            onTap: () => onOpen(i),
          );
        },
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.size,
    required this.docsPath,
    required this.relativePath,
    required this.isCover,
    required this.semanticLabel,
    required this.onTap,
  });

  final double size;
  final String? docsPath;
  final String relativePath;
  final bool isCover;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        borderRadius: AppRadii.borderMd,
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: AppRadii.borderMd,
                child: docsPath == null
                    ? _placeholder(scheme)
                    : Image(
                        image: coverImageProvider(
                          docsPath: docsPath!,
                          relativePath: relativePath,
                        ),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholder(scheme),
                      ),
              ),
              // The cover gets a subtle, always-legible badge — an icon plus a
              // semantic label, so it never relies on colour alone.
              if (isCover)
                Positioned(
                  left: AppSpacing.xs,
                  top: AppSpacing.xs,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star,
                      size: AppIconSize.sm,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) => Container(
    color: scheme.surfaceContainerHighest,
    child: Icon(
      Icons.image_not_supported_outlined,
      color: scheme.onSurfaceVariant,
    ),
  );
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.size,
    required this.label,
    required this.onTap,
  });

  final double size;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: AppRadii.borderMd,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: AppRadii.borderMd,
          ),
          child: Icon(
            Icons.add_a_photo_outlined,
            size: AppIconSize.md,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }
}
