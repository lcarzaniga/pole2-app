import '../../../shared/platform/photo_types.dart';
import 'staged_photo.dart';

/// Web/other-platform stub: staged photo import is native-only, so capture is a
/// silent cancellation, promotion never runs and there is nothing to reconcile.
/// Imports nothing native.
Future<PhotoStageResult> stagePhoto(PhotoSource source) async =>
    const PhotoStageResult.cancelled();

Future<PhotoStageResult> stagePhotosFromGallery() async =>
    const PhotoStageResult.cancelled();

class LocalFileToStage {
  const LocalFileToStage({
    required this.srcPath,
    required this.mimeType,
    this.ext,
  });
  final String srcPath;
  final String mimeType;
  final String? ext;
}

Future<StagedImport> stageLocalFile(
  String srcPath, {
  required String finalRoot,
  required String mimeType,
}) async => const StagedImport(operationId: '', photos: []);

Future<StagedImport> stageLocalFiles(
  List<LocalFileToStage> sources, {
  required String finalRoot,
}) async => const StagedImport(operationId: '', photos: []);

Future<PhotoPromoteOutcome> promoteAndCommit(
  StagedImport import,
  Future<void> Function() commit,
) async {
  // No filesystem here; just run the DB commit so web stays consistent.
  await commit();
  return PhotoPromoteOutcome.committed;
}

Future<void> discardImport(String operationId) async {}

Future<PhotoImportReconcileReport> reconcilePhotoImports({
  required Future<bool> Function(String finalRel) isReferenced,
}) async => const PhotoImportReconcileReport();
