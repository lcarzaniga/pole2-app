/// Metadata for a photo the app has stored on disk. Platform-agnostic so both
/// the real (dart:io) and web-stub implementations share it.
class StoredPhoto {
  const StoredPhoto({
    required this.relativePath,
    required this.mimeType,
    required this.byteSize,
  });

  final String relativePath;
  final String mimeType;
  final int byteSize;
}

/// Where a photo comes from. The user always chooses explicitly (see the calm
/// source chooser) — we never silently default to one.
enum PhotoSource { camera, gallery }

/// What happened when we tried to capture/pick a photo. Kept as data (not
/// exceptions) so callers handle every case calmly and the UI copy is decided
/// in one place. `cancelled` is a normal, silent outcome — never an error.
enum PhotoOutcome { success, cancelled, permissionDenied, failed }

/// The result of a capture attempt. On [PhotoOutcome.success], [photo] is set.
class PhotoResult {
  const PhotoResult.success(StoredPhoto this.photo)
      : outcome = PhotoOutcome.success;
  const PhotoResult.cancelled()
      : outcome = PhotoOutcome.cancelled,
        photo = null;
  const PhotoResult.permissionDenied()
      : outcome = PhotoOutcome.permissionDenied,
        photo = null;
  const PhotoResult.failed()
      : outcome = PhotoOutcome.failed,
        photo = null;

  final PhotoOutcome outcome;
  final StoredPhoto? photo;
}
