/// Platform facade for M9 document selection. The native (Android SAF)
/// implementation lives in `document_store_io.dart`; the web/other build gets
/// the compile-only stub. Keeps `dart:io` and platform channels out of the web
/// graph, mirroring `photo_store.dart`.
library;

export 'document_store_stub.dart' if (dart.library.io) 'document_store_io.dart';
