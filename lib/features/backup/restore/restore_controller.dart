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

  /// Closes the database and terminates the process so the next launch runs the
  /// pre-DB swap. Called from the "close now" button after confirmation.
  Future<void> closeApp() async {
    try {
      await _db.close();
    } catch (_) {}
    await SystemChannels.platform.invokeMethod<void>('SystemNavigator.pop');
    // Guarantee a clean process end so the pre-DB bootstrap runs on reopen.
    exit(0);
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
