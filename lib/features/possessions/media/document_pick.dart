/// Pure types and helpers for M9 document selection — no `dart:io`, so this is
/// safe to import from the web graph and directly unit-testable.
library;

/// What happened when the user tried to pick a document.
enum DocumentPickStatus {
  /// A document was chosen, copied into app storage, and is ready to stage.
  picked,

  /// The user backed out of the system picker — say nothing.
  cancelled,

  /// No document picker is available on this platform/device.
  unavailable,

  /// The chosen file could not be read (permission lost, empty, or gone).
  unreadable,

  /// Any other failure copying the bytes.
  failed,
}

/// What happened when a document was handed to the OS viewer.
enum DocumentOpenStatus {
  /// The OS viewer was launched.
  opened,

  /// The file is no longer on disk.
  missing,

  /// No installed app can open this type of document.
  noHandler,

  /// Opening documents is not available on this platform.
  unavailable,

  /// Any other failure.
  failed,
}

/// The result of [pickDocument]: a status and, on success, the copied temp file
/// with its sanitized display name, mime type and byte size.
class PickedDocument {
  const PickedDocument._(
    this.status, {
    this.tempPath,
    this.displayName,
    this.mimeType,
    this.byteSize,
  });

  const PickedDocument.cancelled() : this._(DocumentPickStatus.cancelled);
  const PickedDocument.unavailable() : this._(DocumentPickStatus.unavailable);
  const PickedDocument.unreadable() : this._(DocumentPickStatus.unreadable);
  const PickedDocument.failed() : this._(DocumentPickStatus.failed);

  const PickedDocument.picked({
    required String tempPath,
    required String displayName,
    required String mimeType,
    required int byteSize,
  }) : this._(
         DocumentPickStatus.picked,
         tempPath: tempPath,
         displayName: displayName,
         mimeType: mimeType,
         byteSize: byteSize,
       );

  final DocumentPickStatus status;
  final String? tempPath;
  final String? displayName;
  final String? mimeType;
  final int? byteSize;
}

/// Turns a provider-supplied display name into something safe to **store as an
/// extension** and **show to a person**: a single path segment (no separators),
/// no control characters, trimmed, length-bounded, with a calm fallback. The
/// original is never trusted for a filesystem path — only a generated id is —
/// but a clean name still drives the extension and the on-screen label.
String sanitizeDocumentName(String? raw) {
  const fallback = 'documento';
  if (raw == null) return fallback;
  // Keep only the last path segment — defeat `../` and absolute paths.
  var name = raw.replaceAll('\\', '/');
  name = name.contains('/') ? name.split('/').last : name;
  // Drop control chars and characters awkward on common filesystems.
  final buf = StringBuffer();
  for (final rune in name.runes) {
    if (rune < 0x20 || rune == 0x7f) continue;
    final ch = String.fromCharCode(rune);
    if (r'<>:"/\|?*'.contains(ch)) continue;
    buf.write(ch);
  }
  name = buf.toString().trim();
  // Collapse a name that is only dots (".", "..") to the fallback.
  if (name.isEmpty || name.replaceAll('.', '').isEmpty) return fallback;
  if (name.length > 120) {
    // Preserve a trailing extension when trimming an over-long name.
    final dot = name.lastIndexOf('.');
    if (dot > 0 && name.length - dot <= 12) {
      final ext = name.substring(dot);
      name = name.substring(0, 120 - ext.length) + ext;
    } else {
      name = name.substring(0, 120);
    }
  }
  return name;
}
