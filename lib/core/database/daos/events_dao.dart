import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../tables/enums.dart';
import '../tables/tables.dart';

part 'events_dao.g.dart';

/// A reminder that is coming up, paired with the name of the thing it belongs
/// to — enough for the Home summary without exposing internals.
///
/// [at] is the *effective* reminder date: an ordinary reminder's own date, or a
/// loan's expected-return date. [borrowerName] is set only for loan returns.
class UpcomingReminder {
  const UpcomingReminder({
    required this.event,
    required this.possessionTitle,
    required this.at,
    this.borrowerName,
  });

  final PossessionEvent event;
  final String possessionTitle;
  final DateTime at;
  final String? borrowerName;

  /// True when this "reminder" is really a lent possession's expected return.
  bool get isLoanReturn => event.kind == EventKind.lent;
}

/// Data access for the timeline: acquisition (one per thing), reminders, and
/// loans (temporary custody).
///
/// Internally these are `Event`s (and suppliers/borrowers are `Party`s); nothing
/// here is exposed to the user in those terms. Reactive throughout; no
/// repository layer.
@DriftAccessor(tables: [Events, Parties, Possessions, Places])
class EventsDao extends DatabaseAccessor<AppDatabase> with _$EventsDaoMixin {
  EventsDao(super.db);

  static const _uuid = Uuid();

  /// All of a thing's timeline events, oldest first.
  Stream<List<PossessionEvent>> watchTimeline(String possessionId) {
    return (select(events)
          ..where(
            (t) => t.possessionId.equals(possessionId) & t.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.at)]))
        .watch();
  }

  /// The single acquisition event for a thing, if any.
  Stream<PossessionEvent?> watchAcquisition(String possessionId) {
    return (select(events)
          ..where(
            (t) =>
                t.possessionId.equals(possessionId) &
                t.kind.equalsValue(EventKind.acquired) &
                t.deletedAt.isNull(),
          )
          ..limit(1))
        .watchSingleOrNull();
  }

  /// A party (supplier) by id — to resolve a supplier name for display.
  Stream<Party?> watchParty(String partyId) {
    return (select(
      parties,
    )..where((t) => t.id.equals(partyId))).watchSingleOrNull();
  }

  Future<String?> _findOrCreateParty(String? name) async {
    final n = name?.trim();
    if (n == null || n.isEmpty) return null;
    final existing =
        await (select(parties)
              ..where((t) => t.name.equals(n) & t.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return existing.id;
    final id = _uuid.v4();
    final now = DateTime.now();
    await into(parties).insert(
      PartiesCompanion.insert(
        id: id,
        name: n,
        kind: const Value(PartyKind.retailer),
        createdAt: now,
        updatedAt: now,
      ),
    );
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
    final existing =
        await (select(events)
              ..where(
                (t) =>
                    t.possessionId.equals(possessionId) &
                    t.kind.equalsValue(EventKind.acquired) &
                    t.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    // `at` anchors the event on the timeline; use the explicit purchase date
    // when known, otherwise keep any existing anchor, else "now".
    final at = purchasedOn ?? existing?.at ?? now;

    if (existing == null) {
      await into(events).insert(
        EventsCompanion.insert(
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
        ),
      );
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
    return into(events).insertReturning(
      EventsCompanion.insert(
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
      ),
    );
  }

  /// Creates a free-text note attached to a thing, anchored on the timeline at
  /// "now". [body] is the note itself; [title] is an optional short heading.
  Future<PossessionEvent> createNote({
    required String possessionId,
    required String body,
    String? title,
  }) {
    final now = DateTime.now();
    return into(events).insertReturning(
      EventsCompanion.insert(
        id: _uuid.v4(),
        possessionId: possessionId,
        kind: EventKind.note,
        at: now,
        title: Value(title),
        notes: Value(body),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> deleteEvent(String id) {
    return (update(events)..where((t) => t.id.equals(id))).write(
      EventsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> restoreEvent(String id) {
    return (update(events)..where((t) => t.id.equals(id))).write(
      EventsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Pending reminders across all active things, soonest first — for Home.
  ///
  /// Two sources, one reactive query: ordinary `reminder` events (dated by their
  /// own `at`), and active loans that asked for a return reminder (a pending
  /// `lent` event with an expected-return `endsAt` and a `remindLead`, dated by
  /// `endsAt`). A loan carries its own reminder, so returning it — which sets the
  /// loan `done` — drops it here automatically, with no orphaned reminder row.
  Stream<List<UpcomingReminder>> watchUpcomingReminders() {
    final query =
        select(events).join([
          innerJoin(possessions, possessions.id.equalsExp(events.possessionId)),
          leftOuterJoin(parties, parties.id.equalsExp(events.partyId)),
        ])..where(
          events.deletedAt.isNull() &
              possessions.deletedAt.isNull() &
              possessions.status.equalsValue(PossessionStatus.active) &
              (events.kind.equalsValue(EventKind.reminder) |
                  (events.kind.equalsValue(EventKind.lent) &
                      events.status.equalsValue(EventStatus.pending) &
                      events.endsAt.isNotNull() &
                      events.remindLead.isNotNull())),
        );
    return query.watch().map((rows) {
      final list = rows.map((r) {
        final event = r.readTable(events);
        final isLoan = event.kind == EventKind.lent;
        return UpcomingReminder(
          event: event,
          possessionTitle: r.readTable(possessions).title,
          at: isLoan ? event.endsAt! : event.at,
          borrowerName: isLoan ? r.readTableOrNull(parties)?.name : null,
        );
      }).toList()..sort((a, b) => a.at.compareTo(b.at));
      return list;
    });
  }

  // ---- People & loans (M5.2) ----

  /// Non-deleted people (borrowers), alphabetical — powers the person picker.
  /// Only `PartyKind.person`; suppliers and other party kinds never appear.
  Stream<List<Party>> watchPeople() {
    return (select(parties)
          ..where(
            (t) => t.kind.equalsValue(PartyKind.person) & t.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.name.lower())]))
        .watch();
  }

  /// Find an existing person by normalized (case-insensitive) name, or create
  /// one. **Always `PartyKind.person`** — this never touches or converts a
  /// supplier/retailer party. [name] must already be trimmed and non-empty.
  Future<String> findOrCreatePerson(String name) async {
    final n = name.trim();
    final existing =
        await (select(parties)
              ..where(
                (t) =>
                    t.name.lower().equals(n.toLowerCase()) &
                    t.kind.equalsValue(PartyKind.person) &
                    t.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return existing.id;
    final id = _uuid.v4();
    final now = DateTime.now();
    await into(parties).insert(
      PartiesCompanion.insert(
        id: id,
        name: n,
        kind: const Value(PartyKind.person),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  /// The active loan for a possession (a pending, non-deleted `lent` event), or
  /// null — reactive, powers the custody card and the Home indicator.
  Stream<PossessionEvent?> watchActiveLoan(String possessionId) {
    return (select(events)
          ..where(
            (t) =>
                t.possessionId.equals(possessionId) &
                t.kind.equalsValue(EventKind.lent) &
                t.status.equalsValue(EventStatus.pending) &
                t.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.at)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// One-shot check used to guard against a second simultaneous loan.
  Future<PossessionEvent?> _activeLoan(String possessionId) {
    return (select(events)
          ..where(
            (t) =>
                t.possessionId.equals(possessionId) &
                t.kind.equalsValue(EventKind.lent) &
                t.status.equalsValue(EventStatus.pending) &
                t.deletedAt.isNull(),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  /// Lends a possession to a person, transactionally. Creates/reuses the person,
  /// records the loan (remembering the possession's current place as
  /// `originPlaceId`), and clears the possession's place so it is no longer shown
  /// as physically stored. Returns the loan event, or null if there is already an
  /// active loan (so repeated taps can never create a duplicate).
  Future<PossessionEvent?> lend({
    required String possessionId,
    required String personName,
    String? partyId,
    required DateTime lentAt,
    DateTime? expectedReturn,
    ReminderLead? lead,
  }) {
    return transaction(() async {
      if (await _activeLoan(possessionId) != null) return null;
      final borrowerId = partyId ?? await findOrCreatePerson(personName);
      final possession = await (select(
        possessions,
      )..where((t) => t.id.equals(possessionId))).getSingleOrNull();
      if (possession == null) return null;
      final now = DateTime.now();
      final loan = await into(events).insertReturning(
        EventsCompanion.insert(
          id: _uuid.v4(),
          possessionId: possessionId,
          kind: EventKind.lent,
          at: lentAt,
          endsAt: Value(expectedReturn),
          partyId: Value(borrowerId),
          originPlaceId: Value(possession.placeId),
          remindLead: Value(expectedReturn == null ? null : lead),
          status: const Value(EventStatus.pending),
          createdAt: now,
          updatedAt: now,
        ),
      );
      // Lending clears the physical place; the loan remembers where it was.
      await (update(
        possessions,
      )..where((t) => t.id.equals(possessionId))).write(
        PossessionsCompanion(placeId: const Value(null), updatedAt: Value(now)),
      );
      return loan;
    });
  }

  /// Corrects an active loan in place (never creates a second one): borrower,
  /// expected return date and reminder. The lent date and `originPlaceId` are
  /// preserved. Clearing the return date also clears its reminder.
  Future<void> updateLoan(
    String loanEventId, {
    required String personName,
    String? partyId,
    required DateTime? expectedReturn,
    ReminderLead? lead,
  }) {
    return transaction(() async {
      final borrowerId = partyId ?? await findOrCreatePerson(personName);
      await (update(events)..where((t) => t.id.equals(loanEventId))).write(
        EventsCompanion(
          partyId: Value(borrowerId),
          endsAt: Value(expectedReturn),
          remindLead: Value(expectedReturn == null ? null : lead),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// Closes an active loan, transactionally: marks the loan `done`, records a
  /// `returned` event for history, and restores a place. The place is restored
  /// only if it still exists and is active; anything else leaves the possession
  /// with no place. The possession stays active; the borrower and loan history
  /// are preserved. The loan's pending return reminder drops automatically once
  /// the loan is `done`.
  Future<void> returnLoan({
    required String possessionId,
    required String loanEventId,
    required DateTime returnedAt,
    String? returnPlaceId,
  }) {
    return transaction(() async {
      final loan = await (select(
        events,
      )..where((t) => t.id.equals(loanEventId))).getSingleOrNull();
      final now = DateTime.now();
      await (update(events)..where((t) => t.id.equals(loanEventId))).write(
        EventsCompanion(
          status: const Value(EventStatus.done),
          updatedAt: Value(now),
        ),
      );
      await into(events).insert(
        EventsCompanion.insert(
          id: _uuid.v4(),
          possessionId: possessionId,
          kind: EventKind.returned,
          at: returnedAt,
          partyId: Value(loan?.partyId),
          status: const Value(EventStatus.done),
          createdAt: now,
          updatedAt: now,
        ),
      );
      // Restore the place only if it is still **reachable** — the place and its
      // whole ancestor chain are active — so a return never lands in a deleted
      // or unreachable branch.
      final restored = (await _placeReachable(returnPlaceId))
          ? returnPlaceId
          : null;
      await (update(
        possessions,
      )..where((t) => t.id.equals(possessionId))).write(
        PossessionsCompanion(placeId: Value(restored), updatedAt: Value(now)),
      );
    });
  }

  /// True when [placeId] is null, or it and every ancestor up to a root are
  /// active (non-deleted), with no cycle. Cheap for realistic tree depths.
  Future<bool> _placeReachable(String? placeId) async {
    if (placeId == null) return true;
    final visited = <String>{};
    String? cur = placeId;
    while (cur != null) {
      if (!visited.add(cur)) return false;
      final p = await (select(
        places,
      )..where((t) => t.id.equals(cur!))).getSingleOrNull();
      if (p == null || p.deletedAt != null) return false;
      cur = p.parentId;
    }
    return true;
  }

  // ---- Giving / permanent transfer (M5.5) ----

  /// The current transfer for a possession — the latest non-deleted `transfer`
  /// event. Resolves the recipient and date for the "Dato a …" banner/timeline.
  Stream<PossessionEvent?> watchTransfer(String possessionId) {
    return (select(events)
          ..where(
            (t) =>
                t.possessionId.equals(possessionId) &
                t.kind.equalsValue(EventKind.transfer) &
                t.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.at)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Permanently gives a possession to a person, transactionally: create/reuse
  /// the person, record the transfer (remembering the exact current place as
  /// `originPlaceId`), set the status to `transferred`, and clear the place so it
  /// leaves Home and Places. Returns the transfer event, or null if the give is
  /// not allowed (an active loan, or the thing isn't active & non-deleted) — so
  /// repeated taps and stale state can never produce a bad transfer.
  Future<PossessionEvent?> give({
    required String possessionId,
    required String personName,
    String? partyId,
    required DateTime transferredAt,
    String? note,
  }) {
    return transaction(() async {
      final poss = await (select(
        possessions,
      )..where((t) => t.id.equals(possessionId))).getSingleOrNull();
      // Must be an active, non-deleted, not-already-given thing.
      if (poss == null ||
          poss.deletedAt != null ||
          poss.status != PossessionStatus.active) {
        return null;
      }
      // An actively lent thing must be returned before it can be given.
      if (await _activeLoan(possessionId) != null) return null;

      final recipientId = partyId ?? await findOrCreatePerson(personName);
      final now = DateTime.now();
      final event = await into(events).insertReturning(
        EventsCompanion.insert(
          id: _uuid.v4(),
          possessionId: possessionId,
          kind: EventKind.transfer,
          at: transferredAt,
          partyId: Value(recipientId),
          originPlaceId: Value(poss.placeId),
          notes: Value(note),
          status: const Value(EventStatus.done),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await (update(
        possessions,
      )..where((t) => t.id.equals(possessionId))).write(
        PossessionsCompanion(
          status: const Value(PossessionStatus.transferred),
          placeId: const Value(null),
          updatedAt: Value(now),
        ),
      );
      return event;
    });
  }

  /// Immediate, fully atomic Undo of [give]: neutralize *only* the just-created
  /// transfer event (soft-delete), set the status back to active, and restore the
  /// exact origin place only if it is still reachable (else no place). Every
  /// other event/photo is untouched; the recipient party is never changed.
  Future<void> undoGive({
    required String possessionId,
    required String transferEventId,
  }) {
    return transaction(() async {
      final transfer = await (select(
        events,
      )..where((t) => t.id.equals(transferEventId))).getSingleOrNull();
      final now = DateTime.now();
      await (update(events)..where((t) => t.id.equals(transferEventId))).write(
        EventsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      final restored = (await _placeReachable(transfer?.originPlaceId))
          ? transfer?.originPlaceId
          : null;
      await (update(
        possessions,
      )..where((t) => t.id.equals(possessionId))).write(
        PossessionsCompanion(
          status: const Value(PossessionStatus.active),
          placeId: Value(restored),
          updatedAt: Value(now),
        ),
      );
    });
  }

  /// Reacquire a given possession ("Torna tra i miei oggetti"): set it active
  /// again, put it in the chosen place (kept only if reachable, else none), and
  /// record a distinct `reacquired` history event — **preserving** the original
  /// transfer event, so the full truth (given on…, back on…) stays readable.
  Future<void> reacquire({
    required String possessionId,
    required DateTime reacquiredAt,
    String? placeId,
  }) {
    return transaction(() async {
      final now = DateTime.now();
      final restored = (await _placeReachable(placeId)) ? placeId : null;
      await (update(
        possessions,
      )..where((t) => t.id.equals(possessionId))).write(
        PossessionsCompanion(
          status: const Value(PossessionStatus.active),
          placeId: Value(restored),
          updatedAt: Value(now),
        ),
      );
      await into(events).insert(
        EventsCompanion.insert(
          id: _uuid.v4(),
          possessionId: possessionId,
          kind: EventKind.reacquired,
          at: reacquiredAt,
          status: const Value(EventStatus.done),
          createdAt: now,
          updatedAt: now,
        ),
      );
    });
  }
}
