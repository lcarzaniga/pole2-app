/// Read-only, durable "is a restore pending?" check, exposed by the restore
/// feature so the updater never touches the restore filesystem directly.
///
/// Native-only; a web/other stub returns false so the app compiles everywhere.
/// The check only *observes* the durable `restore_pending.json` marker — it
/// never writes, deletes, or interprets its contents. See the M6.1 restore
/// state machine (`restore_marker.dart`, `restore_swapper.dart`).
library;

export 'restore_pending_stub.dart'
    if (dart.library.io) 'restore_pending_io.dart';
