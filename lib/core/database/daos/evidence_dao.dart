import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../tables/enums.dart';
import '../tables/tables.dart';

part 'evidence_dao.g.dart';

/// A document attachment (Evidence) paired with its backing file — everything a
/// record row needs to render and open one attachment.
class AttachmentWithFile {
  const AttachmentWithFile({required this.evidence, required this.file});

  final EvidenceItem evidence;
  final StoredFile file;

  /// Human display name (falls back to the stored filename).
  String get displayName =>
      (evidence.label != null && evidence.label!.trim().isNotEmpty)
      ? evidence.label!
      : file.relativePath.split('/').last;
}

/// One document to attach to a record: the promoted file plus its display label
/// and (technical) evidence kind. The user-facing *category* lives on the record
/// ([Events.kind]), never here.
class AttachmentInput {
  const AttachmentInput({
    required this.fileId,
    required this.relativePath,
    required this.mimeType,
    required this.byteSize,
    this.kind = EvidenceKind.other,
    this.label,
  });

  final String fileId;
  final String relativePath;
  final String mimeType;
  final int byteSize;
  final EvidenceKind kind;
  final String? label;
}

/// M9 — document attachments for **contextual records** (timeline [Events]).
/// Built on `EvidenceItems` + the new `EventEvidence` link + `Files`. An
/// attachment belongs to a record, and one attachment can be shared by several
/// records, so removing a record only unlinks and reclaims a file when nothing
/// surviving — another record, the dormant `PossessionEvidence` /
/// `Events.evidenceId`, or a cover/photo — still references it.
@DriftAccessor(
  tables: [EvidenceItems, EventEvidence, PossessionEvidence, Files, Events],
)
class EvidenceDao extends DatabaseAccessor<AppDatabase>
    with _$EvidenceDaoMixin {
  EvidenceDao(super.db);

  static const _uuid = Uuid();

  /// Attachments linked to [eventId] (non-deleted evidence), with their file,
  /// oldest-added first — reactive.
  Stream<List<AttachmentWithFile>> watchAttachments(String eventId) {
    final query =
        select(eventEvidence).join([
            innerJoin(
              evidenceItems,
              evidenceItems.id.equalsExp(eventEvidence.evidenceId),
            ),
            innerJoin(files, files.id.equalsExp(evidenceItems.fileId)),
          ])
          ..where(
            eventEvidence.eventId.equals(eventId) &
                evidenceItems.deletedAt.isNull(),
          )
          ..orderBy([OrderingTerm.asc(eventEvidence.addedAt)]);
    return query.watch().map(
      (rows) => rows
          .map(
            (r) => AttachmentWithFile(
              evidence: r.readTable(evidenceItems),
              file: r.readTable(files),
            ),
          )
          .toList(),
    );
  }

  /// Creates a timeline record ([Events]) and atomically attaches [attachments]
  /// (each a promoted file → `Files` + `EvidenceItems` + `EventEvidence`), all
  /// in one transaction. Returns the new event id.
  Future<String> createRecordWithAttachments({
    required String possessionId,
    required EventKind kind,
    required DateTime at,
    DateTime? endsAt,
    String? title,
    String? notes,
    ReminderLead? remindLead,
    List<AttachmentInput> attachments = const [],
  }) {
    return transaction(() async {
      final now = DateTime.now();
      final eventId = _uuid.v4();
      await into(events).insert(
        EventsCompanion.insert(
          id: eventId,
          possessionId: possessionId,
          kind: kind,
          at: at,
          endsAt: Value(endsAt),
          title: Value(title),
          notes: Value(notes),
          remindLead: Value(remindLead),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await _attach(eventId, attachments, now);
      return eventId;
    });
  }

  /// Attaches already-promoted [attachments] to an existing record, atomically.
  Future<void> commitAttachments(
    String eventId,
    List<AttachmentInput> attachments,
  ) {
    return transaction(() => _attach(eventId, attachments, DateTime.now()));
  }

  Future<void> _attach(
    String eventId,
    List<AttachmentInput> attachments,
    DateTime now,
  ) async {
    for (final a in attachments) {
      await into(files).insert(
        FilesCompanion.insert(
          id: a.fileId,
          relativePath: a.relativePath,
          mimeType: a.mimeType,
          byteSize: a.byteSize,
          createdAt: now,
        ),
      );
      final evidenceId = _uuid.v4();
      await into(evidenceItems).insert(
        EvidenceItemsCompanion.insert(
          id: evidenceId,
          kind: a.kind,
          label: Value(a.label),
          fileId: Value(a.fileId),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await into(eventEvidence).insert(
        EventEvidenceCompanion.insert(
          eventId: eventId,
          evidenceId: evidenceId,
          addedAt: now,
        ),
      );
    }
  }

  /// Unlinks an attachment from a record (removes only the link — the file and
  /// EvidenceItem are untouched, so a shared attachment stays intact elsewhere).
  Future<void> unlinkAttachment(String eventId, String evidenceId) {
    return (delete(eventEvidence)..where(
          (t) => t.eventId.equals(eventId) & t.evidenceId.equals(evidenceId),
        ))
        .go();
  }

  /// Re-creates a link (Undo).
  Future<void> relinkAttachment(String eventId, String evidenceId) {
    return into(eventEvidence).insert(
      EventEvidenceCompanion.insert(
        eventId: eventId,
        evidenceId: evidenceId,
        addedAt: DateTime.now(),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// The evidence ids linked to [eventId] (any state) — used to unlink and
  /// reclaim a record's attachments after its Undo window closes.
  Future<List<String>> attachmentEvidenceIds(String eventId) async {
    final rows = await (select(
      eventEvidence,
    )..where((t) => t.eventId.equals(eventId))).get();
    return [for (final r in rows) r.evidenceId];
  }

  /// If [evidenceId] is now an orphan — no surviving `EventEvidence` link, no
  /// dormant `PossessionEvidence` link, no `Events.evidenceId` reference, and no
  /// cover/photo/other-evidence sharing its file — delete the EvidenceItem and
  /// its `Files` row, returning the raw `relativePath` to reclaim on disk. A
  /// still-referenced (shared) attachment is left completely untouched (null).
  Future<String?> reclaimIfOrphan(String evidenceId) {
    return transaction(() async {
      final ev = await (select(
        evidenceItems,
      )..where((t) => t.id.equals(evidenceId))).getSingleOrNull();
      if (ev == null) return null;

      // Any surviving reference from a record, the dormant possession link, or
      // an event's single evidenceId keeps the evidence alive.
      final linkedToEvent =
          await (select(eventEvidence)
                ..where((t) => t.evidenceId.equals(evidenceId))
                ..limit(1))
              .getSingleOrNull();
      if (linkedToEvent != null) return null;
      final linkedToPossession =
          await (select(possessionEvidence)
                ..where((t) => t.evidenceId.equals(evidenceId))
                ..limit(1))
              .getSingleOrNull();
      if (linkedToPossession != null) return null;
      final eventRef =
          await (select(events)
                ..where((t) => t.evidenceId.equals(evidenceId))
                ..limit(1))
              .getSingleOrNull();
      if (eventRef != null) return null;

      await (delete(evidenceItems)..where((t) => t.id.equals(evidenceId))).go();

      final fid = ev.fileId;
      if (fid == null) return null;
      // Delete the Files row only when nothing surviving references the file.
      final asCover =
          await (select(db.possessions)
                ..where((t) => t.coverFileId.equals(fid))
                ..limit(1))
              .getSingleOrNull();
      final asPhoto =
          await (select(db.possessionPhotos)
                ..where((t) => t.fileId.equals(fid))
                ..limit(1))
              .getSingleOrNull();
      final asOtherEvidence =
          await (select(evidenceItems)
                ..where((t) => t.fileId.equals(fid))
                ..limit(1))
              .getSingleOrNull();
      if (asCover != null || asPhoto != null || asOtherEvidence != null) {
        return null;
      }
      final file = await (select(
        files,
      )..where((t) => t.id.equals(fid))).getSingleOrNull();
      await (delete(files)..where((t) => t.id.equals(fid))).go();
      return file?.relativePath;
    });
  }
}
