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
  File marker() => File(p.join(docs.path, 'restore_pending.json'));
  File receipt() => File(p.join(docs.path, 'restore_result.json'));

  test('happy path installs new data, keeps recovery, writes success', () {
    final s = scenario(phase: RestorePhase.prepared);
    final out = RestoreSwapper(docs).run();
    expect(out.kind, RestoreOutcomeKind.committed);
    expect(sha(live()), s.newSha); // new DB live
    expect(File(p.join(docs.path, 'photos', 'new.jpg')).existsSync(), isTrue);
    expect(File(p.join(docs.path, 'photos', 'old.jpg')).existsSync(), isFalse);
    // Old data preserved in recovery, marker gone, success receipt.
    expect(
      File(
        p.join(
          docs.path,
          'recovery',
          'current',
          'op1',
          'db',
          'project_kobe.sqlite',
        ),
      ).existsSync(),
      isTrue,
    );
    expect(marker().existsSync(), isFalse);
    expect(receipt().readAsStringSync().contains('success'), isTrue);
  });

  test('re-running after commit is a no-op', () {
    scenario(phase: RestorePhase.prepared);
    RestoreSwapper(docs).run();
    final liveAfter = sha(live());
    final out2 = RestoreSwapper(docs).run();
    expect(out2.kind, RestoreOutcomeKind.none);
    expect(sha(live()), liveAfter);
  });

  test('resumes from newDataInstalling to committed', () {
    final s = scenario(
      phase: RestorePhase.newDataInstalling,
      oldAlreadyMoved: true,
    );
    final out = RestoreSwapper(docs).run();
    expect(out.kind, RestoreOutcomeKind.committed);
    expect(sha(live()), s.newSha);
  });

  test(
    'prepared-hash mismatch rolls back WITHOUT touching untouched live data',
    () {
      final s = scenario(
        phase: RestorePhase.prepared,
        forcedPreparedSha: 'deadbeef', // won't match staged prepared db
      );
      final out = RestoreSwapper(docs).run();
      expect(out.kind, RestoreOutcomeKind.rolledBack);
      // Old data is exactly as it was — nothing lost.
      expect(sha(live()), s.oldSha);
      expect(File(p.join(docs.path, 'photos', 'old.jpg')).existsSync(), isTrue);
      expect(
        File(p.join(docs.path, 'photos', 'new.jpg')).existsSync(),
        isFalse,
      );
    },
  );

  test('installed-integrity failure rolls back to the old data', () {
    // Prepared DB is well-formed but wrong schema version → verify fails.
    final s = scenario(phase: RestorePhase.prepared, preparedUserVersion: 6);
    final out = RestoreSwapper(docs).run();
    expect(out.kind, RestoreOutcomeKind.rolledBack);
    expect(sha(live()), s.oldSha); // old restored
    expect(File(p.join(docs.path, 'photos', 'old.jpg')).existsSync(), isTrue);
  });

  test('boot-loop guard forces rollback past the attempt limit', () {
    final s = scenario(
      phase: RestorePhase.prepared,
      attemptCount: kMaxRestoreAttempts, // next attempt exceeds the limit
    );
    final out = RestoreSwapper(docs).run();
    expect(out.kind, RestoreOutcomeKind.rolledBack);
    expect(sha(live()), s.oldSha);
  });

  test('a corrupt marker is cleaned and live data left intact', () {
    final oldDb = makeDb(p.join(docs.path, 'project_kobe.sqlite'), tag: 'OLD');
    final oldSha = sha(oldDb);
    marker().writeAsStringSync('{ not json');
    final out = RestoreSwapper(docs).run();
    expect(out.kind, RestoreOutcomeKind.rolledBack);
    expect(marker().existsSync(), isFalse);
    expect(sha(live()), oldSha);
  });

  test('no marker → none', () {
    expect(RestoreSwapper(docs).run().kind, RestoreOutcomeKind.none);
  });
}
