import '../../../core/database/app_database.dart';

/// How the Home list is ordered. Newest-first is the calm default; by-name helps
/// when the collection grows.
enum PossessionSort { newest, name }

/// Which places the Home list is narrowed to.
enum _PlaceScope { all, none, specific }

/// A place filter for the Home list: everything, only things with no place, or
/// one specific place. A small closed set kept as a value type so it compares
/// cleanly for the filter menu's selected state.
class PlaceFilter {
  const PlaceFilter.all() : id = null, _scope = _PlaceScope.all;
  const PlaceFilter.none() : id = null, _scope = _PlaceScope.none;
  const PlaceFilter.place(String this.id) : _scope = _PlaceScope.specific;

  /// The place id when this filter targets a specific place; otherwise null.
  final String? id;
  final _PlaceScope _scope;

  bool get isAll => _scope == _PlaceScope.all;

  bool get isSpecific => _scope == _PlaceScope.specific;

  /// [subtreeIds] is the selected place plus all its descendants (M5.4): a
  /// specific-place filter includes the whole subtree, so "Casa" shows things in
  /// Casa and every nested place. Falls back to an exact match if not supplied.
  bool _matches(Possession p, Set<String>? subtreeIds) => switch (_scope) {
    _PlaceScope.all => true,
    _PlaceScope.none => p.placeId == null,
    _PlaceScope.specific =>
      p.placeId != null && (subtreeIds?.contains(p.placeId) ?? p.placeId == id),
  };

  @override
  bool operator ==(Object other) =>
      other is PlaceFilter && other._scope == _scope && other.id == id;

  @override
  int get hashCode => Object.hash(_scope, id);
}

/// The Home list's live query: free-text search, sort order, and place filter.
class PossessionQuery {
  const PossessionQuery({
    this.search = '',
    this.sort = PossessionSort.newest,
    this.place = const PlaceFilter.all(),
  });

  final String search;
  final PossessionSort sort;
  final PlaceFilter place;

  /// True when the list is showing everything, newest-first — the calm default.
  bool get isDefault =>
      search.trim().isEmpty && sort == PossessionSort.newest && place.isAll;

  PossessionQuery copyWith({
    String? search,
    PossessionSort? sort,
    PlaceFilter? place,
  }) => PossessionQuery(
    search: search ?? this.search,
    sort: sort ?? this.sort,
    place: place ?? this.place,
  );
}

/// Applies a [PossessionQuery] to an already-loaded list — pure, so it is unit
/// testable without any database or widgets. Search matches title or category
/// (case-insensitive); the place filter narrows; then the chosen sort orders a
/// fresh copy (the input is never mutated).
/// [placeSubtreeIds] (when a specific place is selected) is that place plus its
/// descendants, so the hierarchical Home filter includes the whole subtree.
List<Possession> applyPossessionQuery(
  List<Possession> items,
  PossessionQuery query, {
  Set<String>? placeSubtreeIds,
}) {
  final needle = query.search.trim().toLowerCase();
  final filtered = items.where((p) {
    if (needle.isNotEmpty) {
      final inTitle = p.title.toLowerCase().contains(needle);
      final inCategory = p.category?.toLowerCase().contains(needle) ?? false;
      if (!inTitle && !inCategory) return false;
    }
    return query.place._matches(p, placeSubtreeIds);
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
