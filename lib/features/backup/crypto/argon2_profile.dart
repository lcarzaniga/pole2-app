import '../domain/backup_limits.dart';

/// Argon2id parameters, serialized (without the key/password) into the backup
/// header so a backup made today can always be opened later.
class Argon2Profile {
  const Argon2Profile({
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
    this.hashLength = 32,
  });

  /// Memory in 1 KiB blocks (cryptography's `memory` unit).
  final int memoryKiB;
  final int iterations;
  final int parallelism;
  final int hashLength;

  /// The default *production* profile. Conservative on purpose — pure-Dart
  /// Argon2id is CPU-bound, and 12 MiB / 3 iterations keeps derivation in the
  /// ~0.5–1.5 s range on a Galaxy S23 class device while staying well within
  /// memory that low-RAM phones can allocate. **Must be confirmed by an
  /// on-device benchmark** before final release; adjust here only.
  static const production = Argon2Profile(
    memoryKiB: 12 * 1024, // 12 MiB
    iterations: 3,
    parallelism: 1,
  );

  bool get isWithinAcceptedBounds =>
      memoryKiB >= kArgon2MinMemoryKiB &&
      memoryKiB <= kArgon2MaxMemoryKiB &&
      iterations >= kArgon2MinIterations &&
      iterations <= kArgon2MaxIterations &&
      parallelism >= kArgon2MinParallelism &&
      parallelism <= kArgon2MaxParallelism &&
      hashLength == 32;

  Map<String, dynamic> toJson() => {
    'algorithm': 'argon2id',
    'memoryKiB': memoryKiB,
    'iterations': iterations,
    'parallelism': parallelism,
    'hashLength': hashLength,
  };

  static Argon2Profile fromJson(Map<String, dynamic> j) => Argon2Profile(
    memoryKiB: (j['memoryKiB'] as num).toInt(),
    iterations: (j['iterations'] as num).toInt(),
    parallelism: (j['parallelism'] as num).toInt(),
    hashLength: (j['hashLength'] as num?)?.toInt() ?? 32,
  );
}
