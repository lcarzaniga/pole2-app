import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/enums.dart';
import '../domain/custody.dart';

/// Grouped, reactive People read/write queries built directly on [AppDatabase]
/// (kept in the feature layer so `core` never depends on a feature). Every read
/// is a **single** joined query reduced in Dart — no per-person N+1 fan-out —
/// and reactive to lend/return/give/reacquire/delete/restore.

/// Possessions currently lent to someone: a pending, non-deleted `lent` event on
/// an active, non-deleted possession. Ordered by possession title.
Stream<List<LoanView>> watchActiveLoans(AppDatabase db) {
  final e = db.events, p = db.possessions, pa = db.parties;
  final q =
      db.select(e).join([
        innerJoin(p, p.id.equalsExp(e.possessionId)),
        innerJoin(pa, pa.id.equalsExp(e.partyId)),
      ])..where(
        e.kind.equalsValue(EventKind.lent) &
            e.status.equalsValue(EventStatus.pending) &
            e.deletedAt.isNull() &
            p.deletedAt.isNull() &
            p.status.equalsValue(PossessionStatus.active),
      );
  return q.watch().map((rows) {
    final list = [
      for (final r in rows)
        LoanView(
          possession: r.readTable(p),
          party: r.readTable(pa),
          loan: r.readTable(e),
        ),
    ];
    list.sort(
      (a, b) => a.possession.title.toLowerCase().compareTo(
        b.possession.title.toLowerCase(),
      ),
    );
    return list;
  });
}

/// Possessions currently given to someone: for every `transferred`, non-deleted
/// possession, its **latest** valid transfer's recipient (so a re-give assigns
/// only the newest recipient, never a duplicate). Ordered by possession title.
Stream<List<GivenView>> watchCurrentGiven(AppDatabase db) {
  final e = db.events, p = db.possessions, pa = db.parties;
  final q =
      db.select(e).join([
        innerJoin(p, p.id.equalsExp(e.possessionId)),
        innerJoin(pa, pa.id.equalsExp(e.partyId)),
      ])..where(
        e.kind.equalsValue(EventKind.transfer) &
            e.deletedAt.isNull() &
            p.deletedAt.isNull() &
            p.status.equalsValue(PossessionStatus.transferred),
      );
  return q.watch().map((rows) {
    final latest = <String, TypedResult>{};
    for (final r in rows) {
      final ev = r.readTable(e);
      final cur = latest[ev.possessionId];
      if (cur == null) {
        latest[ev.possessionId] = r;
      } else {
        final ce = cur.readTable(e);
        final newer =
            ev.at.isAfter(ce.at) ||
            (ev.at == ce.at && ev.createdAt.isAfter(ce.createdAt));
        if (newer) latest[ev.possessionId] = r;
      }
    }
    final list = [
      for (final r in latest.values)
        GivenView(
          possession: r.readTable(p),
          party: r.readTable(pa),
          transfer: r.readTable(e),
        ),
    ];
    list.sort(
      (a, b) => a.possession.title.toLowerCase().compareTo(
        b.possession.title.toLowerCase(),
      ),
    );
    return list;
  });
}

/// Every non-deleted returned/transfer/reacquired event, joined with just enough
/// of its possession (including removed ones, so history can still navigate) and
/// its party. Reduced by [buildCustodyHistory] into the newest-first history.
Stream<List<CustodyEventRaw>> watchCustodyEvents(AppDatabase db) {
  final e = db.events, p = db.possessions, pa = db.parties;
  final q =
      db.select(e).join([
        innerJoin(p, p.id.equalsExp(e.possessionId)),
        leftOuterJoin(pa, pa.id.equalsExp(e.partyId)),
      ])..where(
        e.deletedAt.isNull() &
            (e.kind.equalsValue(EventKind.returned) |
                e.kind.equalsValue(EventKind.transfer) |
                e.kind.equalsValue(EventKind.reacquired)),
      );
  return q.watch().map((rows) {
    return [
      for (final r in rows)
        CustodyEventRaw(
          event: r.readTable(e),
          possessionTitle: r.readTable(p).title,
          possessionStatus: r.readTable(p).status,
          possessionDeleted: r.readTable(p).deletedAt != null,
          party: r.readTableOrNull(pa),
        ),
    ];
  });
}

/// True when [personId] currently holds custody of something — an active loan,
/// or a possession currently given to them — so deletion must be blocked.
Future<bool> personHasCurrentCustody(AppDatabase db, String personId) async {
  final e = db.events, p = db.possessions;
  final loans =
      await (db.select(e).join([innerJoin(p, p.id.equalsExp(e.possessionId))])
            ..where(
              e.partyId.equals(personId) &
                  e.kind.equalsValue(EventKind.lent) &
                  e.status.equalsValue(EventStatus.pending) &
                  e.deletedAt.isNull() &
                  p.deletedAt.isNull() &
                  p.status.equalsValue(PossessionStatus.active),
            ))
          .get();
  if (loans.isNotEmpty) return true;
  final given = await watchCurrentGiven(db).first;
  return given.any((g) => g.party.id == personId);
}

/// Creates or reuses a person (case-insensitive, always `PartyKind.person`).
Future<String> createPerson(AppDatabase db, String name) =>
    db.eventsDao.findOrCreatePerson(name.trim());

/// Renames a person. Returns false (changing nothing) when the name is blank or
/// would collide with another existing person (we never create duplicates).
Future<bool> renamePerson(AppDatabase db, String id, String rawName) async {
  final name = rawName.trim();
  if (name.isEmpty) return false;
  final clash =
      await (db.select(db.parties)
            ..where(
              (t) =>
                  t.id.equals(id).not() &
                  t.kind.equalsValue(PartyKind.person) &
                  t.deletedAt.isNull() &
                  t.name.lower().equals(name.toLowerCase()),
            )
            ..limit(1))
          .getSingleOrNull();
  if (clash != null) return false;
  await (db.update(db.parties)..where((t) => t.id.equals(id))).write(
    PartiesCompanion(name: Value(name), updatedAt: Value(DateTime.now())),
  );
  return true;
}

/// Soft-deletes a person (callers must first confirm no current custody). The
/// row stays name-resolvable for history; it just leaves People and pickers.
Future<void> softDeletePerson(AppDatabase db, String id) =>
    (db.update(db.parties)..where((t) => t.id.equals(id))).write(
      PartiesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
