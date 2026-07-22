import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/daos/evidence_dao.dart';
import '../../../core/database/tables/enums.dart';
import '../../../core/managed_roots.dart';
import '../../../l10n/app_localizations.dart';
import '../../backup/domain/safe_path.dart';
import '../../backup/restore/restore_activity.dart';
import '../../backup/restore/restore_pending.dart';
import '../application/permanent_delete_activity.dart';
import '../application/permanent_delete_cleanup.dart';
import '../application/possession_providers.dart';
import 'document_pick.dart';
import 'document_store.dart';
import 'photo_import.dart';

/// The user-facing outcome of saving a record (creating or editing).
enum RecordSaveStatus {
  saved,
  blockedByBackup,
  blockedByRestore,
  blockedByPermanentDelete,
  failed,
}

/// Opens the system picker and copies the chosen file into app storage, ready to
/// hold in the editor as a pending attachment. Nothing is committed here.
Future<PickedDocument> pickAttachment() => pickDocument();

/// The calm message for a picker outcome (null when nothing to say — a chosen or
/// cancelled pick is silent).
String? attachmentPickMessage(
  AppLocalizations l10n,
  DocumentPickStatus status,
) => switch (status) {
  DocumentPickStatus.picked || DocumentPickStatus.cancelled => null,
  DocumentPickStatus.unavailable ||
  DocumentPickStatus.unreadable ||
  DocumentPickStatus.failed => l10n.documentAddFailed,
};

/// Creates a record ([EventKind] category + title/notes + date + optional
/// validity end + optional opt-in reminder) and atomically attaches
/// [newAttachments] under `documents/` — staged → promoted → one DB transaction,
/// so a failure leaves no orphan. Guards against a busy backup/restore/delete.
Future<RecordSaveStatus> saveNewRecord(
  WidgetRef ref, {
  required String possessionId,
  required EventKind kind,
  required DateTime at,
  DateTime? endsAt,
  String? title,
  String? notes,
  ReminderLead? remindLead,
  List<PickedDocument> newAttachments = const [],
}) async {
  final blocked = await _saveBlockedReason(ref);
  if (blocked != null) return _blockedStatus(blocked);

  final dao = ref.read(evidenceDaoProvider);
  Future<void> commit(List<AttachmentInput> inputs) => dao
      .createRecordWithAttachments(
        possessionId: possessionId,
        kind: kind,
        at: at,
        endsAt: endsAt,
        title: title,
        notes: notes,
        remindLead: remindLead,
        attachments: inputs,
      )
      .then((_) {});

  return _stageAndCommit(newAttachments, commit);
}

/// Adds [newAttachments] to an existing record, atomically. Used when editing.
Future<RecordSaveStatus> addAttachmentsToRecord(
  WidgetRef ref, {
  required String eventId,
  required List<PickedDocument> newAttachments,
}) async {
  if (newAttachments.isEmpty) return RecordSaveStatus.saved;
  final blocked = await _saveBlockedReason(ref);
  if (blocked != null) return _blockedStatus(blocked);
  final dao = ref.read(evidenceDaoProvider);
  return _stageAndCommit(
    newAttachments,
    (inputs) => dao.commitAttachments(eventId, inputs),
  );
}

/// Shared staging+promotion: stage all [attachments] into one operation, promote
/// them, then run [commit] with the promoted inputs — all atomic. Cleans staged
/// temp files on any failure.
Future<RecordSaveStatus> _stageAndCommit(
  List<PickedDocument> attachments,
  Future<void> Function(List<AttachmentInput>) commit,
) async {
  if (attachments.isEmpty) {
    try {
      await commit(const []);
      return RecordSaveStatus.saved;
    } catch (_) {
      return RecordSaveStatus.failed;
    }
  }

  final StagedImport staged;
  try {
    staged = await stageLocalFiles([
      for (final a in attachments)
        LocalFileToStage(srcPath: a.tempPath!, mimeType: a.mimeType!),
    ], finalRoot: kDocumentsRoot);
  } catch (_) {
    for (final a in attachments) {
      _discardTemp(a.tempPath);
    }
    return RecordSaveStatus.failed;
  }

  final outcome = await promoteAndCommit(staged, () {
    final inputs = <AttachmentInput>[
      for (var i = 0; i < staged.photos.length; i++)
        AttachmentInput(
          fileId: staged.photos[i].fileId,
          relativePath: staged.photos[i].finalRelativePath,
          mimeType: staged.photos[i].mimeType,
          byteSize: staged.photos[i].byteSize,
          label: attachments[i].displayName,
        ),
    ];
    return commit(inputs);
  });
  return outcome == PhotoPromoteOutcome.committed
      ? RecordSaveStatus.saved
      : RecordSaveStatus.failed;
}

/// After a record's Undo window closes: unlink and reclaim every attachment that
/// is no longer referenced anywhere (shared attachments are preserved). The
/// soft-deleted record itself is left as-is (never surfaced again).
Future<void> reclaimRecordAttachments(WidgetRef ref, String eventId) async {
  final dao = ref.read(evidenceDaoProvider);
  final ids = await dao.attachmentEvidenceIds(eventId);
  for (final evId in ids) {
    await dao.unlinkAttachment(eventId, evId);
    await _reclaim(ref, evId);
  }
}

/// Removes a single attachment from a record (editor "remove"): unlink now, then
/// reclaim its bytes only if nothing else references the file.
Future<void> unlinkAttachmentAndReclaim(
  WidgetRef ref, {
  required String eventId,
  required String evidenceId,
}) async {
  final dao = ref.read(evidenceDaoProvider);
  await dao.unlinkAttachment(eventId, evidenceId);
  await _reclaim(ref, evidenceId);
}

Future<void> _reclaim(WidgetRef ref, String evidenceId) async {
  final rel = await ref.read(evidenceDaoProvider).reclaimIfOrphan(evidenceId);
  if (rel == null) return; // still referenced, or file kept for another row
  final norm = normalizeRelativePath(rel);
  if (norm == null) return;
  final surviving = <String>{
    for (final raw
        in await ref.read(possessionsDaoProvider).survivingFileRelativePaths())
      ?normalizeRelativePath(raw),
  };
  if (surviving.contains(norm)) return;
  await cleanupOrphanFiles(
    normalizedPaths: [norm],
    stillReferenced: (n) async => surviving.contains(n),
  );
}

/// The calm message for a non-saved status (null when nothing to say).
String? recordSaveMessage(AppLocalizations l10n, RecordSaveStatus status) =>
    switch (status) {
      RecordSaveStatus.saved => null,
      RecordSaveStatus.blockedByBackup => l10n.mediaSaveBlockedBackup,
      RecordSaveStatus.blockedByRestore => l10n.mediaSaveBlockedRestore,
      RecordSaveStatus.blockedByPermanentDelete => l10n.mediaSaveBlockedBusy,
      RecordSaveStatus.failed => l10n.mediaSaveFailed,
    };

void _discardTemp(String? path) {
  if (path == null) return;
  try {
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
  } catch (_) {}
}

Future<String?> _saveBlockedReason(WidgetRef ref) async {
  if (await isRestorePendingOnDisk() || isRestoreBusy(ref)) return 'restore';
  if (isBackupBusy(ref)) return 'backup';
  if (ref.read(permanentDeleteBusyProvider)) return 'permanentDelete';
  return null;
}

RecordSaveStatus _blockedStatus(String reason) => switch (reason) {
  'restore' => RecordSaveStatus.blockedByRestore,
  'backup' => RecordSaveStatus.blockedByBackup,
  _ => RecordSaveStatus.blockedByPermanentDelete,
};
