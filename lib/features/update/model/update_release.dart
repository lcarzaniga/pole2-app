import 'dart:convert';

/// A parsed, validated release descriptor from `latest.json`.
///
/// Only constructible via [tryParse], which returns null for anything
/// malformed, older, equal, or missing a required field — so callers can
/// silently ignore bad metadata and never act on it. Required fields:
/// `versionName` (non-empty), `versionCode` (int), `apkUrl` (https),
/// `sha256` (64-char lowercase hex). `notes` and `mandatory` are optional.
class UpdateRelease {
  const UpdateRelease({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.sha256,
    required this.notes,
    required this.mandatory,
  });

  final String versionName;
  final int versionCode;
  final String apkUrl; // HTTPS only
  final String sha256; // lowercase hex, 64 chars
  final List<String> notes;
  final bool mandatory;

  static final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');

  /// Strict parse — returns null on any problem (never throws).
  static UpdateRelease? tryParse(String body) {
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;

    final name = decoded['versionName'];
    final code = decoded['versionCode'];
    final url = decoded['apkUrl'];
    final hash = decoded['sha256'];

    if (name is! String || name.trim().isEmpty) return null;
    if (code is! int) return null;
    if (url is! String || !url.startsWith('https://')) return null;
    if (hash is! String) return null;
    final h = hash.trim().toLowerCase();
    if (!_hex64.hasMatch(h)) return null;

    final rawNotes = decoded['notes'];
    final notes = rawNotes is List
        ? rawNotes.whereType<String>().toList(growable: false)
        : const <String>[];

    return UpdateRelease(
      versionName: name.trim(),
      versionCode: code,
      apkUrl: url,
      sha256: h,
      notes: notes,
      mandatory: decoded['mandatory'] == true,
    );
  }

  /// True only when this release is **strictly newer** than the installed
  /// [currentCode] (equal or older is ignored).
  bool isNewerThan(int currentCode) => versionCode > currentCode;
}
