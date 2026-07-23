import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How this build of Pole² was distributed.
///
/// Pole² ships today as a **direct** APK that updates itself from `latest.json`.
/// A future Google Play build may not do that: Play forbids an app installing
/// its own APK. Rather than branch on `Platform` or a product flavor everywhere,
/// the whole difference is expressed here and read through
/// [distributionProvider], so the UI is already correct when the Play artifact
/// arrives.
enum Distribution {
  /// Sideloaded / direct download. The self-updater is available.
  direct,

  /// Google Play. No self-update: the store owns updates.
  play;

  /// Whether this build may offer its own APK updater (the check action, the
  /// download + install flow, the startup prompt).
  bool get allowsSelfUpdate => this == Distribution.direct;
}

/// Compile-time selector: `--dart-define=POLE2_DISTRIBUTION=direct|play`.
///
/// Defaults to `direct` so every existing build command — and every existing
/// test — keeps today's behaviour untouched.
const String kDistributionDefine = String.fromEnvironment(
  'POLE2_DISTRIBUTION',
  defaultValue: 'direct',
);

Distribution distributionFromDefine(String raw) =>
    raw.trim().toLowerCase() == 'play'
    ? Distribution.play
    : Distribution.direct;

/// The active distribution. Overridable in tests to exercise the Play boundary
/// without a second build.
///
/// ⚠️ Play checklist (NOT part of this checkpoint): before any upload to Google
/// Play, the Play artifact must also drop `REQUEST_INSTALL_PACKAGES` from
/// `AndroidManifest.xml`. This provider hides the *UI*; it cannot remove a
/// manifest permission, which needs a flavor-specific manifest or a manifest
/// placeholder. The permission is deliberately left in place here so the direct
/// build keeps working exactly as it does today.
final distributionProvider = Provider<Distribution>(
  (ref) => distributionFromDefine(kDistributionDefine),
);
