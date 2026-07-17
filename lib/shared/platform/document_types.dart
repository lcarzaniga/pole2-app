/// Metadata for a document the app has copied onto its own storage. Kept
/// platform-agnostic so the real (dart:io) and web-stub implementations share
/// it, mirroring [StoredPhoto].
class StoredDocument {
  const StoredDocument({
    required this.relativePath,
    required this.mimeType,
    required this.byteSize,
    required this.name,
  });

  final String relativePath;
  final String mimeType;
  final int byteSize;

  /// The original file name, shown to the user (the on-disk name is a UUID).
  final String name;
}

/// What happened when we tried to pick a document. Data, not exceptions, so
/// callers stay calm and the copy lives in one place. `cancelled` is normal.
enum DocumentOutcome { success, cancelled, failed }

/// The result of a pick attempt. On [DocumentOutcome.success], [document] is set.
class DocumentResult {
  const DocumentResult.success(StoredDocument this.document)
      : outcome = DocumentOutcome.success;
  const DocumentResult.cancelled()
      : outcome = DocumentOutcome.cancelled,
        document = null;
  const DocumentResult.failed()
      : outcome = DocumentOutcome.failed,
        document = null;

  final DocumentOutcome outcome;
  final StoredDocument? document;
}
