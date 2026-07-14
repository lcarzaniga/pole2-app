import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../tables/enums.dart';
import '../tables/tables.dart';

part 'events_dao.g.dart';

/// A reminder that is coming up, paired with the name of the thing it belongs
/// to — enough for the Home summary without exposing internals.
class UpcomingReminder {
  const UpcomingReminder({required this.event, required this.possessionTitle});

  final PossessionEvent event;
  final String possessionTitle;
}

/// Data access for the timeline: acquisition (one per thing) and reminders.
///
/// Internally these are `Event`s (and suppliers are `Party`s); nothing here is
/// exposed to the user in those terms. Reactive throughout; no repository layer.
@DriftAccessor(tables: [Events, Parties, Possessions])
class EventsDao extends DatabaseAccessor<AppDatabase> with _$EventsDaoMixin {
  EventsDao(super.db);

  static const _uuid = Uuid();

  /// All of a thing's timeline events, oldest first.
  Stream<List<PossessionEvent>> watchTimeline(String possessionId) {
    return (select(events)
          ..where((t) => t.possessionId.equals(possessionId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.at)]))
        .watch();
  }

  /// The single acquisition event for a thing, if any.
  Stream<PossessionEvent?> watchAcquisition(String possessionId) {
    return (select(events)
          ..where((t) =>
              t.possessionId.equals(possessionId) &
              t.kind.equalsValue(EventKind.acquired) &
              t.deletedAt.isNull())
          ..limit(1))
        .watchSingleOrNull();
  }

  /// A party (supplier) by id — to resolve a supplier name for display.
  Stream<Party?> watchParty(String partyId) {
    return (select(parties)..where((t) => t.id.equals(partyId)))
        .watchSingleOrNull();
  }

  Future<String?> _findOrCreateParty(String? name) async {
    final n = name?.trim();
    if (n == null || n.isEmpty) return null;
    final existing = await (select(parties)
          ..where((t) => t.name.equals(n) & t.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return existing.id;
    final id = _uuid.v4();
    final now = DateTime.now();
    await into(parties).insert(PartiesCompanion.insert(
      id: id,
      name: n,
      kind: const Value(PartyKind.retailer),
      createdAt: now,
      updatedAt: now,
    ));
    return id;
  }

  /// Creates or updates the acquisition for a thing. Every field is optional;
  /// saving partial information is always valid.
  Future<void> saveAcquisition({
    required String possessionId,
    AcquisitionType? type,
    DateTime? purchasedOn,
    String? supplierName,
    int? amountMinor,
    String? currency,
    String? note,
  }) async {
    final partyId = await _findOrCreateParty(supplierName);
    final now = DateTime.now();
    final existing = await (select(events)
          ..where((t) =>
              t.possessionId.equals(possessionId) &
              t.kind.equalsValue(EventKind.acquired) &
              t.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    // `at` anchors the event on the timeline; use the explicit purchase date
    // when known, otherwise keep any existing anchor, else "now".
    final at = purchasedOn ?? existing?.at ?? now;

    if (existing == null) {
      await into(events).insert(EventsCompanion.insert(
        id: _uuid.v4(),
        possessionId: possessionId,
        kind: EventKind.acquired,
        at: at,
        purchasedOn: Value(purchasedOn),
        acquisitionType: Value(type),
        partyId: Value(partyId),
        amountMinor: Value(amountMinor),
        currency: Value(currency),
        notes: Value(note),
        createdAt: now,
        updatedAt: now,
      ));
    } else {
      await (update(events)..where((t) => t.id.equals(existing.id))).write(
        EventsCompanion(
          at: Value(at),
          purchasedOn: Value(purchasedOn),
          acquisitionType: Value(type),
          partyId: Value(partyId),
          amountMinor: Value(amountMinor),
          currency: Value(currency),
          notes: Value(note),
          updatedAt: Value(now),
        ),
      );
    }
  }

  Future<PossessionEvent> createReminder({
    required String possessionId,
    required String title,
    required DateTime at,
    String? note,
    ReminderLead? lead,
  }) {
    final now = DateTime.now();
    return into(events).insertReturning(EventsCompanion.insert(
      id: _uuid.v4(),
      possessionId: possessionId,
      kind: EventKind.reminder,
      at: at,
      title: Value(title),
      notes: Value(note),
      remindLead: Value(lead),
      status: const Value(EventStatus.pending),
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<void> deleteEvent(String id) {
    return (update(events)..where((t) => t.id.equals(id))).write(EventsCompanion(
        deletedAt: Value(DateTime.now()), updatedAt: Value(DateTime.now())));
  }

  Future<void> restoreEvent(String id) {
    return (update(events)..where((t) => t.id.equals(id))).write(EventsCompanion(
        deletedAt: const Value(null), updatedAt: Value(DateTime.now())));
  }

  /// Pending reminders across all active things, soonest first — for Home.
  Stream<List<UpcomingReminder>> watchUpcomingReminders() {
    final query = select(events).join([
      innerJoin(possessions, possessions.id.equalsExp(events.possessionId)),
    ])
      ..where(events.kind.equalsValue(EventKind.reminder) &
          events.deletedAt.isNull() &
          possessions.deletedAt.isNull() &
          possessions.status.equalsValue(PossessionStatus.active))
      ..orderBy([OrderingTerm.asc(events.at)]);
    return query.watch().map((rows) => rows
        .map((r) => UpcomingReminder(
              event: r.readTable(events),
              possessionTitle: r.readTable(possessions).title,
            ))
        .toList());
  }
}
