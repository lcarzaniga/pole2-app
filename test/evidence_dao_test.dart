import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/database/daos/evidence_dao.dart';
import 'package:project_kobe/core/database/tables/enums.dart';
import 'package:uuid/uuid.dart';

/// M9 — document attachments on **contextual records** (event-linked via
/// EventEvidence), on the real schema-8 database (foreign keys ON). Exercises the
/// record+attachment create, watch, unlink/relink and the orphan-reclamation
/// rules including shared-attachment protection. FK integrity is asserted after
/// every mutating path (incl. `PRAGMA foreign_key_check`).
void main() {
  late AppDatabase db;
  const uuid = Uuid();
  EvidenceDao dao() => db.evidenceDao;
  final now = DateTime(2026, 7, 22, 10);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> count(dynamic query) async => (await query.get()).length as int;
  fkCheck() async => db.customSelect('PRAGMA foreign_key_check').get();

  Future<String> newPossession(String title) async {
    final p = await db.possessionsDao.createPossession(title: title);
    return p.id;
  }

  var n = 0;
  AttachmentInput attachment({String? label}) {
    n++;
    return AttachmentInput(
      fileId: uuid.v4(),
      relativePath: 'documents/doc$n.pdf',
      mimeType: 'application/pdf',
      byteSize: 10 + n,
      label: label ?? 'Ricevuta$n.pdf',
    );
  }

  test(
    'createRecordWithAttachments builds event + files + evidence + links',
    () async {
      final p = await newPossession('Trapano');
      final eventId = await dao().createRecordWithAttachments(
        possessionId: p,
        kind: EventKind.warranty,
        at: now,
        endsAt: DateTime(2028, 7, 22),
        notes: 'Garanzia 2 anni',
        attachments: [attachment(), attachment()],
      );

      final atts = await dao().watchAttachments(eventId).first;
      expect(atts, hasLength(2));
      expect(await count(db.select(db.events)), 1);
      expect(await count(db.select(db.files)), 2);
      expect(await count(db.select(db.evidenceItems)), 2);
      expect(await count(db.select(db.eventEvidence)), 2);
      final ev = await db.eventsDao.watchEvent(eventId).first;
      expect(ev!.kind, EventKind.warranty);
      expect(ev.endsAt, DateTime(2028, 7, 22));
      expect(await fkCheck(), isEmpty);
    },
  );

  test('a record with zero attachments is a plain event', () async {
    final p = await newPossession('X');
    final eventId = await dao().createRecordWithAttachments(
      possessionId: p,
      kind: EventKind.note,
      at: now,
      notes: 'una nota semplice',
    );
    expect(await dao().watchAttachments(eventId).first, isEmpty);
    expect(await count(db.select(db.files)), 0);
    expect(await fkCheck(), isEmpty);
  });

  test('commitAttachments adds attachments to an existing record', () async {
    final p = await newPossession('X');
    final eventId = await dao().createRecordWithAttachments(
      possessionId: p,
      kind: EventKind.note,
      at: now,
      notes: 'nota',
    );
    await dao().commitAttachments(eventId, [attachment(), attachment()]);
    expect(await dao().watchAttachments(eventId).first, hasLength(2));
    expect(await fkCheck(), isEmpty);
  });

  test('watchAttachments excludes soft-deleted evidence', () async {
    final p = await newPossession('X');
    final eventId = await dao().createRecordWithAttachments(
      possessionId: p,
      kind: EventKind.note,
      at: now,
      attachments: [attachment()],
    );
    final evId =
        (await dao().watchAttachments(eventId).first).single.evidence.id;
    await (db.update(db.evidenceItems)..where((t) => t.id.equals(evId))).write(
      EvidenceItemsCompanion(deletedAt: Value(now)),
    );
    expect(await dao().watchAttachments(eventId).first, isEmpty);
  });

  test('unlink then relink (Undo) restores the attachment', () async {
    final p = await newPossession('X');
    final eventId = await dao().createRecordWithAttachments(
      possessionId: p,
      kind: EventKind.note,
      at: now,
      attachments: [attachment()],
    );
    final evId =
        (await dao().watchAttachments(eventId).first).single.evidence.id;
    await dao().unlinkAttachment(eventId, evId);
    expect(await dao().watchAttachments(eventId).first, isEmpty);
    // Evidence + file survive the unlink so Undo is possible.
    expect(await count(db.select(db.evidenceItems)), 1);
    expect(await count(db.select(db.files)), 1);
    await dao().relinkAttachment(eventId, evId);
    expect(await dao().watchAttachments(eventId).first, hasLength(1));
    expect(await fkCheck(), isEmpty);
  });

  test(
    'reclaimIfOrphan deletes row + returns path for a true orphan',
    () async {
      final p = await newPossession('X');
      final eventId = await dao().createRecordWithAttachments(
        possessionId: p,
        kind: EventKind.note,
        at: now,
        attachments: [attachment()],
      );
      final att = (await dao().watchAttachments(eventId).first).single;
      await dao().unlinkAttachment(eventId, att.evidence.id);
      final rel = await dao().reclaimIfOrphan(att.evidence.id);
      expect(rel, att.file.relativePath);
      expect(await count(db.select(db.evidenceItems)), 0);
      expect(await count(db.select(db.files)), 0);
      expect(await fkCheck(), isEmpty);
    },
  );

  test(
    'reclaimIfOrphan preserves an attachment shared by another record',
    () async {
      final p = await newPossession('X');
      final e1 = await dao().createRecordWithAttachments(
        possessionId: p,
        kind: EventKind.note,
        at: now,
        attachments: [attachment()],
      );
      final evId = (await dao().watchAttachments(e1).first).single.evidence.id;
      // Share the same evidence with a second record.
      final e2 = await dao().createRecordWithAttachments(
        possessionId: p,
        kind: EventKind.warranty,
        at: now,
      );
      await dao().relinkAttachment(e2, evId);

      await dao().unlinkAttachment(e1, evId);
      final rel = await dao().reclaimIfOrphan(evId);
      expect(rel, isNull); // still linked to e2 → untouched
      expect(await count(db.select(db.evidenceItems)), 1);
      expect(await count(db.select(db.files)), 1);
      expect(await dao().watchAttachments(e2).first, hasLength(1));
      expect(await fkCheck(), isEmpty);
    },
  );

  test('reclaimIfOrphan preserves evidence still referenced by an event\'s '
      'legacy evidenceId', () async {
    final p = await newPossession('X');
    final eventId = await dao().createRecordWithAttachments(
      possessionId: p,
      kind: EventKind.note,
      at: now,
      attachments: [attachment()],
    );
    final evId =
        (await dao().watchAttachments(eventId).first).single.evidence.id;
    // A different event points at it via the dormant single evidenceId column.
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            id: uuid.v4(),
            possessionId: p,
            kind: EventKind.custom,
            at: now,
            evidenceId: Value(evId),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await dao().unlinkAttachment(eventId, evId);
    final rel = await dao().reclaimIfOrphan(evId);
    expect(rel, isNull); // a dormant reference still holds it
    expect(await count(db.select(db.evidenceItems)), 1);
    expect(await fkCheck(), isEmpty);
  });

  test(
    'reclaimIfOrphan keeps the file when a photo row still maps it',
    () async {
      final p = await newPossession('X');
      final eventId = await dao().createRecordWithAttachments(
        possessionId: p,
        kind: EventKind.note,
        at: now,
        attachments: [
          const AttachmentInput(
            fileId: 'shared-file',
            relativePath: 'documents/shared.pdf',
            mimeType: 'application/pdf',
            byteSize: 5,
          ),
        ],
      );
      final evId =
          (await dao().watchAttachments(eventId).first).single.evidence.id;
      await db
          .into(db.possessionPhotos)
          .insert(
            PossessionPhotosCompanion.insert(
              id: uuid.v4(),
              possessionId: p,
              fileId: 'shared-file',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await dao().unlinkAttachment(eventId, evId);
      final rel = await dao().reclaimIfOrphan(evId);
      // The evidence row is orphaned and gone, but the shared file is preserved.
      expect(rel, isNull);
      expect(await count(db.select(db.evidenceItems)), 0);
      expect(await count(db.select(db.files)), 1);
      expect(await fkCheck(), isEmpty);
    },
  );

  test('attachmentEvidenceIds lists a record\'s links', () async {
    final p = await newPossession('X');
    final eventId = await dao().createRecordWithAttachments(
      possessionId: p,
      kind: EventKind.note,
      at: now,
      attachments: [attachment(), attachment()],
    );
    expect(await dao().attachmentEvidenceIds(eventId), hasLength(2));
  });

  test('reclaimIfOrphan on an unknown id is a calm no-op', () async {
    expect(await dao().reclaimIfOrphan('nope'), isNull);
  });
}
