import 'package:path_provider/path_provider.dart';

import 'restore_swapper.dart';

/// Returns the last restore result ('success' | 'rolledBack') exactly once, then
/// deletes the receipt so the message never repeats. Null when there's nothing
/// to report. Never throws.
Future<String?> consumeRestoreReceipt() async {
  try {
    final docs = await getApplicationDocumentsDirectory();
    return RestoreSwapper(docs).consumeReceipt();
  } catch (_) {
    return null;
  }
}
