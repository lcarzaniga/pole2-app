/// Pure, platform-agnostic types for M9.1 record attachments — no `dart:io` and
/// no platform channels, so the UI/domain layer depends only on this contract
/// (never on Android/image_picker/SAF classes) and the web graph stays clean.
library;

import '../../../core/database/tables/enums.dart';

/// Where an attachment comes from. The user always chooses explicitly from the
/// "Aggiungi allegato" sheet — we never default to one.
enum AttachmentSource {
  /// Photograph new evidence with the system camera.
  camera,

  /// Pick an existing image from the system photo picker.
  gallery,

  /// Pick a document (PDF etc.) via the system document picker (SAF).
  document,
}

/// What happened when the user tried to pick an attachment. Data, never
/// exceptions, so every case is handled calmly in one place.
enum AttachmentPickStatus {
  /// Chosen and copied into app storage, ready to stage.
  picked,

  /// The user backed out — say nothing.
  cancelled,

  /// No picker for this source is available on this platform/device.
  unavailable,

  /// The OS denied camera / photo access.
  permissionDenied,

  /// The chosen file couldn't be read (gone, empty, or access lost).
  unreadable,

  /// Any other failure.
  failed,
}

/// A picked (not yet committed) attachment: the local temp file plus the
/// metadata the staged lifecycle needs, and the [EvidenceKind] that will be
/// stored on its EvidenceItem (image evidence → [EvidenceKind.photo]).
class PickedAttachment {
  const PickedAttachment._(
    this.status, {
    this.tempPath,
    this.displayName,
    this.mimeType,
    this.byteSize,
    this.kind,
  });

  const PickedAttachment.cancelled() : this._(AttachmentPickStatus.cancelled);
  const PickedAttachment.unavailable()
    : this._(AttachmentPickStatus.unavailable);
  const PickedAttachment.permissionDenied()
    : this._(AttachmentPickStatus.permissionDenied);
  const PickedAttachment.unreadable() : this._(AttachmentPickStatus.unreadable);
  const PickedAttachment.failed() : this._(AttachmentPickStatus.failed);

  const PickedAttachment.picked({
    required String tempPath,
    required String mimeType,
    required int byteSize,
    required EvidenceKind kind,
    String? displayName,
  }) : this._(
         AttachmentPickStatus.picked,
         tempPath: tempPath,
         displayName: displayName,
         mimeType: mimeType,
         byteSize: byteSize,
         kind: kind,
       );

  final AttachmentPickStatus status;
  final String? tempPath;
  final String? displayName;
  final String? mimeType;
  final int? byteSize;
  final EvidenceKind? kind;

  /// True when the attachment is a raster image (drives the thumbnail preview).
  bool get isImage => (mimeType ?? '').startsWith('image/');

  /// A copy with a chosen display name — used to apply the localized default
  /// label ("Foto") to a captured image, since the picker has no localization.
  PickedAttachment withDisplayName(String name) => PickedAttachment._(
    status,
    tempPath: tempPath,
    displayName: name,
    mimeType: mimeType,
    byteSize: byteSize,
    kind: kind,
  );
}
