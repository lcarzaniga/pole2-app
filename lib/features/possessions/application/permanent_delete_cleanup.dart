/// Facade over the **filesystem phase** of M8.2A permanent deletion: deleting
/// the physical bytes of media that the database phase already proved orphaned.
///
/// Native-only; the web/other stub is a no-op (there is no managed photo store
/// there). Kept behind this facade so the coordinator and UI stay web-safe and
/// never pull `dart:io`/`path_provider` into the web graph.
library;

export 'permanent_delete_cleanup_stub.dart'
    if (dart.library.io) 'permanent_delete_cleanup_io.dart';
