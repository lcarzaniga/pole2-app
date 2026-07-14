/// Spacing scale — the single source of truth for gaps, padding and margins.
///
/// Base unit is 4dp; every value is a multiple. These are brightness-invariant
/// constants (they never differ between light and dark), so they live as plain
/// constants rather than in a [ThemeExtension] — interpolating them would be
/// ceremony with no benefit. Features import and use `AppSpacing.lg` directly.
///
/// See `docs/DESIGN_SYSTEM.md` §3. Space is our primary tool for calm: when in
/// doubt, add space and remove a divider.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;

  /// Default screen margin and card padding.
  static const double lg = 16;

  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Hero vertical rhythm (e.g. empty-state generosity).
  static const double xxxxl = 64;
}
