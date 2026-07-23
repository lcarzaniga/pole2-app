/// Platform facade for M9.1 attachment selection. Camera/gallery go through
/// image_picker (already a dependency; cross-platform incl. iOS); documents go
/// through the existing Android SAF flow — all behind one contract so the record
/// editor and domain never touch platform classes. Web/other get the stub.
library;

export 'attachment_source.dart';
export 'attachment_picker_stub.dart'
    if (dart.library.io) 'attachment_picker_io.dart';
