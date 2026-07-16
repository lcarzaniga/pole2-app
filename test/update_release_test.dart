import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:project_kobe/features/update/model/update_release.dart';
import 'package:project_kobe/features/update/update_service.dart';

const _validJson = '''
{
  "versionName": "1.0.1",
  "versionCode": 2006,
  "apkUrl": "https://github.com/lcarzaniga/pole2-app/releases/download/v1.0.1%2B2006/pole2-1.0.1-2006.apk",
  "sha256": "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  "notes": ["Gestione dei luoghi", "Launcher migliorato"],
  "mandatory": false
}
''';

void main() {
  group('UpdateRelease.tryParse', () {
    test('parses a valid descriptor', () {
      final r = UpdateRelease.tryParse(_validJson)!;
      expect(r.versionName, '1.0.1');
      expect(r.versionCode, 2006);
      expect(r.apkUrl, startsWith('https://'));
      expect(r.sha256.length, 64);
      expect(r.notes, hasLength(2));
      expect(r.mandatory, isFalse);
    });

    test('rejects malformed JSON', () {
      expect(UpdateRelease.tryParse('{not json'), isNull);
      expect(UpdateRelease.tryParse('[]'), isNull);
      expect(UpdateRelease.tryParse('42'), isNull);
    });

    test('rejects missing / wrong-typed required fields', () {
      expect(UpdateRelease.tryParse('{"versionCode":2006,"apkUrl":"https://a","sha256":"${'a' * 64}"}'),
          isNull); // no versionName
      expect(
          UpdateRelease.tryParse(
              '{"versionName":"x","versionCode":"2006","apkUrl":"https://a","sha256":"${'a' * 64}"}'),
          isNull); // versionCode not int
    });

    test('rejects a non-HTTPS apkUrl', () {
      final json =
          '{"versionName":"x","versionCode":6,"apkUrl":"http://insecure/a.apk","sha256":"${'a' * 64}"}';
      expect(UpdateRelease.tryParse(json), isNull);
    });

    test('rejects an invalid sha256', () {
      final short =
          '{"versionName":"x","versionCode":6,"apkUrl":"https://a","sha256":"abc"}';
      final nonHex =
          '{"versionName":"x","versionCode":6,"apkUrl":"https://a","sha256":"${'z' * 64}"}';
      expect(UpdateRelease.tryParse(short), isNull);
      expect(UpdateRelease.tryParse(nonHex), isNull);
    });

    test('notes optional, mandatory defaults to false', () {
      final r = UpdateRelease.tryParse(
          '{"versionName":"x","versionCode":6,"apkUrl":"https://a","sha256":"${'a' * 64}"}')!;
      expect(r.notes, isEmpty);
      expect(r.mandatory, isFalse);
    });
  });

  group('isNewerThan', () {
    final r = UpdateRelease.tryParse(_validJson)!; // 2006
    test('newer > installed', () => expect(r.isNewerThan(2005), isTrue));
    test('equal is not newer', () => expect(r.isNewerThan(2006), isFalse));
    test('older is not newer', () => expect(r.isNewerThan(2007), isFalse));
  });

  group('fetchLatestRelease', () {
    test('200 + valid → release', () async {
      final client = MockClient((_) async => http.Response(_validJson, 200));
      final r = await fetchLatestRelease(client, url: 'https://example/latest.json');
      expect(r?.versionCode, 2006);
    });
    test('404 → null (silent)', () async {
      final client = MockClient((_) async => http.Response('nope', 404));
      expect(await fetchLatestRelease(client, url: 'https://example/latest.json'), isNull);
    });
    test('200 + malformed → null', () async {
      final client = MockClient((_) async => http.Response('{bad', 200));
      expect(await fetchLatestRelease(client, url: 'https://example/latest.json'), isNull);
    });
    test('non-HTTPS url → null (never requested)', () async {
      final client = MockClient((_) async => http.Response(_validJson, 200));
      expect(await fetchLatestRelease(client, url: 'http://example/latest.json'), isNull);
    });
  });

  group('sha256OfFile', () {
    test('matches a known vector for "abc"', () async {
      final dir = Directory.systemTemp.createTempSync('kobe_sha');
      addTearDown(() => dir.deleteSync(recursive: true));
      final f = File('${dir.path}/x')..writeAsStringSync('abc');
      expect(await sha256OfFile(f),
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    });
  });
}
