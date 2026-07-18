/// Presentation ordering for a possession's photo gallery: the cover first,
/// then everything else in its existing stable order.
///
/// Pure and generic over the item type so it's trivially unit-testable without
/// Drift rows: the caller supplies how to read each item's file id and the
/// current cover file id. [items] is assumed already in stable stored order.
List<T> orderCoverFirst<T>(
  List<T> items, {
  required String Function(T) fileId,
  required String? coverFileId,
}) {
  if (coverFileId == null) return List<T>.of(items);
  final cover = <T>[];
  final rest = <T>[];
  for (final item in items) {
    if (fileId(item) == coverFileId) {
      cover.add(item);
    } else {
      rest.add(item);
    }
  }
  return [...cover, ...rest];
}
