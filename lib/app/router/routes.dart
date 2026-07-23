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

  /// Archivio: consult & restore kept-aside and removed things.
  static const String archiveName = 'archive';
  static const String archivePath = '/archive';

  /// Luoghi: the root browser for the place hierarchy.
  static const String placesName = 'places';
  static const String placesPath = '/places';

  /// Persone: the browser of people you lend/give things to.
  static const String peopleName = 'people';
  static const String peoplePath = '/people';

  /// A single person's detail (loans, gifts, history). Path param: `id`.
  static const String personName = 'person';
  static const String personPath = '/person/:id';

  /// Backup e ripristino.
  static const String backupName = 'backup';
  static const String backupPath = '/backup';

  /// Informazioni e supporto: identity, installed build, and the public pages.
  static const String informationName = 'information';
  static const String informationPath = '/information';

  /// Impostazioni: language, data & space, updates, information.
  static const String settingsName = 'settings';
  static const String settingsPath = '/settings';

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

  /// New contextual record / note editor. Path param: `id`.
  static const String noteName = 'note';
  static const String notePath = '/possession/:id/note';

  /// Edit an existing record / note. Path params: `id`, `recordId`.
  static const String recordEditName = 'recordEdit';
  static const String recordEditPath = '/possession/:id/record/:recordId';

  /// Full-screen viewer for a possession's cover photo. Path param: `id`.
  static const String photoName = 'photo';
  static const String photoPath = '/possession/:id/photo';

  /// Lend editor (create or correct a loan). Path param: `id`.
  static const String lendName = 'lend';
  static const String lendPath = '/possession/:id/lend';

  /// Give editor (permanent transfer). Path param: `id`.
  static const String giveName = 'give';
  static const String givePath = '/possession/:id/give';

  /// A single place's contents (the possessions kept there). Path param: `id`.
  static const String placeName = 'place';
  static const String placePath = '/place/:id';

  /// Builds the concrete contents path for place [id].
  static String place(String id) => '/place/$id';

  /// The guided "Riordina questo luogo" walk for a place. Path param: `id`.
  static const String placeReviewName = 'place-review';
  static const String placeReviewPath = '/place/:id/review';

  /// Builds the concrete review path for place [id].
  static String placeReview(String id) => '/place/$id/review';
}
