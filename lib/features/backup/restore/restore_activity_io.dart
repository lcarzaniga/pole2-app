import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/backup_controller.dart';
import 'restore_controller.dart';

/// True while a restore preparation OR a backup export is in progress this
/// session. Read-only — it only observes the two controllers' `isBusy` state.
bool isRestoreOrBackupBusy(WidgetRef ref) =>
    ref.read(restoreControllerProvider).isBusy ||
    ref.read(backupControllerProvider).isBusy;

/// True while a backup export is in progress this session. Granular variant, so
/// a caller can tell the two apart (e.g. distinct "backup vs restore" copy).
bool isBackupBusy(WidgetRef ref) => ref.read(backupControllerProvider).isBusy;

/// True while a restore preparation is in progress this session.
bool isRestoreBusy(WidgetRef ref) => ref.read(restoreControllerProvider).isBusy;
