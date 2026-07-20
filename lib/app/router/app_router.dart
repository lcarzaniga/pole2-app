import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/archive/presentation/archive_screen.dart';
import '../../features/backup/presentation/backup_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/information/presentation/information_screen.dart';
import '../../features/places/presentation/place_contents_screen.dart';
import '../../features/places/presentation/place_review_screen.dart';
import '../../features/people/presentation/people_browser_screen.dart';
import '../../features/people/presentation/person_detail_screen.dart';
import '../../features/places/presentation/places_browser_screen.dart';
import '../../features/possessions/presentation/acquisition_editor_screen.dart';
import '../../features/possessions/presentation/create_possession_screen.dart';
import '../../features/possessions/presentation/give_editor_screen.dart';
import '../../features/possessions/presentation/lend_editor_screen.dart';
import '../../features/possessions/presentation/note_editor_screen.dart';
import '../../features/possessions/presentation/photo_viewer_screen.dart';
import '../../features/possessions/presentation/possession_detail_screen.dart';
import '../../features/possessions/presentation/reminder_editor_screen.dart';
import '../../shared/platform/photo_store.dart';
import 'routes.dart';

part 'app_router.g.dart';

/// The application's single [GoRouter] instance.
///
/// Exposed as a provider (rather than a bare global) so navigation can later
/// react to app state — e.g. an onboarding gate — via `redirect` reading other
/// providers, without restructuring call sites. `keepAlive` because the router
/// lives for the whole app lifetime.
///
/// Note: `/possession/new` is declared before `/possession/:id` so the literal
/// `new` isn't captured as an id.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: Routes.homePath,
    routes: [
      GoRoute(
        path: Routes.homePath,
        name: Routes.homeName,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.archivePath,
        name: Routes.archiveName,
        builder: (context, state) => const ArchiveScreen(),
      ),
      GoRoute(
        path: Routes.placesPath,
        name: Routes.placesName,
        builder: (context, state) => const PlacesBrowserScreen(),
      ),
      GoRoute(
        path: Routes.peoplePath,
        name: Routes.peopleName,
        builder: (context, state) => const PeopleBrowserScreen(),
      ),
      GoRoute(
        path: Routes.personPath,
        name: Routes.personName,
        builder: (context, state) =>
            PersonDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.backupPath,
        name: Routes.backupName,
        builder: (context, state) => const BackupScreen(),
      ),
      GoRoute(
        path: Routes.informationPath,
        name: Routes.informationName,
        builder: (context, state) => const InformationScreen(),
      ),
      GoRoute(
        path: Routes.newPossessionPath,
        name: Routes.newPossessionName,
        // `extra` carries an already-captured photo when arriving via "Una foto".
        builder: (context, state) =>
            CreatePossessionScreen(initialPhoto: state.extra as StoredPhoto?),
      ),
      GoRoute(
        path: Routes.possessionPath,
        name: Routes.possessionName,
        builder: (context, state) =>
            PossessionDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.acquisitionPath,
        name: Routes.acquisitionName,
        builder: (context, state) =>
            AcquisitionEditorScreen(possessionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.reminderPath,
        name: Routes.reminderName,
        builder: (context, state) =>
            ReminderEditorScreen(possessionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.notePath,
        name: Routes.noteName,
        builder: (context, state) =>
            NoteEditorScreen(possessionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.photoPath,
        name: Routes.photoName,
        // Optional `?i=<index>` opens the gallery at a specific photo (the cover
        // is index 0). Missing or malformed falls back to the cover.
        builder: (context, state) => PhotoViewerScreen(
          possessionId: state.pathParameters['id']!,
          initialIndex: int.tryParse(state.uri.queryParameters['i'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: Routes.lendPath,
        name: Routes.lendName,
        // `extra` carries LendEditData when correcting an existing loan.
        builder: (context, state) => LendEditorScreen(
          possessionId: state.pathParameters['id']!,
          edit: state.extra as LendEditData?,
        ),
      ),
      GoRoute(
        path: Routes.givePath,
        name: Routes.giveName,
        builder: (context, state) =>
            GiveEditorScreen(possessionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.placePath,
        name: Routes.placeName,
        builder: (context, state) =>
            PlaceContentsScreen(placeId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.placeReviewPath,
        name: Routes.placeReviewName,
        builder: (context, state) =>
            PlaceReviewScreen(placeId: state.pathParameters['id']!),
      ),
    ],
  );
}
