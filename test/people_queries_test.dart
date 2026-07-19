import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/features/people/application/people_queries.dart';
import 'package:project_kobe/features/people/domain/custody.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> newPossession(String title) async {
    final p = await db.possessionsDao.createPossession(title: title);
    return p.id;
  }

  test(
    'active loans group by person; suppliers never appear as people',
    () async {
      final drill = await newPossession('Trapano');
      final ladder = await newPossession('Scala');
      await db.eventsDao.lend(
        possessionId: drill,
        personName: 'Carlo',
        lentAt: DateTime.now(),
      );
      await db.eventsDao.lend(
        possessionId: ladder,
        personName: 'Carlo',
        lentAt: DateTime.now(),
      );
      // A retailer/supplier party (created via acquisition) must never surface.
      final tv = await newPossession('TV');
      await db.eventsDao.saveAcquisition(
        possessionId: tv,
        supplierName: 'MediaWorld',
      );

      final loans = await watchActiveLoans(db).first;
      expect(loans, hasLength(2));
      expect(loans.every((l) => l.party.name == 'Carlo'), isTrue);

      final people = await db.eventsDao.watchPeople().first;
      expect(people.map((p) => p.name), ['Carlo']); // no MediaWorld
    },
  );

  test('current given tracks the latest recipient across re-gives', () async {
    final book = await newPossession('Libro');
    await db.eventsDao.give(
      possessionId: book,
      personName: 'Anna',
      transferredAt: DateTime(2026, 1, 1),
    );
    await db.eventsDao.reacquire(
      possessionId: book,
      reacquiredAt: DateTime(2026, 2, 1),
    );
    await db.eventsDao.give(
      possessionId: book,
      personName: 'Bruno',
      transferredAt: DateTime(2026, 3, 1),
    );

    final given = await watchCurrentGiven(db).first;
    expect(given, hasLength(1));
    expect(given.single.party.name, 'Bruno'); // latest recipient only

    // History: Anna has the past transfer + the reacquire; Bruno is current.
    final history = buildCustodyHistory(await watchCustodyEvents(db).first);
    expect(history.any((h) => h.personName == 'Bruno'), isFalse);
    final annaKinds = history
        .where((h) => h.personName == 'Anna')
        .map((h) => h.kind)
        .toSet();
    expect(annaKinds, {HistoryKind.pastTransfer, HistoryKind.reacquired});
  });

  test(
    'returning a loan removes it from current and records history',
    () async {
      final drill = await newPossession('Trapano');
      final loan = await db.eventsDao.lend(
        possessionId: drill,
        personName: 'Carlo',
        lentAt: DateTime.now(),
      );
      expect((await watchActiveLoans(db).first), hasLength(1));

      await db.eventsDao.returnLoan(
        possessionId: drill,
        loanEventId: loan!.id,
        returnedAt: DateTime.now(),
      );
      expect((await watchActiveLoans(db).first), isEmpty);

      final history = buildCustodyHistory(await watchCustodyEvents(db).first);
      expect(history.single.kind, HistoryKind.returnedLoan);
      expect(history.single.personName, 'Carlo');
    },
  );

  test(
    'a soft-deleted person disappears from people but resolves in history',
    () async {
      final drill = await newPossession('Trapano');
      final loan = await db.eventsDao.lend(
        possessionId: drill,
        personName: 'Carlo',
        lentAt: DateTime.now(),
      );
      await db.eventsDao.returnLoan(
        possessionId: drill,
        loanEventId: loan!.id,
        returnedAt: DateTime.now(),
      );
      final carlo = (await db.eventsDao.watchPeople().first).single;

      // Only completed history → deletion allowed.
      expect(await personHasCurrentCustody(db, carlo.id), isFalse);
      await softDeletePerson(db, carlo.id);

      expect(
        await db.eventsDao.watchPeople().first,
        isEmpty,
      ); // gone from People
      // Still name-resolvable in history rows.
      final history = buildCustodyHistory(await watchCustodyEvents(db).first);
      expect(history.single.personName, 'Carlo');
    },
  );

  test(
    'rename preserves the relationship (loan resolves to the new name)',
    () async {
      final drill = await newPossession('Trapano');
      await db.eventsDao.lend(
        possessionId: drill,
        personName: 'Carlo',
        lentAt: DateTime.now(),
      );
      final carlo = (await db.eventsDao.watchPeople().first).single;

      expect(await renamePerson(db, carlo.id, 'Carletto'), isTrue);
      final loans = await watchActiveLoans(db).first;
      expect(loans.single.party.name, 'Carletto');
    },
  );

  test('rename is rejected when it would duplicate another person', () async {
    final a = await createPerson(db, 'Anna');
    await createPerson(db, 'Bruno');
    // Renaming Anna → "bruno" (case-insensitive) must be refused.
    expect(await renamePerson(db, a, 'bruno'), isFalse);
    expect(await renamePerson(db, a, '   '), isFalse); // blank refused
  });

  test('deletion is blocked by an active loan', () async {
    final drill = await newPossession('Trapano');
    await db.eventsDao.lend(
      possessionId: drill,
      personName: 'Carlo',
      lentAt: DateTime.now(),
    );
    final carlo = (await db.eventsDao.watchPeople().first).single;
    expect(await personHasCurrentCustody(db, carlo.id), isTrue);
  });

  test('deletion is blocked by a currently given possession', () async {
    final book = await newPossession('Libro');
    await db.eventsDao.give(
      possessionId: book,
      personName: 'Anna',
      transferredAt: DateTime.now(),
    );
    final anna = (await db.eventsDao.watchPeople().first).single;
    expect(await personHasCurrentCustody(db, anna.id), isTrue);
  });

  test('soft-deleted possession is excluded from current sections', () async {
    final drill = await newPossession('Trapano');
    await db.eventsDao.lend(
      possessionId: drill,
      personName: 'Carlo',
      lentAt: DateTime.now(),
    );
    await db.possessionsDao.softDelete(drill); // removed
    expect(await watchActiveLoans(db).first, isEmpty);
  });
}
