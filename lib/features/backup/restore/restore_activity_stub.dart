import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Web/other stub: there is no local backup/restore engine here, so nothing is
/// ever busy. Imports no native (Drift/sqlite3) code.
bool isRestoreOrBackupBusy(WidgetRef ref) => false;
