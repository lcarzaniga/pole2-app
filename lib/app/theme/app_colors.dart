import 'package:flutter/material.dart';

/// Brand color tokens.
///
/// The whole Material 3 palette (light and dark) is derived from a single
/// [seed] via `ColorScheme.fromSeed`. Keeping one seed here means re-theming
/// the entire app is a one-line change, and it leaves room to adopt platform
/// dynamic color later without touching call sites.
abstract final class AppColors {
  /// A calm teal-green — chosen to evoke trust, safety and stability, the
  /// core feelings Project Kobe is meant to give its users. The primary brand
  /// identity; this is never replaced.
  static const Color seed = Color(0xFF2E6B5E);

  // --- Tanzania-inspired secondary accents (see docs/BRAND_BIBLE.md §Accents).
  // Defined as tokens for restraint and reuse. Used sparingly and never all at
  // once: petrol stays the identity; red stays reserved for genuine failure;
  // attention amber stays calm. Ocean blue and charcoal are held in reserve.

  /// Deep Indian Ocean blue — a rare secondary brand surface only.
  static const Color oceanBlue = Color(0xFF1C6E8C);

  /// Warm sun-gold — used only as a very small, transient guardian/shell detail
  /// (the idle-cue highlight). Never as UI chrome or text.
  static const Color sunGold = Color(0xFFE0A83D);

  /// Very dark charcoal — held in reserve for future dark brand surfaces.
  static const Color charcoal = Color(0xFF20211F);

  /// Warm ivory — the P² on the icon and the wordmark on petrol.
  static const Color warmIvory = Color(0xFFF6F1E7);

  // --- Canonical Kobe (docs/BRAND_BIBLE.md §10c) — exact values published on the
  // landing (pole2.it). The illustrated (character) colourway. These are fixed
  // brand values, not theme-derived, so Kobe reads identically everywhere.

  /// Kobe shell — one continuous light-mint surface (darkened ~8% from the
  /// original #CFE8DB for stronger contrast on white; still clearly lighter than
  /// the body).
  static const Color kobeShell = Color(0xFFBFDACD);

  /// Kobe body + all dark joint edges + shell border (dark petrol).
  static const Color kobeBody = Color(0xFF1F4638);

  /// Kobe grout — the light groove channel between the dark joint edges.
  static const Color kobeGrout = Color(0xFFE7F4EE);
}
