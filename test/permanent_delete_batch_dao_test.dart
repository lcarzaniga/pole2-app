import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/database/daos/possessions_dao.dart';
import 'package:project_kobe/core/database/tables/enums.dart';
import 'package:uuid/uuid.dart';

/// M8.2B — the atomic batch deletion engine. Real in-memory schema-7 database
/// (foreign keys ON), so all-or-nothing semantics, the union candidate rules and
/// FK integrity are exercised.
void main() {
  late AppDatabase db;
  const uuid = Uuid();
  PossessionsDao dao() => db.possessionsDao;
  final now = DateTime(2026, 7, 21, 12);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> removedPossession(String title) async {
    final p = await dao().createPossession(title: title);
    await dao().softDelete(p.id);
    return p.id;
  }

  Future<String> addPhoto(String possId, String rel) async {
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

  Future<int> count(dynamic query) async => (await query.get()).length as int;
  fkCheck() async => db.customSelect('PRAGMA foreign_key_check').get();

  test('deletes every selected possession and its owned rows', () async {
    final party = await addParty('Marco');
    final place = await db.placesDao.create(name: 'Garage');
    final a = await removedPossession('A');
    final b = await removedPossession('B');
    final keep = await removedPossession('Keep');
    await dao().setCover(
      a,
      relativePath: 'photos/a.jpg',
      mimeType: 'image/jpeg',
      byteSize: 1,
    );
    await addPhoto(b, 'photos/b.jpg');
    await dao().setPlace(keep, place);
    await addEvent(a, EventKind.acquired, partyId: party);
    await addEvent(b, EventKind.note);
    await addEvent(keep, EventKind.acquired, partyId: party);

    final r = await dao().permanentlyDeleteMany([a, b]);
    expect(r.outcome, PermanentDeleteDbOutcome.deleted);

    expect(await dao().watchById(a).first, isNull);
    expect(await dao().watchById(b).first, isNull);
    // Unselected possession and its history survive.
    expect(await dao().watchById(keep).first, isNotNull);
    expect(
      await count(
        db.select(db.events)..where((t) => t.possessionId.equals(keep)),
      ),
      1,
    );
    // Owned events of the selected are gone.
    expect(
      await count(
        db.select(db.events)..where((t) => t.possessionId.isIn([a, b])),
      ),
      0,
    );
    // Shared Party and Place survive.
    expect(await count(db.select(db.parties)), 1);
    expect(await count(db.select(db.places)), 1);
    expect(await fkCheck(), isEmpty);
  });

  test(
    'one restored/ineligible id aborts the whole batch (all-or-nothing)',
    () async {
      final a = await removedPossession('A');
      final b = await removedPossession('B');
      await dao().setCover(
        a,
        relativePath: 'photos/a.jpg',
        mimeType: 'image/jpeg',
        byteSize: 1,
      );
      // b is restored (no longer removed) → the batch must abort untouched.
      await dao().restoreRemoved(b);

      final r = await dao().permanentlyDeleteMany([a, b]);
      expect(r.outcome, PermanentDeleteDbOutcome.staleSelection);
      // Nothing changed.
      expect(await dao().watchById(a).first, isNotNull);
      expect(await dao().watchById(b).first, isNotNull);
      expect(await count(db.select(db.files)), 1);
      expect(await fkCheck(), isEmpty);
    },
  );

  test('a missing id aborts the whole batch', () async {
    final a = await removedPossession('A');
    final r = await dao().permanentlyDeleteMany([a, 'ghost']);
    expect(r.outcome, PermanentDeleteDbOutcome.staleSelection);
    expect(await dao().watchById(a).first, isNotNull);
  });

  test('an active (non-removed) selected id is rejected', () async {
    final removed = await removedPossession('R');
    final active = await dao().createPossession(title: 'Live');
    final r = await dao().permanentlyDeleteMany([removed, active.id]);
    expect(r.outcome, PermanentDeleteDbOutcome.staleSelection);
    expect(await dao().watchById(removed).first, isNotNull);
    expect(await dao().watchById(active.id).first, isNotNull);
  });

  test(
    'a file shared between two selected possessions is deleted once',
    () async {
      final a = await removedPossession('A');
      final b = await removedPossession('B');
      final fid = await addPhoto(a, 'photos/shared.jpg');
      // b references the same file id.
      await db
          .into(db.possessionPhotos)
          .insert(
            PossessionPhotosCompanion.insert(
              id: uuid.v4(),
              possessionId: b,
              fileId: fid,
              createdAt: now,
              updatedAt: now,
            ),
          );

      final r = await dao().permanentlyDeleteMany([a, b]);
      expect(r.outcome, PermanentDeleteDbOutcome.deleted);
      expect(r.removedFilePaths, ['photos/shared.jpg']);
      expect(await count(db.select(db.files)), 0);
      expect(await fkCheck(), isEmpty);
    },
  );

  test('a file shared with an UNselected possession survives', () async {
    final a = await removedPossession('A');
    final keep = await removedPossession('Keep');
    final fid = await addPhoto(a, 'photos/shared.jpg');
    await db
        .into(db.possessionPhotos)
        .insert(
          PossessionPhotosCompanion.insert(
            id: uuid.v4(),
            possessionId: keep,
            fileId: fid,
            createdAt: now,
            updatedAt: now,
          ),
        );

    final r = await dao().permanentlyDeleteMany([a]); // keep NOT selected
    expect(r.outcome, PermanentDeleteDbOutcome.deleted);
    expect(r.removedFilePaths, isEmpty);
    expect(await count(db.select(db.files)), 1);
    expect(await fkCheck(), isEmpty);
  });

  test('a candidate file referenced by surviving evidence survives', () async {
    final a = await removedPossession('A');
    await dao().setCover(
      a,
      relativePath: 'photos/a.jpg',
      mimeType: 'image/jpeg',
      byteSize: 1,
    );
    final coverId = (await dao().watchById(a).first)!.coverFileId!;
    await db
        .into(db.evidenceItems)
        .insert(
          EvidenceItemsCompanion.insert(
            id: uuid.v4(),
            kind: EvidenceKind.receipt,
            fileId: Value(coverId),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final r = await dao().permanentlyDeleteMany([a]);
    expect(r.outcome, PermanentDeleteDbOutcome.deleted);
    expect(r.removedFilePaths, isEmpty);
    expect(await count(db.select(db.files)), 1); // preserved for evidence
    expect(await count(db.select(db.evidenceItems)), 1);
  });

  test('never globally garbage-collects unrelated orphan Files', () async {
    final a = await removedPossession('A');
    await dao().setCover(
      a,
      relativePath: 'photos/a.jpg',
      mimeType: 'image/jpeg',
      byteSize: 1,
    );
    // An unrelated orphan file row, referenced by nothing.
    await db
        .into(db.files)
        .insert(
          FilesCompanion.insert(
            id: uuid.v4(),
            relativePath: 'photos/orphan.jpg',
            mimeType: 'image/jpeg',
            byteSize: 1,
            createdAt: now,
          ),
        );

    final r = await dao().permanentlyDeleteMany([a]);
    expect(r.outcome, PermanentDeleteDbOutcome.deleted);
    // Only a's cover file was removed; the unrelated orphan is untouched.
    expect(r.removedFilePaths, ['photos/a.jpg']);
    final remaining = await db.select(db.files).get();
    expect(remaining.map((f) => f.relativePath), ['photos/orphan.jpg']);
  });

  test('empty selection is a harmless no-op', () async {
    final r = await dao().permanentlyDeleteMany([]);
    expect(r.outcome, PermanentDeleteDbOutcome.deleted);
    expect(r.removedFilePaths, isEmpty);
  });

  test('single permanentlyDelete still delegates and is idempotent', () async {
    final a = await removedPossession('A');
    await dao().setCover(
      a,
      relativePath: 'photos/a.jpg',
      mimeType: 'image/jpeg',
      byteSize: 1,
    );
    final first = await dao().permanentlyDelete(a);
    expect(first.outcome, PermanentDeleteDbOutcome.deleted);
    expect(first.removedFilePaths, ['photos/a.jpg']);
    final second = await dao().permanentlyDelete(a);
    expect(second.outcome, PermanentDeleteDbOutcome.notFound);
    expect(await fkCheck(), isEmpty);
  });
}
