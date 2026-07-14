import 'package:flutter/widgets.dart';

/// Corner-radius scale. Soft and rounded throughout — sharp corners read as
/// clinical and alarming, which is off-brand for a calm keeper.
///
/// Brightness-invariant, so exposed as plain constants. See
/// `docs/DESIGN_SYSTEM.md` §3.3.
abstract final class AppRadii {
  /// Chips and small controls.
  static const double sm = 8;

  /// Default cards and inputs.
  static const double md = 12;

  /// Prominent cards and sheets.
  static const double lg = 16;

  /// Bottom sheets and large surfaces.
  static const double xl = 24;

  // Convenience [BorderRadius] values for direct use in widgets.
  static const BorderRadius borderSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius borderMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius borderLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius borderXl = BorderRadius.all(Radius.circular(xl));
}
