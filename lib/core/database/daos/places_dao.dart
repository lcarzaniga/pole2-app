import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../tables/tables.dart';

part 'places_dao.g.dart';

/// The outcome of a place move — lets the UI explain a rejection calmly rather
/// than failing silently.
enum PlaceMoveResult { moved, invalid, cycle, notFound }

/// Data access for [Places] — a user-defined **tree** of physical containment
/// (M5.4). Reads are **reactive** (Drift `Stream`s). "No place" is simply a null
/// `placeId` on a possession, never a placeholder row here; a root place is one
/// with a null `parentId`.
@DriftAccessor(tables: [Places, Possessions])
class PlacesDao extends DatabaseAccessor<AppDatabase> with _$PlacesDaoMixin {
  PlacesDao(super.db);

  static const _uuid = Uuid();

  /// All non-deleted places, alphabetical — the full set the app builds the tree
  /// from (see `PlaceTree`) and the flat search/picker use.
  Stream<List<Place>> watchAll() {
    return (select(places)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name.lower())]))
        .watch();
  }

  /// Non-deleted root places (no parent), alphabetical — the root browser.
  Stream<List<Place>> watchRoots() {
    return (select(places)
          ..where((t) => t.deletedAt.isNull() & t.parentId.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name.lower())]))
        .watch();
  }

  /// Non-deleted direct children of [parentId], alphabetical.
  Stream<List<Place>> watchChildren(String parentId) {
    return (select(places)
          ..where((t) => t.deletedAt.isNull() & t.parentId.equals(parentId))
          ..orderBy([(t) => OrderingTerm(expression: t.name.lower())]))
        .watch();
  }

  /// A single **non-deleted** place by id, reactive. A soft-deleted or missing
  /// place yields null, so the UI resolves it to "no place".
  Stream<Place?> watchById(String id) {
    return (select(places)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  /// One-shot raw fetch (includes soft-deleted rows) — handy right after
  /// creating a place, or to confirm a tombstone exists.
  Future<Place?> findById(String id) {
    return (select(places)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Create a place; returns its new id. `name` is trimmed and required.
  /// [parentId] null → a root place; otherwise a child of that place. A parent
  /// that is missing or soft-deleted is rejected (the place is created at root),
  /// so a child never dangles under a tombstone.
  Future<String> create({
    required String name,
    String? notes,
    String? parentId,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    String? parent = parentId;
    if (parent != null) {
      final p =
          await (select(places)
                ..where((t) => t.id.equals(parent!) & t.deletedAt.isNull()))
              .getSingleOrNull();
      if (p == null) parent = null; // never nest under a missing/deleted place
    }
    await into(places).insert(
      PlacesCompanion.insert(
        id: id,
        name: name.trim(),
        parentId: Value(parent),
        notes: Value(notes?.trim()),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  /// Rename / edit a place's details.
  Future<void> edit(String id, {String? name, String? notes}) {
    return (update(places)..where((t) => t.id.equals(id))).write(
      PlacesCompanion(
        name: name == null ? const Value.absent() : Value(name.trim()),
        notes: notes == null ? const Value.absent() : Value(notes.trim()),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Soft-delete a place. Possessions that referenced it keep their `placeId`
  /// value; the UI resolves a deleted place to "no place". (Hard cleanup and
  /// re-assignment UX come with the M2 UI, not the data layer.)
  Future<void> softDelete(String id) {
    return (update(places)..where((t) => t.id.equals(id))).write(
      PlacesCompanion(deletedAt: Value(DateTime.now().toUtc())),
    );
  }

  /// Delete a place and unassign it from every possession that referenced it,
  /// **atomically**. The possessions are never touched beyond their `placeId`
  /// (which returns to null = "no place"); nothing is deleted or archived. Doing
  /// both in one transaction means a place can never be left half-deleted with
  /// possessions still pointing at a tombstone.
  Future<void> deleteAndUnassign(String id) {
    return transaction(() async {
      await softDelete(id);
      await (update(possessions)..where((t) => t.placeId.equals(id))).write(
        PossessionsCompanion(
          placeId: const Value(null),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    });
  }

  // ---- Hierarchy (M5.4) ----

  /// How many active (non-deleted) direct children a place has — drives the
  /// "move children first" delete guard. Only active children block deletion.
  Future<int> activeChildCount(String id) async {
    final n = places.id.count();
    final q = selectOnly(places)
      ..addColumns([n])
      ..where(places.parentId.equals(id) & places.deletedAt.isNull());
    return (await q.getSingle()).read(n) ?? 0;
  }

  /// Delete a **leaf** place (no active children): soft-delete it and unassign
  /// its directly-held possessions, atomically. Returns false without touching
  /// anything when the place still has active children — the subtree is never
  /// cascaded and children are never silently promoted to root.
  Future<bool> deleteLeaf(String id) {
    return transaction(() async {
      if (await activeChildCount(id) > 0) return false;
      await softDelete(id);
      await (update(possessions)..where((t) => t.placeId.equals(id))).write(
        PossessionsCompanion(
          placeId: const Value(null),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      return true;
    });
  }

  /// Move a place under [newParentId] (null = root), transactionally, rejecting
  /// any invalid move so the tree can never become cyclic or dangling — even if
  /// a stale UI sends a bad target. All descendants and possession assignments
  /// are preserved (only this row's `parentId` changes).
  Future<PlaceMoveResult> move(String id, String? newParentId) {
    return transaction(() async {
      if (id == newParentId) return PlaceMoveResult.invalid;
      final self = await (select(
        places,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (self == null || self.deletedAt != null) {
        return PlaceMoveResult.notFound; // can't move a missing/deleted place
      }
      if (newParentId != null) {
        final parent =
            await (select(places)..where(
                  (t) => t.id.equals(newParentId) & t.deletedAt.isNull(),
                ))
                .getSingleOrNull();
        if (parent == null) return PlaceMoveResult.notFound;
        // A move creates a cycle iff the new parent is `id` itself or lives
        // inside `id`'s subtree — i.e. `id` is an ancestor-or-self of the new
        // parent. Walk up from the new parent; visited-protected against any
        // pre-existing corrupt cycle.
        final parentOf = {
          for (final p in await select(places).get()) p.id: p.parentId,
        };
        final visited = <String>{};
        String? cur = newParentId;
        while (cur != null) {
          if (cur == id) return PlaceMoveResult.cycle;
          if (!visited.add(cur)) break; // corrupt cycle upstream — stop safely
          cur = parentOf[cur];
        }
      }
      await (update(places)..where((t) => t.id.equals(id))).write(
        PlacesCompanion(
          parentId: Value(newParentId),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      return PlaceMoveResult.moved;
    });
  }
}
