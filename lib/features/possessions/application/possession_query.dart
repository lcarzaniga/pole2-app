import '../../../core/database/app_database.dart';

/// How the Home list is ordered. Newest-first is the calm default; by-name helps
/// when the collection grows.
enum PossessionSort { newest, name }

/// The mutually-exclusive custody scopes behind "Dove si trova".
enum _CustodyScope { all, noLocation, place, person }

/// The unified Home custody filter — answers "Dove si trova questa cosa?":
/// everything, things with no place *and no active loan*, one Place subtree, or
/// things currently lent to one person. Place and Person are never combined. A
/// small closed value type so it compares cleanly for the filter menu's
/// selected state.
class CustodyFilter {
  const CustodyFilter.all() : id = null, _scope = _CustodyScope.all;
  const CustodyFilter.noLocation()
    : id = null,
      _scope = _CustodyScope.noLocation;
  const CustodyFilter.place(String this.id) : _scope = _CustodyScope.place;
  const CustodyFilter.person(String this.id) : _scope = _CustodyScope.person;

  /// The place id (place scope) or borrower party id (person scope); else null.
  final String? id;
  final _CustodyScope _scope;

  bool get isAll => _scope == _CustodyScope.all;
  bool get isNoLocation => _scope == _CustodyScope.noLocation;
  bool get isPlace => _scope == _CustodyScope.place;
  bool get isPerson => _scope == _CustodyScope.person;

  /// [placeSubtreeIds] is the selected place plus its descendants (M5.4).
  /// [loanPersonByPossession] maps a possession id → its active borrower's party
  /// id (from the M7.1 grouped loan stream) — the single source of truth for
  /// "is this lent, and to whom".
  bool _matches(
    Possession p, {
    Set<String>? placeSubtreeIds,
    Map<String, String>? loanPersonByPossession,
  }) => switch (_scope) {
    _CustodyScope.all => true,
    // A lent possession has placeId == null but is NOT "senza luogo": it belongs
    // under its borrower. So exclude anything with an active loan here.
    _CustodyScope.noLocation =>
      p.placeId == null &&
          !(loanPersonByPossession?.containsKey(p.id) ?? false),
    _CustodyScope.place =>
      p.placeId != null &&
          (placeSubtreeIds?.contains(p.placeId) ?? p.placeId == id),
    _CustodyScope.person => loanPersonByPossession?[p.id] == id,
  };

  @override
  bool operator ==(Object other) =>
      other is CustodyFilter && other._scope == _scope && other.id == id;

  @override
  int get hashCode => Object.hash(_scope, id);
}

/// Falls back to [CustodyFilter.all] when [custody] is no longer a valid option
/// — a selected Place was deleted (its id left [validPlaceIds]) or the last loan
/// to a selected person ended (their id left [loanPersonIds]). Pure, so the
/// Home view can resolve the effective filter without mutating state in build.
CustodyFilter resolveCustody(
  CustodyFilter custody, {
  required Set<String> validPlaceIds,
  required Set<String> loanPersonIds,
}) {
  if (custody.isPlace && !validPlaceIds.contains(custody.id)) {
    return const CustodyFilter.all();
  }
  if (custody.isPerson && !loanPersonIds.contains(custody.id)) {
    return const CustodyFilter.all();
  }
  return custody;
}

/// The Home list's live query: free-text search, sort order, and custody filter.
class PossessionQuery {
  const PossessionQuery({
    this.search = '',
    this.sort = PossessionSort.newest,
    this.custody = const CustodyFilter.all(),
  });

  final String search;
  final PossessionSort sort;
  final CustodyFilter custody;

  /// True when the list is showing everything, newest-first — the calm default.
  bool get isDefault =>
      search.trim().isEmpty && sort == PossessionSort.newest && custody.isAll;

  PossessionQuery copyWith({
    String? search,
    PossessionSort? sort,
    CustodyFilter? custody,
  }) => PossessionQuery(
    search: search ?? this.search,
    sort: sort ?? this.sort,
    custody: custody ?? this.custody,
  );
}

/// Applies a [PossessionQuery] to an already-loaded list — pure, so it is unit
/// testable without any database or widgets. Search matches title or category
/// (case-insensitive); the custody filter narrows; then the chosen sort orders a
/// fresh copy (the input is never mutated).
///
/// [placeSubtreeIds] (when a specific place is selected) is that place plus its
/// descendants. [loanPersonByPossession] (possession id → borrower party id) is
/// the grouped active-loan relationship, used for the person filter and to keep
/// lent things out of "Senza luogo".
List<Possession> applyPossessionQuery(
  List<Possession> items,
  PossessionQuery query, {
  Set<String>? placeSubtreeIds,
  Map<String, String>? loanPersonByPossession,
}) {
  final needle = query.search.trim().toLowerCase();
  final filtered = items.where((p) {
    if (needle.isNotEmpty) {
      final inTitle = p.title.toLowerCase().contains(needle);
      final inCategory = p.category?.toLowerCase().contains(needle) ?? false;
      if (!inTitle && !inCategory) return false;
    }
    return query.custody._matches(
      p,
      placeSubtreeIds: placeSubtreeIds,
      loanPersonByPossession: loanPersonByPossession,
    );
  }).toList();

  switch (query.sort) {
    case PossessionSort.newest:
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case PossessionSort.name:
      filtered.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
  }
  return filtered;
}
