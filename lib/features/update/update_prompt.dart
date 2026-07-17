import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import 'android_installer.dart';
import 'model/update_release.dart';
import 'update_downloader.dart';

/// SharedPreferences key: the highest versionCode the user has said "Più tardi"
/// to. The prompt stays hidden until a strictly-newer versionCode is published.
const String kUpdateDismissedKey = 'update_dismissed_vc';

/// The calm, optional update prompt. "Aggiorna" runs download → SHA-256 verify →
/// install; "Più tardi" persists the dismissed versionCode.
Future<void> showUpdateDialog(
    BuildContext context, UpdateRelease release) async {
  final l10n = AppLocalizations.of(context);
  final accept = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.updateAvailableTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.updateAvailableBody(release.versionName)),
          if (release.notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (final n in release.notes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('•  $n'),
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.updateLater)),
        FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.updateNow)),
      ],
    ),
  );

  if (accept == false) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kUpdateDismissedKey, release.versionCode);
    return;
  }
  if (accept != true || !context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DownloadDialog(release: release),
  );
}

class _DownloadDialog extends StatefulWidget {
  const _DownloadDialog({required this.release});
  final UpdateRelease release;
  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  final UpdateDownloader _downloader = UpdateDownloader();
  StreamSubscription<DownloadState>? _sub;
  DownloadState _state = const DownloadState(DownloadStage.downloading);

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    setState(() => _state = const DownloadState(DownloadStage.downloading));
    _sub?.cancel();
    _sub = _downloader.run(widget.release).listen((s) {
      if (!mounted) return;
      setState(() => _state = s);
      // Installer launched, or user cancelled → close the dialog.
      if (s.stage == DownloadStage.installing ||
          s.stage == DownloadStage.cancelled) {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    late final Widget content;
    late final List<Widget> actions;

    switch (_state.stage) {
      case DownloadStage.downloading:
        content = Column(mainAxisSize: MainAxisSize.min, children: [
          LinearProgressIndicator(
              value: _state.progress == 0 ? null : _state.progress),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.updateDownloading),
        ]);
        actions = [
          TextButton(
              onPressed: _downloader.cancel,
              child: Text(l10n.cancelButton)),
        ];
      case DownloadStage.verifying:
        content = Column(mainAxisSize: MainAxisSize.min, children: [
          const LinearProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.updateVerifying),
        ]);
        actions = const [];
      case DownloadStage.installing:
        content = Text(l10n.updateInstalling);
        actions = const [];
      case DownloadStage.permissionNeeded:
        content = Text(l10n.updatePermissionNeeded);
        actions = [
          TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(l10n.cancelButton)),
          FilledButton(
            onPressed: () async {
              await AndroidInstaller.openInstallSettings();
              _start(); // re-check permission and retry
            },
            child: Text(l10n.updateAllow),
          ),
        ];
      case DownloadStage.error:
        final msg = switch (_state.reason) {
          'sha256' => l10n.updateErrorSha,
          'install' => l10n.updateErrorInstall,
          _ => l10n.updateErrorDownload,
        };
        content = Text(msg, style: TextStyle(color: scheme.error));
        actions = [
          TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(l10n.closeButton)),
          FilledButton(onPressed: _start, child: Text(l10n.updateRetry)),
        ];
      case DownloadStage.cancelled:
        content = const SizedBox.shrink();
        actions = const [];
    }

    return AlertDialog(
      title: Text(l10n.updateAvailableTitle),
      content: content,
      actions: actions,
    );
  }
}
