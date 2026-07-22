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

/// The database-phase outcome of the permanent-deletion engine.
enum PermanentDeleteDbOutcome {
  /// The selected possessions and their owned rows were deleted in one
  /// transaction (all-or-nothing).
  deleted,

  /// (Single only) the possession is not removed (`deletedAt == null`); nothing
  /// was changed.
  notRemoved,

  /// (Single only) no such possession — including the idempotent
  /// already-deleted second call.
  notFound,

  /// (Batch only) at least one selected id was missing, restored, or otherwise
  /// ineligible when re-checked inside the transaction: the whole batch was
  /// aborted and nothing was changed.
  staleSelection,
}

/// Result of the transactional database phase: the [outcome] plus, when
/// [PermanentDeleteDbOutcome.deleted], the **raw** relative paths of the media
/// files whose backing [Files] rows were removed — candidates for byte cleanup
/// by the caller (which normalizes and re-checks them before deleting bytes).
class PermanentDeleteDbResult {
  const PermanentDeleteDbResult(
    this.outcome, {
    this.removedFilePaths = const [],
  });

  final PermanentDeleteDbOutcome outcome;
  final List<String> removedFilePaths;
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

  // ---- Staged photo commit (M8.2D) ----

  /// Inserts one already-**promoted** photo using its **pre-generated** [fileId]
  /// and final [relativePath] (bytes already renamed into `photos/` by the
  /// import store). Cover logic mirrors [_insertPhoto]. Assumes a [transaction].
  Future<void> _insertStagedPhoto(
    String possessionId, {
    required String fileId,
    required String relativePath,
    required String mimeType,
    required int byteSize,
    required bool asCover,
  }) async {
    final now = DateTime.now();
    await into(files).insert(
      FilesCompanion.insert(
        id: fileId,
        relativePath: relativePath,
        mimeType: mimeType,
        byteSize: byteSize,
        createdAt: now,
      ),
    );
    await into(possessionPhotos).insert(
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
    if (asCover || current?.coverFileId == null) {
      await (update(
        possessions,
      )..where((t) => t.id.equals(possessionId))).write(
        PossessionsCompanion(coverFileId: Value(fileId), updatedAt: Value(now)),
      );
    }
  }

  /// Commits one or more promoted staged photos to an existing possession in a
  /// single transaction (M8.2D). Either all rows are created or none.
  Future<void> commitStagedPhotos(
    String possessionId,
    List<
      ({
        String fileId,
        String relativePath,
        String mimeType,
        int byteSize,
        bool asCover,
      })
    >
    photos,
  ) {
    return transaction(() async {
      for (final ph in photos) {
        await _insertStagedPhoto(
          possessionId,
          fileId: ph.fileId,
          relativePath: ph.relativePath,
          mimeType: ph.mimeType,
          byteSize: ph.byteSize,
          asCover: ph.asCover,
        );
      }
    });
  }

  /// Creates a possession and, atomically, its promoted cover photo (M8.2D
  /// photo-first creation). A failure leaves neither the possession nor the
  /// Files/photo rows — so a promoted file can never bind to a half-created row.
  Future<Possession> createPossessionWithCover({
    required String title,
    String? category,
    ({String fileId, String relativePath, String mimeType, int byteSize})?
    cover,
  }) {
    return transaction(() async {
      final now = DateTime.now();
      final created = await into(possessions).insertReturning(
        PossessionsCompanion.insert(
          id: _uuid.v4(),
          title: title,
          category: Value(category),
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (cover != null) {
        await _insertStagedPhoto(
          created.id,
          fileId: cover.fileId,
          relativePath: cover.relativePath,
          mimeType: cover.mimeType,
          byteSize: cover.byteSize,
          asCover: true,
        );
      }
      return created;
    });
  }

  // ---- Permanent deletion (M8.2A) ----

  /// Permanently deletes one **removed** possession and every row it exclusively
  /// owns, in a single transaction, returning the raw relative paths of the
  /// media files whose backing [Files] rows were removed (byte-cleanup
  /// candidates for the caller).
  ///
  /// Candidate media are collected **only** from this possession — its
  /// `coverFileId` and every `possession_photos.file_id` for it, **including
  /// soft-deleted rows**. Evidence files are never candidates here (their
  /// lifecycle is deferred), although the possession's `possession_evidence`
  /// **link** rows are deleted. A candidate [Files] row is removed only when,
  /// after this possession's rows are gone, nothing surviving references its id:
  /// no cover, no `possession_photos` row (active or soft-deleted), and no
  /// `evidence_items` row. This never performs global Files garbage collection.
  ///
  /// `deletedAt` is re-checked **inside** the transaction, and all candidate
  /// ids/paths are captured before any row is deleted, so a concurrent change
  /// or a mid-flight failure can never delete a still-referenced file.
  ///
  /// Delegates to the shared batch engine ([permanentlyDeleteMany]'s core) so
  /// there is exactly one deletion implementation; the single form only reports
  /// the finer [PermanentDeleteDbOutcome.notFound] / `.notRemoved` distinction.
  Future<PermanentDeleteDbResult> permanentlyDelete(String id) {
    return transaction(() async {
      final poss = await (select(
        possessions,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (poss == null) {
        return const PermanentDeleteDbResult(PermanentDeleteDbOutcome.notFound);
      }
      if (poss.deletedAt == null) {
        return const PermanentDeleteDbResult(
          PermanentDeleteDbOutcome.notRemoved,
        );
      }
      return _deleteBatch([id]);
    });
  }

  /// M8.2B — permanently delete **several** removed possessions in one atomic
  /// transaction (all selected or none), returning the raw relative paths of the
  /// media files whose backing [Files] rows were removed.
  ///
  /// Every selected id is re-checked **inside** the transaction: if any is
  /// missing, restored, or otherwise not removed (`deletedAt == null`), the whole
  /// batch aborts with [PermanentDeleteDbOutcome.staleSelection] and nothing is
  /// changed. Otherwise the same candidate/exclusivity rules as the single form
  /// apply, over the **union** of the selected possessions:
  /// candidates are the selected `coverFileId`s, every `possession_photos.file_id`
  /// of the selected (incl. soft-deleted), and document files whose EvidenceItem
  /// becomes unlinked+unreferenced (M9); shared documents are preserved; no
  /// global Files garbage collection; Parties and Places always survive.
  Future<PermanentDeleteDbResult> permanentlyDeleteMany(List<String> ids) {
    return transaction(() async {
      // Re-check eligibility of *every* selected id before touching anything.
      for (final id in ids) {
        final poss =
            await (select(possessions)
                  ..where((t) => t.id.equals(id))
                  ..limit(1))
                .getSingleOrNull();
        if (poss == null || poss.deletedAt == null) {
          return const PermanentDeleteDbResult(
            PermanentDeleteDbOutcome.staleSelection,
          );
        }
      }
      return _deleteBatch(ids);
    });
  }

  /// The single, shared deletion engine. **Assumes every id in [ids] is already
  /// verified removed** and runs inside an open [transaction]. Captures the union
  /// of candidate ids/paths before any deletion, deletes owned rows in FK-safe
  /// order, then removes each candidate [Files] row only when nothing surviving
  /// references its id.
  Future<PermanentDeleteDbResult> _deleteBatch(List<String> ids) async {
    if (ids.isEmpty) {
      return const PermanentDeleteDbResult(PermanentDeleteDbOutcome.deleted);
    }
    final adb = attachedDatabase;

    // 1) Union of candidate file ids from the selected possessions only, before
    // any deletion: their covers plus every gallery photo (incl. soft-deleted).
    final candidateIds = <String>{};
    final possRows = await (select(
      possessions,
    )..where((t) => t.id.isIn(ids))).get();
    for (final p in possRows) {
      if (p.coverFileId != null) candidateIds.add(p.coverFileId!);
    }
    final photoRows = await (select(
      possessionPhotos,
    )..where((t) => t.possessionId.isIn(ids))).get();
    for (final r in photoRows) {
      candidateIds.add(r.fileId);
    }
    // M9 — attachment files linked to the selected possessions become
    // candidates too, via BOTH the (dormant) possession→evidence link and the
    // record→evidence link (`EventEvidence`) on the possessions' events. The
    // EvidenceItem/File is only actually removed below when nothing surviving
    // still references it (shared attachments are preserved).
    final eventRows = await (select(
      adb.events,
    )..where((t) => t.possessionId.isIn(ids))).get();
    final eventIds = {for (final e in eventRows) e.id};
    final eventLinkRows = eventIds.isEmpty
        ? <EventEvidenceLink>[]
        : await (select(
            adb.eventEvidence,
          )..where((t) => t.eventId.isIn(eventIds))).get();
    final possLinkRows = await (select(
      adb.possessionEvidence,
    )..where((t) => t.possessionId.isIn(ids))).get();
    final linkedEvidenceIds = {
      for (final r in possLinkRows) r.evidenceId,
      for (final r in eventLinkRows) r.evidenceId,
    };
    if (linkedEvidenceIds.isNotEmpty) {
      final evRows = await (select(
        adb.evidenceItems,
      )..where((t) => t.id.isIn(linkedEvidenceIds))).get();
      for (final e in evRows) {
        if (e.fileId != null) candidateIds.add(e.fileId!);
      }
    }

    // Capture each candidate's raw relative path before its Files row goes.
    final pathById = <String, String>{};
    if (candidateIds.isNotEmpty) {
      final fileRows = await (select(
        files,
      )..where((t) => t.id.isIn(candidateIds))).get();
      for (final f in fileRows) {
        pathById[f.id] = f.relativePath;
      }
    }

    // 2) Delete owned rows in FK-safe order (children first, then the anchors).
    // EventEvidence links must go before their events (FK), and both before the
    // EvidenceItems they reference (handled in 2b).
    if (eventIds.isNotEmpty) {
      await (delete(
        adb.eventEvidence,
      )..where((t) => t.eventId.isIn(eventIds))).go();
    }
    await (delete(adb.events)..where((t) => t.possessionId.isIn(ids))).go();
    await (delete(
      adb.possessionEvidence,
    )..where((t) => t.possessionId.isIn(ids))).go();
    await (delete(
      adb.identifiers,
    )..where((t) => t.possessionId.isIn(ids))).go();
    await (delete(adb.attributes)..where((t) => t.possessionId.isIn(ids))).go();
    await (delete(
      possessionPhotos,
    )..where((t) => t.possessionId.isIn(ids))).go();
    await (delete(possessions)..where((t) => t.id.isIn(ids))).go();

    // 2b) Delete an EvidenceItem (attachment) only when nothing surviving still
    // references it — no surviving record link (`EventEvidence`), no dormant
    // possession link, and no `Events.evidenceId` — so an attachment shared with
    // another record or possession is preserved (M9).
    for (final evId in linkedEvidenceIds) {
      final stillOnRecord =
          await (select(adb.eventEvidence)
                ..where((t) => t.evidenceId.equals(evId))
                ..limit(1))
              .getSingleOrNull();
      if (stillOnRecord != null) continue;
      final stillLinked =
          await (select(adb.possessionEvidence)
                ..where((t) => t.evidenceId.equals(evId))
                ..limit(1))
              .getSingleOrNull();
      if (stillLinked != null) continue;
      final eventRef =
          await (select(adb.events)
                ..where((t) => t.evidenceId.equals(evId))
                ..limit(1))
              .getSingleOrNull();
      if (eventRef != null) continue;
      await (delete(adb.evidenceItems)..where((t) => t.id.equals(evId))).go();
    }

    // 3) Delete a candidate Files row only when nothing surviving references its
    // id — no cover, no photo (active/soft-deleted), no evidence.
    final removedPaths = <String>[];
    for (final fid in candidateIds) {
      final coverRef =
          await (select(possessions)
                ..where((t) => t.coverFileId.equals(fid))
                ..limit(1))
              .getSingleOrNull();
      if (coverRef != null) continue;
      final photoRef =
          await (select(possessionPhotos)
                ..where((t) => t.fileId.equals(fid))
                ..limit(1))
              .getSingleOrNull();
      if (photoRef != null) continue;
      final evidenceRef =
          await (select(adb.evidenceItems)
                ..where((t) => t.fileId.equals(fid))
                ..limit(1))
              .getSingleOrNull();
      if (evidenceRef != null) continue;

      await (delete(files)..where((t) => t.id.equals(fid))).go();
      final raw = pathById[fid];
      if (raw != null) removedPaths.add(raw);
    }

    return PermanentDeleteDbResult(
      PermanentDeleteDbOutcome.deleted,
      removedFilePaths: removedPaths,
    );
  }

  /// Raw `relativePath` of every surviving [Files] row. The caller normalizes
  /// these to guard byte deletion against a path still mapped by another row
  /// (the duplicate-path safety re-check, repeated after the commit).
  Future<List<String>> survivingFileRelativePaths() async {
    final rows = await select(files).get();
    return [for (final f in rows) f.relativePath];
  }
}
