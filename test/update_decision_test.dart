import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/features/update/model/update_release.dart';
import 'package:project_kobe/features/update/update_decision.dart';

/// A minimal valid release with the given flags.
UpdateRelease _release({
  bool backupRecommended = false,
  bool mandatory = false,
}) => UpdateRelease(
  versionName: '1.0.17',
  versionCode: 2022,
  apkUrl: 'https://pole2.app/a.apk',
  sha256: 'a' * 64,
  notes: const [],
  mandatory: mandatory,
  backupRecommended: backupRecommended,
);

void main() {
  group('decideUpdatePreflight (pure rule)', () {
    test('restore pending always blocks, whatever the flags', () {
      expect(
        decideUpdatePreflight(restorePending: true, release: _release()),
        UpdatePreflight.blockedByRestore,
      );
      expect(
        decideUpdatePreflight(
          restorePending: true,
          release: _release(backupRecommended: true, mandatory: true),
        ),
        UpdatePreflight.blockedByRestore,
      );
    });

    test('an ordinary patch downloads directly (one-tap)', () {
      expect(
        decideUpdatePreflight(restorePending: false, release: _release()),
        UpdatePreflight.downloadDirectly,
      );
    });

    test('backupRecommended → the three-way choice', () {
      expect(
        decideUpdatePreflight(
          restorePending: false,
          release: _release(backupRecommended: true),
        ),
        UpdatePreflight.backupChoice,
      );
    });

    test('mandatory → the three-way choice (recommend, never lock)', () {
      expect(
        decideUpdatePreflight(
          restorePending: false,
          release: _release(mandatory: true),
        ),
        UpdatePreflight.backupChoice,
      );
    });
  });

  group('runUpdatePreflight (injected effects, no UI)', () {
    // A recorder for the injected callbacks.
    late List<String> calls;
    Future<void> block() async => calls.add('blocked');

    setUp(() => calls = <String>[]);

    test(
      'restore pending → blocked, never proceeds, no choice shown',
      () async {
        var choiceShown = false;
        final proceed = await runUpdatePreflight(
          restorePending: true,
          release: _release(backupRecommended: true),
          onBlockedByRestore: block,
          askBackupChoice: () async {
            choiceShown = true;
            return BackupChoice.create;
          },
          runBackup: () async => true,
          askContinueWithout: () async => true,
        );
        expect(proceed, isFalse);
        expect(calls, ['blocked']);
        expect(choiceShown, isFalse);
      },
    );

    test('ordinary patch proceeds immediately, no prompts', () async {
      var choiceShown = false;
      final proceed = await runUpdatePreflight(
        restorePending: false,
        release: _release(),
        onBlockedByRestore: block,
        askBackupChoice: () async {
          choiceShown = true;
          return BackupChoice.cancel;
        },
        runBackup: () async => true,
        askContinueWithout: () async => true,
      );
      expect(proceed, isTrue);
      expect(choiceShown, isFalse);
      expect(calls, isEmpty);
    });

    test('a completed backup starts the download exactly once', () async {
      var backupRuns = 0;
      final proceed = await runUpdatePreflight(
        restorePending: false,
        release: _release(backupRecommended: true),
        onBlockedByRestore: block,
        askBackupChoice: () async => BackupChoice.create,
        runBackup: () async {
          backupRuns++;
          return true;
        },
        askContinueWithout: () async => true,
      );
      expect(proceed, isTrue);
      expect(backupRuns, 1);
    });

    test(
      'a cancelled picker returns to the choice and starts nothing',
      () async {
        var choiceCount = 0;
        final proceed = await runUpdatePreflight(
          restorePending: false,
          release: _release(backupRecommended: true),
          onBlockedByRestore: block,
          askBackupChoice: () async {
            choiceCount++;
            // First loop: try to create (picker cancels → false). Second loop:
            // give up with Annulla.
            return choiceCount == 1 ? BackupChoice.create : BackupChoice.cancel;
          },
          runBackup: () async => false, // cancelled/failed
          askContinueWithout: () async => true,
        );
        expect(proceed, isFalse);
        expect(choiceCount, 2, reason: 'looped back to the three-way choice');
      },
    );

    test('a failed backup never starts the update', () async {
      final proceed = await runUpdatePreflight(
        restorePending: false,
        release: _release(backupRecommended: true),
        onBlockedByRestore: block,
        askBackupChoice: () async => BackupChoice.cancel,
        runBackup: () async => false,
        askContinueWithout: () async => true,
      );
      expect(proceed, isFalse);
    });

    test('continue-without requires the second acknowledgment', () async {
      // Declining the ack loops back; only an explicit yes proceeds.
      var choiceCount = 0;
      var ackCount = 0;
      final proceed = await runUpdatePreflight(
        restorePending: false,
        release: _release(backupRecommended: true),
        onBlockedByRestore: block,
        askBackupChoice: () async {
          choiceCount++;
          return BackupChoice.without;
        },
        runBackup: () async => true,
        askContinueWithout: () async {
          ackCount++;
          return ackCount == 2; // first: decline (→loop), second: confirm
        },
      );
      expect(proceed, isTrue);
      expect(ackCount, 2);
      expect(choiceCount, 2);
    });

    test('Annulla ends the flow without starting anything', () async {
      var backupRuns = 0;
      final proceed = await runUpdatePreflight(
        restorePending: false,
        release: _release(mandatory: true),
        onBlockedByRestore: block,
        askBackupChoice: () async => BackupChoice.cancel,
        runBackup: () async {
          backupRuns++;
          return true;
        },
        askContinueWithout: () async => true,
      );
      expect(proceed, isFalse);
      expect(backupRuns, 0);
    });
  });
}
