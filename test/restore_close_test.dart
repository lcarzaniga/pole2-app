import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/features/backup/platform/backup_saver_stub.dart'
    as stub;
import 'package:project_kobe/features/backup/restore/restore_controller.dart';

void main() {
  // Records diag stages; asserts we never revert to an editable state and that
  // the marker is never touched by the close sequence itself.
  late List<String> stages;
  setUp(() => stages = []);
  void diag(String s) => stages.add(s);

  test('a missing marker prevents native close (no kill)', () async {
    var closed = false;
    var native = false;
    final result = await runRestoreClose(
      markerValid: () async => false,
      closeDb: () async => closed = true,
      nativeClose: () async => native = true,
      diag: diag,
    );
    expect(result, RestoreCloseResult.markerMissing);
    expect(closed, isFalse); // never even closes the DB
    expect(native, isFalse); // never asks to terminate
    expect(stages, isEmpty);
  });

  test('a clean DB close proceeds to native close', () async {
    var closed = false;
    var native = false;
    final result = await runRestoreClose(
      markerValid: () async => true,
      closeDb: () async => closed = true,
      nativeClose: () async => native = true,
      diag: diag,
    );
    expect(closed, isTrue);
    expect(native, isTrue);
    expect(result, RestoreCloseResult.manualFallback);
    expect(stages, [
      'close_started',
      'close_completed',
      'native_close_requested',
    ]);
  });

  test('a DB close that hangs times out and still closes natively', () async {
    var native = false;
    final never = Completer<void>(); // never completes
    final result = await runRestoreClose(
      markerValid: () async => true,
      closeDb: () => never.future,
      nativeClose: () async => native = true,
      diag: diag,
      timeout: const Duration(milliseconds: 50),
    );
    expect(native, isTrue);
    expect(result, RestoreCloseResult.manualFallback);
    expect(stages, [
      'close_started',
      'close_timeout',
      'native_close_requested',
    ]);
  });

  test('a DB close that throws still closes natively', () async {
    var native = false;
    final result = await runRestoreClose(
      markerValid: () async => true,
      closeDb: () async => throw StateError('drift still busy'),
      nativeClose: () async => native = true,
      diag: diag,
    );
    expect(native, isTrue);
    expect(result, RestoreCloseResult.manualFallback);
    expect(stages, contains('close_timeout'));
    expect(stages.last, 'native_close_requested');
  });

  test(
    'a native close failure yields the manual fallback, not a crash',
    () async {
      final result = await runRestoreClose(
        markerValid: () async => true,
        closeDb: () async {},
        nativeClose: () async => throw StateError('channel missing'),
        diag: diag,
      );
      expect(result, RestoreCloseResult.manualFallback);
    },
  );

  test(
    'the close sequence never mutates a marker (it only reads validity)',
    () async {
      var reads = 0;
      await runRestoreClose(
        markerValid: () async {
          reads++;
          return true;
        },
        closeDb: () async {},
        nativeClose: () async {},
        diag: diag,
      );
      // Exactly one read, no write hook exists in the contract.
      expect(reads, 1);
    },
  );

  test('the non-Android stub close is a safe no-op', () async {
    await expectLater(stub.closeForRestore(), completes);
  });
}
