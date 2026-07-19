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

  test('custody: all returns every active input', () async {
    final all = [await make('A'), await make('B')];
    expect(applyPossessionQuery(all, const PossessionQuery()).length, 2);
  });

  test('custody: place filter includes the whole subtree (M5.4)', () async {
    final casa = await db.placesDao.create(name: 'Casa');
    final armadio = await db.placesDao.create(name: 'Armadio', parentId: casa);
    final inCasa = await make('Quadro', placeId: casa);
    final inArmadio = await make('Maglione', placeId: armadio);
    final all = [inCasa, inArmadio];

    expect(
      applyPossessionQuery(
        all,
        PossessionQuery(custody: CustodyFilter.place(casa)),
        placeSubtreeIds: {casa, armadio},
      ).map((p) => p.title).toSet(),
      {'Quadro', 'Maglione'},
    );
    expect(
      applyPossessionQuery(
        all,
        PossessionQuery(custody: CustodyFilter.place(armadio)),
        placeSubtreeIds: {armadio},
      ).map((p) => p.title),
      ['Maglione'],
    );
  });

  test(
    'custody: noLocation includes a genuinely unassigned possession',
    () async {
      final loose = await make('Chiavi'); // placeId null, not lent
      final garage = await db.placesDao.create(name: 'Garage');
      final placed = await make('Trapano', placeId: garage);
      final out = applyPossessionQuery([
        loose,
        placed,
      ], const PossessionQuery(custody: CustodyFilter.noLocation()));
      expect(out.map((p) => p.title), ['Chiavi']);
    },
  );

  test(
    'custody: noLocation EXCLUDES a lent possession (placeId null)',
    () async {
      final lent = await make('Trapano'); // placeId null (lending cleared it)
      final loose = await make('Chiavi');
      final loans = {lent.id: 'personA'};
      final out = applyPossessionQuery(
        [lent, loose],
        const PossessionQuery(custody: CustodyFilter.noLocation()),
        loanPersonByPossession: loans,
      );
      // The lent thing belongs under its borrower, never under "Senza luogo".
      expect(out.map((p) => p.title), ['Chiavi']);
    },
  );

  test(
    'custody: person filter includes only active loans to that person',
    () async {
      final toA = await make('Trapano');
      final toB = await make('Scala');
      final loose = await make('Chiavi');
      final loans = {toA.id: 'A', toB.id: 'B'};

      final out = applyPossessionQuery(
        [toA, toB, loose],
        const PossessionQuery(custody: CustodyFilter.person('A')),
        loanPersonByPossession: loans,
      );
      expect(out.map((p) => p.title), [
        'Trapano',
      ]); // only A's, not B's or loose
    },
  );

  test('custody: search composes with the person filter', () async {
    final drill = await make('Trapano rosso');
    final ladder = await make('Trapano blu'); // also matches "trapano"
    final other = await make('Scala');
    final loans = {drill.id: 'A', ladder.id: 'A', other.id: 'A'};
    final out = applyPossessionQuery(
      [drill, ladder, other],
      const PossessionQuery(
        search: 'rosso',
        custody: CustodyFilter.person('A'),
      ),
      loanPersonByPossession: loans,
    );
    expect(out.map((p) => p.title), ['Trapano rosso']);
  });

  test(
    'custody: sorting composes with a place filter, no duplicates',
    () async {
      final casa = await db.placesDao.create(name: 'Casa');
      final b = await make('bravo', placeId: casa);
      final a = await make('Alpha', placeId: casa);
      final out = applyPossessionQuery(
        [b, a],
        PossessionQuery(
          custody: CustodyFilter.place(casa),
          sort: PossessionSort.name,
        ),
        placeSubtreeIds: {casa},
      );
      expect(out.map((p) => p.title), ['Alpha', 'bravo']);
      expect(out.length, out.toSet().length); // no duplicates
    },
  );

  group('resolveCustody fallback', () {
    test('a deleted Place falls back to Tutti', () {
      final r = resolveCustody(
        const CustodyFilter.place('gone'),
        validPlaceIds: {'casa'},
        loanPersonIds: {},
      );
      expect(r.isAll, isTrue);
    });

    test('a person with no active loan falls back to Tutti', () {
      final r = resolveCustody(
        const CustodyFilter.person('carlo'),
        validPlaceIds: {},
        loanPersonIds: {'anna'},
      );
      expect(r.isAll, isTrue);
    });

    test('valid selections are preserved', () {
      expect(
        resolveCustody(
          const CustodyFilter.place('casa'),
          validPlaceIds: {'casa'},
          loanPersonIds: {},
        ),
        const CustodyFilter.place('casa'),
      );
      expect(
        resolveCustody(
          const CustodyFilter.person('anna'),
          validPlaceIds: {},
          loanPersonIds: {'anna'},
        ),
        const CustodyFilter.person('anna'),
      );
      expect(
        resolveCustody(
          const CustodyFilter.noLocation(),
          validPlaceIds: {},
          loanPersonIds: {},
        ),
        const CustodyFilter.noLocation(),
      );
    });
  });
}
