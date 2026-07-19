import '../../../core/database/app_database.dart';
import '../../../core/database/tables/enums.dart';

/// A person plus their **current** relationship counts, for the People browser.
class PersonSummary {
  const PersonSummary({
    required this.party,
    required this.loanCount,
    required this.givenCount,
  });

  final Party party;
  final int loanCount; // possessions currently lent to this person
  final int givenCount; // possessions currently given (transferred) to them
}

/// One possession currently lent to a person (a pending, non-deleted `lent`).
class LoanView {
  const LoanView({
    required this.possession,
    required this.party,
    required this.loan,
  });

  final Possession possession;
  final Party party;
  final PossessionEvent loan;
}

/// One possession currently given to a person — its **latest** valid transfer.
class GivenView {
  const GivenView({
    required this.possession,
    required this.party,
    required this.transfer,
  });

  final Possession possession;
  final Party party;
  final PossessionEvent transfer;
}

/// A raw custody event (returned / transfer / reacquired) joined with just
/// enough of its possession to build history, plus the event's party (if any).
class CustodyEventRaw {
  const CustodyEventRaw({
    required this.event,
    required this.possessionTitle,
    required this.possessionStatus,
    required this.possessionDeleted,
    this.party,
  });

  final PossessionEvent event;
  final String possessionTitle;
  final PossessionStatus possessionStatus;
  final bool possessionDeleted;
  final Party? party;
}

enum HistoryKind { returnedLoan, pastTransfer, reacquired }

/// A completed / past relationship between a person and a possession.
class HistoryEntry {
  const HistoryEntry({
    required this.personId,
    required this.personName,
    required this.possessionId,
    required this.possessionTitle,
    required this.possessionDeleted,
    required this.kind,
    required this.at,
  });

  final String personId;
  final String personName;
  final String possessionId;
  final String possessionTitle;
  final bool possessionDeleted;
  final HistoryKind kind;
  final DateTime at;
}

/// Builds the newest-first custody **history** across all people from the raw
/// returned/transfer/reacquired events. Pure, so it is unit-testable without a
/// database. Rules:
/// - `returned` → the borrower it names;
/// - `transfer` → the recipient it names, **unless** it is the *current* transfer
///   (its possession is still `transferred`, not deleted, and it is the latest
///   transfer for that possession) — current ones live in "Dati", not history;
/// - `reacquired` (which carries no party) → resolved to the recipient of the
///   latest transfer on the same possession at or before the reacquire date.
/// Deleted people are still name-resolved (their name is joined on the event).
List<HistoryEntry> buildCustodyHistory(List<CustodyEventRaw> rows) {
  final transfersByPossession = <String, List<CustodyEventRaw>>{};
  final partiesById = <String, Party>{};
  for (final r in rows) {
    final p = r.party;
    if (p != null) partiesById[p.id] = p;
    if (r.event.kind == EventKind.transfer) {
      (transfersByPossession[r.event.possessionId] ??= []).add(r);
    }
  }
  int byTime(CustodyEventRaw a, CustodyEventRaw b) {
    final c = a.event.at.compareTo(b.event.at);
    return c != 0 ? c : a.event.createdAt.compareTo(b.event.createdAt);
  }

  for (final list in transfersByPossession.values) {
    list.sort(byTime);
  }

  String? latestTransferId(String possessionId) =>
      transfersByPossession[possessionId]?.last.event.id;

  String name(String? id) => id == null ? '' : (partiesById[id]?.name ?? '');

  final out = <HistoryEntry>[];
  for (final r in rows) {
    final e = r.event;
    switch (e.kind) {
      case EventKind.returned:
        final pid = e.partyId;
        if (pid == null) break;
        out.add(
          HistoryEntry(
            personId: pid,
            personName: name(pid),
            possessionId: e.possessionId,
            possessionTitle: r.possessionTitle,
            possessionDeleted: r.possessionDeleted,
            kind: HistoryKind.returnedLoan,
            at: e.at,
          ),
        );
      case EventKind.transfer:
        final pid = e.partyId;
        if (pid == null) break;
        final isCurrent =
            e.id == latestTransferId(e.possessionId) &&
            r.possessionStatus == PossessionStatus.transferred &&
            !r.possessionDeleted;
        if (isCurrent) break; // shown under "Dati", never duplicated in history
        out.add(
          HistoryEntry(
            personId: pid,
            personName: name(pid),
            possessionId: e.possessionId,
            possessionTitle: r.possessionTitle,
            possessionDeleted: r.possessionDeleted,
            kind: HistoryKind.pastTransfer,
            at: e.at,
          ),
        );
      case EventKind.reacquired:
        // Resolve the person via the latest transfer at/before the reacquire.
        final transfers = transfersByPossession[e.possessionId] ?? const [];
        String? pid;
        for (final t in transfers) {
          if (!t.event.at.isAfter(e.at)) pid = t.event.partyId;
        }
        if (pid == null) break;
        out.add(
          HistoryEntry(
            personId: pid,
            personName: name(pid),
            possessionId: e.possessionId,
            possessionTitle: r.possessionTitle,
            possessionDeleted: r.possessionDeleted,
            kind: HistoryKind.reacquired,
            at: e.at,
          ),
        );
      default:
        break;
    }
  }

  out.sort((a, b) {
    final c = b.at.compareTo(a.at); // newest first
    return c != 0
        ? c
        : a.possessionTitle.toLowerCase().compareTo(
            b.possessionTitle.toLowerCase(),
          );
  });
  return out;
}
