import 'dart:convert';

import '../../../core/managed_roots.dart';
import '../../backup/domain/safe_path.dart';

/// The durable operation marker for M8.2D staged photo imports. Pure (no
/// `dart:io`): serialization, parsing and path-safety validation only.
///
/// It contains **no personal text, title, photo content or absolute path** —
/// only generated identifiers, safe relative paths, a [state] and a timestamp.
/// Written atomically (temp file + rename) by the native store.
enum PhotoImportState { prepared, promoted }

class PhotoImportEntry {
  const PhotoImportEntry({
    required this.fileId,
    required this.tempRelativePath,
    required this.finalRelativePath,
    required this.byteSize,
    required this.mimeType,
  });

  final String fileId;
  final String tempRelativePath;
  final String finalRelativePath;
  final int byteSize;
  final String mimeType;
}

class PhotoImportMarker {
  const PhotoImportMarker({
    required this.operationId,
    required this.state,
    required this.createdAtUtc,
    required this.entries,
  });

  static const int version = 1;

  final String operationId;
  final PhotoImportState state;
  final String createdAtUtc;
  final List<PhotoImportEntry> entries;

  PhotoImportMarker withState(PhotoImportState next) => PhotoImportMarker(
    operationId: operationId,
    state: next,
    createdAtUtc: createdAtUtc,
    entries: entries,
  );

  String encode() => jsonEncode({
    'v': version,
    'operationId': operationId,
    'state': state.name,
    'createdAtUtc': createdAtUtc,
    'entries': [
      for (final e in entries)
        {
          'fileId': e.fileId,
          'temp': e.tempRelativePath,
          'final': e.finalRelativePath,
          'size': e.byteSize,
          'mime': e.mimeType,
        },
    ],
  });

  /// Parses a marker, returning null on anything malformed or wrong-typed (a
  /// corrupt marker is never followed).
  static PhotoImportMarker? decode(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final opId = decoded['operationId'];
    final stateRaw = decoded['state'];
    final created = decoded['createdAtUtc'];
    final rawEntries = decoded['entries'];
    if (opId is! String || opId.isEmpty) return null;
    if (created is! String) return null;
    final state = switch (stateRaw) {
      'prepared' => PhotoImportState.prepared,
      'promoted' => PhotoImportState.promoted,
      _ => null,
    };
    if (state == null) return null;
    if (rawEntries is! List) return null;
    final entries = <PhotoImportEntry>[];
    for (final e in rawEntries) {
      if (e is! Map) return null;
      final fileId = e['fileId'];
      final temp = e['temp'];
      final fin = e['final'];
      final size = e['size'];
      final mime = e['mime'];
      if (fileId is! String || temp is! String || fin is! String) return null;
      if (size is! int || mime is! String) return null;
      entries.add(
        PhotoImportEntry(
          fileId: fileId,
          tempRelativePath: temp,
          finalRelativePath: fin,
          byteSize: size,
          mimeType: mime,
        ),
      );
    }
    return PhotoImportMarker(
      operationId: opId,
      state: state,
      createdAtUtc: created,
      entries: entries,
    );
  }

  /// True when every path is safe: temp under this operation's import dir, final
  /// under `photos/`. An unsafe marker is never followed to a filesystem path.
  bool pathsSafe() {
    final prefix = 'photo_imports/$operationId/';
    if (!isSafeOperationId(operationId)) return false;
    for (final e in entries) {
      final t = normalizeRelativePath(e.tempRelativePath);
      final f = normalizeRelativePath(e.finalRelativePath);
      if (t == null || !t.startsWith(prefix)) return false;
      if (f == null || !isUnderManagedRoot(f)) return false;
    }
    return true;
  }
}

/// A Pole²-generated operation id must be a plain single path segment — no dots,
/// slashes, or separators — so it can never traverse out of `photo_imports/`.
bool isSafeOperationId(String id) {
  if (id.isEmpty || id.length > 64) return false;
  return RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id);
}
