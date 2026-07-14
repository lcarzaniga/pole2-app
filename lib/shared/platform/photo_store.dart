/// Photo storage + cover rendering, resolved per platform via conditional
/// import. On device (dart:io) it picks from the gallery and writes files to
/// the app documents directory; on web it is a safe no-op so the app still
/// compiles. Callers depend only on this file.
library;

export 'photo_types.dart';
export 'photo_store_stub.dart' if (dart.library.io) 'photo_store_io.dart';
