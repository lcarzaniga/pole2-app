import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../application/backup_controller.dart';
import '../crypto/backup_container.dart';
import '../platform/backup_saver.dart' as saf;
import 'restore_marker.dart';
import 'restore_preparer.dart';

enum RestoreStatus {
  idle,
  picking,
  copying,
  readingHeader,
  awaitingPassword,
  preparing,
  readyForConfirmation,
  writingMarker,
  awaitingReopen,
  closing,
  awaitingManualClose,
  completed,
  failed,
  cancelled,
}

class RestoreState {
  const RestoreState({
    this.status = RestoreStatus.idle,
    this.errorCode,
    this.summary,
  });

  final RestoreStatus status;
  final String? errorCode;
  final RestoreSummary? summary;

  bool get isBusy =>
      status != RestoreStatus.idle &&
      status != RestoreStatus.completed &&
      status != RestoreStatus.failed &&
      status != RestoreStatus.cancelled;

  /// True only while actually inspecting the picked file (before confirmation).
  /// The close/reopen states are busy but must not read as "verifying".
  bool get isVerifying =>
      status == RestoreStatus.picking ||
      status == RestoreStatus.copying ||
      status == RestoreStatus.readingHeader ||
      status == RestoreStatus.preparing ||
      status == RestoreStatus.writingMarker;

  RestoreState copyWith({
    RestoreStatus? status,
    String? errorCode,
    RestoreSummary? summary,
  }) => RestoreState(
    status: status ?? this.status,
    errorCode: errorCode,
    summary: summary ?? this.summary,
  );
}

final restoreControllerProvider =
    NotifierProvider<RestoreController, RestoreState>(RestoreController.new);

/// Coordinates a full restore *preparation* (everything before the swap, which
/// the bootstrap performs on the next launch). Single-flight and mutually
/// exclusive with export. The password lives only in local variables here — it
/// is never put into state, the marker, logs, or the filesystem.
class RestoreController extends Notifier<RestoreState> {
  static const _uuid = Uuid();

  @override
  RestoreState build() => const RestoreState();

  AppDatabase get _db => ref.read(databaseProvider);

  // Set once a source is copied to staging; cleared on reset.
  File? _source;
  Directory? _staging;
  String? _operationId;
  RestorePreparation? _prepared;

  bool get _exportBusy => ref.read(backupControllerProvider).isBusy;

  /// Pick a file, copy it into staging, read its header. If encrypted, waits for
  /// [submitPassword]; otherwise proceeds to prepare immediately.
  ///
  /// Each stage before password/decryption — pick, copy, staged-file check,
  /// header read — fails with its own [RestoreState.errorCode] so an access or
  /// copy problem is never shown as "corrupt backup". No secrets, backup
  /// contents, or full URIs/paths are logged.
  Future<void> start() async {
    if (state.isBusy || _exportBusy) return;
    _reset();

    // Stage: pick a document.
    state = const RestoreState(status: RestoreStatus.picking);
    String? uri;
    try {
      uri = await saf.openBackupDocument();
    } on PlatformException catch (e) {
      _fail(e.code == 'open_denied' ? 'accessDenied' : 'generic');
      return;
    } catch (_) {
      _fail('generic');
      return;
    }
    if (uri == null) {
      state = const RestoreState(status: RestoreStatus.cancelled);
      return;
    }

    // Stage: copy the picked document into app-private restore staging, then
    // verify the copy actually completed before reading anything.
    state = const RestoreState(status: RestoreStatus.copying);
    Directory? staging;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final opId = _uuid.v4();
      staging = Directory(p.join(docs.path, 'restore_staging', opId))
        ..createSync(recursive: true);
      final source = File(p.join(staging.path, 'source.pole2backup'));

      final int copied;
      try {
        copied = await saf.copyUriToFile(uri: uri, destPath: source.path);
      } on PlatformException catch (e) {
        _cleanup(staging);
        _fail(restoreCopyErrorCode(e.code));
        return;
      }
      if (copied <= 0) {
        _cleanup(staging);
        _fail('emptyBackup');
        return;
      }
      // The staged file must exist and its length must match the bytes the
      // native copy reported — otherwise the copy was incomplete.
      if (!source.existsSync() || source.lengthSync() != copied) {
        _cleanup(staging);
        _fail('copyFailed');
        return;
      }

      _source = source;
      _staging = staging;
      _operationId = opId;
    } catch (_) {
      if (staging != null) _cleanup(staging);
      _reset();
      _fail('stagingError');
      return;
    }

    // Stage: read the header (magic/version). Format problems here mean "not a
    // Pole² backup" or "too new" — never conflated with the copy/access stages.
    try {
      state = const RestoreState(status: RestoreStatus.readingHeader);
      final header = await BackupContainer.readHeader(_source!);
      if (header.encrypted) {
        state = const RestoreState(status: RestoreStatus.awaitingPassword);
      } else {
        await _prepare(null);
      }
    } on BackupUnsupportedVersionException {
      _cleanupCurrent();
      _fail('newerFormat');
    } on BackupFormatException {
      _cleanupCurrent();
      _fail('notABackup');
    } catch (_) {
      _cleanupCurrent();
      _fail('generic');
    }
  }

  void _fail(String code) =>
      state = RestoreState(status: RestoreStatus.failed, errorCode: code);

  /// Supplies the password for an encrypted backup and prepares it.
  Future<void> submitPassword(String password) async {
    if (state.status != RestoreStatus.awaitingPassword) return;
    await _prepare(password);
  }

  Future<void> _prepare(String? password) async {
    state = const RestoreState(status: RestoreStatus.preparing);
    try {
      final prep = await RestorePreparer(appSchemaVersion: _db.schemaVersion)
          .prepare(
            source: _source!,
            stagingDir: _staging!,
            operationId: _operationId!,
            password: password,
          );
      _prepared = prep;
      state = RestoreState(
        status: RestoreStatus.readyForConfirmation,
        summary: prep.summary,
      );
    } on RestorePrepareException catch (e) {
      _cleanupCurrent();
      state = RestoreState(status: RestoreStatus.failed, errorCode: e.code);
    } catch (_) {
      _cleanupCurrent();
      state = const RestoreState(
        status: RestoreStatus.failed,
        errorCode: 'generic',
      );
    }
    // Password is out of scope here on; it was only ever a parameter.
  }

  /// Writes the durable marker and enters the maintenance/close state. After
  /// this point there is no cancellation — the bootstrap will finish the swap.
  Future<void> confirm() async {
    final prep = _prepared;
    if (prep == null || state.status != RestoreStatus.readyForConfirmation) {
      return;
    }
    state = const RestoreState(status: RestoreStatus.writingMarker);
    try {
      final docs = await getApplicationDocumentsDirectory();

      // Free-space preflight for the swap: recovery copy ≈ current data.
      final free = await saf.freeBytesForBackup();
      if (free != null && free < _estimateSwapBytes(docs)) {
        state = const RestoreState(
          status: RestoreStatus.failed,
          errorCode: 'lowSpace',
        );
        return;
      }

      final marker = RestoreMarker(
        operationId: prep.operationId,
        stagingRelPath: p.join('restore_staging', prep.operationId),
        recoveryRelPath: p.join('recovery', 'current', prep.operationId),
        createdAtUtc: DateTime.now().toUtc().toIso8601String(),
        phase: RestorePhase.prepared,
        attemptCount: 0,
        preparedDbSha256: prep.preparedDbSha256,
        managedFiles: prep.managedFiles,
      );
      RestoreMarker.writeAtomic(
        File(p.join(docs.path, 'restore_pending.json')),
        marker,
      );
      state = const RestoreState(status: RestoreStatus.awaitingReopen);
    } catch (_) {
      state = const RestoreState(
        status: RestoreStatus.failed,
        errorCode: 'generic',
      );
    }
  }

  /// Terminates the process so the next launch runs the pre-DB swap. Called from
  /// the "Chiudi Pole²" button after confirmation.
  ///
  /// The old implementation awaited `AppDatabase.close()` unconditionally, which
  /// hangs while Home and other widgets still hold live Drift stream
  /// subscriptions — so `exit(0)` was never reached and the app stayed stuck
  /// behind the dialog. Now the DB close is best-effort with a short timeout,
  /// and the process is killed natively regardless (the durable marker + the
  /// preserved sqlite/WAL/SHM trio make an unclean termination recoverable).
  /// The pending marker is never touched here.
  Future<void> closeApp() async {
    // Single-flight: ignore repeated taps while a close is already in progress.
    if (state.status == RestoreStatus.closing) return;
    // Only from the post-confirmation states (initial close or a manual retry).
    if (state.status != RestoreStatus.awaitingReopen &&
        state.status != RestoreStatus.awaitingManualClose) {
      return;
    }
    // Disable the button immediately.
    state = const RestoreState(status: RestoreStatus.closing);

    final result = await runRestoreClose(
      // Safety: never kill the process unless the durable marker exists & is
      // valid. Without it the bootstrap would have nothing to resume.
      markerValid: () async {
        final docs = await getApplicationDocumentsDirectory();
        return RestoreMarker.readOrNull(
              File(p.join(docs.path, 'restore_pending.json')),
            ) !=
            null;
      },
      closeDb: () => _db.close(),
      nativeClose: saf.closeForRestore,
      diag: _diag,
    );

    switch (result) {
      case RestoreCloseResult.markerMissing:
        _fail('markerMissing');
      case RestoreCloseResult.manualFallback:
        // Native close returned/threw without terminating us → manual
        // instructions; never revert to an editable state.
        state = const RestoreState(status: RestoreStatus.awaitingManualClose);
    }
  }

  void _diag(String stage) {
    assert(() {
      developer.log(stage, name: 'Pole2Restore');
      return true;
    }());
  }

  /// Cancel before the marker exists — cleans staging, changes nothing live.
  void cancel() {
    if (state.status == RestoreStatus.awaitingReopen) return; // too late
    _cleanupCurrent();
    state = const RestoreState(status: RestoreStatus.cancelled);
  }

  void reset() {
    if (state.status == RestoreStatus.awaitingReopen) return;
    _reset();
    state = const RestoreState();
  }

  int _estimateSwapBytes(Directory docs) {
    var bytes = 0;
    final db = File(p.join(docs.path, 'project_kobe.sqlite'));
    if (db.existsSync()) bytes += db.lengthSync();
    final photos = Directory(p.join(docs.path, 'photos'));
    if (photos.existsSync()) {
      for (final e in photos.listSync(recursive: true)) {
        if (e is File) bytes += e.lengthSync();
      }
    }
    return bytes + 8 * 1024 * 1024;
  }

  void _cleanupCurrent() {
    if (_staging != null) _cleanup(_staging!);
    _reset();
  }

  void _cleanup(Directory dir) {
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {}
  }

  void _reset() {
    _source = null;
    _staging = null;
    _operationId = null;
    _prepared = null;
  }
}

/// Maps a native `copyUriToFile` error code (see `MainActivity.copyUriToFile`)
/// to a calm, specific restore error code. Kept pure and top-level so the
/// native → UI contract is unit-testable. An access/copy problem must never be
/// mapped to a backup-format ("corrupt") code.
String restoreCopyErrorCode(String nativeCode) => switch (nativeCode) {
  'open_denied' => 'accessDenied',
  'open_failed' => 'unreadableSource',
  'copy_io_failed' => 'copyFailed',
  'empty_document' => 'emptyBackup',
  'bad_dest' => 'stagingError',
  _ => 'copyFailed',
};

enum RestoreCloseResult { markerMissing, manualFallback }

/// The deliberate close sequence, pure of Flutter/platform deps (all effects
/// injected) so the whole decision path is unit-testable:
///  1. require a valid durable marker — else [RestoreCloseResult.markerMissing]
///     and native close is NOT attempted;
///  2. best-effort [closeDb] with [timeout] — success, timeout or throw all
///     continue (the marker + preserved sqlite/WAL/SHM trio make an unclean
///     termination recoverable);
///  3. [nativeClose] the process. On a real device the process dies inside it
///     and this never returns; if it returns/throws we did NOT terminate, so
///     [RestoreCloseResult.manualFallback] is returned.
///
/// Never touches the marker. [diag] receives only stage labels — no data/paths.
Future<RestoreCloseResult> runRestoreClose({
  required Future<bool> Function() markerValid,
  required Future<void> Function() closeDb,
  required Future<void> Function() nativeClose,
  required void Function(String stage) diag,
  Duration timeout = const Duration(seconds: 2),
}) async {
  if (!await markerValid()) return RestoreCloseResult.markerMissing;

  diag('close_started');
  try {
    await closeDb().timeout(timeout);
    diag('close_completed');
  } catch (_) {
    diag('close_timeout');
  }

  diag('native_close_requested');
  try {
    await nativeClose();
  } catch (_) {}
  return RestoreCloseResult.manualFallback;
}
