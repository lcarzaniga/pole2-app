import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/database/tables/enums.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> newPossession({String? placeId}) async {
    final p = await db.possessionsDao.createPossession(title: 'Trapano');
    if (placeId != null) await db.possessionsDao.setPlace(p.id, placeId);
    return p.id;
  }

  Future<String?> statusPlace(String id) async =>
      (await db.possessionsDao.watchById(id).first)!.placeId;
  Future<PossessionStatus> status(String id) async =>
      (await db.possessionsDao.watchById(id).first)!.status;
  Future<List<String>> ids(Stream<List<Possession>> s) async =>
      (await s.first).map((p) => p.id).toList();

  test(
    'giving records a transfer to a person, sets transferred, clears place',
    () async {
      final garage = await db.placesDao.create(name: 'Garage');
      final id = await newPossession(placeId: garage);
      final ev = await db.eventsDao.give(
        possessionId: id,
        personName: 'Marco',
        transferredAt: DateTime(2026, 7, 1),
        note: 'per il trasloco',
      );
      expect(ev, isNotNull);
      expect(ev!.kind, EventKind.transfer);
      expect(ev.status, EventStatus.done);
      expect(ev.at, DateTime(2026, 7, 1));
      expect(ev.originPlaceId, garage);
      expect(ev.notes, 'per il trasloco');
      final recipient = await db.eventsDao.watchParty(ev.partyId!).first;
      expect(recipient!.kind, PartyKind.person);
      expect(await status(id), PossessionStatus.transferred);
      expect(await statusPlace(id), isNull);
    },
  );

  test('a supplier is never selected/created as recipient', () async {
    await db.eventsDao.saveAcquisition(
      possessionId: await newPossession(),
      supplierName: 'Negozio',
    );
    final id = await newPossession();
    await db.eventsDao.give(
      possessionId: id,
      personName: 'Marco',
      transferredAt: DateTime(2026, 7, 1),
    );
    final people = await db.eventsDao.watchPeople().first;
    expect(people.map((p) => p.name), ['Marco']); // supplier excluded
  });

  test('given thing leaves Home and Places, appears in Conservati', () async {
    final garage = await db.placesDao.create(name: 'Garage');
    final id = await newPossession(placeId: garage);
    await db.eventsDao.give(
      possessionId: id,
      personName: 'Marco',
      transferredAt: DateTime(2026, 7, 1),
    );
    expect(await ids(db.possessionsDao.watchAll()), isNot(contains(id)));
    expect(await ids(db.possessionsDao.watchByPlace(garage)), isEmpty);
    expect(await ids(db.possessionsDao.watchArchived()), contains(id));
    expect(await ids(db.possessionsDao.watchRemoved()), isNot(contains(id)));
  });

  test('an active loan blocks giving; a completed loan does not', () async {
    final id = await newPossession();
    final loan = (await db.eventsDao.lend(
      possessionId: id,
      personName: 'Lucia',
      lentAt: DateTime(2026, 6, 1),
    ))!;
    // Active loan → give refused, nothing changes.
    expect(
      await db.eventsDao.give(
        possessionId: id,
        personName: 'Marco',
        transferredAt: DateTime(2026, 7, 1),
      ),
      isNull,
    );
    expect(await status(id), PossessionStatus.active);
    // Return it, then giving works.
    await db.eventsDao.returnLoan(
      possessionId: id,
      loanEventId: loan.id,
      returnedAt: DateTime(2026, 6, 10),
    );
    expect(
      await db.eventsDao.give(
        possessionId: id,
        personName: 'Marco',
        transferredAt: DateTime(2026, 7, 1),
      ),
      isNotNull,
    );
  });

  test('a transferred thing cannot be given again', () async {
    final id = await newPossession();
    await db.eventsDao.give(
      possessionId: id,
      personName: 'Marco',
      transferredAt: DateTime(2026, 7, 1),
    );
    expect(
      await db.eventsDao.give(
        possessionId: id,
        personName: 'Lucia',
        transferredAt: DateTime(2026, 7, 2),
      ),
      isNull,
    );
  });

  test('recipient history survives the person being soft-deleted', () async {
    final id = await newPossession();
    final ev = (await db.eventsDao.give(
      possessionId: id,
      personName: 'Marco',
      transferredAt: DateTime(2026, 7, 1),
    ))!;
    await (db.update(db.parties)..where((t) => t.id.equals(ev.partyId!))).write(
      PartiesCompanion(deletedAt: Value(DateTime.now())),
    );
    expect(
      (await db.eventsDao.watchPeople().first),
      isEmpty,
    ); // hidden as recipient
    final recipient = await db.eventsDao.watchParty(ev.partyId!).first;
    expect(recipient!.name, 'Marco'); // history still readable
  });

  test(
    'transferred + removed appears only in Rimossi; undelete → Conservati',
    () async {
      final id = await newPossession();
      await db.eventsDao.give(
        possessionId: id,
        personName: 'Marco',
        transferredAt: DateTime(2026, 7, 1),
      );
      await db.possessionsDao.softDelete(id);
      expect(await ids(db.possessionsDao.watchArchived()), isNot(contains(id)));
      expect(await ids(db.possessionsDao.watchRemoved()), contains(id));
      // Undeleting preserves the transferred status → back to Conservati, not Home.
      await db.possessionsDao.restoreRemoved(id);
      expect(await status(id), PossessionStatus.transferred);
      expect(await ids(db.possessionsDao.watchArchived()), contains(id));
      expect(await ids(db.possessionsDao.watchAll()), isNot(contains(id)));
    },
  );

  test(
    'reacquire sets active, records a distinct event, keeps the transfer',
    () async {
      final garage = await db.placesDao.create(name: 'Garage');
      final id = await newPossession(placeId: garage);
      final ev = (await db.eventsDao.give(
        possessionId: id,
        personName: 'Marco',
        transferredAt: DateTime(2026, 7, 1),
      ))!;
      await db.eventsDao.reacquire(
        possessionId: id,
        reacquiredAt: DateTime(2026, 7, 10),
        placeId: garage,
      );
      expect(await status(id), PossessionStatus.active);
      expect(await statusPlace(id), garage); // valid origin restored
      final timeline = await db.eventsDao.watchTimeline(id).first;
      expect(
        timeline.any((e) => e.id == ev.id && e.kind == EventKind.transfer),
        isTrue,
      );
      expect(timeline.any((e) => e.kind == EventKind.reacquired), isTrue);
      expect(
        await ids(db.possessionsDao.watchAll()),
        contains(id),
      ); // back on Home
    },
  );

  test(
    'reacquire into a deleted/unreachable branch falls back to no place',
    () async {
      final casa = await db.placesDao.create(name: 'Casa');
      final box = await db.placesDao.create(name: 'Scatola', parentId: casa);
      final id = await newPossession(placeId: box);
      await db.eventsDao.give(
        possessionId: id,
        personName: 'Marco',
        transferredAt: DateTime(2026, 7, 1),
      );
      await db.placesDao.softDelete(casa); // ancestor gone → box unreachable
      await db.eventsDao.reacquire(
        possessionId: id,
        reacquiredAt: DateTime(2026, 7, 10),
        placeId: box,
      );
      expect(await statusPlace(id), isNull);
    },
  );

  test('a moved subtree keeps the exact valid origin on reacquire', () async {
    final casa = await db.placesDao.create(name: 'Casa');
    final camera = await db.placesDao.create(name: 'Camera', parentId: casa);
    final box = await db.placesDao.create(name: 'Scatola', parentId: camera);
    final id = await newPossession(placeId: box);
    final ev = (await db.eventsDao.give(
      possessionId: id,
      personName: 'Marco',
      transferredAt: DateTime(2026, 7, 1),
    ))!;
    expect(ev.originPlaceId, box);
    await db.placesDao.move(camera, null); // subtree still valid, new path
    await db.eventsDao.reacquire(
      possessionId: id,
      reacquiredAt: DateTime(2026, 7, 10),
      placeId: ev.originPlaceId,
    );
    expect(await statusPlace(id), box);
  });

  test('immediate Undo is atomic: active, transfer neutralized, place back, '
      'other data intact', () async {
    final garage = await db.placesDao.create(name: 'Garage');
    final id = await newPossession(placeId: garage);
    await db.possessionsDao.addPhoto(
      id,
      relativePath: 'p/a.jpg',
      mimeType: 'image/jpeg',
      byteSize: 1,
    );
    await db.eventsDao.saveAcquisition(possessionId: id, note: 'mine');
    final ev = (await db.eventsDao.give(
      possessionId: id,
      personName: 'Marco',
      transferredAt: DateTime(2026, 7, 1),
    ))!;

    await db.eventsDao.undoGive(possessionId: id, transferEventId: ev.id);
    expect(await status(id), PossessionStatus.active);
    expect(await statusPlace(id), garage); // origin restored
    final timeline = await db.eventsDao.watchTimeline(id).first;
    expect(timeline.any((e) => e.id == ev.id), isFalse); // transfer neutralized
    expect(timeline.any((e) => e.kind == EventKind.acquired), isTrue); // intact
    expect((await db.possessionsDao.watchPhotos(id).first).length, 1);
    expect(await ids(db.possessionsDao.watchAll()), contains(id));
  });
}
