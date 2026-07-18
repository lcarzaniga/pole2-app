import '../../../core/database/app_database.dart';

/// A cycle-safe, in-memory view of the Place hierarchy, built once from the
/// reactive list of non-deleted places (+ an optional direct-count map). All
/// traversal is visited-protected, so even corrupt/cyclic legacy data can never
/// cause infinite recursion in the UI or in derived counts.
///
/// Deliberately application-level (no per-node queries): the whole tree comes
/// from one `watchAll()` stream and one grouped-count stream.
class PlaceTree {
  PlaceTree(List<Place> places, [Map<String, int> directCounts = const {}])
    : _byId = {for (final p in places) p.id: p},
      _directCounts = directCounts {
    for (final p in places) {
      // A parent that isn't in the (non-deleted) set is treated as absent → the
      // node surfaces as a root, never dangling.
      final parent = p.parentId != null && _byId.containsKey(p.parentId)
          ? p.parentId
          : null;
      (_childrenByParent[parent] ??= []).add(p);
    }
    for (final list in _childrenByParent.values) {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
  }

  final Map<String, Place> _byId;
  final Map<String, int> _directCounts;
  final Map<String?, List<Place>> _childrenByParent = {};

  /// Root places (no parent), alphabetical.
  List<Place> get roots => _childrenByParent[null] ?? const [];

  /// Every known (non-deleted) place, unordered.
  Iterable<Place> get allPlaces => _byId.values;

  Place? byId(String id) => _byId[id];

  /// A human path like `Casa › Camera › Armadio` for disambiguating duplicate
  /// names in filters, pickers and search results.
  String pathLabel(String id, {String separator = ' › '}) =>
      pathTo(id).map((p) => p.name).join(separator);

  /// Direct children of [id], alphabetical.
  List<Place> childrenOf(String id) => _childrenByParent[id] ?? const [];

  bool hasChildren(String id) => childrenOf(id).isNotEmpty;

  /// The path from the root down to (and including) [id]: `[root, …, id]`.
  /// Visited-protected against cycles. Empty when [id] is unknown.
  List<Place> pathTo(String id) {
    final chain = <Place>[];
    final visited = <String>{};
    String? cur = id;
    while (cur != null && _byId.containsKey(cur) && visited.add(cur)) {
      final p = _byId[cur]!;
      chain.add(p);
      cur = p.parentId;
    }
    return chain.reversed.toList();
  }

  /// Ancestors of [id] from root down to its parent (excludes [id] itself).
  List<Place> ancestorsOf(String id) {
    final path = pathTo(id);
    return path.isEmpty ? const [] : path.sublist(0, path.length - 1);
  }

  /// The set of place ids in [id]'s subtree, including [id]. Visited-protected.
  Set<String> subtreeIds(String id) {
    final out = <String>{};
    void walk(String node) {
      if (!out.add(node)) return; // already seen → stop (cycle-safe)
      for (final child in childrenOf(node)) {
        walk(child.id);
      }
    }

    if (_byId.containsKey(id)) walk(id);
    return out;
  }

  /// Direct possessions in exactly this place.
  int directCount(String id) => _directCounts[id] ?? 0;

  /// Possessions in this place or any descendant — never double-counts (subtree
  /// ids are a set).
  int subtreeCount(String id) {
    var total = 0;
    for (final node in subtreeIds(id)) {
      total += _directCounts[node] ?? 0;
    }
    return total;
  }
}
