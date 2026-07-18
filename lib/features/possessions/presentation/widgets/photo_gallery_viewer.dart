import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A calm, full-screen multi-photo viewer: one image at a time on a dark
/// background, horizontal swipe between photos, pinch-zoom and pan on each.
///
/// Presentational — it takes ready [images] and callbacks, so it's testable
/// with any [ImageProvider]. Gesture handling keeps [PageView] and
/// [InteractiveViewer] from fighting: while the current image is zoomed the page
/// swipe is suspended (so a pan moves the image, not the page), and every page
/// change resets zoom so the next image always starts at normal scale.
class PhotoGalleryViewer extends StatefulWidget {
  const PhotoGalleryViewer({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.closeTooltip,
    this.positionLabel,
    this.actionsBuilder,
  });

  final List<ImageProvider> images;
  final int initialIndex;
  final String closeTooltip;

  /// Builds the subtle "2 di 4" indicator; only shown when there's more than one
  /// photo. Given the 1-based current position and the total.
  final String Function(int current, int total)? positionLabel;

  /// Optional app-bar actions for the *current* photo (e.g. set-as-cover /
  /// remove), rebuilt as the page changes so they always target what's on screen.
  final Widget Function(BuildContext context, int currentIndex)? actionsBuilder;

  @override
  State<PhotoGalleryViewer> createState() => _PhotoGalleryViewerState();
}

class _PhotoGalleryViewerState extends State<PhotoGalleryViewer> {
  late PageController _page;
  late List<TransformationController> _controllers;
  int _index = 0;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _index = _clampIndex(widget.initialIndex);
    _page = PageController(initialPage: _index);
    _controllers = _makeControllers(widget.images.length);
    _attachListener(_index);
  }

  int _clampIndex(int i) =>
      widget.images.isEmpty ? 0 : i.clamp(0, widget.images.length - 1);

  List<TransformationController> _makeControllers(int n) =>
      List.generate(n, (_) => TransformationController());

  void _attachListener(int i) {
    for (final c in _controllers) {
      c.removeListener(_onTransform);
    }
    if (i >= 0 && i < _controllers.length) {
      _controllers[i].addListener(_onTransform);
    }
  }

  void _onTransform() {
    if (_index >= _controllers.length) return;
    final zoomed = _controllers[_index].value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  @override
  void didUpdateWidget(PhotoGalleryViewer old) {
    super.didUpdateWidget(old);
    // The gallery shrank/grew under us (a photo was removed/restored while open).
    // Rebuild controllers and keep the page index valid instead of crashing.
    if (widget.images.length != _controllers.length) {
      for (final c in _controllers) {
        c.removeListener(_onTransform);
        c.dispose();
      }
      _controllers = _makeControllers(widget.images.length);
      _index = _clampIndex(_index);
      _zoomed = false;
      _attachListener(_index);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _page.hasClients && widget.images.isNotEmpty) {
          _page.jumpToPage(_index);
        }
      });
    }
  }

  void _onPageChanged(int i) {
    // Reset every page's zoom so no image is left unexpectedly magnified.
    for (final c in _controllers) {
      c.value = Matrix4.identity();
    }
    _attachListener(i);
    setState(() {
      _index = i;
      _zoomed = false;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.images.length;
    final showPosition = total > 1 && widget.positionLabel != null;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          tooltip: widget.closeTooltip,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: showPosition
            ? Text(
                widget.positionLabel!(math.min(_index, total - 1) + 1, total),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              )
            : null,
        actions: [
          if (widget.actionsBuilder != null && total > 0)
            widget.actionsBuilder!(context, _clampIndex(_index)),
        ],
      ),
      body: SafeArea(
        child: PageView.builder(
          controller: _page,
          physics: _zoomed
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          onPageChanged: _onPageChanged,
          itemCount: total,
          itemBuilder: (context, i) => InteractiveViewer(
            transformationController: _controllers[i],
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: Image(image: widget.images[i], fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
