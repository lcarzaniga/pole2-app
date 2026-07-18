/// Platform seam for saving a finished backup through the Android Storage Access
/// Framework (no storage permission). Resolved per platform via conditional
/// import so web/other targets compile with a graceful "unsupported" stub.
///
/// The complete backup bytes never travel through the MethodChannel: Dart writes
/// the final file into app-private storage, the user picks a destination
/// (`ACTION_CREATE_DOCUMENT`), and native copies the file into the chosen
/// `content://` URI off the main thread.
library;

export 'backup_saver_stub.dart' if (dart.library.io) 'backup_saver_io.dart';
