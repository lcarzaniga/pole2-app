import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../possessions/application/event_providers.dart';
import '../domain/custody.dart';
import 'people_queries.dart';

// Hand-written providers (same reason as the possession/place providers: the
// Riverpod generator can't resolve Drift row types in return positions).

/// Every possession currently lent to someone (grouped, one query).
final activeLoansProvider = StreamProvider<List<LoanView>>(
  (ref) => watchActiveLoans(ref.watch(databaseProvider)),
);

/// Every possession currently given to someone — latest recipient only.
final currentGivenProvider = StreamProvider<List<GivenView>>(
  (ref) => watchCurrentGiven(ref.watch(databaseProvider)),
);

/// The newest-first custody history across everyone (returned / past transfer /
/// reacquired), built by the pure [buildCustodyHistory].
final custodyHistoryProvider = StreamProvider<List<HistoryEntry>>(
  (ref) =>
      watchCustodyEvents(ref.watch(databaseProvider)).map(buildCustodyHistory),
);

/// People (only [peopleProvider]'s non-deleted `PartyKind.person`) with their
/// current relationship counts, alphabetical — the People browser rows. Derived
/// from the three grouped streams, so counts never fan out per row.
final peopleWithCountsProvider = Provider<List<PersonSummary>>((ref) {
  final people = ref.watch(peopleProvider).value ?? const [];
  final loans = ref.watch(activeLoansProvider).value ?? const [];
  final given = ref.watch(currentGivenProvider).value ?? const [];

  final loanCounts = <String, int>{};
  for (final l in loans) {
    loanCounts[l.party.id] = (loanCounts[l.party.id] ?? 0) + 1;
  }
  final givenCounts = <String, int>{};
  for (final g in given) {
    givenCounts[g.party.id] = (givenCounts[g.party.id] ?? 0) + 1;
  }

  final list = [
    for (final p in people)
      PersonSummary(
        party: p,
        loanCount: loanCounts[p.id] ?? 0,
        givenCount: givenCounts[p.id] ?? 0,
      ),
  ];
  list.sort(
    (a, b) => a.party.name.toLowerCase().compareTo(b.party.name.toLowerCase()),
  );
  return list;
});

/// Grouped active loans keyed by possession id — the single source the Home list
/// reads once (instead of one `activeLoanProvider` stream per visible card) to
/// resolve each card's "Prestato a …" borrower and the person custody filter.
final homeLoansByPossessionProvider = Provider<Map<String, LoanView>>((ref) {
  final loans = ref.watch(activeLoansProvider).value ?? const [];
  return {for (final l in loans) l.possession.id: l};
});

/// The people who currently have at least one active loan, alphabetical — the
/// only people offered in the Home custody filter (others live in Persone).
final loanPeopleProvider = Provider<List<Party>>((ref) {
  final loans = ref.watch(activeLoansProvider).value ?? const [];
  final byId = <String, Party>{for (final l in loans) l.party.id: l.party};
  final list = byId.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
});

/// The possessions currently lent to one person.
final personLoansProvider = Provider.family<List<LoanView>, String>((ref, id) {
  final loans = ref.watch(activeLoansProvider).value ?? const [];
  return [
    for (final l in loans)
      if (l.party.id == id) l,
  ];
});

/// The possessions currently given to one person.
final personGivenProvider = Provider.family<List<GivenView>, String>((ref, id) {
  final given = ref.watch(currentGivenProvider).value ?? const [];
  return [
    for (final g in given)
      if (g.party.id == id) g,
  ];
});

/// One person's newest-first history (returned / past transfer / reacquired).
final personHistoryProvider = Provider.family<List<HistoryEntry>, String>((
  ref,
  id,
) {
  final history = ref.watch(custodyHistoryProvider).value ?? const [];
  return [
    for (final h in history)
      if (h.personId == id) h,
  ];
});
