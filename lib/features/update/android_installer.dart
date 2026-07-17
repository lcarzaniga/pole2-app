import 'package:flutter/services.dart';

/// Thin wrapper over the native `pole2/installer` channel (see MainActivity.kt).
///
/// The channel only reports the OS install-permission state and launches the
/// system package installer for a file the app has **already** downloaded and
/// SHA-256-verified. It never downloads, verifies, or touches app data.
class AndroidInstaller {
  const AndroidInstaller._();

  static const MethodChannel _channel = MethodChannel('pole2/installer');

  /// Whether the OS currently allows this app to launch an APK install
  /// ("install unknown apps" granted). False on any error.
  static Future<bool> canInstall() async {
    try {
      return (await _channel.invokeMethod<bool>('canInstall')) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens the per-app "install unknown apps" settings screen.
  static Future<void> openInstallSettings() async {
    try {
      await _channel.invokeMethod<void>('openInstallSettings');
    } on PlatformException {
      // best-effort; nothing to do if it fails
    }
  }

  /// Launches the system installer for the verified APK at [path].
  static Future<void> install(String path) =>
      _channel.invokeMethod<void>('install', {'path': path});
}
