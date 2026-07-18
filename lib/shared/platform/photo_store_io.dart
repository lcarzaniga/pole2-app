import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'photo_types.dart';

/// The app documents directory path, where photo bytes live.
Future<String?> documentsPath() async =>
    (await getApplicationDocumentsDirectory()).path;

/// Captures a photo from [source] (camera or gallery), copies it into the
/// app-owned documents directory, and returns a typed [PhotoResult].
///
/// Never throws to the caller: a user cancellation is [PhotoOutcome.cancelled]
/// (silent), a denied camera/photo permission is [PhotoOutcome.permissionDenied]
/// (calm recovery copy), and anything else is [PhotoOutcome.failed] ("nothing
/// was lost"). The user's current work is never disturbed by a failed capture.
Future<PhotoResult> capturePhoto(PhotoSource source) async {
  try {
    final picked = await ImagePicker().pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 85,
    );
    if (picked == null) return const PhotoResult.cancelled();

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'photos'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final ext = p.extension(picked.path);
    final name = '${const Uuid().v4()}${ext.isEmpty ? '.jpg' : ext}';
    final rel = p.join('photos', name);
    final dest = File(p.join(docs.path, rel));
    await dest.writeAsBytes(await picked.readAsBytes());
    return PhotoResult.success(
      StoredPhoto(
        relativePath: rel,
        mimeType: 'image/jpeg',
        byteSize: dest.lengthSync(),
      ),
    );
  } on PlatformException catch (e) {
    // image_picker surfaces a denied OS permission with these codes.
    if (e.code == 'camera_access_denied' || e.code == 'photo_access_denied') {
      return const PhotoResult.permissionDenied();
    }
    return const PhotoResult.failed();
  } catch (_) {
    return const PhotoResult.failed();
  }
}

/// Picks one or more images from the gallery and copies each into app-owned
/// storage, returning them in pick order. `image_picker`'s `pickMultiImage` is
/// stable on the project's Android toolchain. Same calm error model as
/// [capturePhoto]: cancellation and every failure are data, never thrown.
Future<MultiPhotoResult> capturePhotosFromGallery() async {
  try {
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 2400,
      imageQuality: 85,
    );
    if (picked.isEmpty) return const MultiPhotoResult.cancelled();

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'photos'));
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final stored = <StoredPhoto>[];
    for (final picture in picked) {
      final ext = p.extension(picture.path);
      final name = '${const Uuid().v4()}${ext.isEmpty ? '.jpg' : ext}';
      final rel = p.join('photos', name);
      final dest = File(p.join(docs.path, rel));
      await dest.writeAsBytes(await picture.readAsBytes());
      stored.add(
        StoredPhoto(
          relativePath: rel,
          mimeType: 'image/jpeg',
          byteSize: dest.lengthSync(),
        ),
      );
    }
    return MultiPhotoResult.success(stored);
  } on PlatformException catch (e) {
    if (e.code == 'photo_access_denied') {
      return const MultiPhotoResult.permissionDenied();
    }
    return const MultiPhotoResult.failed();
  } catch (_) {
    return const MultiPhotoResult.failed();
  }
}

/// Renders a stored cover photo.
Widget coverImage({
  required String docsPath,
  required String relativePath,
  required double height,
}) {
  return Image.file(
    File(p.join(docsPath, relativePath)),
    width: double.infinity,
    height: height,
    fit: BoxFit.cover,
  );
}

/// An [ImageProvider] for a stored photo — used by the full-screen viewer, which
/// needs the raw provider (not a pre-sized widget) to fit and zoom the image.
ImageProvider coverImageProvider({
  required String docsPath,
  required String relativePath,
}) => FileImage(File(p.join(docsPath, relativePath)));
