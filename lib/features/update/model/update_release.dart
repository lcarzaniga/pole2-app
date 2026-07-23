import 'dart:convert';

/// A parsed, validated release descriptor from `latest.json`.
///
/// Only constructible via [tryParse], which returns null for anything
/// malformed, older, equal, or missing a required field — so callers can
/// silently ignore bad metadata and never act on it. Required fields:
/// `versionName` (non-empty), `versionCode` (int), `apkUrl` (https),
/// `sha256` (64-char lowercase hex).
///
/// Optional fields: `notes`, `mandatory`, `backupRecommended` (bool, default
/// false), `schemaVersion` (int, informational). A missing optional field is
/// always accepted (old `latest.json` files stay compatible); a *present* one
/// of the wrong type invalidates the whole descriptor (silent-null), matching
/// the strict discipline of the required fields. Risk is never inferred from
/// `versionName` — the publisher opts into the backup prompt explicitly via
/// `backupRecommended` (see M8).
class UpdateRelease {
  const UpdateRelease({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.sha256,
    required this.notes,
    required this.mandatory,
    this.notesIt = const [],
    this.notesEn = const [],
    this.backupRecommended = false,
    this.schemaVersion,
  });

  final String versionName;
  final int versionCode;
  final String apkUrl; // HTTPS only
  final String sha256; // lowercase hex, 64 chars

  /// Legacy, single-language notes. Kept forever: clients from 1.0.25 and
  /// earlier read only this field, so it must never be removed from the feed.
  final List<String> notes;

  /// Localized notes (added in 1.0.26). Empty when the feed omits them; a new
  /// client then falls back to whichever localized array exists, then [notes].
  final List<String> notesIt;
  final List<String> notesEn;
  final bool mandatory;

  /// Publisher-controlled: when true, offer a backup before this update. A
  /// `mandatory` release is *also* treated as backup-recommended (see
  /// [needsBackupPrompt]) — but mandatory never removes the user's ability to
  /// postpone or keep using the app (Pole² never hard-locks local data).
  final bool backupRecommended;

  /// The schema version this release targets, if the manifest declares it.
  /// Informational only for now — the app cannot know a *future* build's schema
  /// before installing, so it never drives behaviour here.
  final int? schemaVersion;

  /// Whether tapping "Aggiorna" should first show the backup proposal. The
  /// publisher's `backupRecommended` flag, OR a legacy `mandatory:true`, which
  /// we honour only as "recommend a backup", never as an access lock.
  bool get needsBackupPrompt => backupRecommended || mandatory;

  /// The notes to show for the app's effective language ([languageCode] follows
  /// the current preference, including a manual override): the matching
  /// localized array if non-empty, otherwise the *other* localized array if it
  /// exists, otherwise the legacy [notes]. So a feed with only `notes` behaves
  /// exactly as before, and a partially-localized feed never shows nothing.
  List<String> notesFor(String languageCode) {
    // Match only the language subtag, so 'it', 'it_IT' and 'it-IT' all count as
    // Italian (l10n.localeName may carry a region).
    final lang = languageCode.toLowerCase().split(RegExp('[-_]')).first;
    final isItalian = lang == 'it';
    final preferred = isItalian ? notesIt : notesEn;
    if (preferred.isNotEmpty) return preferred;
    final other = isItalian ? notesEn : notesIt;
    if (other.isNotEmpty) return other;
    return notes;
  }

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

    // Notes arrays are parsed *leniently* — a malformed optional notes field
    // must never break an update check. Anything not a list of strings simply
    // yields an empty list (and the selection then falls back gracefully).
    List<String> stringList(Object? raw) => raw is List
        ? raw.whereType<String>().toList(growable: false)
        : const <String>[];
    final notes = stringList(decoded['notes']);
    final notesIt = stringList(decoded['notes_it']);
    final notesEn = stringList(decoded['notes_en']);

    // Optional, strictly typed: present-but-wrong-type invalidates the manifest;
    // absent uses the default. Old files (neither key) stay valid.
    final rawBackup = decoded['backupRecommended'];
    if (rawBackup != null && rawBackup is! bool) return null;
    final rawSchema = decoded['schemaVersion'];
    if (rawSchema != null && rawSchema is! int) return null;

    return UpdateRelease(
      versionName: name.trim(),
      versionCode: code,
      apkUrl: url,
      sha256: h,
      notes: notes,
      notesIt: notesIt,
      notesEn: notesEn,
      // `mandatory` stays leniently parsed for backward compatibility.
      mandatory: decoded['mandatory'] == true,
      backupRecommended: rawBackup == true,
      schemaVersion: rawSchema as int?,
    );
  }

  /// True only when this release is **strictly newer** than the installed
  /// [currentCode] (equal or older is ignored).
  bool isNewerThan(int currentCode) => versionCode > currentCode;
}
