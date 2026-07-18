/// Reads (and consumes, once) the restore result receipt written by the swap.
/// Native-only; web/other gets a stub returning null so the app compiles.
library;

export 'restore_receipt_stub.dart'
    if (dart.library.io) 'restore_receipt_io.dart';
