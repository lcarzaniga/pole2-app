import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/photo_capture.dart';
import '../../../shared/platform/photo_types.dart';
import '../../backup/restore/restore_activity.dart';
import '../../backup/restore/restore_pending.dart';
import '../application/permanent_delete_activity.dart';
import '../application/possession_providers.dart';
import 'photo_import.dart';

/// The user-facing outcome of a staged-photo save.
enum PhotoSaveStatus {
  saved,
  blockedByBackup,
  blockedByRestore,
  blockedByPermanentDelete,
  failed,
}

/// A create-with-cover result: the [status] and, on success, the new id.
class CreateWithCoverResult {
  const CreateWithCoverResult(this.status, [this.possessionId]);
  final PhotoSaveStatus status;
  final String? possessionId;
}

/// Chooser → stage one photo into the temporary import area. Shows the calm
/// denied/failed snackbar; silent on cancel. Returns the staged import or null.
Future<StagedImport?> chooseAndStagePhoto(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  final source = await showPhotoSourceSheet(context);
  if (source == null) return null;
  final res = await stagePhoto(source);
  _say(messenger, l10n, res.outcome);
  return res.import;
}

/// Chooser → stage one (camera) or several (gallery) photos.
Future<StagedImport?> chooseAndStagePhotos(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  final source = await showPhotoSourceSheet(context);
  if (source == null) return null;
  final res = source == PhotoSource.camera
      ? await stagePhoto(source)
      : await stagePhotosFromGallery();
  _say(messenger, l10n, res.outcome);
  return res.import;
}

/// Guards, then crash-safely promotes [import] and commits its photos onto an
/// existing possession. [coverFirst] promotes the first to cover (replace-cover).
Future<PhotoSaveStatus> saveStagedToPossession(
  WidgetRef ref, {
  required StagedImport import,
  required String possessionId,
  bool coverFirst = false,
}) async {
  final blocked = await _saveBlockedReason(ref);
  if (blocked != null) return _blockedStatus(blocked);

  final outcome = await promoteAndCommit(import, () {
    return ref.read(possessionsDaoProvider).commitStagedPhotos(possessionId, [
      for (var i = 0; i < import.photos.length; i++)
        (
          fileId: import.photos[i].fileId,
          relativePath: import.photos[i].finalRelativePath,
          mimeType: import.photos[i].mimeType,
          byteSize: import.photos[i].byteSize,
          asCover: coverFirst && i == 0,
        ),
    ]);
  });
  return outcome == PhotoPromoteOutcome.committed
      ? PhotoSaveStatus.saved
      : PhotoSaveStatus.failed;
}

/// Creates a possession, atomically with its promoted cover when [import] is set
/// (photo-first creation). Without an import it is a plain, never-blocked create.
Future<CreateWithCoverResult> createPossessionWithStagedCover(
  WidgetRef ref, {
  required String title,
  String? category,
  StagedImport? import,
}) async {
  final dao = ref.read(possessionsDaoProvider);
  if (import == null || import.isEmpty) {
    final created = await dao.createPossession(
      title: title,
      category: category,
    );
    return CreateWithCoverResult(PhotoSaveStatus.saved, created.id);
  }
  final blocked = await _saveBlockedReason(ref);
  if (blocked != null) return CreateWithCoverResult(_blockedStatus(blocked));

  final cover = import.photos.first;
  String? createdId;
  final outcome = await promoteAndCommit(import, () async {
    final created = await dao.createPossessionWithCover(
      title: title,
      category: category,
      cover: (
        fileId: cover.fileId,
        relativePath: cover.finalRelativePath,
        mimeType: cover.mimeType,
        byteSize: cover.byteSize,
      ),
    );
    createdId = created.id;
  });
  return outcome == PhotoPromoteOutcome.committed
      ? CreateWithCoverResult(PhotoSaveStatus.saved, createdId)
      : const CreateWithCoverResult(PhotoSaveStatus.failed);
}

/// The calm message for a non-saved status (or null when nothing to say).
String? photoSaveMessage(AppLocalizations l10n, PhotoSaveStatus status) =>
    switch (status) {
      PhotoSaveStatus.saved => null,
      PhotoSaveStatus.blockedByBackup => l10n.mediaSaveBlockedBackup,
      PhotoSaveStatus.blockedByRestore => l10n.mediaSaveBlockedRestore,
      PhotoSaveStatus.blockedByPermanentDelete => l10n.mediaSaveBlockedBusy,
      PhotoSaveStatus.failed => l10n.mediaSaveFailed,
    };

Future<String?> _saveBlockedReason(WidgetRef ref) async {
  if (await isRestorePendingOnDisk() || isRestoreBusy(ref)) return 'restore';
  if (isBackupBusy(ref)) return 'backup';
  if (ref.read(permanentDeleteBusyProvider)) return 'permanentDelete';
  return null;
}

PhotoSaveStatus _blockedStatus(String reason) => switch (reason) {
  'restore' => PhotoSaveStatus.blockedByRestore,
  'backup' => PhotoSaveStatus.blockedByBackup,
  _ => PhotoSaveStatus.blockedByPermanentDelete,
};

void _say(
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  PhotoOutcome outcome,
) {
  final message = photoOutcomeMessage(l10n, outcome);
  if (message != null) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }
}
