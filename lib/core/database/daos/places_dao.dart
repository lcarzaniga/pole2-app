import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../tables/tables.dart';

part 'places_dao.g.dart';

/// Data access for [Places] — user-defined, reusable locations.
///
/// Reads are **reactive** (Drift `Stream`s), like [PossessionsDao]. Places are
/// flat (no hierarchy in R1.0) and never auto-created: "no place" is simply a
/// null `placeId` on a possession, never a placeholder row here.
@DriftAccessor(tables: [Places])
class PlacesDao extends DatabaseAccessor<AppDatabase> with _$PlacesDaoMixin {
  PlacesDao(super.db);

  static const _uuid = Uuid();

  /// All non-deleted places, alphabetical — powers the place picker and search.
  Stream<List<Place>> watchAll() {
    return (select(places)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.name.lower()),
          ]))
        .watch();
  }

  /// A single place by id, reactive.
  Stream<Place?> watchById(String id) {
    return (select(places)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  /// One-shot fetch (non-reactive) — handy right after creating a place.
  Future<Place?> findById(String id) {
    return (select(places)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Create a place; returns its new id. `name` is trimmed and required.
  Future<String> create({required String name, String? notes}) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    await into(places).insert(PlacesCompanion.insert(
      id: id,
      name: name.trim(),
      notes: Value(notes?.trim()),
      createdAt: now,
      updatedAt: now,
    ));
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
}
