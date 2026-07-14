/// Central registry of route paths and names.
///
/// Every navigation target is declared here as a constant so that features
/// never hardcode path strings. Paths are kept URL-addressable and
/// hierarchical from day one, which keeps deep-linking and state restoration
/// cheap to add later even though the app is offline.
abstract final class Routes {
  const Routes._();

  /// The home / landing screen.
  static const String homeName = 'home';
  static const String homePath = '/';

  /// Create a new possession.
  static const String newPossessionName = 'new-possession';
  static const String newPossessionPath = '/possession/new';

  /// A single possession's detail. Path param: `id`.
  static const String possessionName = 'possession';
  static const String possessionPath = '/possession/:id';

  /// Builds the concrete detail path for [id].
  static String possession(String id) => '/possession/$id';

  /// Purchase / acquisition editor. Path param: `id`.
  static const String acquisitionName = 'acquisition';
  static const String acquisitionPath = '/possession/:id/purchase';

  /// New deadline / reminder editor. Path param: `id`.
  static const String reminderName = 'reminder';
  static const String reminderPath = '/possession/:id/reminder';
}
