import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/features/possessions/application/possession_query.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  // Builds possessions with controlled titles/places/order for the pure query.
  Future<Possession> make(String title, {String? placeId}) async {
    final p = await db.possessionsDao.createPossession(title: title);
    if (placeId != null) await db.possessionsDao.setPlace(p.id, placeId);
    return (await db.possessionsDao.watchById(p.id).first)!;
  }

  test('default query keeps everything, newest-first', () async {
    final a = await make('Alpha');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final b = await make('Bravo');
    final out = applyPossessionQuery([a, b], const PossessionQuery());
    expect(out.map((p) => p.title), ['Bravo', 'Alpha']); // newest first
  });

  test('search matches title or category, case-insensitively', () async {
    final bike = await make('Mountain Bike');
    final lamp = await make('Lampada');
    final out = applyPossessionQuery([
      bike,
      lamp,
    ], const PossessionQuery(search: 'BIKE'));
    expect(out.map((p) => p.title), ['Mountain Bike']);
  });

  test('sort by name orders alphabetically, case-insensitively', () async {
    final b = await make('bravo');
    final a = await make('Alpha');
    final out = applyPossessionQuery([
      b,
      a,
    ], const PossessionQuery(sort: PossessionSort.name));
    expect(out.map((p) => p.title), ['Alpha', 'bravo']);
  });

  test('filter by a specific place, no place, or all', () async {
    final garage = await db.placesDao.create(name: 'Garage');
    final inGarage = await make('Trapano', placeId: garage);
    final loose = await make('Chiavi'); // no place
    final all = [inGarage, loose];

    expect(
      applyPossessionQuery(
        all,
        PossessionQuery(place: PlaceFilter.place(garage)),
      ).map((p) => p.title),
      ['Trapano'],
    );
    expect(
      applyPossessionQuery(
        all,
        const PossessionQuery(place: PlaceFilter.none()),
      ).map((p) => p.title),
      ['Chiavi'],
    );
    expect(applyPossessionQuery(all, const PossessionQuery()).length, 2);
  });

  test('a specific-place filter includes the whole subtree (M5.4)', () async {
    final casa = await db.placesDao.create(name: 'Casa');
    final armadio = await db.placesDao.create(name: 'Armadio', parentId: casa);
    final inCasa = await make('Quadro', placeId: casa);
    final inArmadio = await make('Maglione', placeId: armadio);
    final all = [inCasa, inArmadio];

    // Filtering on Casa includes its descendant Armadio's objects too.
    expect(
      applyPossessionQuery(
        all,
        PossessionQuery(place: PlaceFilter.place(casa)),
        placeSubtreeIds: {casa, armadio},
      ).map((p) => p.title).toSet(),
      {'Quadro', 'Maglione'},
    );
    // Filtering on Armadio includes only its subtree.
    expect(
      applyPossessionQuery(
        all,
        PossessionQuery(place: PlaceFilter.place(armadio)),
        placeSubtreeIds: {armadio},
      ).map((p) => p.title),
      ['Maglione'],
    );
  });
}
