import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The version and build actually installed on this device.
///
/// Read at runtime from the package itself, so the screen can never drift from
/// what the user is really running: a hard-coded string would still say 1.0.15
/// after a 1.0.16 install, which is exactly the kind of quiet lie that makes a
/// support conversation useless.
class InstalledBuild {
  const InstalledBuild({required this.version, required this.buildNumber});

  /// e.g. `1.0.16` (Android versionName).
  final String version;

  /// e.g. `2021` (Android versionCode).
  final String buildNumber;

  /// Whether the platform actually told us something usable.
  bool get isKnown => version.isNotEmpty;
}

/// Reads the installed version/build. Kept as a provider so the screen stays
/// synchronous-looking and tests can override it without a plugin.
final installedBuildProvider = FutureProvider<InstalledBuild>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return InstalledBuild(version: info.version, buildNumber: info.buildNumber);
});
