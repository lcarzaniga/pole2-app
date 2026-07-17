/// Document picking + storage, resolved per platform via conditional import,
/// mirroring `photo_store.dart`. On device (dart:io) it picks a file from
/// storage and copies it into the app documents directory; on web it is a safe
/// no-op so the app still compiles. Callers depend only on this file.
library;

export 'document_types.dart';
export 'document_store_stub.dart' if (dart.library.io) 'document_store_io.dart';
