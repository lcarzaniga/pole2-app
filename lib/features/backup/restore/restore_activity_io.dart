import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/backup_controller.dart';
import 'restore_controller.dart';

/// True while a restore preparation OR a backup export is in progress this
/// session. Read-only — it only observes the two controllers' `isBusy` state.
bool isRestoreOrBackupBusy(WidgetRef ref) =>
    ref.read(restoreControllerProvider).isBusy ||
    ref.read(backupControllerProvider).isBusy;
