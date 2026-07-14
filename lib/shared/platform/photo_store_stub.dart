import 'package:flutter/material.dart';

import 'photo_types.dart';

// Web stub: photo capture is a native-only feature for now, so these are safe
// no-ops that let the app compile for web. A capture attempt reports back as a
// silent cancellation.

Future<String?> documentsPath() async => null;

Future<PhotoResult> capturePhoto(PhotoSource source) async =>
    const PhotoResult.cancelled();

Widget coverImage({
  required String docsPath,
  required String relativePath,
  required double height,
}) =>
    const SizedBox.shrink();
