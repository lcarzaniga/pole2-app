/// Facade over the native filesystem scan/delete for M8.2C "Libera spazio".
///
/// Native-only; the web/other stub reports "unsupported" and deletes nothing, so
/// the app compiles everywhere and the UI can hide/disable the action. Kept
/// behind this facade so the coordinator/controller and UI stay web-safe and
/// never pull `dart:io`/`path_provider` into the web graph.
library;

export 'storage_cleanup_stub.dart'
    if (dart.library.io) 'storage_cleanup_io.dart';
