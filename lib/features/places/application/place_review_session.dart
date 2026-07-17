/// Pure, database-free state for one "Riordina questo luogo" walk.
///
/// The screen drives this off the live list of possessions in the place. The
/// **current** item is always the first live id that has not been *handled* yet
/// — never a numeric cursor into the list. That distinction is the whole point:
/// the list shrinks and reorders as things are moved, unassigned, archived or
/// restored elsewhere, so an index would silently skip the next item. Selecting
/// "the first still-unhandled id" is stable under any list change.
///
/// Nothing here is persisted. Leaving the review and reopening it starts a fresh
/// session (empty [handledIds]), which intentionally re-includes everything —
/// including things kept or (via undo) restored during the previous session.
class ReviewSession {
  ReviewSession([Iterable<String>? handled]) : _handled = {...?handled};

  final Set<String> _handled;

  /// The ids handled so far this session (read-only view).
  Set<String> get handledIds => Set.unmodifiable(_handled);

  bool isHandled(String id) => _handled.contains(id);

  /// Marks [id] handled. Idempotent. Called for "keep" and after any successful
  /// mutation — never on a cancelled picker or a failed write.
  void markHandled(String id) => _handled.add(id);

  /// The current item to show: the first id in [liveIds] not yet handled, or
  /// `null` when every live id has been handled (the completion condition).
  ///
  /// [liveIds] is the *current* order of the place's active possessions, so a
  /// removed current item simply falls out and the next unhandled id surfaces —
  /// no unrelated item is ever skipped.
  String? currentId(List<String> liveIds) {
    for (final id in liveIds) {
      if (!_handled.contains(id)) return id;
    }
    return null;
  }

  /// Completion: no live id remains unhandled. Note this does **not** mean the
  /// place is empty — items kept with "Tieni qui" are still here, just handled.
  bool isComplete(List<String> liveIds) => currentId(liveIds) == null;
}
