import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../backup/restore/restore_pending.dart';
import 'android_installer.dart';
import 'model/update_release.dart';
import 'update_service.dart';

/// Where the update flow currently is — drives the UI.
enum DownloadStage {
  permissionNeeded, // OS "install unknown apps" not granted yet
  downloading,
  verifying,
  blockedByRestore, // a restore became pending — never install over it
  installing, // installer launched (verified)
  cancelled,
  error,
}

class DownloadState {
  const DownloadState(this.stage, {this.progress = 0, this.reason});

  final DownloadStage stage;
  final double progress; // 0..1 during download
  final String? reason; // 'download' | 'sha256' | 'install' on error
}

/// Downloads a release APK with progress + cancellation, verifies its SHA-256,
/// and only then launches the system installer.
///
/// Guarantees: **HTTPS only**; a partial/cancelled/failed/mismatched download is
/// deleted and never installed; never touches app data.
class UpdateDownloader {
  /// [isRestorePending] and [clientFactory] are injected so the defensive
  /// pre-install guard and the download path are unit-testable off-device; both
  /// default to the real implementations.
  UpdateDownloader({
    Future<bool> Function()? isRestorePending,
    http.Client Function()? clientFactory,
  }) : _isRestorePending = isRestorePending ?? isRestorePendingOnDisk,
       _clientFactory = clientFactory ?? http.Client.new;

  final Future<bool> Function() _isRestorePending;
  final http.Client Function() _clientFactory;

  http.Client? _client;
  bool _cancelled = false;

  /// Cancel an in-flight download; the partial file is removed.
  void cancel() {
    _cancelled = true;
    _client?.close();
  }

  Stream<DownloadState> run(UpdateRelease release) async* {
    _cancelled = false;

    if (!release.apkUrl.startsWith('https://')) {
      yield const DownloadState(DownloadStage.error, reason: 'download');
      return;
    }

    // Initial restore guard, before any temp storage is touched: a restore
    // pending here blocks the whole download and leaves no file behind.
    if (await _isRestorePending()) {
      yield const DownloadState(DownloadStage.blockedByRestore);
      return;
    }

    // The OS gate — request only when actually updating.
    if (!await AndroidInstaller.canInstall()) {
      yield const DownloadState(DownloadStage.permissionNeeded);
      return;
    }

    final dir = Directory(
      p.join((await getTemporaryDirectory()).path, 'updates'),
    );
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File(p.join(dir.path, 'pole2-${release.versionCode}.apk'));
    if (file.existsSync()) file.deleteSync();

    // 1. Download (streamed → progress; interruptible).
    try {
      yield const DownloadState(DownloadStage.downloading);
      _client = _clientFactory();
      final resp = await _client!.send(
        http.Request('GET', Uri.parse(release.apkUrl)),
      );
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final total = resp.contentLength ?? 0;
      var received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in resp.stream) {
          if (_cancelled) break;
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            yield DownloadState(
              DownloadStage.downloading,
              progress: received / total,
            );
          }
        }
      } finally {
        await sink.close();
      }
    } catch (_) {
      _deleteQuietly(file);
      yield const DownloadState(DownloadStage.error, reason: 'download');
      return;
    } finally {
      _client?.close();
      _client = null;
    }

    if (_cancelled) {
      _deleteQuietly(file);
      yield const DownloadState(DownloadStage.cancelled);
      return;
    }

    // 2. Verify SHA-256 — never install on mismatch.
    yield const DownloadState(DownloadStage.verifying, progress: 1);
    final digest = await sha256OfFile(file);
    if (digest != release.sha256) {
      _deleteQuietly(file);
      yield const DownloadState(DownloadStage.error, reason: 'sha256');
      return;
    }

    // 3. Defensive restore guard, re-checked immediately before installing: if a
    // restore became pending after the initial gate, never install over it. The
    // verified APK is deleted first (a best-effort delete that never throws), so
    // no unused installer file is left behind; a failed delete still blocks and
    // never falls through to install.
    if (await _isRestorePending()) {
      _deleteQuietly(file);
      yield const DownloadState(DownloadStage.blockedByRestore);
      return;
    }

    // 4. Launch the system installer for the verified file.
    try {
      await AndroidInstaller.install(file.path);
      yield const DownloadState(DownloadStage.installing, progress: 1);
    } catch (_) {
      yield const DownloadState(DownloadStage.error, reason: 'install');
    }
  }

  void _deleteQuietly(File f) {
    try {
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }
}
