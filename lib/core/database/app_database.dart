import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

import 'daos/events_dao.dart';
import 'daos/places_dao.dart';
import 'daos/possessions_dao.dart';
// Imported so the generated part (which references the enum types directly)
// has them in scope, even though this library uses them only via the tables.
import 'tables/enums.dart';
import 'tables/tables.dart';

part 'app_database.g.dart';

/// The application's local SQLite database — the single source of truth.
///
/// Schema v2 encodes the frozen domain (`docs/DOMAIN_MODEL.md`): eight tables,
/// UUID primary keys, portable ISO-UTC dates (see `build.yaml`). Only the
/// [PossessionsDao] is wired for CRUD so far; the other tables exist so the
/// schema is complete and future migrations are additive.
///
/// The connection comes from `drift_flutter`, which stores the file in the
/// right per-platform location and runs SQLite on a background isolate.
@DriftDatabase(
  tables: [
    Files,
    Possessions,
    Identifiers,
    Attributes,
    EvidenceItems,
    PossessionEvidence,
    Events,
    Parties,
    Places,
    PossessionPhotos,
  ],
  daos: [PossessionsDao, EventsDao, PlacesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: _databaseName));

  /// In-memory database for tests — never touches real device storage.
  AppDatabase.forTesting(super.executor);

  static const String _databaseName = 'project_kobe';
  static const Uuid _uuid = Uuid();

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // Each version bump adds its own explicit, tested step here so no user
      // ever loses data — the core promise of the product.
      if (from < 2) {
        // From an empty v1: create the full current schema in one go.
        await m.createAll();
      } else {
        // v2 → v3 (Milestone 9): purchase memory + deadlines. Additive
        // nullable columns on Events, so existing rows are untouched.
        if (from < 3) {
          await m.addColumn(events, events.purchasedOn);
          await m.addColumn(events, events.acquisitionType);
          await m.addColumn(events, events.remindLead);
        }
        // v3 → v4 (M2 Places): a flat Places table + a nullable
        // possessions.placeId. Existing possessions keep placeId = NULL
        // ("no place") — no data touched, no placeholder record created.
        if (from < 4) {
          await m.createTable(places);
          await m.addColumn(possessions, possessions.placeId);
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_possession_place '
            'ON possessions (place_id)',
          );
        }
        // v4 → v5 (M5.1 gallery): a one-to-many PossessionPhotos table.
        // The existing cover stays authoritative via possessions.cover_file_id;
        // we backfill one gallery row per existing cover so legacy covers
        // appear in the new gallery. No image bytes are copied — the row
        // reuses the same file_id. The guard makes the backfill idempotent.
        if (from < 5) {
          await m.createTable(possessionPhotos);
          final rows = await customSelect(
            'SELECT id AS pid, cover_file_id AS fid FROM possessions '
            'WHERE cover_file_id IS NOT NULL',
          ).get();
          final now = DateTime.now().toUtc();
          for (final r in rows) {
            final pid = r.read<String>('pid');
            final fid = r.read<String>('fid');
            final existing =
                await (select(possessionPhotos)..where(
                      (t) => t.possessionId.equals(pid) & t.fileId.equals(fid),
                    ))
                    .getSingleOrNull();
            if (existing != null) continue;
            await into(possessionPhotos).insert(
              PossessionPhotosCompanion.insert(
                id: _uuid.v4(),
                possessionId: pid,
                fileId: fid,
                sortOrder: const Value(0),
                createdAt: now,
                updatedAt: now,
              ),
            );
          }
        }
      }
    },
    beforeOpen: (details) async {
      // The relational model depends on foreign keys being enforced.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
