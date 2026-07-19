import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/features/backup/restore/restore_controller.dart';

void main() {
  test(
    'native copy error codes map to specific, non-corrupt restore codes',
    () {
      // Access / provider problems must never be reported as a corrupt backup.
      expect(restoreCopyErrorCode('open_denied'), 'accessDenied');
      expect(restoreCopyErrorCode('open_failed'), 'unreadableSource');
      expect(restoreCopyErrorCode('copy_io_failed'), 'copyFailed');
      expect(restoreCopyErrorCode('empty_document'), 'emptyBackup');
      expect(restoreCopyErrorCode('bad_dest'), 'stagingError');
    },
  );

  test(
    'an unknown native code falls back to a copy failure, not corruption',
    () {
      expect(restoreCopyErrorCode('something_new'), 'copyFailed');
      // None of the copy-stage codes collapse into the format/password codes.
      const formatCodes = {'passwordOrCorrupt', 'notABackup', 'newerFormat'};
      for (final c in [
        'open_denied',
        'open_failed',
        'copy_io_failed',
        'empty_document',
        'bad_dest',
        'whatever',
      ]) {
        expect(formatCodes.contains(restoreCopyErrorCode(c)), isFalse);
      }
    },
  );
}
