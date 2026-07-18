import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/features/possessions/application/loan_validation.dart';

void main() {
  test('no return date is always valid (open-ended loan)', () {
    expect(loanDatesValid(DateTime(2026, 7, 10), null), isTrue);
  });

  test('return on or after the lent day is valid', () {
    expect(
      loanDatesValid(DateTime(2026, 7, 10), DateTime(2026, 7, 10)),
      isTrue,
    );
    expect(
      loanDatesValid(DateTime(2026, 7, 10), DateTime(2026, 7, 20)),
      isTrue,
    );
  });

  test('return before the lent day is invalid', () {
    expect(
      loanDatesValid(DateTime(2026, 7, 10), DateTime(2026, 7, 9)),
      isFalse,
    );
  });

  test('the time of day is ignored — comparison is by calendar day', () {
    expect(
      loanDatesValid(
        DateTime(2026, 7, 10, 23, 59),
        DateTime(2026, 7, 10, 0, 1),
      ),
      isTrue,
    );
  });

  test('a borrower name must be non-blank once trimmed', () {
    expect(borrowerNameValid('  '), isFalse);
    expect(borrowerNameValid('Marco'), isTrue);
  });

  test('canSaveLoan needs a name and consistent dates', () {
    expect(
      canSaveLoan(
        borrowerName: '',
        lentAt: DateTime(2026, 7, 10),
        expectedReturn: null,
      ),
      isFalse,
    );
    expect(
      canSaveLoan(
        borrowerName: 'Marco',
        lentAt: DateTime(2026, 7, 10),
        expectedReturn: DateTime(2026, 7, 1),
      ),
      isFalse,
    );
    expect(
      canSaveLoan(
        borrowerName: 'Marco',
        lentAt: DateTime(2026, 7, 10),
        expectedReturn: DateTime(2026, 7, 20),
      ),
      isTrue,
    );
  });
}
