/// Platform facade for the backup screen. The real screen (and its whole
/// `dart:io`/`sqlite3`/`archive` pipeline) is compiled only on native; web and
/// other targets get a calm "unsupported" stub, so the app still compiles
/// everywhere without pulling native-only code into the web bundle.
library;

export 'backup_screen_stub.dart'
    if (dart.library.io) 'backup_screen_impl.dart';
