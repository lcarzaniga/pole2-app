/// Hard, documented limits for the backup format. They are generous enough for
/// realistic future Pole² galleries but finite, so a malicious or corrupt file
/// can never make restore/validation allocate unbounded memory, spin forever, or
/// overflow a size counter. All size arithmetic that combines these must be done
/// in checked/guarded steps (see the validator).
library;

/// Outer container ("POLE2BK") magic bytes.
const List<int> kBackupMagic = [
  0x50,
  0x4F,
  0x4C,
  0x45,
  0x32,
  0x42,
  0x4B,
]; // POLE2BK

/// The only container/backup format version this build writes and accepts.
const int kBackupFormatVersion = 1;

/// Encrypted-payload frame size (plaintext bytes per AEAD frame): 1 MiB.
const int kFrameSize = 1024 * 1024;

/// Upper bound on the outer JSON header (bytes). The header is tiny metadata;
/// anything larger is rejected before allocation.
const int kMaxHeaderLength = 64 * 1024; // 64 KiB

/// Max number of entries inside the inner ZIP.
const int kMaxZipEntries = 200000;

/// Max size of any single uncompressed ZIP entry: 512 MiB (a very large photo
/// or the DB) — finite but roomy.
const int kMaxEntryBytes = 512 * 1024 * 1024;

/// Max total uncompressed size across all entries: 8 GiB.
const int kMaxTotalUncompressedBytes = 8 * 1024 * 1024 * 1024;

/// Max overall inflate ratio (total uncompressed / compressed) — a decompression
/// -bomb guard. Photos are already compressed, so real backups sit near 1×.
const int kMaxCompressionRatio = 200;

/// Max number of AEAD frames in an encrypted payload (bounds a truncated/forged
/// stream). At 1 MiB/frame this allows ~8 GiB of ciphertext.
const int kMaxFrameCount = 8192;

/// Accepted Argon2id parameter bounds (defensive; reject absurd headers before
/// attempting a KDF that could OOM or never finish).
const int kArgon2MinMemoryKiB = 8 * 1024; // 8 MiB
const int kArgon2MaxMemoryKiB = 512 * 1024; // 512 MiB
const int kArgon2MinIterations = 1;
const int kArgon2MaxIterations = 10;
const int kArgon2MinParallelism = 1;
const int kArgon2MaxParallelism = 4;

/// Minimum backup password length.
const int kMinPasswordLength = 10;

/// Canonical inner paths.
const String kManifestPath = 'manifest.json';
const String kDatabaseArchivePath = 'database/pole2.sqlite';
const String kFilesPrefix = 'files/';
