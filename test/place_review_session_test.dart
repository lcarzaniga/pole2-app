import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/features/places/application/place_review_session.dart';

void main() {
  group('ReviewSession', () {
    test('selects the first unhandled id', () {
      final s = ReviewSession();
      expect(s.currentId(['a', 'b', 'c']), 'a');
    });

    test('"keep" marks handled and advances to the next', () {
      final s = ReviewSession();
      final ids = ['a', 'b', 'c'];
      s.markHandled(s.currentId(ids)!); // handle 'a'
      expect(s.isHandled('a'), isTrue);
      expect(s.currentId(ids), 'b');
    });

    test('removing the current item does not skip the next one', () {
      final s = ReviewSession();
      // 'a' is current and gets handled (e.g. moved away), then leaves the list.
      s.markHandled('a');
      // The live list no longer contains 'a'.
      expect(s.currentId(['b', 'c']), 'b');
    });

    test('an externally removed *unhandled* current item advances safely', () {
      final s = ReviewSession();
      // Nothing handled yet, but 'a' disappears from the stream (archived
      // elsewhere). The next live unhandled id must surface, not a crash.
      expect(s.currentId(['b', 'c']), 'b');
    });

    test('handled ids stay handled when the list changes/reorders', () {
      final s = ReviewSession();
      s.markHandled('b');
      expect(s.currentId(['a', 'b', 'c']), 'a');
      // Reordered + one new item; 'b' is still handled and skipped.
      expect(s.currentId(['c', 'b', 'a', 'd']), 'c');
      s.markHandled('c');
      s.markHandled('a');
      expect(s.currentId(['c', 'b', 'a', 'd']), 'd');
    });

    test('a restored item stays handled for the rest of the session', () {
      final s = ReviewSession();
      s.markHandled('a'); // archived, then undone → 'a' reappears in the list
      // Even though 'a' is live again, it stays handled this session.
      expect(s.currentId(['a', 'b']), 'b');
    });

    test('reopening (a fresh session) re-includes a previously handled id', () {
      final first = ReviewSession();
      first.markHandled('a');
      expect(first.currentId(['a', 'b']), 'b');

      final reopened = ReviewSession();
      expect(reopened.currentId(['a', 'b']), 'a');
    });

    test('completion when every current item is handled', () {
      final s = ReviewSession();
      final ids = ['a', 'b'];
      s.markHandled('a');
      s.markHandled('b');
      expect(s.isComplete(ids), isTrue);
      expect(s.currentId(ids), isNull);
    });

    test('completion holds when kept items still remain in the place', () {
      final s = ReviewSession();
      // Both kept in place (no DB change), so they stay in the live list.
      final ids = ['a', 'b'];
      s.markHandled('a');
      s.markHandled('b');
      expect(s.isComplete(ids), isTrue); // handled, though still present
    });

    test('an empty place yields no current item and is complete', () {
      final s = ReviewSession();
      expect(s.currentId(const []), isNull);
      expect(s.isComplete(const []), isTrue);
    });

    test('markHandled is idempotent', () {
      final s = ReviewSession();
      s.markHandled('a');
      s.markHandled('a');
      expect(s.handledIds, {'a'});
    });

    test('seeds from an existing handled set', () {
      final s = ReviewSession({'a', 'b'});
      expect(s.currentId(['a', 'b', 'c']), 'c');
    });
  });
}
