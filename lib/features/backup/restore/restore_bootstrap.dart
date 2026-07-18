/// Pre-database restore bootstrap. Runs in `main()` before any AppDatabase can
/// open, so a pending restore's swap/rollback completes before Drift touches the
/// data. Native-only (dart:io); a web/other stub makes it a no-op so the app
/// still compiles everywhere.
library;

export 'restore_bootstrap_stub.dart'
    if (dart.library.io) 'restore_bootstrap_io.dart';
