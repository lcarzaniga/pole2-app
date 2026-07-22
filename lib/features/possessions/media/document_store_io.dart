import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'document_pick.dart';

/// The native document channel — extends the app's existing SAF plumbing with an
/// `ACTION_OPEN_DOCUMENT` flow that returns the chosen file's metadata and copies
/// its bytes into app-private storage (no persisted content-URI permission, no
/// storage permission).
const MethodChannel _channel = MethodChannel('pole2/documents');
const Uuid _uuid = Uuid();

/// Opens the system document picker, then copies the chosen file into a private
/// temp file the caller owns. Never keeps the SAF content URI — the returned
/// [PickedDocument.tempPath] is a real file in app storage.
Future<PickedDocument> pickDocument() async {
  final Map<dynamic, dynamic>? picked;
  try {
    picked = await _channel.invokeMethod<Map<dynamic, dynamic>>('pickDocument');
  } on MissingPluginException {
    return const PickedDocument.unavailable();
  } on PlatformException {
    return const PickedDocument.failed();
  }
  if (picked == null) return const PickedDocument.cancelled();

  final uri = picked['uri'] as String?;
  if (uri == null || uri.isEmpty) return const PickedDocument.failed();

  final displayName = sanitizeDocumentName(picked['name'] as String?);
  final mime = (picked['mime'] as String?)?.trim();
  final mimeType = (mime == null || mime.isEmpty)
      ? 'application/octet-stream'
      : mime;

  // A temp file under the app cache, with the sanitized extension so the OS
  // viewer can later pick a handler. The stored name is a generated id.
  final ext = p.extension(displayName);
  final tmpDir = await getTemporaryDirectory();
  final stageDir = Directory(p.join(tmpDir.path, 'doc_pick'))
    ..createSync(recursive: true);
  final destPath = p.join(stageDir.path, '${_uuid.v4()}$ext');

  final int bytes;
  try {
    bytes =
        await _channel.invokeMethod<int>('copyToFile', {
          'uri': uri,
          'destPath': destPath,
        }) ??
        0;
  } on PlatformException catch (e) {
    _cleanup(destPath);
    return switch (e.code) {
      'open_denied' ||
      'open_failed' ||
      'copy_io_failed' ||
      'empty_document' => const PickedDocument.unreadable(),
      _ => const PickedDocument.failed(),
    };
  }
  if (bytes <= 0) {
    _cleanup(destPath);
    return const PickedDocument.unreadable();
  }

  return PickedDocument.picked(
    tempPath: destPath,
    displayName: displayName,
    mimeType: mimeType,
    byteSize: bytes,
  );
}

/// Hands the document at [relativePath] (under the app documents dir) to the
/// operating system's own viewer. Never keeps a handle open; the OS gets a
/// one-shot read grant to an app-private copy.
Future<DocumentOpenStatus> openDocument({
  required String relativePath,
  required String mimeType,
  String? displayName,
}) async {
  final String absPath;
  try {
    final docs = (await getApplicationDocumentsDirectory()).path;
    absPath = p.join(docs, relativePath);
  } catch (_) {
    return DocumentOpenStatus.failed;
  }
  if (!File(absPath).existsSync()) return DocumentOpenStatus.missing;
  try {
    await _channel.invokeMethod<bool>('openFile', {
      'path': absPath,
      'mime': mimeType,
      'displayName': displayName,
    });
    return DocumentOpenStatus.opened;
  } on MissingPluginException {
    return DocumentOpenStatus.unavailable;
  } on PlatformException catch (e) {
    return switch (e.code) {
      'missing' => DocumentOpenStatus.missing,
      'no_handler' => DocumentOpenStatus.noHandler,
      _ => DocumentOpenStatus.failed,
    };
  }
}

void _cleanup(String path) {
  try {
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
  } catch (_) {}
}

/// Best-effort deletion of a picked-but-never-committed temp file (editor cancel
/// / attachment removed before save). Keeps `dart:io` out of the UI layer.
void discardPickedDocument(String tempPath) => _cleanup(tempPath);
