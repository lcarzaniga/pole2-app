import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'document_types.dart';

/// Picks a single document from device storage (a receipt PDF, a manual, an
/// image of a warranty card, …) and copies it into the app-owned documents
/// directory, returning a typed [DocumentResult].
///
/// Never throws to the caller: a user cancellation is [DocumentOutcome.cancelled]
/// (silent); anything else is [DocumentOutcome.failed] ("nothing was lost"). The
/// user's current work is never disturbed by a failed pick.
Future<DocumentResult> pickDocument() async {
  try {
    final result = await FilePicker.pickFiles();
    final picked = result?.files.singleOrNull;
    if (picked == null) return const DocumentResult.cancelled();
    final srcPath = picked.path;
    if (srcPath == null) return const DocumentResult.failed();

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'documents'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final ext = p.extension(picked.name);
    final name = '${const Uuid().v4()}$ext';
    final rel = p.join('documents', name);
    final dest = File(p.join(docs.path, rel));
    await File(srcPath).copy(dest.path);
    return DocumentResult.success(StoredDocument(
      relativePath: rel,
      mimeType: _mimeForExtension(ext),
      byteSize: dest.lengthSync(),
      name: picked.name,
    ));
  } catch (_) {
    return const DocumentResult.failed();
  }
}

/// A best-effort MIME type from a file extension — enough to pick an icon and
/// keep the metadata meaningful. Unknown types fall back to a generic binary.
String _mimeForExtension(String ext) {
  switch (ext.toLowerCase()) {
    case '.pdf':
      return 'application/pdf';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.png':
      return 'image/png';
    case '.heic':
      return 'image/heic';
    case '.doc':
    case '.docx':
      return 'application/msword';
    case '.txt':
      return 'text/plain';
    default:
      return 'application/octet-stream';
  }
}
