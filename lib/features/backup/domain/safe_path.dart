/// Pure path safety for backup archives. Every path written into (or read from)
/// a backup must be a canonical, forward-slash **relative** path that can never
/// escape the archive/staging root. Kept dependency-free so it's trivially and
/// exhaustively unit-testable.
library;

/// Normalizes a stored `relativePath` to the canonical form used *inside* the
/// backup's `files/` namespace: forward slashes, collapsed `.` and redundant
/// separators. Returns null if the path is unsafe (see [isSafeRelativePath]).
String? normalizeRelativePath(String raw) {
  if (!isSafeRelativePath(raw)) return null;
  final parts = raw.split('/').where((p) => p.isNotEmpty && p != '.').toList();
  if (parts.isEmpty) return null;
  return parts.join('/');
}

/// True when [path] is a safe relative path: no NUL, no backslash, not absolute,
/// no Windows drive prefix, no `..` segment, not empty. Used for both the
/// database `relativePath` values and the ZIP entry names.
bool isSafeRelativePath(String path) {
  if (path.isEmpty) return false;
  if (path.codeUnits.contains(0)) return false; // NUL byte
  if (path.contains('\\')) return false; // backslash
  if (path.startsWith('/')) return false; // absolute (POSIX)
  if (_hasDrivePrefix(path)) return false; // C:\ or C:/
  for (final s in path.split('/')) {
    if (s == '..') return false; // traversal
  }
  return true;
}

/// True when [entryPath] stays strictly within the archive root once normalized
/// — the ZIP-extraction guard (normalization already rejects escapes/absolutes).
bool staysWithinRoot(String entryPath) =>
    normalizeRelativePath(entryPath) != null;

bool _hasDrivePrefix(String path) {
  // e.g. "C:", "C:/", "C:\" — a Windows drive letter followed by a colon.
  if (path.length < 2) return false;
  final c = path.codeUnitAt(0);
  final isLetter =
      (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A); // A-Z a-z
  return isLetter && path[1] == ':';
}
