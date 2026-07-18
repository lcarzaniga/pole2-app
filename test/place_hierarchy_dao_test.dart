import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/database/daos/places_dao.dart';
import 'package:project_kobe/core/database/tables/enums.dart';
import 'package:project_kobe/features/places/application/place_tree.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  PlacesDao places() => db.placesDao;

  Future<Place?> place(String id) => places().findById(id);

  group('creation', () {
    test('root has null parent; child records its parent', () async {
      final casa = await places().create(name: 'Casa');
      final camera = await places().create(name: 'Camera', parentId: casa);
      expect((await place(casa))!.parentId, isNull);
      expect((await place(camera))!.parentId, casa);
    });

    test(
      'creating under a missing/deleted parent falls back to root',
      () async {
        final ghost = await places().create(name: 'Ghost');
        await places().softDelete(ghost);
        final child = await places().create(name: 'Orfano', parentId: ghost);
        expect((await place(child))!.parentId, isNull);
      },
    );
  });

  group('move validation', () {
    test('valid move records the new parent; move to root clears it', () async {
      final casa = await places().create(name: 'Casa');
      final camera = await places().create(name: 'Camera', parentId: casa);
      final box = await places().create(name: 'Scatola', parentId: casa);

      expect(await places().move(box, camera), PlaceMoveResult.moved);
      expect((await place(box))!.parentId, camera);
      expect(await places().move(box, null), PlaceMoveResult.moved);
      expect((await place(box))!.parentId, isNull);
    });

    test('a place cannot be its own parent', () async {
      final a = await places().create(name: 'A');
      expect(await places().move(a, a), PlaceMoveResult.invalid);
    });

    test('a place cannot move beneath its own descendant (cycle)', () async {
      final casa = await places().create(name: 'Casa');
      final camera = await places().create(name: 'Camera', parentId: casa);
      final armadio = await places().create(name: 'Armadio', parentId: camera);
      // Moving Casa under Armadio (its grandchild) would form a cycle.
      expect(await places().move(casa, armadio), PlaceMoveResult.cycle);
      expect((await place(casa))!.parentId, isNull); // unchanged
    });

    test(
      'cannot move under a deleted parent, nor move a deleted place',
      () async {
        final a = await places().create(name: 'A');
        final b = await places().create(name: 'B');
        await places().softDelete(b);
        expect(await places().move(a, b), PlaceMoveResult.notFound);
        await places().softDelete(a);
        final c = await places().create(name: 'C');
        expect(await places().move(a, c), PlaceMoveResult.notFound);
      },
    );

    test(
      'moving a subtree preserves descendants and possession assignments',
      () async {
        final casa = await places().create(name: 'Casa');
        final camera = await places().create(name: 'Camera', parentId: casa);
        final armadio = await places().create(
          name: 'Armadio',
          parentId: camera,
        );
        final ripiano = await places().create(
          name: 'Ripiano',
          parentId: armadio,
        );
        final p = await db.possessionsDao.createPossession(title: 'Doc');
        await db.possessionsDao.setPlace(p.id, ripiano);

        // Move Armadio (with Ripiano under it) to the Casa root-child level.
        expect(await places().move(armadio, casa), PlaceMoveResult.moved);
        expect((await place(ripiano))!.parentId, armadio); // descendant intact
        expect(
          (await db.possessionsDao.watchById(p.id).first)!.placeId,
          ripiano,
        );
      },
    );
  });

  group('delete', () {
    test(
      'a place with active children cannot be deleted (no cascade)',
      () async {
        final casa = await places().create(name: 'Casa');
        final camera = await places().create(name: 'Camera', parentId: casa);
        expect(await places().deleteLeaf(casa), isFalse);
        expect((await place(casa))!.deletedAt, isNull); // untouched
        expect((await place(camera))!.deletedAt, isNull); // not cascaded
      },
    );

    test(
      'a leaf delete unassigns its direct possessions without deleting them',
      () async {
        final box = await places().create(name: 'Scatola');
        final p = await db.possessionsDao.createPossession(title: 'Doc');
        await db.possessionsDao.setPlace(p.id, box);
        expect(await places().deleteLeaf(box), isTrue);
        expect((await place(box))!.deletedAt, isNotNull);
        final reloaded = await db.possessionsDao.watchById(p.id).first;
        expect(reloaded, isNotNull); // possession survives
        expect(reloaded!.placeId, isNull); // → no place
      },
    );

    test('only active children block deletion', () async {
      final casa = await places().create(name: 'Casa');
      final camera = await places().create(name: 'Camera', parentId: casa);
      await places().softDelete(camera); // soft-deleted child doesn't block
      expect(await places().deleteLeaf(casa), isTrue);
    });
  });

  group('counts', () {
    test(
      'direct counts exclude lent/archived/removed; subtree totals add up',
      () async {
        final casa = await places().create(name: 'Casa');
        final armadio = await places().create(name: 'Armadio', parentId: casa);

        final direct = await db.possessionsDao.createPossession(title: 'A');
        await db.possessionsDao.setPlace(direct.id, casa);
        for (var i = 0; i < 3; i++) {
          final p = await db.possessionsDao.createPossession(title: 'X$i');
          await db.possessionsDao.setPlace(p.id, armadio);
        }
        // Archived one in armadio → excluded.
        final arch = await db.possessionsDao.createPossession(title: 'Old');
        await db.possessionsDao.setPlace(arch.id, armadio);
        await db.possessionsDao.setStatus(arch.id, PossessionStatus.archived);
        // Lent one in casa → placeId cleared → excluded.
        final lent = await db.possessionsDao.createPossession(title: 'Lent');
        await db.possessionsDao.setPlace(lent.id, casa);
        await db.eventsDao.lend(
          possessionId: lent.id,
          personName: 'Marco',
          lentAt: DateTime(2026, 7, 1),
        );

        final counts = await db.possessionsDao.watchDirectPlaceCounts().first;
        expect(counts[casa], 1); // only the direct active one
        expect(counts[armadio], 3); // archived excluded

        final tree = PlaceTree(await places().watchAll().first, counts);
        expect(tree.subtreeCount(casa), 4); // 1 + 3
        expect(tree.subtreeCount(armadio), 3);
      },
    );
  });

  group('loan & archive integration', () {
    test(
      'return restores the exact nested place after its subtree moved',
      () async {
        final casa = await places().create(name: 'Casa');
        final camera = await places().create(name: 'Camera', parentId: casa);
        final box = await places().create(name: 'Scatola', parentId: camera);
        final p = await db.possessionsDao.createPossession(title: 'Doc');
        await db.possessionsDao.setPlace(p.id, box);

        final loan = (await db.eventsDao.lend(
          possessionId: p.id,
          personName: 'Marco',
          lentAt: DateTime(2026, 7, 1),
        ))!;
        expect(loan.originPlaceId, box);
        // Move the whole Camera subtree to root while lent.
        await places().move(camera, null);
        await db.eventsDao.returnLoan(
          possessionId: p.id,
          loanEventId: loan.id,
          returnedAt: DateTime(2026, 7, 5),
          returnPlaceId: loan.originPlaceId, // the exact origin, as the sheet does
        );
        // Returns to the exact box, now at its new path.
        expect((await db.possessionsDao.watchById(p.id).first)!.placeId, box);
      },
    );

    test(
      'return does not restore a place whose ancestor was deleted',
      () async {
        final casa = await places().create(name: 'Casa');
        final box = await places().create(name: 'Scatola', parentId: casa);
        final p = await db.possessionsDao.createPossession(title: 'Doc');
        await db.possessionsDao.setPlace(p.id, box);
        final loan = (await db.eventsDao.lend(
          possessionId: p.id,
          personName: 'Marco',
          lentAt: DateTime(2026, 7, 1),
        ))!;
        await places().softDelete(casa); // ancestor gone → box unreachable
        await db.eventsDao.returnLoan(
          possessionId: p.id,
          loanEventId: loan.id,
          returnedAt: DateTime(2026, 7, 5),
          returnPlaceId: box,
        );
        expect(
          (await db.possessionsDao.watchById(p.id).first)!.placeId,
          isNull,
        );
      },
    );

    test(
      'archived restore into an unreachable (deleted-ancestor) branch clears '
      'the place',
      () async {
        final casa = await places().create(name: 'Casa');
        final box = await places().create(name: 'Scatola', parentId: casa);
        final p = await db.possessionsDao.createPossession(title: 'Doc');
        await db.possessionsDao.setPlace(p.id, box);
        await db.possessionsDao.setStatus(p.id, PossessionStatus.archived);
        await places().softDelete(casa); // ancestor gone
        await db.possessionsDao.restoreArchived(p.id);
        final reloaded = await db.possessionsDao.watchById(p.id).first;
        expect(reloaded!.status, PossessionStatus.active);
        expect(
          reloaded.placeId,
          isNull,
        ); // not restored into unreachable branch
      },
    );
  });
}
