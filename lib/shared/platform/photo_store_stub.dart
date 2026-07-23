import 'dart:convert';

import 'package:flutter/material.dart';

import 'photo_types.dart';

// Web stub: photo capture is a native-only feature for now, so these are safe
// no-ops that let the app compile for web. A capture attempt reports back as a
// silent cancellation.

Future<String?> documentsPath() async => null;

Future<PhotoResult> capturePhoto(PhotoSource source) async =>
    const PhotoResult.cancelled();

Future<MultiPhotoResult> capturePhotosFromGallery() async =>
    const MultiPhotoResult.cancelled();

Widget coverImage({
  required String docsPath,
  required String relativePath,
  required double height,
}) => const SizedBox.shrink();

/// Web has no on-disk photo, so this is a 1×1 transparent placeholder — the
/// viewer is a native-only surface in practice and never reaches here with a
/// real cover.
ImageProvider coverImageProvider({
  required String docsPath,
  required String relativePath,
}) => MemoryImage(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  ),
);

/// Web has no on-disk image, so the thumbnail is just the fallback.
Widget attachmentThumb({
  required String absolutePath,
  required double size,
  required Widget fallback,
}) => SizedBox(
  width: size,
  height: size,
  child: Center(child: fallback),
);
