import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/possessions_dao.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/platform/photo_store.dart';

// These providers are hand-written rather than code-generated on purpose:
// `riverpod_generator` and `drift_dev` are independent builders, so the
// generator cannot resolve Drift's generated row types (e.g. `Possession`) in
// a provider's return type. Hand-written providers sidestep that entirely with
// no loss of behavior.

/// The possessions data access, resolved from the app database.
final possessionsDaoProvider = Provider<PossessionsDao>(
  (ref) => ref.watch(databaseProvider).possessionsDao,
);

/// Reactive list of all active possessions, newest first. The Home screen
/// watches this to choose between the empty state and the list.
final possessionListProvider = StreamProvider<List<Possession>>(
  (ref) => ref.watch(possessionsDaoProvider).watchAll(),
);

/// Reactive single possession, for the detail screen.
final possessionByIdProvider = StreamProvider.family<Possession?, String>(
  (ref, id) => ref.watch(possessionsDaoProvider).watchById(id),
);

/// Reactive stored-file metadata by id — used to resolve a cover photo.
final fileByIdProvider = StreamProvider.family<StoredFile?, String>(
  (ref, id) => ref.watch(possessionsDaoProvider).watchFile(id),
);

/// The app documents directory path, where photo bytes live (null on web).
/// Watched only when a cover exists, so it never touches platform channels in
/// tests without one.
final appDocumentsPathProvider = FutureProvider<String?>(
  (ref) => documentsPath(),
);

/// Reactive gallery photos (with their files) for a possession, in stable
/// stored order — powers the thumbnail strip and the full-screen gallery.
final possessionPhotosProvider =
    StreamProvider.family<List<PhotoWithFile>, String>(
      (ref, id) => ref.watch(possessionsDaoProvider).watchPhotos(id),
    );

/// "Conservati": non-deleted, non-active possessions (archived and any
/// transferred/lost/disposed) — the Archivio "kept aside" section.
final archivedListProvider = StreamProvider<List<Possession>>(
  (ref) => ref.watch(possessionsDaoProvider).watchArchived(),
);

/// "Rimossi": soft-deleted possessions — the Archivio "removed" section.
final removedListProvider = StreamProvider<List<Possession>>(
  (ref) => ref.watch(possessionsDaoProvider).watchRemoved(),
);
