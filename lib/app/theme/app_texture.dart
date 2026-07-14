/// Texture tokens — the barely-there honeycomb material of Pole².
///
/// These govern the faint background hexagon motif ([HexBackground]). They are
/// tokens (not per-screen magic values) so the texture reads identically on
/// every surface it appears on: Home, the dossier, calm empty sections.
///
/// `outlineVariant` reads much fainter on a dark surface than a light one, so
/// the dark opacity is lifted to keep the texture *equally* subtle-present in
/// both themes rather than vanishing in dark.
abstract final class AppTexture {
  /// Line opacity applied to `outlineVariant` on light surfaces.
  static const double lightLineOpacity = 0.28;

  /// Line opacity applied to `outlineVariant` on dark surfaces.
  static const double darkLineOpacity = 0.55;

  /// Hex cell radius as a fraction of the painted width — large and sparse, so
  /// it registers as calm structure, never busy wallpaper.
  static const double cellRadiusFactor = 0.085;
}
