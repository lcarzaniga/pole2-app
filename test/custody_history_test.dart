import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/database/tables/enums.dart';
import 'package:project_kobe/features/people/domain/custody.dart';
import 'package:project_kobe/features/people/presentation/people_browser_screen.dart';
import 'package:project_kobe/l10n/app_localizations_it.dart';

PossessionEvent _evt({
  required String id,
  required String poss,
  required EventKind kind,
  required DateTime at,
  String? partyId,
  DateTime? createdAt,
}) => PossessionEvent(
  id: id,
  possessionId: poss,
  kind: kind,
  at: at,
  partyId: partyId,
  createdAt: createdAt ?? at,
  updatedAt: createdAt ?? at,
);

Party _person(String id, String name) => Party(
  id: id,
  name: name,
  kind: PartyKind.person,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

CustodyEventRaw _raw(
  PossessionEvent e, {
  String title = 'Oggetto',
  PossessionStatus status = PossessionStatus.active,
  bool deleted = false,
  Party? party,
}) => CustodyEventRaw(
  event: e,
  possessionTitle: title,
  possessionStatus: status,
  possessionDeleted: deleted,
  party: party,
);

void main() {
  final d = DateTime(2026, 7, 1);

  test('a returned loan becomes a history entry for its borrower', () {
    final a = _person('A', 'Carlo');
    final h = buildCustodyHistory([
      _raw(
        _evt(id: 'e', poss: 'p', kind: EventKind.returned, at: d, partyId: 'A'),
        party: a,
      ),
    ]);
    expect(h, hasLength(1));
    expect(h.single.kind, HistoryKind.returnedLoan);
    expect(h.single.personId, 'A');
    expect(h.single.personName, 'Carlo');
  });

  test('the current transfer is NOT in history (it lives in "Dati")', () {
    final a = _person('A', 'Carlo');
    final h = buildCustodyHistory([
      _raw(
        _evt(id: 't', poss: 'p', kind: EventKind.transfer, at: d, partyId: 'A'),
        status: PossessionStatus.transferred,
        party: a,
      ),
    ]);
    expect(h, isEmpty);
  });

  test('a transfer on a removed possession falls into history', () {
    final a = _person('A', 'Carlo');
    final h = buildCustodyHistory([
      _raw(
        _evt(id: 't', poss: 'p', kind: EventKind.transfer, at: d, partyId: 'A'),
        status: PossessionStatus.transferred,
        deleted: true, // removed → no longer a current gift
        party: a,
      ),
    ]);
    expect(h.single.kind, HistoryKind.pastTransfer);
    expect(h.single.personId, 'A');
  });

  test('reacquired (no partyId) resolves to the latest prior transfer', () {
    final a = _person('A', 'Carlo');
    final h = buildCustodyHistory([
      _raw(
        _evt(id: 't', poss: 'p', kind: EventKind.transfer, at: d, partyId: 'A'),
        // possession is active again after reacquire → transfer is history
        party: a,
      ),
      _raw(
        _evt(
          id: 'r',
          poss: 'p',
          kind: EventKind.reacquired,
          at: d.add(const Duration(days: 5)),
        ),
      ),
    ]);
    final reac = h.firstWhere((e) => e.kind == HistoryKind.reacquired);
    expect(reac.personId, 'A');
    expect(reac.personName, 'Carlo');
  });

  test(
    'give → reacquire → give to another: current is only the latest recipient',
    () {
      final a = _person('A', 'Carlo');
      final b = _person('B', 'Marco');
      final rows = [
        _raw(
          _evt(
            id: 't1',
            poss: 'p',
            kind: EventKind.transfer,
            at: d,
            partyId: 'A',
          ),
          status: PossessionStatus.transferred,
          party: a,
        ),
        _raw(
          _evt(
            id: 'r',
            poss: 'p',
            kind: EventKind.reacquired,
            at: d.add(const Duration(days: 2)),
          ),
        ),
        _raw(
          _evt(
            id: 't2',
            poss: 'p',
            kind: EventKind.transfer,
            at: d.add(const Duration(days: 4)),
            partyId: 'B',
          ),
          status: PossessionStatus.transferred, // currently given to B
          party: b,
        ),
      ];
      final h = buildCustodyHistory(rows);
      // B's transfer is current → excluded. A appears via the past transfer and
      // the reacquire; B never appears in history.
      expect(h.where((e) => e.personId == 'B'), isEmpty);
      final aKinds = h
          .where((e) => e.personId == 'A')
          .map((e) => e.kind)
          .toSet();
      expect(aKinds, {HistoryKind.pastTransfer, HistoryKind.reacquired});
    },
  );

  test('history is newest-first', () {
    final a = _person('A', 'Carlo');
    final h = buildCustodyHistory([
      _raw(
        _evt(
          id: 'old',
          poss: 'p',
          kind: EventKind.returned,
          at: d,
          partyId: 'A',
        ),
        party: a,
      ),
      _raw(
        _evt(
          id: 'new',
          poss: 'q',
          kind: EventKind.returned,
          at: d.add(const Duration(days: 10)),
          partyId: 'A',
        ),
        party: a,
      ),
    ]);
    expect(h.first.possessionId, 'q'); // newest first
    expect(h.last.possessionId, 'p');
  });

  group('relationship summary copy', () {
    final l10n = AppLocalizationsIt();

    test('omits zero counts and combines with a middle dot', () {
      expect(relationshipSummary(l10n, 0, 0), isNull);
      expect(relationshipSummary(l10n, 1, 0), '1 in prestito');
      expect(relationshipSummary(l10n, 2, 0), '2 in prestito');
      expect(relationshipSummary(l10n, 0, 1), '1 dato');
      expect(relationshipSummary(l10n, 0, 3), '3 dati');
      expect(relationshipSummary(l10n, 2, 1), '2 in prestito · 1 dato');
    });
  });
}
