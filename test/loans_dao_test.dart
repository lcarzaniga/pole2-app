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

  Future<String?> placeOf(String id) async =>
      (await db.possessionsDao.watchById(id).first)!.placeId;

  test('findOrCreatePerson creates a person, never a retailer, and reuses by '
      'normalized name', () async {
    final id1 = await db.eventsDao.findOrCreatePerson('  Marco  ');
    final id2 = await db.eventsDao.findOrCreatePerson('marco');
    expect(id1, id2); // reused, case-insensitive + trimmed
    final people = await db.eventsDao.watchPeople().first;
    expect(people.length, 1);
    expect(people.single.kind, PartyKind.person);
  });

  test(
    'the person list excludes non-person parties (e.g. suppliers)',
    () async {
      // A supplier is created as a retailer by the acquisition flow.
      await db.eventsDao.saveAcquisition(
        possessionId: await newPossession(),
        supplierName: 'Negozio',
      );
      await db.eventsDao.findOrCreatePerson('Marco');
      final people = await db.eventsDao.watchPeople().first;
      expect(people.map((p) => p.name), ['Marco']);
    },
  );

  test(
    'lending creates an active loan, clears the place and stores its origin',
    () async {
      final placeId = await db.placesDao.create(name: 'Garage');
      final id = await newPossession(placeId: placeId);
      final loan = await db.eventsDao.lend(
        possessionId: id,
        personName: 'Marco',
        lentAt: DateTime(2026, 7, 1),
      );
      expect(loan, isNotNull);
      expect(loan!.kind, EventKind.lent);
      expect(loan.status, EventStatus.pending);
      expect(loan.originPlaceId, placeId);
      expect(await placeOf(id), isNull); // physical place cleared
      // Still active and visible on Home.
      final onHome = await db.possessionsDao.watchAll().first;
      expect(onHome.any((p) => p.id == id), isTrue);
    },
  );

  test('a second simultaneous loan is rejected', () async {
    final id = await newPossession();
    final first = await db.eventsDao.lend(
      possessionId: id,
      personName: 'Marco',
      lentAt: DateTime(2026, 7, 1),
    );
    final second = await db.eventsDao.lend(
      possessionId: id,
      personName: 'Lucia',
      lentAt: DateTime(2026, 7, 2),
    );
    expect(first, isNotNull);
    expect(second, isNull); // no duplicate active loan
    final active = await db.eventsDao.watchActiveLoan(id).first;
    expect(active!.id, first!.id);
  });

  test('the active-loan query returns the borrower and dates', () async {
    final id = await newPossession();
    await db.eventsDao.lend(
      possessionId: id,
      personName: 'Marco',
      lentAt: DateTime(2026, 7, 1),
      expectedReturn: DateTime(2026, 7, 20),
    );
    final loan = (await db.eventsDao.watchActiveLoan(id).first)!;
    final borrower = await db.eventsDao.watchParty(loan.partyId!).first;
    expect(borrower!.name, 'Marco');
    expect(loan.at, DateTime(2026, 7, 1));
    expect(loan.endsAt, DateTime(2026, 7, 20));
  });

  test(
    'return closes the loan, records history, and restores an active place',
    () async {
      final placeId = await db.placesDao.create(name: 'Garage');
      final id = await newPossession(placeId: placeId);
      final loan = (await db.eventsDao.lend(
        possessionId: id,
        personName: 'Marco',
        lentAt: DateTime(2026, 7, 1),
      ))!;

      await db.eventsDao.returnLoan(
        possessionId: id,
        loanEventId: loan.id,
        returnedAt: DateTime(2026, 7, 15),
        returnPlaceId: placeId,
      );

      expect(await db.eventsDao.watchActiveLoan(id).first, isNull); // closed
      expect(await placeOf(id), placeId); // restored
      // History: the lent event (now done) and a returned event both survive.
      final timeline = await db.eventsDao.watchTimeline(id).first;
      expect(timeline.any((e) => e.kind == EventKind.lent), isTrue);
      expect(timeline.any((e) => e.kind == EventKind.returned), isTrue);
      // The person is preserved.
      expect((await db.eventsDao.watchPeople().first).length, 1);
    },
  );

  test('a deleted origin place is not restored on return', () async {
    final placeId = await db.placesDao.create(name: 'Garage');
    final id = await newPossession(placeId: placeId);
    final loan = (await db.eventsDao.lend(
      possessionId: id,
      personName: 'Marco',
      lentAt: DateTime(2026, 7, 1),
    ))!;
    await db.placesDao.softDelete(placeId); // origin place gone
    await db.eventsDao.returnLoan(
      possessionId: id,
      loanEventId: loan.id,
      returnedAt: DateTime(2026, 7, 15),
      returnPlaceId: placeId, // caller asks for it, but it's deleted
    );
    expect(await placeOf(id), isNull); // safely left with no place
  });

  test('return without an origin place leaves placeId null', () async {
    final id = await newPossession(); // no place
    final loan = (await db.eventsDao.lend(
      possessionId: id,
      personName: 'Marco',
      lentAt: DateTime(2026, 7, 1),
    ))!;
    expect(loan.originPlaceId, isNull);
    await db.eventsDao.returnLoan(
      possessionId: id,
      loanEventId: loan.id,
      returnedAt: DateTime(2026, 7, 15),
      returnPlaceId: null,
    );
    expect(await placeOf(id), isNull);
  });

  test('no reminder without an expected return date', () async {
    final id = await newPossession();
    final loan = (await db.eventsDao.lend(
      possessionId: id,
      personName: 'Marco',
      lentAt: DateTime(2026, 7, 1),
      lead: ReminderLead.weekBefore, // ignored: no return date
    ))!;
    expect(loan.remindLead, isNull);
    final upcoming = await db.eventsDao.watchUpcomingReminders().first;
    expect(upcoming.any((r) => r.event.id == loan.id), isFalse);
  });

  test(
    'a return reminder is created and surfaces in upcoming reminders',
    () async {
      final id = await newPossession();
      final loan = (await db.eventsDao.lend(
        possessionId: id,
        personName: 'Marco',
        lentAt: DateTime(2026, 7, 1),
        expectedReturn: DateTime(2026, 7, 20),
        lead: ReminderLead.weekBefore,
      ))!;
      expect(loan.remindLead, ReminderLead.weekBefore);
      final upcoming = await db.eventsDao.watchUpcomingReminders().first;
      final mine = upcoming.firstWhere((r) => r.event.id == loan.id);
      expect(mine.isLoanReturn, isTrue);
      expect(
        mine.at,
        DateTime(2026, 7, 20),
      ); // effective date is the return date
      expect(mine.borrowerName, 'Marco');
    },
  );

  test(
    'editing the return date updates the reminder; clearing it removes it',
    () async {
      final id = await newPossession();
      final loan = (await db.eventsDao.lend(
        possessionId: id,
        personName: 'Marco',
        lentAt: DateTime(2026, 7, 1),
        expectedReturn: DateTime(2026, 7, 20),
        lead: ReminderLead.weekBefore,
      ))!;
      // Move the return date.
      await db.eventsDao.updateLoan(
        loan.id,
        personName: 'Marco',
        expectedReturn: DateTime(2026, 7, 25),
        lead: ReminderLead.dayBefore,
      );
      var reloaded = (await db.eventsDao.watchActiveLoan(id).first)!;
      expect(reloaded.endsAt, DateTime(2026, 7, 25));
      expect(reloaded.remindLead, ReminderLead.dayBefore);
      // Clear the return date → reminder gone.
      await db.eventsDao.updateLoan(
        loan.id,
        personName: 'Marco',
        expectedReturn: null,
        lead: ReminderLead.dayBefore,
      );
      reloaded = (await db.eventsDao.watchActiveLoan(id).first)!;
      expect(reloaded.endsAt, isNull);
      expect(reloaded.remindLead, isNull);
      final upcoming = await db.eventsDao.watchUpcomingReminders().first;
      expect(upcoming.any((r) => r.event.id == loan.id), isFalse);
    },
  );

  test('returning removes the loan from upcoming reminders', () async {
    final id = await newPossession();
    final loan = (await db.eventsDao.lend(
      possessionId: id,
      personName: 'Marco',
      lentAt: DateTime(2026, 7, 1),
      expectedReturn: DateTime(2026, 7, 20),
      lead: ReminderLead.weekBefore,
    ))!;
    await db.eventsDao.returnLoan(
      possessionId: id,
      loanEventId: loan.id,
      returnedAt: DateTime(2026, 7, 18),
    );
    final upcoming = await db.eventsDao.watchUpcomingReminders().first;
    expect(upcoming.any((r) => r.event.id == loan.id), isFalse);
  });

  test(
    'soft-deleted people are excluded from selection but history survives',
    () async {
      final id = await newPossession();
      final loan = (await db.eventsDao.lend(
        possessionId: id,
        personName: 'Marco',
        lentAt: DateTime(2026, 7, 1),
      ))!;
      // Soft-delete the person directly.
      await (db.update(db.parties)..where((t) => t.id.equals(loan.partyId!)))
          .write(PartiesCompanion(deletedAt: Value(DateTime.now())));
      expect((await db.eventsDao.watchPeople().first), isEmpty); // hidden
      // The loan still resolves the (now soft-deleted) borrower for history.
      final borrower = await db.eventsDao.watchParty(loan.partyId!).first;
      expect(borrower!.name, 'Marco');
    },
  );

  test(
    'editing keeps a single active loan and preserves the lent date',
    () async {
      final id = await newPossession();
      final loan = (await db.eventsDao.lend(
        possessionId: id,
        personName: 'Marco',
        lentAt: DateTime(2026, 7, 1),
      ))!;
      await db.eventsDao.updateLoan(
        loan.id,
        personName: 'Lucia',
        expectedReturn: DateTime(2026, 8, 1),
        lead: null,
      );
      final timeline = await db.eventsDao.watchTimeline(id).first;
      final activeLoans = timeline
          .where((e) =>
              e.kind == EventKind.lent && e.status == EventStatus.pending)
          .toList();
      expect(activeLoans.length, 1); // still one active loan
      expect(activeLoans.single.at, DateTime(2026, 7, 1)); // lent date kept
      final borrower =
          await db.eventsDao.watchParty(activeLoans.single.partyId!).first;
      expect(borrower!.name, 'Lucia');
    },
  );
}
