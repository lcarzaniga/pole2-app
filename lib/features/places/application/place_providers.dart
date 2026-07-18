import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/places_dao.dart';
import '../../../core/providers/database_provider.dart';
import '../../possessions/application/possession_providers.dart';
import 'place_tree.dart';

// Hand-written (not code-generated) for the same reason as the possession
// providers: riverpod_generator can't resolve Drift's generated row types.

/// The places data access, resolved from the app database.
final placesDaoProvider = Provider<PlacesDao>(
  (ref) => ref.watch(databaseProvider).placesDao,
);

/// Reactive list of all (non-deleted) places, alphabetical — powers the picker.
final placeListProvider = StreamProvider<List<Place>>(
  (ref) => ref.watch(placesDaoProvider).watchAll(),
);

/// Reactive single place by id — resolves a possession's assigned place. A
/// deleted or missing place yields null, which the UI shows as "no place".
final placeByIdProvider = StreamProvider.family<Place?, String>(
  (ref, id) => ref.watch(placesDaoProvider).watchById(id),
);

/// Reactive active possessions kept **directly** in a place — powers the
/// place-contents "here directly" section and the direct-only review. Reuses
/// [possessionsDaoProvider], so no new data path is introduced.
final possessionsByPlaceProvider =
    StreamProvider.family<List<Possession>, String>(
      (ref, placeId) => ref.watch(possessionsDaoProvider).watchByPlace(placeId),
    );

/// Reactive non-deleted root places — the root browser.
final rootPlacesProvider = StreamProvider<List<Place>>(
  (ref) => ref.watch(placesDaoProvider).watchRoots(),
);

/// Reactive `{placeId: directCount}` for active, non-deleted, placed
/// possessions — the raw material for subtree totals.
final directPlaceCountsProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(possessionsDaoProvider).watchDirectPlaceCounts(),
);

/// The whole Place hierarchy as a cycle-safe [PlaceTree], rebuilt reactively
/// from the place list and the direct-count map. One structure powers roots,
/// children, breadcrumbs, subtree counts and the subtree Home filter.
final placeTreeProvider = Provider<PlaceTree>((ref) {
  final places = ref.watch(placeListProvider).value ?? const [];
  final counts = ref.watch(directPlaceCountsProvider).value ?? const {};
  return PlaceTree(places, counts);
});
