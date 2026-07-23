import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/database/tables/enums.dart';
import 'attachment_source.dart';
import 'document_pick.dart';
import 'document_store.dart';

/// The evidence-image capture profile (M9.1 locked decision): bound the long
/// edge to 3000 px and re-encode JPEG at quality 90. Passing both `maxWidth` and
/// `maxHeight` makes image_picker scale to fit within 3000×3000 (so the LONG
/// edge ≤ 3000), bake EXIF orientation into the pixels, and strip metadata on
/// re-encode. This is deliberately higher fidelity than the possession-cover
/// profile (2400/85) so photographed receipt text stays readable.
const double _evidenceMaxEdge = 3000;
const int _evidenceQuality = 90;

/// Picks one attachment from [source]. Camera/gallery return a normalized JPEG
/// image ([EvidenceKind.photo], display name left null so the caller can apply
/// the localized "Foto"); documents delegate to the existing SAF flow unchanged.
/// Never throws: cancellation and every failure are returned as status.
Future<PickedAttachment> pickAttachment(AttachmentSource source) async {
  switch (source) {
    case AttachmentSource.document:
      return _fromDocument(await pickDocument());
    case AttachmentSource.camera:
      return _pickImage(ImageSource.camera);
    case AttachmentSource.gallery:
      return _pickImage(ImageSource.gallery);
  }
}

Future<PickedAttachment> _pickImage(ImageSource src) async {
  try {
    final XFile? x = await ImagePicker().pickImage(
      source: src,
      maxWidth: _evidenceMaxEdge,
      maxHeight: _evidenceMaxEdge,
      imageQuality: _evidenceQuality,
      // Don't fetch full EXIF/location metadata; we store stripped JPEGs.
      requestFullMetadata: false,
    );
    if (x == null) return const PickedAttachment.cancelled();
    // Synchronous metadata read (no content, no async IO) — keeps the picker
    // usable under widget-test fake-async and never blocks the UI isolate.
    final file = File(x.path);
    final size = file.existsSync() ? file.lengthSync() : 0;
    if (size <= 0) return const PickedAttachment.unreadable();
    return PickedAttachment.picked(
      tempPath: x.path,
      // Always JPEG after re-encoding — the stored file uses a .jpg extension.
      mimeType: 'image/jpeg',
      byteSize: size,
      kind: EvidenceKind.photo,
      // displayName intentionally null → caller applies the localized "Foto".
    );
  } on PlatformException catch (e) {
    if (e.code == 'camera_access_denied' || e.code == 'photo_access_denied') {
      return const PickedAttachment.permissionDenied();
    }
    return const PickedAttachment.failed();
  } catch (_) {
    return const PickedAttachment.failed();
  }
}

PickedAttachment _fromDocument(PickedDocument d) => switch (d.status) {
  DocumentPickStatus.picked => PickedAttachment.picked(
    tempPath: d.tempPath!,
    displayName: d.displayName,
    mimeType: d.mimeType!,
    byteSize: d.byteSize!,
    kind: EvidenceKind.other,
  ),
  DocumentPickStatus.cancelled => const PickedAttachment.cancelled(),
  DocumentPickStatus.unavailable => const PickedAttachment.unavailable(),
  DocumentPickStatus.unreadable => const PickedAttachment.unreadable(),
  DocumentPickStatus.failed => const PickedAttachment.failed(),
};
