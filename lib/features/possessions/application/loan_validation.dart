// Pure loan-form rules, kept out of the widgets so they're trivially testable.

/// Strips the time so loan dates compare by calendar day (local).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The lent date may not fall after the expected return date. No return date is
/// always valid (an open-ended loan). Compared by day, not instant.
bool loanDatesValid(DateTime lentAt, DateTime? expectedReturn) {
  if (expectedReturn == null) return true;
  return !dateOnly(lentAt).isAfter(dateOnly(expectedReturn));
}

/// A borrower name is acceptable once trimmed to something non-empty.
bool borrowerNameValid(String name) => name.trim().isNotEmpty;

/// Whether the whole lend/edit form can be saved.
bool canSaveLoan({
  required String borrowerName,
  required DateTime lentAt,
  DateTime? expectedReturn,
}) {
  return borrowerNameValid(borrowerName) &&
      loanDatesValid(lentAt, expectedReturn);
}
