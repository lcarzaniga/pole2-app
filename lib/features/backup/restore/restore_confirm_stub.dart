/// Web/non-io stub: there is no restore to confirm off-device.
Future<void> confirmRestoreIfPending({
  required Future<bool> Function() probe,
}) async {}
