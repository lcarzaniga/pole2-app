import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/daos/possessions_dao.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/platform/photo_store.dart';
import '../application/gallery_order.dart';
import '../application/possession_providers.dart';
import 'widgets/photo_gallery_viewer.dart';

/// A calm, full-screen photo viewer: the whole image on a dark background, no
/// cropping, pinch-to-zoom and pan via the native [InteractiveViewer]. Only a
/// close control — never an accidental replace or delete. Presentational, so it
/// is testable with any [ImageProvider]. (Single-image; the gallery screen uses
/// [PhotoGalleryViewer].)
class PhotoViewer extends StatelessWidget {
  const PhotoViewer({
    super.key,
    required this.image,
    required this.closeTooltip,
  });

  final ImageProvider image;
  final String closeTooltip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: closeTooltip,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Image(image: image, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

/// Resolves a possession's photo gallery and shows it full-screen, cover first.
/// Opening the cover starts at the cover; opening a thumbnail starts there. A
/// missing path degrades to a calm, closable black screen; when the last photo
/// is removed the screen leaves itself back to the detail — never a crash.
class PhotoViewerScreen extends ConsumerWidget {
  const PhotoViewerScreen({
    super.key,
    required this.possessionId,
    this.initialIndex = 0,
  });

  final String possessionId;
  final int initialIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final possession = ref.watch(possessionByIdProvider(possessionId)).value;
    final coverFileId = possession?.coverFileId;
    final photosAsync = ref.watch(possessionPhotosProvider(possessionId));
    final photos = photosAsync.value ?? const <PhotoWithFile>[];
    final docs = ref.watch(appDocumentsPathProvider).value;

    final ordered = orderCoverFirst(
      photos,
      fileId: (p) => p.file.id,
      coverFileId: coverFileId,
    );

    // The gallery emptied while open (or the possession is gone) → leave calmly
    // back to the detail. Only pop once we actually know it's empty.
    if (photosAsync.hasValue && ordered.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return _blackClosable(context, l10n);
    }

    // No documents path (web/tests) or still resolving → a calm black screen.
    if (docs == null || ordered.isEmpty) {
      return _blackClosable(context, l10n);
    }

    final images = [
      for (final pf in ordered)
        coverImageProvider(docsPath: docs, relativePath: pf.file.relativePath),
    ];

    return PhotoGalleryViewer(
      images: images,
      initialIndex: initialIndex,
      closeTooltip: l10n.closeButton,
      positionLabel: (current, total) => l10n.photoPosition(current, total),
      actionsBuilder: (context, current) => _PhotoMenu(
        possessionId: possessionId,
        photo: ordered[current],
        isCover: ordered[current].file.id == coverFileId,
      ),
    );
  }

  Widget _blackClosable(BuildContext context, AppLocalizations l10n) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: l10n.closeButton,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}

/// The current photo's management overflow: set as cover / remove. Reachable as
/// a labelled menu (not a swipe or an image tap), so it's TalkBack-friendly and
/// can never fire by accident. Snackbars use the root messenger, so an Undo
/// stays visible even when removing the last photo pops the viewer.
class _PhotoMenu extends ConsumerWidget {
  const _PhotoMenu({
    required this.possessionId,
    required this.photo,
    required this.isCover,
  });

  final String possessionId;
  final PhotoWithFile photo;
  final bool isCover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      iconColor: Colors.white,
      onSelected: (value) => switch (value) {
        'cover' => _setCover(ref),
        'remove' => _remove(context, ref, l10n),
        _ => null,
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'cover',
          enabled: !isCover,
          child: Text(l10n.photoSetCover),
        ),
        PopupMenuItem(value: 'remove', child: Text(l10n.photoRemove)),
      ],
    );
  }

  void _setCover(WidgetRef ref) {
    if (isCover) return;
    ref.read(possessionsDaoProvider).setCoverPhoto(possessionId, photo.file.id);
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final dao = ref.read(possessionsDaoProvider);
    final wasCover = isCover;
    await dao.removePhoto(possessionId, photo.photo.id);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(l10n.photoRemovedSnack),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => dao.restorePhoto(
              possessionId,
              photo.photo.id,
              asCover: wasCover,
            ),
          ),
        ),
      );
  }
}
