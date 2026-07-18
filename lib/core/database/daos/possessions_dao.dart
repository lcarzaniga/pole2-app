import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../tables/enums.dart';
import '../tables/tables.dart';

part 'possessions_dao.g.dart';

/// A gallery photo paired with its backing file — everything the UI needs to
/// render one thumbnail or full-screen image in a single row.
class PhotoWithFile {
  const PhotoWithFile({required this.photo, required this.file});

  final PossessionPhoto photo;
  final StoredFile file;
}

/// Data access for possessions, their cover [Files], and the photo gallery.
///
/// Reads are **reactive** (Drift `Stream`s). No repository layer sits above
/// this — the DAO *is* the data layer.
@DriftAccessor(tables: [Possessions, Files, PossessionPhotos, Places])
class PossessionsDao extends DatabaseAccessor<AppDatabase>
    with _$PossessionsDaoMixin {
  PossessionsDao(super.db);

  static const _uuid = Uuid();

  /// Active, non-deleted possessions, newest first. Archived and removed things
  /// drop out of the main home; the record itself is preserved either way.
  Stream<List<Possession>> watchAll() {
    return (select(possessions)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                t.status.equalsValue(PossessionStatus.active),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Active (non-deleted) possessions kept in [placeId], newest first — powers
  /// the place-contents screen. Same "active" definition and ordering as
  /// [watchAll]; reactive to assignment, removal, soft-delete and restore.
  Stream<List<Possession>> watchByPlace(String placeId) {
    return (select(possessions)
          ..where(
            (t) =>
                t.placeId.equals(placeId) &
                t.deletedAt.isNull() &
                t.status.equalsValue(PossessionStatus.active),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// A single possession by id, reactive — powers the detail screen.
  Stream<Possession?> watchById(String id) {
    return (select(
      possessions,
    )..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  /// A stored file by id, reactive — used to resolve a cover photo.
  Stream<StoredFile?> watchFile(String fileId) {
    return (select(
      files,
    )..where((t) => t.id.equals(fileId))).watchSingleOrNull();
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
      PossessionsCompanion(
        title: Value(title),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Assigns (or clears, when [placeId] is null) the possession's place.
  /// "No place" is simply a null value — never a placeholder record.
  Future<void> setPlace(String id, String? placeId) {
    return (update(possessions)..where((t) => t.id.equals(id))).write(
      PossessionsCompanion(
        placeId: Value(placeId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// How many non-deleted possessions are currently assigned to [placeId].
  /// Powers the "this place is in use" warning before deleting a place.
  Future<int> countByPlace(String placeId) async {
    final n = possessions.id.count();
    final q = selectOnly(possessions)
      ..addColumns([n])
      ..where(
        possessions.placeId.equals(placeId) & possessions.deletedAt.isNull(),
      );
    return (await q.getSingle()).read(n) ?? 0;
  }

  /// Clears the place on every possession that referenced [placeId] — used when
  /// a place is deleted, so affected possessions safely resolve to "no place".
  Future<void> clearPlace(String placeId) {
    return (update(possessions)..where((t) => t.placeId.equals(placeId))).write(
      PossessionsCompanion(
        placeId: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Sets lifecycle status (e.g. archive). Preserves the record.
  Future<void> setStatus(String id, PossessionStatus status) {
    return (update(possessions)..where((t) => t.id.equals(id))).write(
      PossessionsCompanion(
        status: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Soft delete (tombstone) — recoverable via [restore].
  Future<void> softDelete(String id) {
    return (update(possessions)..where((t) => t.id.equals(id))).write(
      PossessionsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Undo for both archive and delete: back to active and un-tombstoned. Kept
  /// for the immediate snackbar Undo on the detail screen; the Archivio surface
  /// uses the precise [restoreArchived] / [restoreRemoved] instead, which honour
  /// the status ≠ deletion distinction.
  Future<void> restore(String id) {
    return (update(possessions)..where((t) => t.id.equals(id))).write(
      PossessionsCompanion(
        status: const Value(PossessionStatus.active),
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ---- Archivio (M5.3): consult & restore inactive/removed things ----

  /// "Conservati": non-deleted possessions that are not active (archived, and —
  /// safely — any transferred/lost/disposed rows). Most recently updated first.
  Stream<List<Possession>> watchArchived() {
    return (select(possessions)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                t.status.equalsValue(PossessionStatus.active).not(),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  /// "Rimossi": soft-deleted possessions, whatever their lifecycle status. Most
  /// recently removed/updated first.
  Stream<List<Possession>> watchRemoved() {
    return (select(possessions)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  /// The place to keep after a restore: the current one only if it is still
  /// **reachable** — the place and its whole ancestor chain are active — so a
  /// thing never restores into a deleted/unreachable branch. Cycle-safe. Assumes
  /// it runs inside a transaction.
  Future<String?> _resolveRestoredPlace(String? placeId) async {
    return (await _placeReachable(placeId)) ? placeId : null;
  }

  /// True when [placeId] is null (no place — trivially fine) or it and every
  /// ancestor up to a root are active (non-deleted), with no cycle.
  Future<bool> _placeReachable(String? placeId) async {
    if (placeId == null) return true;
    final visited = <String>{};
    String? cur = placeId;
    while (cur != null) {
      if (!visited.add(cur)) return false; // corrupt cycle → unreachable
      final p = await (select(
        places,
      )..where((t) => t.id.equals(cur!))).getSingleOrNull();
      if (p == null || p.deletedAt != null) return false;
      cur = p.parentId;
    }
    return true;
  }

  /// Direct active possession count per place: `{placeId: count}` over
  /// non-deleted, active possessions that have a place. Lent things (placeId
  /// null) and archived/removed things are naturally excluded. One reactive
  /// query — the app derives subtree totals from this map + the place tree.
  Stream<Map<String, int>> watchDirectPlaceCounts() {
    final n = possessions.id.count();
    final q = selectOnly(possessions)
      ..addColumns([possessions.placeId, n])
      ..where(
        possessions.deletedAt.isNull() &
            possessions.status.equalsValue(PossessionStatus.active) &
            possessions.placeId.isNotNull(),
      )
      ..groupBy([possessions.placeId]);
    return q.watch().map(
      (rows) => {
        for (final r in rows) r.read(possessions.placeId)!: r.read(n) ?? 0,
      },
    );
  }

  /// Restore from "Conservati": lifecycle back to active, deletion untouched
  /// (stays null). A retained place is kept only if still valid, so the thing
  /// returns to Home and to its place — never to a deleted one. Everything else
  /// (photos, events, loan history, notes, acquisition) is preserved.
  Future<void> restoreArchived(String id) {
    return transaction(() async {
      final p = await (select(
        possessions,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (p == null) return;
      await (update(possessions)..where((t) => t.id.equals(id))).write(
        PossessionsCompanion(
          status: const Value(PossessionStatus.active),
          placeId: Value(await _resolveRestoredPlace(p.placeId)),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// Restore from "Rimossi": clear the tombstone but **preserve the lifecycle
  /// status** (status ≠ deletion) — an undeleted active thing returns to Home,
  /// an undeleted archived thing returns to Conservati. A retained place is kept
  /// only if still valid.
  Future<void> restoreRemoved(String id) {
    return transaction(() async {
      final p = await (select(
        possessions,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (p == null) return;
      await (update(possessions)..where((t) => t.id.equals(id))).write(
        PossessionsCompanion(
          deletedAt: const Value(null),
          placeId: Value(await _resolveRestoredPlace(p.placeId)),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  // ---- Photo gallery (M5.1) ----

  /// A possession's active gallery photos with their files, in stable order
  /// (`sortOrder`, then `createdAt`) — reactive. Cover-first presentation is a
  /// UI concern (see `orderCoverFirst`); this is the raw stored order.
  Stream<List<PhotoWithFile>> watchPhotos(String possessionId) {
    final query =
        select(possessionPhotos).join([
            innerJoin(files, files.id.equalsExp(possessionPhotos.fileId)),
          ])
          ..where(
            possessionPhotos.possessionId.equals(possessionId) &
                possessionPhotos.deletedAt.isNull(),
          )
          ..orderBy([
            OrderingTerm.asc(possessionPhotos.sortOrder),
            OrderingTerm.asc(possessionPhotos.createdAt),
          ]);
    return query.watch().map(
      (rows) => rows
          .map(
            (r) => PhotoWithFile(
              photo: r.readTable(possessionPhotos),
              file: r.readTable(files),
            ),
          )
          .toList(),
    );
  }

  /// The next free sort position for [possessionId] (max active + 1), so a newly
  /// added photo always lands last in stored order.
  Future<int> _nextSortOrder(String possessionId) async {
    final maxOrder = possessionPhotos.sortOrder.max();
    final q = selectOnly(possessionPhotos)
      ..addColumns([maxOrder])
      ..where(
        possessionPhotos.possessionId.equals(possessionId) &
            possessionPhotos.deletedAt.isNull(),
      );
    return ((await q.getSingle()).read(maxOrder) ?? -1) + 1;
  }

  /// Registers a file and appends it to the gallery, all in one transaction.
  /// The possession becomes the cover holder when [forceCover] is set or when it
  /// has no cover yet (so the very first photo is always the cover). Assumes it
  /// runs inside a [transaction].
  Future<PossessionPhoto> _insertPhoto(
    String possessionId, {
    required String relativePath,
    required String mimeType,
    required int byteSize,
    required bool forceCover,
  }) async {
    final now = DateTime.now();
    final fileId = _uuid.v4();
    await into(files).insert(
      FilesCompanion.insert(
        id: fileId,
        relativePath: relativePath,
        mimeType: mimeType,
        byteSize: byteSize,
        createdAt: now,
      ),
    );
    final row = await into(possessionPhotos).insertReturning(
      PossessionPhotosCompanion.insert(
        id: _uuid.v4(),
        possessionId: possessionId,
        fileId: fileId,
        sortOrder: Value(await _nextSortOrder(possessionId)),
        createdAt: now,
        updatedAt: now,
      ),
    );
    final current = await (select(
      possessions,
    )..where((t) => t.id.equals(possessionId))).getSingleOrNull();
    if (forceCover || current?.coverFileId == null) {
      await (update(
        possessions,
      )..where((t) => t.id.equals(possessionId))).write(
        PossessionsCompanion(coverFileId: Value(fileId), updatedAt: Value(now)),
      );
    }
    return row;
  }

  /// Adds one photo to a possession's gallery. Becomes the cover if [asCover] is
  /// set or the possession has no cover yet; otherwise the cover is untouched.
  Future<PossessionPhoto> addPhoto(
    String possessionId, {
    required String relativePath,
    required String mimeType,
    required int byteSize,
    bool asCover = false,
  }) {
    return transaction(
      () => _insertPhoto(
        possessionId,
        relativePath: relativePath,
        mimeType: mimeType,
        byteSize: byteSize,
        forceCover: asCover,
      ),
    );
  }

  /// Adds several photos (a gallery multi-select) in one transaction, preserving
  /// pick order. The first becomes the cover only if the possession had none.
  Future<void> addPhotos(
    String possessionId,
    List<({String relativePath, String mimeType, int byteSize})> photos,
  ) {
    return transaction(() async {
      for (final ph in photos) {
        await _insertPhoto(
          possessionId,
          relativePath: ph.relativePath,
          mimeType: ph.mimeType,
          byteSize: ph.byteSize,
          forceCover: false,
        );
      }
    });
  }

  /// Registers a stored file and makes it the possession's cover — the initial
  /// photo path used by the create flow. Adds a gallery row too, so the cover is
  /// always part of the gallery. The bytes are written to disk by the caller.
  Future<void> setCover(
    String possessionId, {
    required String relativePath,
    required String mimeType,
    required int byteSize,
  }) async {
    await addPhoto(
      possessionId,
      relativePath: relativePath,
      mimeType: mimeType,
      byteSize: byteSize,
      asCover: true,
    );
  }

  /// Promotes an existing gallery photo (identified by its [fileId]) to cover,
  /// transactionally. A no-op unless the file is an active photo of this
  /// possession, so a stale tap can never point the cover at something invalid.
  Future<void> setCoverPhoto(String possessionId, String fileId) {
    return transaction(() async {
      final owned =
          await (select(possessionPhotos)..where(
                (t) =>
                    t.possessionId.equals(possessionId) &
                    t.fileId.equals(fileId) &
                    t.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (owned == null) return;
      await (update(
        possessions,
      )..where((t) => t.id.equals(possessionId))).write(
        PossessionsCompanion(
          coverFileId: Value(fileId),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// Soft-removes a single gallery photo (recoverable via [restorePhoto]). If it
  /// was the cover, the cover deterministically moves to the first remaining
  /// active photo, or clears to null when it was the last one (empty-cover
  /// state). The physical file is intentionally left on disk so removal stays
  /// undoable; orphan cleanup is deferred.
  Future<void> removePhoto(String possessionId, String photoId) {
    return transaction(() async {
      final photo = await (select(
        possessionPhotos,
      )..where((t) => t.id.equals(photoId))).getSingleOrNull();
      if (photo == null) return;
      final now = DateTime.now();
      await (update(
        possessionPhotos,
      )..where((t) => t.id.equals(photoId))).write(
        PossessionPhotosCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      final poss = await (select(
        possessions,
      )..where((t) => t.id.equals(possessionId))).getSingleOrNull();
      if (poss?.coverFileId == photo.fileId) {
        final next =
            await (select(possessionPhotos)
                  ..where(
                    (t) =>
                        t.possessionId.equals(possessionId) &
                        t.deletedAt.isNull(),
                  )
                  ..orderBy([
                    (t) => OrderingTerm.asc(t.sortOrder),
                    (t) => OrderingTerm.asc(t.createdAt),
                    (t) => OrderingTerm.asc(t.id),
                  ])
                  ..limit(1))
                .getSingleOrNull();
        await (update(
          possessions,
        )..where((t) => t.id.equals(possessionId))).write(
          PossessionsCompanion(
            coverFileId: Value(next?.fileId),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  /// Undo for [removePhoto]: un-tombstones the row and, when [asCover] is set
  /// (i.e. it was the cover before removal), restores it as the cover — so undo
  /// returns to exactly the prior state.
  Future<void> restorePhoto(
    String possessionId,
    String photoId, {
    bool asCover = false,
  }) {
    return transaction(() async {
      final photo = await (select(
        possessionPhotos,
      )..where((t) => t.id.equals(photoId))).getSingleOrNull();
      if (photo == null) return;
      final now = DateTime.now();
      await (update(
        possessionPhotos,
      )..where((t) => t.id.equals(photoId))).write(
        PossessionPhotosCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
      if (asCover) {
        await (update(
          possessions,
        )..where((t) => t.id.equals(possessionId))).write(
          PossessionsCompanion(
            coverFileId: Value(photo.fileId),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }
}
