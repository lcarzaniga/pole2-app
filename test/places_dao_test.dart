import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('create returns an id and the place is retrievable', () async {
    final id = await db.placesDao.create(name: '  Garage  ', notes: ' top shelf ');
    final place = await db.placesDao.findById(id);
    expect(place, isNotNull);
    expect(place!.name, 'Garage'); // trimmed
    expect(place.notes, 'top shelf'); // trimmed
    expect(place.deletedAt, isNull);
  });

  test('watchAll lists non-deleted places alphabetically (case-insensitive)',
      () async {
    await db.placesDao.create(name: 'ufficio');
    await db.placesDao.create(name: 'Cantina');
    await db.placesDao.create(name: 'garage');

    final names = (await db.placesDao.watchAll().first).map((p) => p.name);
    expect(names, ['Cantina', 'garage', 'ufficio']);
  });

  test('edit renames a place', () async {
    final id = await db.placesDao.create(name: 'Studio');
    await db.placesDao.edit(id, name: 'Ufficio');
    expect((await db.placesDao.findById(id))!.name, 'Ufficio');
  });

  test('softDelete hides the place from watchAll but keeps the row', () async {
    final id = await db.placesDao.create(name: 'Soffitta');
    await db.placesDao.softDelete(id);
    expect(await db.placesDao.watchAll().first, isEmpty);
    final row = await db.placesDao.findById(id);
    expect(row, isNotNull);
    expect(row!.deletedAt, isNotNull);
  });

  test('setPlace assigns and clears a possession place ("no place" = null)',
      () async {
    final p = await db.possessionsDao.createPossession(title: 'Bici');
    expect(p.placeId, isNull); // default: no place

    final placeId = await db.placesDao.create(name: 'Cantina');
    await db.possessionsDao.setPlace(p.id, placeId);
    expect((await db.possessionsDao.watchById(p.id).first)!.placeId, placeId);

    // Clearing returns to "no place".
    await db.possessionsDao.setPlace(p.id, null);
    expect((await db.possessionsDao.watchById(p.id).first)!.placeId, isNull);
  });

  test('soft-deleting an assigned place leaves the possession placeId intact',
      () async {
    final p = await db.possessionsDao.createPossession(title: 'Trapano');
    final placeId = await db.placesDao.create(name: 'Garage');
    await db.possessionsDao.setPlace(p.id, placeId);

    await db.placesDao.softDelete(placeId);

    // The possession keeps its placeId; the UI resolves the deleted place to
    // "no place" (a null lookup), so nothing is lost.
    final reloaded = await db.possessionsDao.watchById(p.id).first;
    expect(reloaded!.placeId, placeId);
    expect(await db.placesDao.watchById(placeId).first, isNull);
  });

  test('countByPlace counts non-deleted assigned possessions', () async {
    final placeId = await db.placesDao.create(name: 'Garage');
    expect(await db.possessionsDao.countByPlace(placeId), 0);

    final a = await db.possessionsDao.createPossession(title: 'A');
    final b = await db.possessionsDao.createPossession(title: 'B');
    await db.possessionsDao.setPlace(a.id, placeId);
    await db.possessionsDao.setPlace(b.id, placeId);
    expect(await db.possessionsDao.countByPlace(placeId), 2);

    await db.possessionsDao.softDelete(a.id); // tombstoned → not counted
    expect(await db.possessionsDao.countByPlace(placeId), 1);
  });

  test('delete flow (softDelete + clearPlace) resolves possessions to no place',
      () async {
    final placeId = await db.placesDao.create(name: 'Cantina');
    final a = await db.possessionsDao.createPossession(title: 'A');
    final b = await db.possessionsDao.createPossession(title: 'B');
    await db.possessionsDao.setPlace(a.id, placeId);
    await db.possessionsDao.setPlace(b.id, placeId);

    // What the management UI does on delete.
    await db.placesDao.softDelete(placeId);
    await db.possessionsDao.clearPlace(placeId);

    expect((await db.possessionsDao.watchById(a.id).first)!.placeId, isNull);
    expect((await db.possessionsDao.watchById(b.id).first)!.placeId, isNull);
    expect(await db.placesDao.watchById(placeId).first, isNull);
  });

  test('watchByPlace: filters, orders newest-first, reacts to changes', () async {
    final dao = db.possessionsDao;
    final garage = await db.placesDao.create(name: 'Garage');
    final cantina = await db.placesDao.create(name: 'Cantina');

    expect(await dao.watchByPlace(garage).first, isEmpty);

    final a = await dao.createPossession(title: 'A');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final b = await dao.createPossession(title: 'B');
    final c = await dao.createPossession(title: 'C');

    await dao.setPlace(a.id, garage);
    await dao.setPlace(b.id, cantina); // another place → excluded
    // c keeps placeId == null → excluded

    expect((await dao.watchByPlace(garage).first).map((p) => p.id), [a.id]);

    // newest-first: a later item in the same place sorts ahead of an older one
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final d = await dao.createPossession(title: 'D');
    await dao.setPlace(d.id, garage);
    expect(
      (await dao.watchByPlace(garage).first).map((p) => p.id),
      [d.id, a.id],
    );

    // reacts to an assignment change (move a away)
    await dao.setPlace(a.id, cantina);
    expect((await dao.watchByPlace(garage).first).map((p) => p.id), [d.id]);

    // reacts to soft-delete
    await dao.softDelete(d.id);
    expect(await dao.watchByPlace(garage).first, isEmpty);

    // reacts to restore (placeId survives restore)
    await dao.restore(d.id);
    expect((await dao.watchByPlace(garage).first).map((p) => p.id), [d.id]);

    // isolated from unrelated places: a change in cantina doesn't touch garage
    await dao.setPlace(c.id, cantina);
    expect((await dao.watchByPlace(garage).first).map((p) => p.id), [d.id]);
  });

  test('watchByPlace emits updates on a single subscription', () async {
    final dao = db.possessionsDao;
    final garage = await db.placesDao.create(name: 'Garage');
    final a = await dao.createPossession(title: 'A');

    final counts = <int>[];
    final sub = dao.watchByPlace(garage).listen((l) => counts.add(l.length));
    await Future<void>.delayed(const Duration(milliseconds: 10)); // 0 (empty)
    await dao.setPlace(a.id, garage);
    await Future<void>.delayed(const Duration(milliseconds: 10)); // 1 (assigned)
    await dao.softDelete(a.id);
    await Future<void>.delayed(const Duration(milliseconds: 10)); // 0 (removed)
    await sub.cancel();

    expect(counts, containsAllInOrder([0, 1, 0]));
  });

  test(
    'deleteAndUnassign preserves possessions and leaves no active assignment',
    () async {
      final placeId = await db.placesDao.create(name: 'Cantina');
      final a = await db.possessionsDao.createPossession(title: 'A');
      final b = await db.possessionsDao.createPossession(title: 'B');
      await db.possessionsDao.setPlace(a.id, placeId);
      await db.possessionsDao.setPlace(b.id, placeId);

      await db.placesDao.deleteAndUnassign(placeId);

      // The place is gone (soft-deleted → resolves to null in the UI)...
      expect(await db.placesDao.watchById(placeId).first, isNull);
      // ...but both possessions are intact, active, and simply "no place".
      final ra = await db.possessionsDao.watchById(a.id).first;
      final rb = await db.possessionsDao.watchById(b.id).first;
      expect(ra, isNotNull);
      expect(rb, isNotNull);
      expect(ra!.placeId, isNull);
      expect(rb!.placeId, isNull);
      expect(ra.deletedAt, isNull); // not deleted
      // No possession is left pointing at the tombstoned place.
      expect(await db.possessionsDao.watchByPlace(placeId).first, isEmpty);
      // Still on the Home list.
      expect((await db.possessionsDao.watchAll().first).length, 2);
    },
  );

  test('removing a place assignment keeps the possession on Home', () async {
    final placeId = await db.placesDao.create(name: 'Garage');
    final p = await db.possessionsDao.createPossession(title: 'Trapano');
    await db.possessionsDao.setPlace(p.id, placeId);
    expect((await db.possessionsDao.watchByPlace(placeId).first).length, 1);

    // What the "Rimuovi dal luogo" action does.
    await db.possessionsDao.setPlace(p.id, null);

    expect(await db.possessionsDao.watchByPlace(placeId).first, isEmpty);
    final reloaded = await db.possessionsDao.watchById(p.id).first;
    expect(reloaded, isNotNull); // not deleted
    expect(reloaded!.placeId, isNull);
    expect((await db.possessionsDao.watchAll().first).length, 1);
  });
}
