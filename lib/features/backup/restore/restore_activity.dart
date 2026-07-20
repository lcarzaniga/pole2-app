/// Read-only "is a restore or backup export in progress this session?" check,
/// exposed by the backup/restore feature so the (web-reachable) updater can
/// consult the in-memory controllers **without** importing them — they pull the
/// native Drift/sqlite3 stack, which must never enter the web graph.
///
/// Native-only; a web/other stub returns false (there is no local backup engine
/// there). Combined with the durable on-disk check (`restore_pending.dart`),
/// this covers both the live session and a restore pending across a restart.
library;

export 'restore_activity_stub.dart'
    if (dart.library.io) 'restore_activity_io.dart';
