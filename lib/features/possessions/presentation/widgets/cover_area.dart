import 'package:flutter/material.dart';

import '../../../../app/theme/app_icon_size.dart';
import '../../../../app/theme/app_spacing.dart';

/// The possession cover area.
///
/// With no photo ([image] null) the whole area invites adding one and taps
/// through to [onAdd]. With a photo, tapping the image opens it full-screen
/// ([onView]); a calm pencil in the lower-right replaces it ([onEdit]). The
/// pencil consumes its own tap, so replacing never also opens the viewer.
class CoverArea extends StatelessWidget {
  const CoverArea({
    super.key,
    required this.height,
    required this.image,
    required this.addLabel,
    required this.editTooltip,
    this.viewLabel,
    this.onAdd,
    this.onView,
    this.onEdit,
  });

  final double height;

  /// The cover image widget, already sized to fill. Null means "no cover yet".
  final Widget? image;

  final String addLabel;
  final String editTooltip;

  /// Accessibility label for the tap-to-view image (optional).
  final String? viewLabel;

  final VoidCallback? onAdd;
  final VoidCallback? onView;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final img = image;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ColoredBox(
        color: scheme.surfaceContainerLow,
        child: img == null ? _addHint(context) : _withPhoto(context, img),
      ),
    );
  }

  Widget _addHint(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onAdd,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              size: AppIconSize.lg,
              color: scheme.primary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              addLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _withPhoto(BuildContext context, Widget img) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          button: true,
          label: viewLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onView,
            child: img,
          ),
        ),
        // A calm, always-legible pencil over any image. Its own button consumes
        // the tap, so it never falls through to the view gesture beneath.
        Positioned(
          right: AppSpacing.sm,
          bottom: AppSpacing.sm,
          child: Material(
            color: Colors.black.withValues(alpha: 0.45),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              tooltip: editTooltip,
              iconSize: AppIconSize.md,
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              onPressed: onEdit,
            ),
          ),
        ),
      ],
    );
  }
}
