// Web/other-platform stub: backup save is a native-only feature for now, so
// these degrade gracefully and keep the app compiling everywhere.

Future<bool> backupSupported() async => false;

Future<int?> freeBytesForBackup() async => null;

Future<String?> createBackupDocument(String suggestedName) async => null;

Future<int> copyFileToUri({
  required String sourcePath,
  required String uri,
}) async {
  throw UnsupportedError('Backup save is not supported on this platform.');
}
