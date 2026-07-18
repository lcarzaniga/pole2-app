import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/database/tables/enums.dart';
import 'package:sqlite3/sqlite3.dart';

// The exact schema Milestone 7/8 shipped (schema v2), captured from a live v2
// database. A v2 install with real data is rebuilt from this, then opened with
// the current app to prove the v2 → v3 migration preserves everything.
const _v2Schema = '''
CREATE TABLE "files" ("id" TEXT NOT NULL, "relative_path" TEXT NOT NULL, "mime_type" TEXT NOT NULL, "byte_size" INTEGER NOT NULL, "sha256" TEXT NULL, "created_at" TEXT NOT NULL, PRIMARY KEY ("id"));
CREATE TABLE "possessions" ("id" TEXT NOT NULL, "title" TEXT NOT NULL, "category" TEXT NULL, "notes" TEXT NULL, "status" TEXT NOT NULL DEFAULT 'active', "cover_file_id" TEXT NULL REFERENCES files (id), "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "deleted_at" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "parties" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "kind" TEXT NULL, "phone" TEXT NULL, "email" TEXT NULL, "notes" TEXT NULL, "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "deleted_at" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "evidence_items" ("id" TEXT NOT NULL, "kind" TEXT NOT NULL, "label" TEXT NULL, "file_id" TEXT NULL REFERENCES files (id), "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "deleted_at" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "identifiers" ("id" TEXT NOT NULL, "possession_id" TEXT NOT NULL REFERENCES possessions (id), "kind" TEXT NOT NULL, "label" TEXT NULL, "value" TEXT NOT NULL, "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "deleted_at" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "attributes" ("id" TEXT NOT NULL, "possession_id" TEXT NOT NULL REFERENCES possessions (id), "label" TEXT NOT NULL, "value" TEXT NOT NULL, "value_type" TEXT NULL, "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "deleted_at" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "events" ("id" TEXT NOT NULL, "possession_id" TEXT NOT NULL REFERENCES possessions (id), "kind" TEXT NOT NULL, "at" TEXT NOT NULL, "ends_at" TEXT NULL, "title" TEXT NULL, "notes" TEXT NULL, "amount_minor" INTEGER NULL, "currency" TEXT NULL, "party_id" TEXT NULL REFERENCES parties (id), "evidence_id" TEXT NULL REFERENCES evidence_items (id), "status" TEXT NULL, "created_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "deleted_at" TEXT NULL, PRIMARY KEY ("id"));
CREATE TABLE "possession_evidence" ("possession_id" TEXT NOT NULL REFERENCES possessions (id), "evidence_id" TEXT NOT NULL REFERENCES evidence_items (id), "added_at" TEXT NOT NULL, PRIMARY KEY ("possession_id", "evidence_id"));
''';

void main() {
  test('v2 data survives migration to v3', () async {
    final dir = Directory.systemTemp.createTempSync('pole2_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/app.db';

    // Build a real v2 database with data.
    final raw = sqlite3.open(path);
    raw.execute(_v2Schema);
    raw.execute('PRAGMA user_version = 2');
    final now = DateTime.now().toUtc().toIso8601String();
    raw.execute(
        "INSERT INTO possessions (id,title,status,created_at,updated_at) "
        "VALUES ('p1','Old Camera','active','$now','$now')");
    raw.execute(
        "INSERT INTO events (id,possession_id,kind,at,created_at,updated_at) "
        "VALUES ('e1','p1','acquired','$now','$now','$now')");
    raw.close();

    // Open with the current app — the v2 → v3 migration runs on open.
    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    // Existing rows survived untouched.
    final possession = await db.possessionsDao.watchById('p1').first;
    expect(possession, isNotNull);
    expect(possession!.title, 'Old Camera');

    final acquisition = await db.eventsDao.watchAcquisition('p1').first;
    expect(acquisition, isNotNull);
    expect(acquisition!.id, 'e1');
    // The new column exists and defaulted to null on the migrated row.
    expect(acquisition.acquisitionType, isNull);
    expect(acquisition.purchasedOn, isNull);

    // The new columns are fully usable after migration.
    await db.eventsDao
        .saveAcquisition(possessionId: 'p1', type: AcquisitionType.gift);
    final updated = await db.eventsDao.watchAcquisition('p1').first;
    expect(updated!.acquisitionType, AcquisitionType.gift);
  });

  test('v3 data survives migration to v4 (Places + nullable placeId)', () async {
    final dir = Directory.systemTemp.createTempSync('pole2_migration_v4');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/app.db';

    // Build a real v3 database: the v2 schema plus the three additive Event
    // columns the v2→v3 migration appended, then real data.
    final raw = sqlite3.open(path);
    raw.execute(_v2Schema);
    raw.execute('ALTER TABLE events ADD COLUMN purchased_on TEXT NULL');
    raw.execute('ALTER TABLE events ADD COLUMN acquisition_type TEXT NULL');
    raw.execute('ALTER TABLE events ADD COLUMN remind_lead TEXT NULL');
    raw.execute('PRAGMA user_version = 3');
    final now = DateTime.now().toUtc().toIso8601String();
    raw.execute(
        "INSERT INTO possessions (id,title,status,created_at,updated_at) "
        "VALUES ('p1','Old Camera','active','$now','$now')");
    raw.close();

    // Open with the current app — the v3 → v4 migration runs on open.
    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    // The existing possession survived untouched, with no place assigned.
    final possession = await db.possessionsDao.watchById('p1').first;
    expect(possession, isNotNull);
    expect(possession!.title, 'Old Camera');
    expect(possession.placeId, isNull); // "no place" — never a placeholder row

    // The new Places table is fully usable after migration.
    final placeId = await db.placesDao.create(name: 'Garage');
    final place = await db.placesDao.findById(placeId);
    expect(place, isNotNull);
    expect(place!.name, 'Garage');

    // The nullable placeId is settable and round-trips.
    await (db.update(db.possessions)..where((t) => t.id.equals('p1')))
        .write(PossessionsCompanion(placeId: Value(placeId)));
    final reloaded = await db.possessionsDao.watchById('p1').first;
    expect(reloaded!.placeId, placeId);
  });

  test('v4 data survives migration to v5, and the existing cover joins the '
      'gallery', () async {
    final dir = Directory.systemTemp.createTempSync('pole2_migration_v5');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/app.db';

    // Build a real v4 database: the v2 schema + the additive v3 Event columns +
    // the v4 Places table and possessions.place_id, then a possession that has
    // a cover photo (a File the possession points at) — exactly what a vc2010
    // user has on disk.
    final raw = sqlite3.open(path);
    raw.execute(_v2Schema);
    raw.execute('ALTER TABLE events ADD COLUMN purchased_on TEXT NULL');
    raw.execute('ALTER TABLE events ADD COLUMN acquisition_type TEXT NULL');
    raw.execute('ALTER TABLE events ADD COLUMN remind_lead TEXT NULL');
    raw.execute('CREATE TABLE "places" ("id" TEXT NOT NULL, "name" TEXT NOT '
        'NULL, "notes" TEXT NULL, "created_at" TEXT NOT NULL, "updated_at" TEXT '
        'NOT NULL, "deleted_at" TEXT NULL, PRIMARY KEY ("id"));');
    raw.execute('ALTER TABLE possessions ADD COLUMN place_id TEXT NULL '
        'REFERENCES places (id)');
    raw.execute('PRAGMA user_version = 4');
    final now = DateTime.now().toUtc().toIso8601String();
    raw.execute("INSERT INTO files (id,relative_path,mime_type,byte_size,"
        "created_at) VALUES ('f1','photos/old.jpg','image/jpeg',10,'$now')");
    raw.execute(
        "INSERT INTO possessions (id,title,status,cover_file_id,created_at,"
        "updated_at) VALUES ('p1','Old Camera','active','f1','$now','$now')");
    raw.close();

    // Open with the current app — the v4 → v5 migration runs on open.
    final db = AppDatabase.forTesting(NativeDatabase(File(path)));
    addTearDown(db.close);

    // The existing cover is preserved and now also appears in the gallery,
    // reusing the same file (no bytes copied).
    final possession = await db.possessionsDao.watchById('p1').first;
    expect(possession!.coverFileId, 'f1'); // still the cover

    final photos = await db.possessionsDao.watchPhotos('p1').first;
    expect(photos.length, 1);
    expect(photos.single.file.id, 'f1');
    expect(photos.single.file.relativePath, 'photos/old.jpg');

    // The gallery is fully usable after migration: adding another photo leaves
    // the migrated cover in place.
    await db.possessionsDao.addPhoto('p1',
        relativePath: 'photos/new.jpg', mimeType: 'image/jpeg', byteSize: 20);
    final after = await db.possessionsDao.watchPhotos('p1').first;
    expect(after.length, 2);
    expect((await db.possessionsDao.watchById('p1').first)!.coverFileId, 'f1');
  });
}
