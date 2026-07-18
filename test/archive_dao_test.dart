import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/database/daos/possessions_dao.dart';
import 'package:project_kobe/core/database/tables/enums.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  PossessionsDao dao() => db.possessionsDao;

  Future<List<String>> ids(Stream<List<Possession>> s) async =>
      (await s.first).map((p) => p.id).toList();

  Future<String> newPossession() async =>
      (await db.possessionsDao.createPossession(title: 'Trapano')).id;

  test('Conservati holds non-active, non-deleted; Rimossi holds deleted; '
      'active appears in neither', () async {
    final active = await newPossession();
    final archived = await newPossession();
    final removed = await newPossession();
    await dao().setStatus(archived, PossessionStatus.archived);
    await dao().softDelete(removed);

    expect(await ids(dao().watchArchived()), [archived]);
    expect(await ids(dao().watchRemoved()), [removed]);
    // Active is on Home and in neither archive list.
    expect(await ids(dao().watchAll()), contains(active));
    expect(await ids(dao().watchArchived()), isNot(contains(active)));
    expect(await ids(dao().watchRemoved()), isNot(contains(active)));
  });

  test('a removed archived possession appears only in Rimossi', () async {
    final id = await newPossession();
    await dao().setStatus(id, PossessionStatus.archived);
    await dao().softDelete(id);
    expect(await ids(dao().watchArchived()), isNot(contains(id)));
    expect(await ids(dao().watchRemoved()), contains(id));
  });

  test(
    'restoreArchived sets active and preserves a still-valid place',
    () async {
      final placeId = await db.placesDao.create(name: 'Garage');
      final id = await newPossession();
      await dao().setPlace(id, placeId);
      await dao().setStatus(id, PossessionStatus.archived);

      await dao().restoreArchived(id);
      final p = (await dao().watchById(id).first)!;
      expect(p.status, PossessionStatus.active);
      expect(p.deletedAt, isNull);
      expect(p.placeId, placeId); // valid place preserved
      expect(await ids(dao().watchAll()), contains(id)); // back on Home
      expect(await ids(dao().watchArchived()), isNot(contains(id)));
    },
  );

  test('restoreArchived clears a place that was deleted meanwhile', () async {
    final placeId = await db.placesDao.create(name: 'Garage');
    final id = await newPossession();
    await dao().setPlace(id, placeId);
    await dao().setStatus(id, PossessionStatus.archived);
    await db.placesDao.softDelete(placeId); // place gone while archived

    await dao().restoreArchived(id);
    final p = (await dao().watchById(id).first)!;
    expect(p.status, PossessionStatus.active);
    expect(p.placeId, isNull); // no dangling place
  });

  test('restoreRemoved undeletes an active thing back to Home', () async {
    final id = await newPossession();
    await dao().softDelete(id);
    await dao().restoreRemoved(id);
    final p = (await dao().watchById(id).first)!;
    expect(p.deletedAt, isNull);
    expect(p.status, PossessionStatus.active);
    expect(await ids(dao().watchAll()), contains(id));
    expect(await ids(dao().watchRemoved()), isNot(contains(id)));
  });

  test('restoreRemoved preserves lifecycle status: an archived removed thing '
      'returns to Conservati, not Home', () async {
    final id = await newPossession();
    await dao().setStatus(id, PossessionStatus.archived);
    await dao().softDelete(id);

    await dao().restoreRemoved(id);
    final p = (await dao().watchById(id).first)!;
    expect(p.deletedAt, isNull);
    expect(p.status, PossessionStatus.archived); // status ≠ deletion
    expect(await ids(dao().watchArchived()), contains(id));
    expect(await ids(dao().watchAll()), isNot(contains(id)));
  });

  test('restore preserves photos, events and loan history', () async {
    final id = await newPossession();
    await dao().addPhoto(
      id,
      relativePath: 'photos/a.jpg',
      mimeType: 'image/jpeg',
      byteSize: 1,
    );
    await db.eventsDao.saveAcquisition(possessionId: id, note: 'bought it');
    final loan = (await db.eventsDao.lend(
      possessionId: id,
      personName: 'Marco',
      lentAt: DateTime(2026, 7, 1),
    ))!;
    await db.eventsDao.returnLoan(
      possessionId: id,
      loanEventId: loan.id,
      returnedAt: DateTime(2026, 7, 5),
    );

    await dao().setStatus(id, PossessionStatus.archived);
    await dao().restoreArchived(id);

    expect((await dao().watchPhotos(id).first).length, 1);
    final timeline = await db.eventsDao.watchTimeline(id).first;
    expect(timeline.any((e) => e.kind == EventKind.acquired), isTrue);
    expect(timeline.any((e) => e.kind == EventKind.lent), isTrue);
    expect(timeline.any((e) => e.kind == EventKind.returned), isTrue);
  });

  test(
    'no id is ever a member of more than one of active/archived/removed',
    () async {
      final a = await newPossession();
      final b = await newPossession();
      final c = await newPossession();
      await dao().setStatus(b, PossessionStatus.archived);
      await dao().softDelete(c);

      final active = (await ids(dao().watchAll())).toSet();
      final archived = (await ids(dao().watchArchived())).toSet();
      final removed = (await ids(dao().watchRemoved())).toSet();
      expect(active.intersection(archived), isEmpty);
      expect(active.intersection(removed), isEmpty);
      expect(archived.intersection(removed), isEmpty);
      expect({a, b, c}, active.union(archived).union(removed));
    },
  );

  test('lists react to archive/remove/restore', () async {
    final id = await newPossession();
    expect(await ids(dao().watchArchived()), isEmpty);
    await dao().setStatus(id, PossessionStatus.archived);
    expect(await ids(dao().watchArchived()), [id]);
    await dao().restoreArchived(id);
    expect(await ids(dao().watchArchived()), isEmpty);
  });
}
