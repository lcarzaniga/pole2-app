import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/managed_roots.dart';
import '../../../shared/platform/photo_types.dart';
import '../../backup/domain/safe_path.dart';
import 'photo_import_marker.dart';
import 'staged_photo.dart';

const _uuid = Uuid();
const _importsRoot = 'photo_imports';
const _photosRoot = 'photos';

/// Durability note: bytes are written with `File.writeAsBytes(flush: true)` and
/// the marker with `writeAsString(flush: true)` then an atomic `rename`. Dart's
/// `flush` requests the OS flush the file's data; it is **not** a guaranteed
/// hardware fsync (the Dart IO stack exposes no fsync). The rename gives atomic
/// marker-state transitions on the same filesystem. Crash safety therefore rests
/// on startup reconciliation, not on an assumed disk-level durability.

// ---- Staging ----

Future<PhotoStageResult> stagePhoto(PhotoSource source) async {
  try {
    final picked = await ImagePicker().pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 85,
    );
    if (picked == null) return const PhotoStageResult.cancelled();
    return PhotoStageResult.success(await _stageAll([picked]));
  } on PlatformException catch (e) {
    if (e.code == 'camera_access_denied' || e.code == 'photo_access_denied') {
      return const PhotoStageResult.permissionDenied();
    }
    return const PhotoStageResult.failed();
  } catch (_) {
    return const PhotoStageResult.failed();
  }
}

Future<PhotoStageResult> stagePhotosFromGallery() async {
  try {
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 2400,
      imageQuality: 85,
    );
    if (picked.isEmpty) return const PhotoStageResult.cancelled();
    return PhotoStageResult.success(await _stageAll(picked));
  } on PlatformException catch (e) {
    if (e.code == 'photo_access_denied') {
      return const PhotoStageResult.permissionDenied();
    }
    return const PhotoStageResult.failed();
  } catch (_) {
    return const PhotoStageResult.failed();
  }
}

Future<StagedImport> _stageAll(List<XFile> picked) async {
  final docs = (await getApplicationDocumentsDirectory()).path;
  final opId = _uuid.v4();
  final opDir = Directory(p.join(docs, _importsRoot, opId))
    ..createSync(recursive: true);

  final photos = <StagedPhoto>[];
  final entries = <PhotoImportEntry>[];
  for (final x in picked) {
    final fileId = _uuid.v4();
    final ext = p.extension(x.path);
    final e = ext.isEmpty ? '.jpg' : ext;
    final tempRel = '$_importsRoot/$opId/$fileId$e';
    final finalRel = '$_photosRoot/$fileId$e';
    final dest = File(p.join(opDir.path, '$fileId$e'));
    await dest.writeAsBytes(await x.readAsBytes(), flush: true);
    final size = dest.lengthSync();
    photos.add(
      StagedPhoto(
        operationId: opId,
        fileId: fileId,
        tempRelativePath: tempRel,
        finalRelativePath: finalRel,
        byteSize: size,
        mimeType: 'image/jpeg',
      ),
    );
    entries.add(
      PhotoImportEntry(
        fileId: fileId,
        tempRelativePath: tempRel,
        finalRelativePath: finalRel,
        byteSize: size,
        mimeType: 'image/jpeg',
      ),
    );
  }

  _writeMarker(
    docs,
    PhotoImportMarker(
      operationId: opId,
      state: PhotoImportState.prepared,
      createdAtUtc: DateTime.now().toUtc().toIso8601String(),
      entries: entries,
    ),
  );
  return StagedImport(operationId: opId, photos: photos);
}

/// One already app-managed local file to stage (an attachment the native SAF
/// layer copied out of a content URI into app storage).
class LocalFileToStage {
  const LocalFileToStage({required this.srcPath, required this.mimeType});
  final String srcPath;
  final String mimeType;
}

/// Stages one already app-managed local file — see [stageLocalFiles].
Future<StagedImport> stageLocalFile(
  String srcPath, {
  required String finalRoot,
  required String mimeType,
}) => stageLocalFiles([
  LocalFileToStage(srcPath: srcPath, mimeType: mimeType),
], finalRoot: finalRoot);

/// Stages several already app-managed local files into **one** import operation
/// whose final paths are under [finalRoot], returning a [StagedImport] whose
/// photos preserve the input order. Each source is moved into staging
/// (copy+delete if on another device); afterwards the caller no longer owns it.
/// Stored names are generated `fileId`s (safe) — original filenames are kept
/// separately by the caller for display. One operation ⇒ one atomic
/// [promoteAndCommit] for a whole record's attachments. M9 uses the `documents/`
/// root.
Future<StagedImport> stageLocalFiles(
  List<LocalFileToStage> sources, {
  required String finalRoot,
}) async {
  final docs = (await getApplicationDocumentsDirectory()).path;
  final opId = _uuid.v4();
  final opDir = Directory(p.join(docs, _importsRoot, opId))
    ..createSync(recursive: true);

  final photos = <StagedPhoto>[];
  final entries = <PhotoImportEntry>[];
  for (final src in sources) {
    final fileId = _uuid.v4();
    final ext = p.extension(src.srcPath);
    final safeExt = normalizeRelativePath('x$ext') == null ? '' : ext;
    final tempRel = '$_importsRoot/$opId/$fileId$safeExt';
    final finalRel = '$finalRoot/$fileId$safeExt';
    final dest = File(p.join(opDir.path, '$fileId$safeExt'));
    try {
      File(src.srcPath).renameSync(dest.path);
    } catch (_) {
      File(src.srcPath).copySync(dest.path);
      try {
        File(src.srcPath).deleteSync();
      } catch (_) {}
    }
    final size = dest.lengthSync();
    photos.add(
      StagedPhoto(
        operationId: opId,
        fileId: fileId,
        tempRelativePath: tempRel,
        finalRelativePath: finalRel,
        byteSize: size,
        mimeType: src.mimeType,
      ),
    );
    entries.add(
      PhotoImportEntry(
        fileId: fileId,
        tempRelativePath: tempRel,
        finalRelativePath: finalRel,
        byteSize: size,
        mimeType: src.mimeType,
      ),
    );
  }

  _writeMarker(
    docs,
    PhotoImportMarker(
      operationId: opId,
      state: PhotoImportState.prepared,
      createdAtUtc: DateTime.now().toUtc().toIso8601String(),
      entries: entries,
    ),
  );
  return StagedImport(operationId: opId, photos: photos);
}

// ---- Promotion + commit ----

/// Promotes [import]'s temp files to `photos/` then runs [commit] (the Drift
/// save transaction) — crash-safely, via the durable marker. On promotion
/// failure nothing is committed; on commit failure the promoted files are
/// removed (or left for startup recovery). See [PhotoPromoteOutcome].
Future<PhotoPromoteOutcome> promoteAndCommit(
  StagedImport import,
  Future<void> Function() commit,
) async {
  final docs = (await getApplicationDocumentsDirectory()).path;

  // 1) Validate every temp/final path is safe and final paths are unique.
  final finals = <String>{};
  for (final ph in import.photos) {
    final t = normalizeRelativePath(ph.tempRelativePath);
    final f = normalizeRelativePath(ph.finalRelativePath);
    if (t == null || !t.startsWith('$_importsRoot/${import.operationId}/')) {
      return PhotoPromoteOutcome.promotionFailed;
    }
    if (f == null || !isUnderManagedRoot(f)) {
      return PhotoPromoteOutcome.promotionFailed;
    }
    if (!finals.add(f)) return PhotoPromoteOutcome.promotionFailed; // collision
    if (!File(p.join(docs, t)).existsSync()) {
      return PhotoPromoteOutcome.promotionFailed; // temp missing
    }
    if (File(p.join(docs, f)).existsSync()) {
      return PhotoPromoteOutcome.promotionFailed; // would overwrite
    }
  }

  // 2) Rename temp → final for each (creating the managed root dir); undo on
  // any failure.
  final promoted = <StagedPhoto>[];
  try {
    for (final ph in import.photos) {
      final dst = File(p.join(docs, ph.finalRelativePath));
      dst.parent.createSync(recursive: true);
      File(p.join(docs, ph.tempRelativePath)).renameSync(dst.path);
      promoted.add(ph);
    }
  } catch (_) {
    for (final ph in promoted) {
      try {
        File(
          p.join(docs, ph.finalRelativePath),
        ).renameSync(p.join(docs, ph.tempRelativePath));
      } catch (_) {}
    }
    return PhotoPromoteOutcome.promotionFailed;
  }

  // 3) Persist the promoted marker state.
  _writeMarker(
    docs,
    PhotoImportMarker(
      operationId: import.operationId,
      state: PhotoImportState.promoted,
      createdAtUtc: DateTime.now().toUtc().toIso8601String(),
      entries: [
        for (final ph in import.photos)
          PhotoImportEntry(
            fileId: ph.fileId,
            tempRelativePath: ph.tempRelativePath,
            finalRelativePath: ph.finalRelativePath,
            byteSize: ph.byteSize,
            mimeType: ph.mimeType,
          ),
      ],
    ),
  );

  // 4) Commit the database transaction.
  try {
    await commit();
  } catch (_) {
    // Roll back the filesystem: delete the promoted finals best-effort. Keep the
    // marker so startup can recover if a delete failed. No DB change survived.
    for (final ph in import.photos) {
      try {
        final f = File(p.join(docs, ph.finalRelativePath));
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    return PhotoPromoteOutcome.commitFailed;
  }

  // 5) Success — remove the marker + (now empty) import directory best-effort.
  _safeDeleteOpDir(docs, import.operationId);
  return PhotoPromoteOutcome.committed;
}

// ---- Cancellation ----

/// Removes one staged operation's temporary directory (Back/cancel). Never
/// touches anything outside the single, validated import directory.
Future<void> discardImport(String operationId) async {
  final docs = (await getApplicationDocumentsDirectory()).path;
  _safeDeleteOpDir(docs, operationId);
}

// ---- Startup reconciliation ----

/// Idempotent reconciliation of leftover imports from a previous process. Runs
/// after the database is available: [isReferenced] answers whether a committed
/// `Files` row maps a given normalized final relative path.
Future<PhotoImportReconcileReport> reconcilePhotoImports({
  required Future<bool> Function(String finalRel) isReferenced,
}) async {
  final String docs;
  try {
    docs = (await getApplicationDocumentsDirectory()).path;
  } catch (_) {
    return const PhotoImportReconcileReport();
  }
  final root = Directory(p.join(docs, _importsRoot));
  if (!root.existsSync()) return const PhotoImportReconcileReport();

  var abandoned = 0, kept = 0, orphans = 0, corrupt = 0;
  List<FileSystemEntity> entries;
  try {
    entries = root.listSync(followLinks: false);
  } catch (_) {
    return const PhotoImportReconcileReport();
  }

  for (final entry in entries) {
    if (entry is! Directory) {
      // A stray file directly under the root — remove it.
      try {
        entry.deleteSync();
      } catch (_) {}
      continue;
    }
    final opId = p.basename(entry.path);
    if (!isSafeOperationId(opId)) continue; // never follow an unsafe dir name

    final markerFile = File(p.join(entry.path, 'marker.json'));
    final marker = markerFile.existsSync()
        ? PhotoImportMarker.decode(_readOrEmpty(markerFile))
        : null;

    if (marker == null || marker.operationId != opId || !marker.pathsSafe()) {
      _safeDeleteOpDir(
        docs,
        opId,
      ); // corrupt/unsafe → drop its own temp dir only
      corrupt++;
      continue;
    }

    switch (marker.state) {
      case PhotoImportState.prepared:
        // Abandoned before promotion — remove temp + marker.
        _safeDeleteOpDir(docs, opId);
        abandoned++;
      case PhotoImportState.promoted:
        for (final e in marker.entries) {
          final rel = normalizeRelativePath(e.finalRelativePath);
          if (rel == null || !isUnderManagedRoot(rel)) continue;
          if (await isReferenced(rel)) {
            kept++; // committed — leave the final in place
          } else {
            _deleteFinal(docs, rel); // promoted orphan → remove
            orphans++;
          }
        }
        _safeDeleteOpDir(docs, opId);
    }
  }

  return PhotoImportReconcileReport(
    abandonedPrepared: abandoned,
    keptCommitted: kept,
    deletedOrphans: orphans,
    cleanedCorrupt: corrupt,
  );
}

// ---- Helpers ----

void _writeMarker(String docs, PhotoImportMarker marker) {
  final opDir = Directory(p.join(docs, _importsRoot, marker.operationId))
    ..createSync(recursive: true);
  final tmp = File(p.join(opDir.path, 'marker.json.tmp'));
  tmp.writeAsStringSync(marker.encode(), flush: true);
  tmp.renameSync(p.join(opDir.path, 'marker.json'));
}

String _readOrEmpty(File f) {
  try {
    return f.readAsStringSync();
  } catch (_) {
    return '';
  }
}

/// Deletes exactly one validated import operation directory, checking canonical
/// containment inside `photo_imports/`. Never recurses outside it.
void _safeDeleteOpDir(String docs, String operationId) {
  if (!isSafeOperationId(operationId)) return;
  final root = Directory(p.join(docs, _importsRoot));
  final dir = Directory(p.join(root.path, operationId));
  try {
    if (!dir.existsSync()) return;
    final canonicalRoot = root.resolveSymbolicLinksSync();
    final canonical = dir.resolveSymbolicLinksSync();
    if (!p.isWithin(canonicalRoot, canonical)) return;
    dir.deleteSync(recursive: true);
  } catch (_) {}
}

/// Deletes a single final file under its managed root (`photos/`/`documents/`),
/// non-recursively, with a canonical containment check.
void _deleteFinal(String docs, String normalizedRel) {
  try {
    if (!isUnderManagedRoot(normalizedRel)) return;
    final rootName = normalizedRel.split('/').first;
    final rootDir = Directory(p.join(docs, rootName));
    if (!rootDir.existsSync()) return;
    final file = File(p.join(docs, normalizedRel));
    if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return;
    }
    final canonicalRoot = rootDir.resolveSymbolicLinksSync();
    final canonical = file.resolveSymbolicLinksSync();
    if (!p.isWithin(canonicalRoot, canonical)) return;
    file.deleteSync();
  } catch (_) {}
}
