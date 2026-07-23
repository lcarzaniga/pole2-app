import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;

import 'model/update_release.dart';

/// The public update endpoint — static and **HTTPS only**.
///
/// Uses the canonical domain (`pole2.app`); `pole2.it` serves byte-identical
/// JSON and remains a working alias, so older installs keep updating.
const String kLatestJsonUrl = 'https://pole2.app/releases/latest.json';

/// Fetches and validates the release descriptor from [url].
///
/// **Fails silently** (returns null) on any network, status, or parse error, so
/// the startup check can never block or disrupt the app. HTTPS is enforced.
Future<UpdateRelease?> fetchLatestRelease(
  http.Client client, {
  String url = kLatestJsonUrl,
  Duration timeout = const Duration(seconds: 8),
}) async {
  if (!url.startsWith('https://')) return null; // HTTPS only
  try {
    final resp = await client.get(Uri.parse(url)).timeout(timeout);
    if (resp.statusCode != 200) return null;
    return UpdateRelease.tryParse(resp.body);
  } catch (_) {
    return null; // offline, timeout, TLS, malformed — all ignored
  }
}

/// Lowercase-hex SHA-256 of a file, streamed (so a large APK isn't held in
/// memory). Used to verify a download **before** the installer is ever launched.
Future<String> sha256OfFile(File file) async {
  final digest = await crypto.sha256.bind(file.openRead()).first;
  return digest.toString();
}
