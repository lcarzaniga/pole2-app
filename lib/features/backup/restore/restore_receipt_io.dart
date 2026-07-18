import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Returns the last restore result ('success' | 'rolledBack') exactly once, then
/// deletes the receipt so the message never repeats. Null when there's nothing
/// to report. Never throws.
Future<String?> consumeRestoreReceipt() async {
  try {
    final docs = await getApplicationDocumentsDirectory();
    final f = File(p.join(docs.path, 'restore_result.json'));
    if (!f.existsSync()) return null;
    String? status;
    try {
      status =
          (jsonDecode(f.readAsStringSync()) as Map<String, dynamic>)['status']
              as String?;
    } catch (_) {
      status = null;
    }
    try {
      f.deleteSync();
    } catch (_) {}
    return status;
  } catch (_) {
    return null;
  }
}
