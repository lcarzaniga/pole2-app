import 'loan_validation.dart' show dateOnly;

// Pure rules for giving / reacquiring, kept out of the widgets so they're
// trivially testable (see also loan_validation.dart for [dateOnly]).

/// A transfer happened in the past or today — never in the future. Compared by
/// calendar day (local), like the loan dates.
bool transferDateValid(DateTime at, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  return !dateOnly(at).isAfter(today);
}

/// The whole give form can be saved: a real recipient and a non-future date.
bool canSaveTransfer({
  required String recipientName,
  required DateTime transferredAt,
  DateTime? now,
}) {
  return recipientName.trim().isNotEmpty &&
      transferDateValid(transferredAt, now: now);
}

/// Reacquisition can't predate the transfer and can't be in the future.
bool reacquireDateValid(
  DateTime reacquiredAt,
  DateTime transferredAt, {
  DateTime? now,
}) {
  final day = dateOnly(reacquiredAt);
  if (day.isBefore(dateOnly(transferredAt))) return false;
  return !day.isAfter(dateOnly(now ?? DateTime.now()));
}
