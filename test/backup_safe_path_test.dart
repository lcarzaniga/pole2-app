import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/features/backup/domain/safe_path.dart';

void main() {
  group('isSafeRelativePath', () {
    test('accepts a normal relative path', () {
      expect(isSafeRelativePath('photos/uuid.jpg'), isTrue);
    });
    test('rejects traversal, absolute, drive, backslash, empty', () {
      expect(isSafeRelativePath('../secret'), isFalse);
      expect(isSafeRelativePath('a/../../b'), isFalse);
      expect(isSafeRelativePath('/etc/passwd'), isFalse);
      expect(isSafeRelativePath('C:/x'), isFalse);
      expect(isSafeRelativePath('photos\\x.jpg'), isFalse);
      expect(isSafeRelativePath(''), isFalse);
    });
    test('rejects a NUL byte', () {
      final withNul = 'photos/${String.fromCharCode(0)}.jpg';
      expect(isSafeRelativePath(withNul), isFalse);
    });
  });

  group('normalizeRelativePath', () {
    test('collapses . and redundant separators', () {
      expect(normalizeRelativePath('photos/./a.jpg'), 'photos/a.jpg');
      expect(normalizeRelativePath('photos//a.jpg'), 'photos/a.jpg');
    });
    test('returns null for unsafe input', () {
      expect(normalizeRelativePath('../a'), isNull);
      expect(normalizeRelativePath('files/../../x'), isNull);
    });
  });

  test('staysWithinRoot mirrors normalization', () {
    expect(staysWithinRoot('files/photos/a.jpg'), isTrue);
    expect(staysWithinRoot('../escape'), isFalse);
  });
}
