import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/database/tables/enums.dart';
import 'package:sqlite3/sqlite3.dart';

/// M9 — the additive v7→v8 migration: it must create the `event_evidence` link
/// table without touching any existing row, and leave the schema FK-clean.
///
/// A real "v7" file is synthesized by creating the current (v8) schema, seeding
/// data, then dropping `event_evidence` and stamping `user_version = 7` — exactly
/// the on-disk shape a pre-M9 install has. Opening it through [AppDatabase] runs
/// the real migration chain.
void main() {
  late Directory dir;
  late File dbFile;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('pole2_mig8_');
    dbFile = File('${dir.path}/project_kobe.sqlite');
  });
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<void> seedAndDowngradeToV7() async {
    // 1) Create the current schema + seed a possession, an event and an
    //    evidence item (so the migration runs against real, non-empty data).
    final db = AppDatabase(NativeDatabase(dbFile));
    final p = await db.possessionsDao.createPossession(title: 'Trapano');
    await db
        .into(db.events)
        .insert(
          EventsCompanion.insert(
            id: 'evt-1',
            possessionId: p.id,
            kind: EventKind.warranty,
            at: DateTime(2026, 7, 22),
            createdAt: DateTime(2026, 7, 22),
            updatedAt: DateTime(2026, 7, 22),
          ),
        );
    await db
        .into(db.evidenceItems)
        .insert(
          EvidenceItemsCompanion.insert(
            id: 'ev-1',
            kind: EvidenceKind.other,
            createdAt: DateTime(2026, 7, 22),
            updatedAt: DateTime(2026, 7, 22),
          ),
        );
    await db.close();

    // 2) Make it look like a genuine v7 file: drop the M9 table and stamp v7.
    final raw = sqlite3.open(dbFile.path);
    raw.execute('DROP TABLE event_evidence');
    raw.execute('PRAGMA user_version = 7');
    raw.close();
  }

  bool hasTable(String name) {
    final raw = sqlite3.open(dbFile.path, mode: OpenMode.readOnly);
    try {
      final rows = raw.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [name],
      );
      return rows.isNotEmpty;
    } finally {
      raw.close();
    }
  }

  test('v7→v8 adds event_evidence, preserves data, stays FK-clean', () async {
    await seedAndDowngradeToV7();
    expect(hasTable('event_evidence'), isFalse); // genuinely absent at v7

    // Open through the app → runs the real migration chain (7 → 8).
    final db = AppDatabase(NativeDatabase(dbFile));
    // Existing data is untouched.
    expect(await db.possessionsDao.watchAll().first, hasLength(1));
    final fk = await db.customSelect('PRAGMA foreign_key_check').get();
    expect(fk, isEmpty);

    // The new table exists and actually links a record to its evidence.
    await db.evidenceDao.relinkAttachment('evt-1', 'ev-1');
    final links = await db.customSelect('SELECT * FROM event_evidence').get();
    expect(links, hasLength(1));
    await db.close();

    // The file is now stamped v8, and the table survives the reopen.
    expect(hasTable('event_evidence'), isTrue);
    final raw = sqlite3.open(dbFile.path, mode: OpenMode.readOnly);
    final uv = raw.select('PRAGMA user_version').first.values.first as int;
    raw.close();
    expect(uv, 8);
  });

  test('v7→v8 migration is idempotent on an already-v8 database', () async {
    // A fresh DB is created at v8 directly; opening it again must not fail or
    // duplicate the table.
    final first = AppDatabase(NativeDatabase(dbFile));
    await first.possessionsDao.createPossession(title: 'X');
    await first.close();

    final second = AppDatabase(NativeDatabase(dbFile));
    expect(await second.possessionsDao.watchAll().first, hasLength(1));
    final fk = await second.customSelect('PRAGMA foreign_key_check').get();
    expect(fk, isEmpty);
    await second.close();
    expect(hasTable('event_evidence'), isTrue);
  });
}
