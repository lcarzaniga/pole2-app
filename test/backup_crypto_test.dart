import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/features/backup/crypto/argon2_profile.dart';
import 'package:project_kobe/features/backup/crypto/backup_container.dart';

void main() {
  // Fast KDF for tests — the container derives with whatever the header says;
  // parameter *bounds* are enforced by the validator, not here.
  const fast = Argon2Profile(memoryKiB: 256, iterations: 1, parallelism: 1);
  const appHeader = {
    'app': {'versionName': '1.0.11', 'versionCode': 2016},
    'platform': 'android',
    'createdAtUtc': '2026-07-18T00:00:00.000Z',
  };

  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('pole2_crypto'));
  tearDown(() => dir.deleteSync(recursive: true));

  File payload(List<int> bytes) {
    final f = File('${dir.path}/payload.zip');
    f.writeAsBytesSync(bytes);
    return f;
  }

  Future<List<int>> roundTrip(File input, String pw) async {
    final out = File('${dir.path}/out.zip');
    await BackupContainer.extractToZip(input: input, outZip: out, password: pw);
    return out.readAsBytesSync();
  }

  test('encrypted round-trip returns the exact payload', () async {
    final data = List<int>.generate(5000, (i) => i % 256);
    final out = File('${dir.path}/b.pole2backup');
    await BackupContainer.writeEncrypted(
      zipFile: payload(data),
      out: out,
      password: 'correct horse battery',
      profile: fast,
      appHeader: appHeader,
    );
    expect(await roundTrip(out, 'correct horse battery'), data);
  });

  test('multi-frame payload (> frame size) round-trips', () async {
    final data = Uint8List(1024 * 1024 + 12345)..fillRange(0, 1024, 7);
    final out = File('${dir.path}/b.pole2backup');
    await BackupContainer.writeEncrypted(
      zipFile: payload(data),
      out: out,
      password: 'pw-multi-frame-ok',
      profile: fast,
      appHeader: appHeader,
    );
    final back = await roundTrip(out, 'pw-multi-frame-ok');
    expect(back.length, data.length);
    expect(back.first, data.first);
    expect(back.last, data.last);
  });

  test('wrong password is a generic password/corrupt failure', () async {
    final out = File('${dir.path}/b.pole2backup');
    await BackupContainer.writeEncrypted(
      zipFile: payload([1, 2, 3, 4, 5]),
      out: out,
      password: 'the-right-one',
      profile: fast,
      appHeader: appHeader,
    );
    expect(
      () => roundTrip(out, 'the-wrong-one'),
      throwsA(isA<BackupPasswordOrCorruptException>()),
    );
  });

  test('a tampered ciphertext frame is rejected', () async {
    final out = File('${dir.path}/b.pole2backup');
    await BackupContainer.writeEncrypted(
      zipFile: payload(List<int>.generate(3000, (i) => i % 256)),
      out: out,
      password: 'tamper-test-pw',
      profile: fast,
      appHeader: appHeader,
    );
    final bytes = out.readAsBytesSync();
    bytes[bytes.length - 30] ^= 0xFF; // flip a payload byte
    out.writeAsBytesSync(bytes);
    expect(
      () => roundTrip(out, 'tamper-test-pw'),
      throwsA(isA<BackupPasswordOrCorruptException>()),
    );
  });

  test('a tampered header is rejected (bound into frame AAD)', () async {
    final out = File('${dir.path}/b.pole2backup');
    await BackupContainer.writeEncrypted(
      zipFile: payload(List<int>.generate(3000, (i) => i % 256)),
      out: out,
      password: 'header-tamper-pw',
      profile: fast,
      appHeader: appHeader,
    );
    final bytes = out.readAsBytesSync();
    // Flip a byte inside the JSON header (well past magic+version+len).
    bytes[40] ^= 0x01;
    out.writeAsBytesSync(bytes);
    expect(
      () => roundTrip(out, 'header-tamper-pw'),
      throwsA(isA<BackupPasswordOrCorruptException>()),
    );
  });

  test('truncation is rejected', () async {
    final out = File('${dir.path}/b.pole2backup');
    await BackupContainer.writeEncrypted(
      zipFile: payload(List<int>.generate(3000, (i) => i % 256)),
      out: out,
      password: 'truncate-test-pw',
      profile: fast,
      appHeader: appHeader,
    );
    final bytes = out.readAsBytesSync();
    out.writeAsBytesSync(bytes.sublist(0, bytes.length - 25));
    expect(
      () => roundTrip(out, 'truncate-test-pw'),
      throwsA(isA<BackupPasswordOrCorruptException>()),
    );
  });

  test('plaintext container round-trips and reports encrypted=false', () async {
    final data = List<int>.generate(2048, (i) => (i * 3) % 256);
    final out = File('${dir.path}/plain.pole2backup');
    await BackupContainer.writePlaintext(
      zipFile: payload(data),
      out: out,
      appHeader: appHeader,
    );
    final header = await BackupContainer.readHeader(out);
    expect(header.encrypted, isFalse);
    final back = File('${dir.path}/back.zip');
    await BackupContainer.extractToZip(input: out, outZip: back);
    expect(back.readAsBytesSync(), data);
  });

  test('not-a-backup magic is a format error', () async {
    final bogus = File('${dir.path}/x.bin')
      ..writeAsBytesSync([1, 2, 3, 4, 5, 6, 7, 8]);
    expect(
      () => BackupContainer.readHeader(bogus),
      throwsA(isA<BackupFormatException>()),
    );
  });
}
