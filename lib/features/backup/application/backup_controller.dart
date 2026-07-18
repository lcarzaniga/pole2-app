import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../data/backup_plan.dart';
import '../platform/backup_saver.dart' as saf;
import '../restore/restore_controller.dart';
import 'backup_service.dart';

/// Where the backup job is.
enum BackupStatus {
  idle,
  working,
  awaitingDestination,
  saving,
  completed,
  cancelled,
  failed,
}

/// Immutable UI state for the backup job.
class BackupState {
  const BackupState({
    this.status = BackupStatus.idle,
    this.phase,
    this.errorCode,
    this.incompleteObject,
    this.summary,
    this.warnings = const [],
  });

  final BackupStatus status;
  final BackupPhase? phase;

  /// Coarse, localizable error code — e.g. 'incomplete', 'lowSpace', 'generic'.
  final String? errorCode;

  /// The object that made an incomplete backup impossible (for the message).
  final String? incompleteObject;

  /// A short "N oggetti · M foto" summary on success.
  final String? summary;
  final List<String> warnings;

  bool get isBusy =>
      status == BackupStatus.working ||
      status == BackupStatus.awaitingDestination ||
      status == BackupStatus.saving;

  BackupState copyWith({
    BackupStatus? status,
    BackupPhase? phase,
    String? errorCode,
    String? incompleteObject,
    String? summary,
    List<String>? warnings,
  }) => BackupState(
    status: status ?? this.status,
    phase: phase,
    errorCode: errorCode,
    incompleteObject: incompleteObject,
    summary: summary ?? this.summary,
    warnings: warnings ?? this.warnings,
  );
}

final backupControllerProvider =
    NotifierProvider<BackupController, BackupState>(BackupController.new);

/// Thin coordinator over [BackupService] + the SAF saver: single operation at a
/// time (repeated taps ignored), phase/status for the UI, cancellation before
/// the native copy, and calm failure that never leaves the live data changed.
class BackupController extends Notifier<BackupState> {
  @override
  BackupState build() => const BackupState();

  AppDatabase get _db => ref.read(databaseProvider);

  /// Runs a full backup and, on success, saves it through the Android picker.
  Future<void> createBackup({required bool encrypt, String? password}) async {
    // Single-flight, and mutually exclusive with an in-progress restore.
    if (state.isBusy || ref.read(restoreControllerProvider).isBusy) return;
    state = const BackupState(status: BackupStatus.working);

    BuiltBackup? built;
    try {
      final info = await PackageInfo.fromPlatform();
      final tempDir = await getTemporaryDirectory();
      final docsDir = await getApplicationDocumentsDirectory();

      // Free-space preflight: snapshot + ZIP + encrypted output ≈ 3× data.
      final need = await _estimateNeededBytes(docsDir);
      final free = await saf.freeBytesForBackup();
      if (free != null && free < need) {
        state = const BackupState(
          status: BackupStatus.failed,
          errorCode: 'lowSpace',
        );
        return;
      }

      final service = BackupService(
        db: _db,
        tempDir: tempDir,
        documentsDir: docsDir,
        appVersion: info.version,
        versionCode: int.tryParse(info.buildNumber) ?? 0,
        schemaVersion: _db.schemaVersion,
      );
      built = await service.build(
        encrypt: encrypt,
        password: password,
        onPhase: (phase) =>
            state = state.copyWith(status: BackupStatus.working, phase: phase),
      );

      // Choose destination (cancellable no-op).
      state = state.copyWith(status: BackupStatus.awaitingDestination);
      final uri = await saf.createBackupDocument(built.suggestedName);
      if (uri == null) {
        state = const BackupState(status: BackupStatus.cancelled);
        return;
      }

      // Non-cancellable native copy.
      state = state.copyWith(status: BackupStatus.saving);
      final expected = await built.file.length();
      final written = await saf.copyFileToUri(
        sourcePath: built.file.path,
        uri: uri,
      );
      if (written != expected) {
        state = const BackupState(
          status: BackupStatus.failed,
          errorCode: 'generic',
        );
        return;
      }

      await _rememberLastBackup();
      state = BackupState(
        status: BackupStatus.completed,
        summary:
            '${built.manifest.counts.possessions} oggetti · '
            '${built.manifest.counts.photos} foto',
        warnings: built.warnings,
      );
    } on BackupIncompleteException catch (e) {
      state = BackupState(
        status: BackupStatus.failed,
        errorCode: 'incomplete',
        incompleteObject: e.message,
      );
    } catch (_) {
      state = const BackupState(
        status: BackupStatus.failed,
        errorCode: 'generic',
      );
    } finally {
      // Always clean this job's staging (success, cancel, or failure).
      if (built != null) {
        try {
          built.stagingDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
  }

  /// Return to idle after showing a terminal state.
  void reset() => state = const BackupState();

  Future<int> _estimateNeededBytes(Directory docsDir) async {
    var bytes = 0;
    final dbFile = File(p.join(docsDir.path, 'project_kobe.sqlite'));
    if (dbFile.existsSync()) bytes += dbFile.lengthSync();
    final photos = Directory(p.join(docsDir.path, 'photos'));
    if (photos.existsSync()) {
      for (final e in photos.listSync(recursive: true)) {
        if (e is File) bytes += e.lengthSync();
      }
    }
    return bytes * 3 + 8 * 1024 * 1024; // 3× + 8 MiB headroom
  }

  Future<void> _rememberLastBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'lastBackupUtc',
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {}
  }
}

/// The last successful backup timestamp (local, non-essential), for the UI.
final lastBackupProvider = FutureProvider<DateTime?>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('lastBackupUtc');
    return s == null ? null : DateTime.tryParse(s);
  } catch (_) {
    return null;
  }
});
