import 'package:flutter/animation.dart';

/// Motion tokens — durations and easing curves.
///
/// Motion in Kobe is slow, natural reassurance, never spectacle (the unhurried
/// turtle). These are brightness-invariant constants. See
/// `docs/DESIGN_SYSTEM.md` §5.
///
/// IMPORTANT: every animation must also honor the OS "reduce motion" setting —
/// when reduced, replace movement/scale with a short opacity fade (≤ [micro])
/// or nothing. That is enforced at the call site, not here.
abstract final class AppDurations {
  /// State tints, ripples, tiny feedback.
  static const Duration micro = Duration(milliseconds: 120);

  /// Small transitions and fades.
  static const Duration short = Duration(milliseconds: 220);

  /// Screen and element transitions.
  static const Duration medium = Duration(milliseconds: 320);

  /// The signature turtle shell-unfold. Must be interruptible and skippable,
  /// and is used only when creating a new possession.
  static const Duration signature = Duration(milliseconds: 560);
}

/// Easing curves. Nothing snaps or overshoots aggressively.
abstract final class AppCurves {
  /// Soft decelerate for entrances — things arrive and settle.
  static const Curve gentle = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Symmetric ease for reversible transitions.
  static const Curve standard = Cubic(0.4, 0.0, 0.2, 1.0);

  /// A barely-there settle for the "kept" confirmation — no spring overshoot.
  static const Curve settle = Cubic(0.33, 0.0, 0.0, 1.0);
}
