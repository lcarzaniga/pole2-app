/// Facade over the M8.2D staged-photo lifecycle: capture into an app-private
/// temporary import area, crash-safe promotion into `photos/` bound to a
/// completed database save, cancellation, and idempotent startup reconciliation.
///
/// Native-only; the web/other stub captures nothing and reconciles nothing, so
/// the app compiles everywhere and callers stay web-safe. Kept behind this
/// facade so `dart:io`/`image_picker`/`path_provider` never enter the web graph.
library;

export 'staged_photo.dart';
export 'photo_import_stub.dart' if (dart.library.io) 'photo_import_io.dart';
