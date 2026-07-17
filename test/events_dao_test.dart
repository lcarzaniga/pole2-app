import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/database/tables/enums.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('acquisition: create then edit updates one event and reuses the supplier',
      () async {
    final p = await db.possessionsDao.createPossession(title: 'Blender');
    final events = db.eventsDao;

    await events.saveAcquisition(
      possessionId: p.id,
      type: AcquisitionType.purchased,
      supplierName: 'MediaWorld',
      amountMinor: 49900,
      currency: 'EUR',
      purchasedOn: DateTime(2024, 3, 3),
    );

    var acq = await events.watchAcquisition(p.id).first;
    expect(acq, isNotNull);
    expect(acq!.acquisitionType, AcquisitionType.purchased);
    expect(acq.amountMinor, 49900);
    expect(acq.currency, 'EUR');
    expect(acq.partyId, isNotNull);
    final firstParty = await events.watchParty(acq.partyId!).first;
    expect(firstParty!.name, 'MediaWorld');

    // Editing keeps a single acquisition and reuses the same supplier record.
    await events.saveAcquisition(
      possessionId: p.id,
      type: AcquisitionType.gift,
      supplierName: 'MediaWorld',
    );
    expect((await events.watchTimeline(p.id).first).length, 1);
    acq = await events.watchAcquisition(p.id).first;
    expect(acq!.acquisitionType, AcquisitionType.gift);
    final secondParty = await events.watchParty(acq.partyId!).first;
    expect(secondParty!.id, firstParty.id);
  });

  test('timeline is chronological (oldest first)', () async {
    final p = await db.possessionsDao.createPossession(title: 'Fridge');
    final events = db.eventsDao;

    await events.saveAcquisition(
        possessionId: p.id,
        type: AcquisitionType.purchased,
        purchasedOn: DateTime(2020, 1, 1));
    await events.createReminder(
        possessionId: p.id, title: 'Warranty expires', at: DateTime(2028, 5, 14));
    await events.createReminder(
        possessionId: p.id, title: 'Service due', at: DateTime(2025, 6, 1));

    final titles =
        (await events.watchTimeline(p.id).first).map((e) => e.title).toList();
    expect(titles, [null, 'Service due', 'Warranty expires']);
  });

  test('upcoming reminders exclude archived things', () async {
    final possessions = db.possessionsDao;
    final events = db.eventsDao;
    final active = await possessions.createPossession(title: 'Active');
    final away = await possessions.createPossession(title: 'Put away');

    await events.createReminder(
        possessionId: active.id,
        title: 'A',
        at: DateTime.now().add(const Duration(days: 10)));
    await events.createReminder(
        possessionId: away.id,
        title: 'B',
        at: DateTime.now().add(const Duration(days: 5)));
    await possessions.setStatus(away.id, PossessionStatus.archived);

    final upcoming = await events.watchUpcomingReminders().first;
    expect(upcoming.map((u) => u.possessionTitle), ['Active']);
    expect(upcoming.single.event.title, 'A');
  });

  test('a reminder can be removed and restored', () async {
    final p = await db.possessionsDao.createPossession(title: 'Car');
    final events = db.eventsDao;
    final r = await events.createReminder(
        possessionId: p.id, title: 'Insurance renewal', at: DateTime(2030));

    expect((await events.watchTimeline(p.id).first).length, 1);
    await events.deleteEvent(r.id);
    expect(await events.watchTimeline(p.id).first, isEmpty);
    await events.restoreEvent(r.id);
    expect((await events.watchTimeline(p.id).first).length, 1);
  });

  test('createNote stores a note on the timeline and can be removed', () async {
    final p = await db.possessionsDao.createPossession(title: 'Bici');
    final events = db.eventsDao;

    final note = await events.createNote(
        possessionId: p.id, body: 'Chiavi di scorta nel cassetto');
    expect(note.kind, EventKind.note);
    expect(note.notes, 'Chiavi di scorta nel cassetto');

    final timeline = await events.watchTimeline(p.id).first;
    expect(timeline.single.id, note.id);
    expect(timeline.single.kind, EventKind.note);

    // Notes are soft-deletable and restorable like any other event.
    await events.deleteEvent(note.id);
    expect(await events.watchTimeline(p.id).first, isEmpty);
    await events.restoreEvent(note.id);
    expect((await events.watchTimeline(p.id).first).length, 1);
  });
}
