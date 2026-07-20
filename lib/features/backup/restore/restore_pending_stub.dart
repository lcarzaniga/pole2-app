/// Web/other-platform stub: there is no local restore filesystem here, so a
/// restore is never pending. Imports nothing native (no `dart:io`).
Future<bool> isRestorePendingOnDisk() async => false;
