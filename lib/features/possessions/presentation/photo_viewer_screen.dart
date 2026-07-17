import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/platform/photo_store.dart';
import '../application/possession_providers.dart';

/// A calm, full-screen photo viewer: the whole image on a dark background, no
/// cropping, pinch-to-zoom and pan via the native [InteractiveViewer]. Only a
/// close control — never an accidental replace or delete. Presentational, so it
/// is testable with any [ImageProvider].
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

/// Resolves a possession's cover photo and shows it full-screen. A missing or
/// still-resolving cover degrades to a calm, closable black screen — never a
/// crash. Android/system Back and the close button both return to the detail.
class PhotoViewerScreen extends ConsumerWidget {
  const PhotoViewerScreen({super.key, required this.possessionId});

  final String possessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final possession = ref.watch(possessionByIdProvider(possessionId)).value;
    final fileId = possession?.coverFileId;
    final file = fileId == null
        ? null
        : ref.watch(fileByIdProvider(fileId)).value;
    final docs = ref.watch(appDocumentsPathProvider).value;

    if (file == null || docs == null) {
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

    return PhotoViewer(
      image: coverImageProvider(
        docsPath: docs,
        relativePath: file.relativePath,
      ),
      closeTooltip: l10n.closeButton,
    );
  }
}
