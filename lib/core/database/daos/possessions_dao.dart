import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../tables/enums.dart';
import '../tables/tables.dart';

part 'possessions_dao.g.dart';

/// Data access for possessions (and their cover [Files]).
///
/// Reads are **reactive** (Drift `Stream`s). No repository layer sits above
/// this — the DAO *is* the data layer.
@DriftAccessor(tables: [Possessions, Files])
class PossessionsDao extends DatabaseAccessor<AppDatabase>
    with _$PossessionsDaoMixin {
  PossessionsDao(super.db);

  static const _uuid = Uuid();

  /// Active, non-deleted possessions, newest first. Archived and removed things
  /// drop out of the main home; the record itself is preserved either way.
  Stream<List<Possession>> watchAll() {
    return (select(possessions)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.status.equalsValue(PossessionStatus.active))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// A single possession by id, reactive — powers the detail screen.
  Stream<Possession?> watchById(String id) {
    return (select(possessions)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  /// A stored file by id, reactive — used to resolve a cover photo.
  Stream<StoredFile?> watchFile(String fileId) {
    return (select(files)..where((t) => t.id.equals(fileId)))
        .watchSingleOrNull();
  }

  /// Creates a possession. Only [title] is required.
  Future<Possession> createPossession({
    required String title,
    String? category,
  }) {
    final now = DateTime.now();
    return into(possessions).insertReturning(
      PossessionsCompanion.insert(
        id: _uuid.v4(),
        title: title,
        category: Value(category),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> rename(String id, String title) {
    return (update(possessions)..where((t) => t.id.equals(id))).write(
      PossessionsCompanion(title: Value(title), updatedAt: Value(DateTime.now())),
    );
  }

  /// Assigns (or clears, when [placeId] is null) the possession's place.
  /// "No place" is simply a null value — never a placeholder record.
  Future<void> setPlace(String id, String? placeId) {
    return (update(possessions)..where((t) => t.id.equals(id))).write(
      PossessionsCompanion(
          placeId: Value(placeId), updatedAt: Value(DateTime.now())),
    );
  }

  /// Sets lifecycle status (e.g. archive). Preserves the record.
  Future<void> setStatus(String id, PossessionStatus status) {
    return (update(possessions)..where((t) => t.id.equals(id))).write(
      PossessionsCompanion(
          status: Value(status), updatedAt: Value(DateTime.now())),
    );
  }

  /// Soft delete (tombstone) — recoverable via [restore].
  Future<void> softDelete(String id) {
    return (update(possessions)..where((t) => t.id.equals(id))).write(
      PossessionsCompanion(
          deletedAt: Value(DateTime.now()), updatedAt: Value(DateTime.now())),
    );
  }

  /// Undo for both archive and delete: back to active and un-tombstoned.
  Future<void> restore(String id) {
    return (update(possessions)..where((t) => t.id.equals(id))).write(
      PossessionsCompanion(
        status: const Value(PossessionStatus.active),
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Registers a stored file and sets it as the possession's cover. The bytes
  /// are written to disk by the caller; only the metadata lives here.
  Future<void> setCover(
    String possessionId, {
    required String relativePath,
    required String mimeType,
    required int byteSize,
  }) async {
    final fileId = _uuid.v4();
    await into(files).insert(
      FilesCompanion.insert(
        id: fileId,
        relativePath: relativePath,
        mimeType: mimeType,
        byteSize: byteSize,
        createdAt: DateTime.now(),
      ),
    );
    await (update(possessions)..where((t) => t.id.equals(possessionId))).write(
      PossessionsCompanion(
          coverFileId: Value(fileId), updatedAt: Value(DateTime.now())),
    );
  }
}
