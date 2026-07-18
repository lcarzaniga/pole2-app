import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as crypto;

import '../domain/backup_limits.dart';
import 'argon2_profile.dart';

/// Typed failures so the UI/validator can react precisely.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;
  @override
  String toString() => 'BackupFormatException: $message';
}

/// The container declares a newer format than this build understands.
class BackupUnsupportedVersionException implements Exception {
  const BackupUnsupportedVersionException(this.version);
  final int version;
}

/// Wrong password OR tampered/corrupt ciphertext — the two are deliberately
/// **not** distinguished (a key-check frame cannot reliably tell them apart).
class BackupPasswordOrCorruptException implements Exception {
  const BackupPasswordOrCorruptException();
}

/// The parsed outer header (metadata only — never a key or password).
class BackupHeader {
  const BackupHeader({
    required this.formatVersion,
    required this.encrypted,
    required this.json,
    required this.headerBytes,
  });

  final int formatVersion;
  final bool encrypted;
  final Map<String, dynamic> json;

  /// The exact serialized header bytes (magic..header JSON) — bound into every
  /// frame's AAD, so any header tampering breaks decryption.
  final Uint8List headerBytes;

  int get payloadPlaintextLength =>
      (json['payloadPlaintextLength'] as num).toInt();
}

/// Reads and writes the `.pole2backup` outer container: a small plaintext header
/// followed by either a raw ZIP payload (encrypted=false) or a sequence of
/// independently-authenticated AES-256-GCM frames whose plaintext is the ZIP.
class BackupContainer {
  BackupContainer._();

  static final AesGcm _aes = AesGcm.with256bits();

  // ---- Writing ----

  /// Encrypts [zipFile] into [out] using [password] (Argon2id → AES-256-GCM,
  /// framed). Streams frame-by-frame — never loads the whole archive in memory.
  static Future<void> writeEncrypted({
    required File zipFile,
    required File out,
    required String password,
    required Argon2Profile profile,
    required Map<String, dynamic> appHeader,
  }) async {
    final salt = _random(16);
    final baseNonce = _random(12);
    final key = await _deriveKey(password, salt, profile);

    final payloadLen = await zipFile.length();
    final header = <String, dynamic>{
      ...appHeader,
      'backupFormatVersion': kBackupFormatVersion,
      'encrypted': true,
      'payloadPlaintextLength': payloadLen,
      'frameSize': kFrameSize,
      'kdf': {...profile.toJson(), 'saltB64': base64.encode(salt)},
      'cipher': {
        'algorithm': 'aes-256-gcm',
        'baseNonceB64': base64.encode(baseNonce),
        'tagLength': 16,
      },
    };
    final headerBytes = _serializeHeader(encrypted: true, header: header);
    final headerHash = _sha256(headerBytes);

    final sink = out.openWrite();
    try {
      sink.add(headerBytes);
      final raf = await zipFile.open();
      try {
        var index = 0;
        var remaining = payloadLen;
        while (true) {
          final isFinal = remaining <= kFrameSize;
          final take = isFinal ? remaining : kFrameSize;
          final plain = await raf.read(take);
          final box = await _aes.encrypt(
            plain,
            secretKey: key,
            nonce: _frameNonce(baseNonce, index),
            aad: _aad(headerHash, index, isFinal),
          );
          final frame = Uint8List(box.cipherText.length + box.mac.bytes.length)
            ..setAll(0, box.cipherText)
            ..setAll(box.cipherText.length, box.mac.bytes);
          sink.add(_u32(frame.length));
          sink.add(frame);
          index++;
          remaining -= take;
          if (isFinal) break;
        }
      } finally {
        await raf.close();
      }
    } finally {
      await sink.close();
    }
  }

  /// Writes an explicitly **unencrypted** container: the same header (with
  /// encrypted=false) followed by the raw ZIP bytes.
  static Future<void> writePlaintext({
    required File zipFile,
    required File out,
    required Map<String, dynamic> appHeader,
  }) async {
    final payloadLen = await zipFile.length();
    final header = <String, dynamic>{
      ...appHeader,
      'backupFormatVersion': kBackupFormatVersion,
      'encrypted': false,
      'payloadPlaintextLength': payloadLen,
    };
    final headerBytes = _serializeHeader(encrypted: false, header: header);
    final sink = out.openWrite();
    try {
      sink.add(headerBytes);
      await sink.addStream(zipFile.openRead());
    } finally {
      await sink.close();
    }
  }

  // ---- Reading ----

  /// Parses and validates the outer header of [input] (no decryption).
  static Future<BackupHeader> readHeader(File input) async {
    final raf = await input.open();
    try {
      final magic = await raf.read(kBackupMagic.length);
      if (!_bytesEqual(magic, kBackupMagic)) {
        throw const BackupFormatException('not a Pole² backup');
      }
      final verFlags = await raf.read(2);
      if (verFlags.length < 2) {
        throw const BackupFormatException('truncated header');
      }
      final formatVersion = verFlags[0];
      final encrypted = verFlags[1] & 0x01 == 0x01;
      if (formatVersion > kBackupFormatVersion) {
        throw BackupUnsupportedVersionException(formatVersion);
      }
      final lenBytes = await raf.read(4);
      final headerLen = _readU32(lenBytes);
      if (headerLen <= 0 || headerLen > kMaxHeaderLength) {
        throw const BackupFormatException('bad header length');
      }
      final jsonBytes = await raf.read(headerLen);
      if (jsonBytes.length != headerLen) {
        throw const BackupFormatException('truncated header');
      }
      final Map<String, dynamic> json;
      try {
        json = jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>;
      } catch (_) {
        throw const BackupFormatException('bad header json');
      }
      final full = Uint8List(kBackupMagic.length + 2 + 4 + headerLen)
        ..setAll(0, magic)
        ..setAll(kBackupMagic.length, verFlags)
        ..setAll(kBackupMagic.length + 2, lenBytes)
        ..setAll(kBackupMagic.length + 6, jsonBytes);
      return BackupHeader(
        formatVersion: formatVersion,
        encrypted: encrypted,
        json: json,
        headerBytes: full,
      );
    } finally {
      await raf.close();
    }
  }

  /// Decrypts (or copies, if plaintext) [input] into a ZIP file at [outZip].
  /// Enforces frame continuity, exactly one final frame, no trailing data, and
  /// the declared plaintext length. Throws [BackupPasswordOrCorruptException] on
  /// any authentication/format failure of the payload.
  static Future<void> extractToZip({
    required File input,
    required File outZip,
    String? password,
  }) async {
    final header = await readHeader(input);
    final headerLen = header.headerBytes.length;
    final declaredLen = header.payloadPlaintextLength;
    if (declaredLen < 0 || declaredLen > kMaxTotalUncompressedBytes) {
      throw const BackupFormatException('bad payload length');
    }

    final raf = await input.open();
    final sink = outZip.openWrite();
    try {
      await raf.setPosition(headerLen);

      if (!header.encrypted) {
        var remaining = declaredLen;
        while (remaining > 0) {
          final chunk = await raf.read(
            remaining > kFrameSize ? kFrameSize : remaining,
          );
          if (chunk.isEmpty) break;
          sink.add(chunk);
          remaining -= chunk.length;
        }
        if (remaining != 0) {
          throw const BackupFormatException('truncated payload');
        }
        return;
      }

      if (password == null || password.isEmpty) {
        throw const BackupPasswordOrCorruptException();
      }
      final cipher = header.json['cipher'] as Map<String, dynamic>;
      final kdf = header.json['kdf'] as Map<String, dynamic>;
      // Parameter *bounds* are a DoS guard enforced by the validator before it
      // ever calls here; the container itself derives with whatever the header
      // declares (so tests can use fast params).
      final profile = Argon2Profile.fromJson(kdf);
      final salt = base64.decode(kdf['saltB64'] as String);
      final baseNonce = base64.decode(cipher['baseNonceB64'] as String);
      if (baseNonce.length != 12) {
        throw const BackupFormatException('bad nonce');
      }
      final key = await _deriveKey(password, salt, profile);
      final headerHash = _sha256(header.headerBytes);

      final total = await input.length();
      var index = 0;
      var produced = 0;
      while (true) {
        final pos = await raf.position();
        if (pos >= total) break; // clean EOF between frames
        final lenBytes = await raf.read(4);
        if (lenBytes.length != 4) {
          throw const BackupPasswordOrCorruptException();
        }
        final frameLen = _readU32(lenBytes);
        if (frameLen < 16 || frameLen > kFrameSize + 16) {
          throw const BackupPasswordOrCorruptException();
        }
        if (index >= kMaxFrameCount) {
          throw const BackupFormatException('too many frames');
        }
        final frame = await raf.read(frameLen);
        if (frame.length != frameLen) {
          throw const BackupPasswordOrCorruptException();
        }
        final isFinal = (await raf.position()) >= total;
        final ct = frame.sublist(0, frameLen - 16);
        final mac = frame.sublist(frameLen - 16);
        List<int> plain;
        try {
          plain = await _aes.decrypt(
            SecretBox(ct, nonce: _frameNonce(baseNonce, index), mac: Mac(mac)),
            secretKey: key,
            aad: _aad(headerHash, index, isFinal),
          );
        } on SecretBoxAuthenticationError {
          throw const BackupPasswordOrCorruptException();
        }
        sink.add(plain);
        produced += plain.length;
        if (produced > declaredLen) {
          throw const BackupPasswordOrCorruptException();
        }
        index++;
      }
      if (produced != declaredLen || index == 0) {
        throw const BackupPasswordOrCorruptException();
      }
    } finally {
      await sink.close();
      await raf.close();
    }
  }

  // ---- Helpers ----

  static Uint8List _serializeHeader({
    required bool encrypted,
    required Map<String, dynamic> header,
  }) {
    final jsonBytes = utf8.encode(jsonEncode(header));
    if (jsonBytes.length > kMaxHeaderLength) {
      throw const BackupFormatException('header too large');
    }
    final out = BytesBuilder();
    out.add(kBackupMagic);
    out.addByte(kBackupFormatVersion);
    out.addByte(encrypted ? 0x01 : 0x00);
    out.add(_u32(jsonBytes.length));
    out.add(jsonBytes);
    return out.toBytes();
  }

  static Future<SecretKey> _deriveKey(
    String password,
    List<int> salt,
    Argon2Profile profile,
  ) async {
    final argon2 = Argon2id(
      memory: profile.memoryKiB,
      iterations: profile.iterations,
      parallelism: profile.parallelism,
      hashLength: profile.hashLength,
    );
    return argon2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  /// 12-byte nonce: the 12-byte random base with its last 4 bytes set to the
  /// big-endian frame index — a unique nonce per (backup, frame).
  static List<int> _frameNonce(List<int> baseNonce, int index) {
    final n = Uint8List.fromList(baseNonce);
    final bd = ByteData.sublistView(n);
    bd.setUint32(8, index, Endian.big);
    return n;
  }

  static List<int> _aad(List<int> headerHash, int index, bool isFinal) {
    final b = BytesBuilder();
    b.add(headerHash);
    b.add(_u64(index));
    b.addByte(isFinal ? 1 : 0);
    return b.toBytes();
  }

  static Uint8List _u32(int v) {
    final b = ByteData(4)..setUint32(0, v, Endian.big);
    return b.buffer.asUint8List();
  }

  static int _readU32(List<int> b) {
    if (b.length != 4) throw const BackupFormatException('bad u32');
    return ByteData.sublistView(Uint8List.fromList(b)).getUint32(0, Endian.big);
  }

  static Uint8List _u64(int v) {
    final b = ByteData(8)..setUint64(0, v, Endian.big);
    return b.buffer.asUint8List();
  }

  static List<int> _sha256(List<int> bytes) =>
      crypto.sha256.convert(bytes).bytes;

  static Uint8List _random(int n) {
    final r = SecretKeyData.random(length: n);
    return Uint8List.fromList(r.bytes);
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
