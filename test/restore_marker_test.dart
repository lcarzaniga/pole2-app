import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/features/backup/restore/restore_marker.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('pole2_marker'));
  tearDown(() => dir.deleteSync(recursive: true));

  RestoreMarker sample() => RestoreMarker(
    operationId: 'op-1',
    stagingRelPath: 'restore_staging/op-1',
    recoveryRelPath: 'recovery/current/op-1',
    createdAtUtc: '2026-07-18T00:00:00.000Z',
    phase: RestorePhase.prepared,
    attemptCount: 0,
    preparedDbSha256: 'abc',
    managedFiles: const [
      RestoreManagedFile(
        relativePath: 'photos/a.jpg',
        sha256: 'h',
        byteSize: 3,
      ),
    ],
  );

  test('atomic write + read round-trips', () {
    final f = File('${dir.path}/restore_pending.json');
    RestoreMarker.writeAtomic(f, sample());
    final read = RestoreMarker.readOrNull(f)!;
    expect(read.operationId, 'op-1');
    expect(read.phase, RestorePhase.prepared);
    expect(read.managedFiles.single.relativePath, 'photos/a.jpg');
  });

  test('absent marker → null', () {
    expect(RestoreMarker.readOrNull(File('${dir.path}/nope.json')), isNull);
  });

  test('corrupt marker → null (treated as unresolvable)', () {
    final f = File('${dir.path}/restore_pending.json')
      ..writeAsStringSync('{ not json');
    expect(RestoreMarker.readOrNull(f), isNull);
  });

  test('the serialized marker never contains a password field', () {
    final f = File('${dir.path}/restore_pending.json');
    RestoreMarker.writeAtomic(f, sample());
    final raw = f.readAsStringSync().toLowerCase();
    expect(raw.contains('password'), isFalse);
    expect(raw.contains('passphrase'), isFalse);
  });

  test('copyWith advances phase and attempt without losing data', () {
    final m = sample().copyWith(
      phase: RestorePhase.oldDataMoved,
      attemptCount: 2,
    );
    expect(m.phase, RestorePhase.oldDataMoved);
    expect(m.attemptCount, 2);
    expect(m.preparedDbSha256, 'abc');
  });
}
