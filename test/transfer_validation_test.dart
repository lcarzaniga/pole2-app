import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/features/possessions/application/transfer_validation.dart';

void main() {
  final now = DateTime(2026, 7, 18);

  group('transferDateValid', () {
    test('today and past are allowed', () {
      expect(transferDateValid(DateTime(2026, 7, 18), now: now), isTrue);
      expect(transferDateValid(DateTime(2026, 1, 1), now: now), isTrue);
    });
    test('a future date is rejected', () {
      expect(transferDateValid(DateTime(2026, 7, 19), now: now), isFalse);
    });
  });

  group('canSaveTransfer', () {
    test('needs a recipient and a non-future date', () {
      expect(
        canSaveTransfer(
          recipientName: '',
          transferredAt: DateTime(2026, 7, 1),
          now: now,
        ),
        isFalse,
      );
      expect(
        canSaveTransfer(
          recipientName: 'Marco',
          transferredAt: DateTime(2026, 7, 19),
          now: now,
        ),
        isFalse,
      );
      expect(
        canSaveTransfer(
          recipientName: 'Marco',
          transferredAt: DateTime(2026, 7, 1),
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('reacquireDateValid', () {
    final transfer = DateTime(2026, 7, 10);
    test('on or after the transfer date, not in the future', () {
      expect(
        reacquireDateValid(DateTime(2026, 7, 10), transfer, now: now),
        isTrue,
      );
      expect(
        reacquireDateValid(DateTime(2026, 7, 15), transfer, now: now),
        isTrue,
      );
    });
    test('before the transfer date is rejected', () {
      expect(
        reacquireDateValid(DateTime(2026, 7, 9), transfer, now: now),
        isFalse,
      );
    });
    test('a future date is rejected', () {
      expect(
        reacquireDateValid(DateTime(2026, 7, 19), transfer, now: now),
        isFalse,
      );
    });
  });
}
