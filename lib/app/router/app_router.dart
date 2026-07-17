import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/places/presentation/place_contents_screen.dart';
import '../../features/possessions/presentation/acquisition_editor_screen.dart';
import '../../features/possessions/presentation/create_possession_screen.dart';
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
        path: Routes.newPossessionPath,
        name: Routes.newPossessionName,
        // `extra` carries an already-captured photo when arriving via "Una foto".
        builder: (context, state) =>
            CreatePossessionScreen(initialPhoto: state.extra as StoredPhoto?),
      ),
      GoRoute(
        path: Routes.possessionPath,
        name: Routes.possessionName,
        builder: (context, state) => PossessionDetailScreen(
          id: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: Routes.acquisitionPath,
        name: Routes.acquisitionName,
        builder: (context, state) => AcquisitionEditorScreen(
          possessionId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: Routes.reminderPath,
        name: Routes.reminderName,
        builder: (context, state) => ReminderEditorScreen(
          possessionId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: Routes.notePath,
        name: Routes.noteName,
        builder: (context, state) => NoteEditorScreen(
          possessionId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: Routes.photoPath,
        name: Routes.photoName,
        builder: (context, state) => PhotoViewerScreen(
          possessionId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: Routes.placePath,
        name: Routes.placeName,
        builder: (context, state) => PlaceContentsScreen(
          placeId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
}
