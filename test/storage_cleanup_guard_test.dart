import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/features/storage/application/storage_cleanup_controller.dart';

/// M8.2C — the pure guard precedence used to refuse a scan/cleanup while another
/// operation is active.
void main() {
  test('nothing active → not blocked', () {
    expect(
      storageBlockedReason(
        restore: false,
        backup: false,
        permanentDelete: false,
      ),
      isNull,
    );
  });

  test('restore takes priority', () {
    expect(
      storageBlockedReason(restore: true, backup: true, permanentDelete: true),
      'restore',
    );
  });

  test('backup blocks when no restore', () {
    expect(
      storageBlockedReason(restore: false, backup: true, permanentDelete: true),
      'backup',
    );
  });

  test('permanent delete blocks when nothing else', () {
    expect(
      storageBlockedReason(
        restore: false,
        backup: false,
        permanentDelete: true,
      ),
      'permanentDelete',
    );
  });
}
