import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:project_kobe/features/backup/restore/restore_marker.dart';
import 'package:project_kobe/features/backup/restore/restore_swapper.dart';
import 'package:sqlite3/sqlite3.dart';

const _tables = [
  'files',
  'possessions',
  'places',
  'identifiers',
  'attributes',
  'evidence_items',
  'possession_evidence',
  'events',
  'parties',
  'possession_photos',
];

void main() {
  late Directory docs;
  setUp(() => docs = Directory.systemTemp.createTempSync('pole2_swap'));
  tearDown(() => docs.deleteSync(recursive: true));

  String sha(File f) => crypto.sha256.convert(f.readAsBytesSync()).toString();

  File makeDb(String path, {int userVersion = 7, String tag = 'x'}) {
    final db = sqlite3.open(path);
    for (final t in _tables) {
      db.execute('CREATE TABLE $t (id TEXT)');
    }
    db.execute('CREATE TABLE _tag (v TEXT)');
    db.execute("INSERT INTO _tag VALUES ('$tag')");
    db.execute('PRAGMA user_version = $userVersion');
    db.close();
    return File(path);
  }

  File file(String rel, String content) {
    final f = File(p.join(docs.path, rel))..createSync(recursive: true);
    f.writeAsStringSync(content);
    return f;
  }

  /// Builds a scenario: live old DB + old photo, staged prepared new DB + new
  /// photo, and a marker at [phase]. Returns (oldSha, newSha, marker).
  ({String oldSha, String newSha, RestoreMarker marker}) scenario({
    required RestorePhase phase,
    int attemptCount = 0,
    int preparedUserVersion = 7,
    String? forcedPreparedSha,
    bool oldAlreadyMoved = false,
  }) {
    const op = 'op1';
    final oldDb = makeDb(p.join(docs.path, 'project_kobe.sqlite'), tag: 'OLD');
    final oldSha = sha(oldDb);
    file('photos/old.jpg', 'OLD-PHOTO');

    final staging = Directory(p.join(docs.path, 'restore_staging', op))
      ..createSync(recursive: true);
    final preparedDir = Directory(p.join(staging.path, 'prepared'))
      ..createSync(recursive: true);
    final newDb = makeDb(
      p.join(preparedDir.path, 'project_kobe.sqlite'),
      userVersion: preparedUserVersion,
      tag: 'NEW',
    );
    final newSha = sha(newDb);
    final newPhoto = File(
      p.join(preparedDir.path, 'managed_files', 'photos', 'new.jpg'),
    )..createSync(recursive: true);
    newPhoto.writeAsStringSync('NEW-PHOTO');

    if (oldAlreadyMoved) {
      // Simulate a completed emergency snapshot.
      final rec = Directory(p.join(docs.path, 'recovery', 'current', op, 'db'))
        ..createSync(recursive: true);
      oldDb.renameSync(p.join(rec.path, 'project_kobe.sqlite'));
      final recMedia = Directory(
        p.join(docs.path, 'recovery', 'current', op, 'media'),
      )..createSync(recursive: true);
      Directory(
        p.join(docs.path, 'photos'),
      ).renameSync(p.join(recMedia.path, 'photos'));
    }

    final marker = RestoreMarker(
      operationId: op,
      stagingRelPath: p.join('restore_staging', op),
      recoveryRelPath: p.join('recovery', 'current', op),
      createdAtUtc: '2026-07-18T00:00:00.000Z',
      phase: phase,
      attemptCount: attemptCount,
      preparedDbSha256: forcedPreparedSha ?? newSha,
      managedFiles: [
        RestoreManagedFile(
          relativePath: 'photos/new.jpg',
          sha256: crypto.sha256.convert('NEW-PHOTO'.codeUnits).toString(),
          byteSize: 9,
        ),
      ],
    );
    RestoreMarker.writeAtomic(
      File(p.join(docs.path, 'restore_pending.json')),
      marker,
    );
    return (oldSha: oldSha, newSha: newSha, marker: marker);
  }

  File live() => File(p.join(docs.path, 'project_kobe.sqlite'));
  File pending() => File(p.join(docs.path, 'restore_pending.json'));
  File unconfirmed() => File(p.join(docs.path, 'restore_unconfirmed.json'));
  File confirmed() => File(p.join(docs.path, 'restore_confirmed.json'));
  File receipt() => File(p.join(docs.path, 'restore_result.json'));
  Directory recoveryDb() =>
      Directory(p.join(docs.path, 'recovery', 'current', 'op1', 'db'));

  // ---- Install (pre-DB): now stops at "unconfirmed", never final success ----

  test('install records unconfirmed state (not final success), keeps recovery, '
      'writes NO success receipt yet', () {
    final s = scenario(phase: RestorePhase.prepared);
    final out = RestoreSwapper(docs).run();
    expect(out.kind, RestoreOutcomeKind.installedUnconfirmed);
    expect(sha(live()), s.newSha); // new DB live
    expect(File(p.join(docs.path, 'photos', 'new.jpg')).existsSync(), isTrue);
    expect(File(p.join(docs.path, 'photos', 'old.jpg')).existsSync(), isFalse);
    // Unconfirmed marker written; pending gone; recovery kept; NO receipt.
    expect(unconfirmed().existsSync(), isTrue);
    expect(pending().existsSync(), isFalse);
    expect(confirmed().existsSync(), isFalse);
    expect(
      File(p.join(recoveryDb().path, 'project_kobe.sqlite')).existsSync(),
      isTrue,
    );
    expect(receipt().existsSync(), isFalse);
  });

  test('resumes from newDataInstalling to an unconfirmed install', () {
    final s = scenario(
      phase: RestorePhase.newDataInstalling,
      oldAlreadyMoved: true,
    );
    final out = RestoreSwapper(docs).run();
    expect(out.kind, RestoreOutcomeKind.installedUnconfirmed);
    expect(sha(live()), s.newSha);
    expect(unconfirmed().existsSync(), isTrue);
    expect(receipt().existsSync(), isFalse);
  });

  // ---- Confirmation (normal app launch, real Drift query) ----

  test('a successful probe writes confirmed state + success receipt and drops '
      'unconfirmed', () async {
    scenario(phase: RestorePhase.prepared);
    final sw = RestoreSwapper(docs);
    sw.run(); // install → unconfirmed
    expect(receipt().existsSync(), isFalse); // absent before the query

    await sw.confirmInstalled(() async => true);
    expect(confirmed().existsSync(), isTrue);
    expect(unconfirmed().existsSync(), isFalse);
    expect(receipt().readAsStringSync().contains('success'), isTrue);
  });

  test('next startup with a confirmed marker removes recovery', () {
    scenario(phase: RestorePhase.prepared);
    final sw = RestoreSwapper(docs);
    sw.run(); // install → unconfirmed
    // Simulate the app confirming (as confirmInstalled would).
    RestoreConfirmed.writeAtomic(
      confirmed(),
      const RestoreConfirmed(
        operationId: 'op1',
        recoveryRelPath: 'recovery/current/op1',
        confirmedAtUtc: '2026-07-18T00:00:00.000Z',
      ),
    );
    unconfirmed().deleteSync();

    final out = RestoreSwapper(docs).run();
    expect(out.kind, RestoreOutcomeKind.none);
    expect(confirmed().existsSync(), isFalse);
    expect(Directory(p.join(docs.path, 'recovery')).existsSync(), isFalse);
  });

  // ---- Unconfirmed on next startup → roll back (the core new guarantee) ----

  test('next startup with an unconfirmed install rolls back to the old data '
      '(process killed before confirmation)', () {
    final s = scenario(phase: RestorePhase.prepared);
    RestoreSwapper(docs).run(); // install → unconfirmed, then "process dies"
    expect(unconfirmed().existsSync(), isTrue);

    final out = RestoreSwapper(docs).run(); // next startup
    expect(out.kind, RestoreOutcomeKind.rolledBack);
    expect(sha(live()), s.oldSha); // old data restored
    expect(File(p.join(docs.path, 'photos', 'old.jpg')).existsSync(), isTrue);
    expect(File(p.join(docs.path, 'photos', 'new.jpg')).existsSync(), isFalse);
    expect(unconfirmed().existsSync(), isFalse);
    expect(Directory(p.join(docs.path, 'recovery')).existsSync(), isFalse);
    expect(receipt().readAsStringSync().contains('rolledBack'), isTrue);
  });

  test('a failed Drift probe leaves recovery + unconfirmed intact; the next '
      'startup rolls back', () async {
    final s = scenario(phase: RestorePhase.prepared);
    final sw = RestoreSwapper(docs);
    sw.run(); // install → unconfirmed

    await sw.confirmInstalled(() async => false); // query failed
    expect(unconfirmed().existsSync(), isTrue); // still unconfirmed
    expect(confirmed().existsSync(), isFalse);
    expect(receipt().existsSync(), isFalse);
    expect(
      File(p.join(recoveryDb().path, 'project_kobe.sqlite')).existsSync(),
      isTrue,
    ); // recovery intact

    final out = RestoreSwapper(docs).run(); // next startup
    expect(out.kind, RestoreOutcomeKind.rolledBack);
    expect(sha(live()), s.oldSha);
  });

  test(
    'a probe that throws is treated as failure (leaves unconfirmed)',
    () async {
      scenario(phase: RestorePhase.prepared);
      final sw = RestoreSwapper(docs);
      sw.run();
      await sw.confirmInstalled(
        () async => throw StateError('drift open failed'),
      );
      expect(unconfirmed().existsSync(), isTrue);
      expect(receipt().existsSync(), isFalse);
    },
  );

  // ---- Rollback safety during install ----

  test(
    'prepared-hash mismatch rolls back WITHOUT touching untouched live data',
    () {
      final s = scenario(
        phase: RestorePhase.prepared,
        forcedPreparedSha: 'deadbeef', // won't match staged prepared db
      );
      final out = RestoreSwapper(docs).run();
      expect(out.kind, RestoreOutcomeKind.rolledBack);
      expect(sha(live()), s.oldSha);
      expect(File(p.join(docs.path, 'photos', 'old.jpg')).existsSync(), isTrue);
      expect(
        File(p.join(docs.path, 'photos', 'new.jpg')).existsSync(),
        isFalse,
      );
    },
  );

  test('installed-integrity failure rolls back to the old data', () {
    final s = scenario(phase: RestorePhase.prepared, preparedUserVersion: 6);
    final out = RestoreSwapper(docs).run();
    expect(out.kind, RestoreOutcomeKind.rolledBack);
    expect(sha(live()), s.oldSha);
    expect(File(p.join(docs.path, 'photos', 'old.jpg')).existsSync(), isTrue);
  });

  test('boot-loop guard forces rollback past the attempt limit', () {
    final s = scenario(
      phase: RestorePhase.prepared,
      attemptCount: kMaxRestoreAttempts,
    );
    final out = RestoreSwapper(docs).run();
    expect(out.kind, RestoreOutcomeKind.rolledBack);
    expect(sha(live()), s.oldSha);
  });

  // ---- Recovery cleanup authorization ----

  test('no pending marker alone never authorizes recovery deletion', () {
    // A recovery snapshot exists with no markers at all.
    final rec = Directory(p.join(docs.path, 'recovery', 'current', 'op9'))
      ..createSync(recursive: true);
    File(p.join(rec.path, 'db', 'project_kobe.sqlite'))
      ..createSync(recursive: true)
      ..writeAsStringSync('OLD');

    final out = RestoreSwapper(docs).run();
    expect(out.kind, RestoreOutcomeKind.none);
    expect(rec.existsSync(), isTrue); // preserved
  });

  test('unknown/orphan recovery is preserved (even via bootstrap sweep)', () {
    final rec = Directory(p.join(docs.path, 'recovery', 'orphan'))
      ..createSync(recursive: true);
    File(p.join(rec.path, 'something')).writeAsStringSync('x');

    final sw = RestoreSwapper(docs);
    expect(sw.run().kind, RestoreOutcomeKind.none);
    sw.sweepStaging();
    expect(rec.existsSync(), isTrue);
  });

  // ---- Corrupt marker handling ----

  test(
    'a corrupt pending marker with recovery present enters the fatal path and '
    'deletes nothing',
    () {
      final oldDb = makeDb(
        p.join(docs.path, 'project_kobe.sqlite'),
        tag: 'OLD',
      );
      final oldSha = sha(oldDb);
      Directory(
        p.join(docs.path, 'recovery', 'current', 'opX'),
      ).createSync(recursive: true);
      pending().writeAsStringSync('{ not json');

      final out = RestoreSwapper(docs).run();
      expect(out.kind, RestoreOutcomeKind.fatal);
      expect(pending().existsSync(), isTrue); // preserved, not guessed away
      expect(
        Directory(p.join(docs.path, 'recovery', 'current', 'opX')).existsSync(),
        isTrue,
      );
      expect(sha(live()), oldSha);
    },
  );

  test('a corrupt pending marker with no restore data is safely cleaned', () {
    final oldDb = makeDb(p.join(docs.path, 'project_kobe.sqlite'), tag: 'OLD');
    final oldSha = sha(oldDb);
    pending().writeAsStringSync('{ not json');
    final out = RestoreSwapper(docs).run();
    expect(out.kind, RestoreOutcomeKind.none);
    expect(pending().existsSync(), isFalse);
    expect(sha(live()), oldSha);
  });

  // ---- Receipt is consumed exactly once ----

  test('the restore receipt is consumed exactly once', () async {
    scenario(phase: RestorePhase.prepared);
    final sw = RestoreSwapper(docs);
    sw.run();
    await sw.confirmInstalled(() async => true);
    expect(sw.consumeReceipt(), 'success');
    expect(sw.consumeReceipt(), isNull); // never repeats
  });

  test('no marker → none', () {
    expect(RestoreSwapper(docs).run().kind, RestoreOutcomeKind.none);
  });
}
