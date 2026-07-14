import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/events_dao.dart';
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
  ],
  daos: [PossessionsDao, EventsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: _databaseName));

  /// In-memory database for tests — never touches real device storage.
  AppDatabase.forTesting(super.executor);

  static const String _databaseName = 'project_kobe';

  @override
  int get schemaVersion => 3;

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
          }
        },
        beforeOpen: (details) async {
          // The relational model depends on foreign keys being enforced.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
