import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/database/daos/possessions_dao.dart';
import 'package:project_kobe/core/database/tables/enums.dart';
import 'package:uuid/uuid.dart';

/// M8.2A — the transactional database phase of permanent deletion. Uses a real
/// in-memory schema-7 database (foreign keys ON via the migration's beforeOpen),
/// so FK integrity and the exact candidate/exclusivity rules are exercised.
void main() {
  late AppDatabase db;
  const uuid = Uuid();
  PossessionsDao dao() => db.possessionsDao;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  final now = DateTime(2026, 7, 21, 12);

  Future<String> addFilePhoto(String possId, String rel) async {
    await dao().addPhoto(
      possId,
      relativePath: rel,
      mimeType: 'image/jpeg',
      byteSize: 1,
    );
    final photos = await dao().watchPhotos(possId).first;
    return photos.firstWhere((p) => p.file.relativePath == rel).file.id;
  }

  Future<void> addEvent(
    String possId,
    EventKind kind, {
    String? partyId,
    String? originPlaceId,
    String? evidenceId,
  }) async {
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            id: uuid.v4(),
            possessionId: possId,
            kind: kind,
            at: now,
            partyId: Value(partyId),
            originPlaceId: Value(originPlaceId),
            evidenceId: Value(evidenceId),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<String> addParty(String name) async {
    final id = uuid.v4();
    await db
        .into(db.parties)
        .insert(
          PartiesCompanion.insert(
            id: id,
            name: name,
            kind: const Value(PartyKind.person),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<String> addEvidence({String? fileId}) async {
    final id = uuid.v4();
    await db
        .into(db.evidenceItems)
        .insert(
          EvidenceItemsCompanion.insert(
            id: id,
            kind: EvidenceKind.receipt,
            fileId: Value(fileId),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<int> count(dynamic query) async => (await query.get()).length as int;

  fkCheck() async => db.customSelect('PRAGMA foreign_key_check').get();

  test('an active possession cannot be permanently deleted', () async {
    final p = await dao().createPossession(title: 'Trapano');
    final r = await dao().permanentlyDelete(p.id);
    expect(r.outcome, PermanentDeleteDbOutcome.notRemoved);
    expect(await dao().watchById(p.id).first, isNotNull);
  });

  test(
    'archived / transferred / lost / disposed but non-removed cannot be deleted',
    () async {
      for (final s in [
        PossessionStatus.archived,
        PossessionStatus.transferred,
        PossessionStatus.lost,
        PossessionStatus.disposed,
      ]) {
        final p = await dao().createPossession(title: 'X');
        await dao().setStatus(p.id, s);
        final r = await dao().permanentlyDelete(p.id);
        expect(
          r.outcome,
          PermanentDeleteDbOutcome.notRemoved,
          reason: '$s must not be permanently deletable while not removed',
        );
        expect(await dao().watchById(p.id).first, isNotNull);
      }
    },
  );

  test('unknown id is notFound', () async {
    final r = await dao().permanentlyDelete('nope');
    expect(r.outcome, PermanentDeleteDbOutcome.notFound);
  });

  test('a removed possession is deleted with all owned rows gone', () async {
    final place = await db.placesDao.create(name: 'Garage');
    final party = await addParty('Marco');
    final p = await dao().createPossession(title: 'Trapano');
    // Cover + a second gallery photo.
    await dao().setCover(
      p.id,
      relativePath: 'photos/cover.jpg',
      mimeType: 'image/jpeg',
      byteSize: 1,
    );
    await addFilePhoto(p.id, 'photos/second.jpg');
    // A full spread of owned rows.
    await addEvent(p.id, EventKind.acquired, partyId: party);
    await addEvent(p.id, EventKind.reminder);
    await addEvent(p.id, EventKind.note);
    await addEvent(p.id, EventKind.lent, partyId: party, originPlaceId: place);
    await addEvent(p.id, EventKind.returned, partyId: party);
    await addEvent(
      p.id,
      EventKind.transfer,
      partyId: party,
      originPlaceId: place,
    );
    await addEvent(p.id, EventKind.reacquired);
    await db
        .into(db.identifiers)
        .insert(
          IdentifiersCompanion.insert(
            id: uuid.v4(),
            possessionId: p.id,
            kind: IdentifierKind.serialNumber,
            value: 'SN1',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.attributes)
        .insert(
          AttributesCompanion.insert(
            id: uuid.v4(),
            possessionId: p.id,
            label: 'Colore',
            value: 'Blu',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final evidence = await addEvidence();
    await db
        .into(db.possessionEvidence)
        .insert(
          PossessionEvidenceCompanion.insert(
            possessionId: p.id,
            evidenceId: evidence,
            addedAt: now,
          ),
        );

    await dao().softDelete(p.id);
    final r = await dao().permanentlyDelete(p.id);
    expect(r.outcome, PermanentDeleteDbOutcome.deleted);

    // Everything owned is gone.
    expect(await dao().watchById(p.id).first, isNull);
    expect(
      await count(
        db.select(db.events)..where((t) => t.possessionId.equals(p.id)),
      ),
      0,
    );
    expect(
      await count(
        db.select(db.possessionPhotos)
          ..where((t) => t.possessionId.equals(p.id)),
      ),
      0,
    );
    expect(
      await count(
        db.select(db.identifiers)..where((t) => t.possessionId.equals(p.id)),
      ),
      0,
    );
    expect(
      await count(
        db.select(db.attributes)..where((t) => t.possessionId.equals(p.id)),
      ),
      0,
    );
    expect(
      await count(
        db.select(db.possessionEvidence)
          ..where((t) => t.possessionId.equals(p.id)),
      ),
      0,
    );

    // The two exclusive files' rows are gone and returned as byte candidates.
    expect(r.removedFilePaths.toSet(), {
      'photos/cover.jpg',
      'photos/second.jpg',
    });
    expect(await count(db.select(db.files)), 0);

    // Shared/other-owned data survives.
    expect(await count(db.select(db.parties)), 1);
    expect(await count(db.select(db.places)), 1);
    expect(await count(db.select(db.evidenceItems)), 1);

    // No dangling foreign keys.
    expect(await fkCheck(), isEmpty);
  });

  test('a file also used by another possession is preserved', () async {
    final keep = (await dao().createPossession(title: 'Keep')).id;
    final gone = (await dao().createPossession(title: 'Gone')).id;
    final sharedFileId = await addFilePhoto(gone, 'photos/shared.jpg');
    // A second possession's photo row points at the SAME file id.
    await db
        .into(db.possessionPhotos)
        .insert(
          PossessionPhotosCompanion.insert(
            id: uuid.v4(),
            possessionId: keep,
            fileId: sharedFileId,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await dao().softDelete(gone);
    final r = await dao().permanentlyDelete(gone);
    expect(r.outcome, PermanentDeleteDbOutcome.deleted);

    // The shared file row survives and is NOT a byte candidate.
    expect(r.removedFilePaths, isEmpty);
    expect(await count(db.select(db.files)), 1);
    expect(await fkCheck(), isEmpty);
  });

  test(
    'a candidate file referenced by surviving evidence is preserved',
    () async {
      final p = await dao().createPossession(title: 'X');
      await dao().setCover(
        p.id,
        relativePath: 'photos/cover.jpg',
        mimeType: 'image/jpeg',
        byteSize: 1,
      );
      final coverId = (await dao().watchById(p.id).first)!.coverFileId!;
      // An EvidenceItem (shared lifecycle, deferred) references the cover file.
      await addEvidence(fileId: coverId);

      await dao().softDelete(p.id);
      final r = await dao().permanentlyDelete(p.id);
      expect(r.outcome, PermanentDeleteDbOutcome.deleted);

      // Cover file row preserved (evidence still references it), no byte candidate.
      expect(r.removedFilePaths, isEmpty);
      expect(await count(db.select(db.files)), 1);
      expect(await fkCheck(), isEmpty);
    },
  );

  test('another possession and its history are untouched', () async {
    final party = await addParty('Ada');
    final keep = (await dao().createPossession(title: 'Keep')).id;
    await dao().setCover(
      keep,
      relativePath: 'photos/keep.jpg',
      mimeType: 'image/jpeg',
      byteSize: 1,
    );
    await addEvent(keep, EventKind.acquired, partyId: party);

    final gone = (await dao().createPossession(title: 'Gone')).id;
    await dao().setCover(
      gone,
      relativePath: 'photos/gone.jpg',
      mimeType: 'image/jpeg',
      byteSize: 1,
    );
    await dao().softDelete(gone);
    await dao().permanentlyDelete(gone);

    expect(await dao().watchById(keep).first, isNotNull);
    expect(
      await count(
        db.select(db.events)..where((t) => t.possessionId.equals(keep)),
      ),
      1,
    );
    expect(await count(db.select(db.files)), 1); // only keep's cover remains
    expect(await fkCheck(), isEmpty);
  });

  test('soft-deleted gallery photos are deleted too', () async {
    final p = await dao().createPossession(title: 'X');
    await dao().setCover(
      p.id,
      relativePath: 'photos/a.jpg',
      mimeType: 'image/jpeg',
      byteSize: 1,
    );
    await addFilePhoto(p.id, 'photos/b.jpg');
    final photos = await dao().watchPhotos(p.id).first;
    final bPhoto = photos.firstWhere(
      (x) => x.file.relativePath == 'photos/b.jpg',
    );
    await dao().removePhoto(p.id, bPhoto.photo.id); // soft-delete b

    await dao().softDelete(p.id);
    final r = await dao().permanentlyDelete(p.id);

    expect(r.outcome, PermanentDeleteDbOutcome.deleted);
    expect(r.removedFilePaths.toSet(), {'photos/a.jpg', 'photos/b.jpg'});
    expect(await count(db.select(db.possessionPhotos)), 0);
    expect(await count(db.select(db.files)), 0);
    expect(await fkCheck(), isEmpty);
  });

  test('repeated deletion is idempotent (second call is notFound)', () async {
    final p = await dao().createPossession(title: 'X');
    await dao().softDelete(p.id);
    final first = await dao().permanentlyDelete(p.id);
    expect(first.outcome, PermanentDeleteDbOutcome.deleted);
    final second = await dao().permanentlyDelete(p.id);
    expect(second.outcome, PermanentDeleteDbOutcome.notFound);
    expect(second.removedFilePaths, isEmpty);
  });
}
