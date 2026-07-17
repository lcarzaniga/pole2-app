import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_prompt.dart';
import 'update_service.dart';

/// Runs **one** non-blocking update check shortly after startup and, if a
/// strictly-newer, non-dismissed release exists, shows the optional prompt.
/// Fails silently on anything (offline, malformed, etc.) and renders [child]
/// unchanged — it never blocks or gates the app.
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  bool _ran = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_ran) return;
    _ran = true;
    try {
      final client = http.Client();
      final release = await fetchLatestRelease(client);
      client.close();
      if (release == null || !mounted) return;

      final info = await PackageInfo.fromPlatform();
      final currentVc = int.tryParse(info.buildNumber) ?? 0;
      if (!release.isNewerThan(currentVc)) return; // equal/older ignored

      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getInt(kUpdateDismissedKey) ?? 0;
      if (release.versionCode <= dismissed) return; // "Più tardi" for this one

      if (!mounted) return;
      await showUpdateDialog(context, release);
    } catch (_) {
      // Silent — the updater must never disrupt the app.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
