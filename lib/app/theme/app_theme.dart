import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_typography.dart';
import 'brand_colors.dart';

/// Central theme definition.
///
/// Both themes derive from a single seed ([AppColors.seed]) so light and dark
/// stay in sync, then layer on our design-system decisions: the Inter type
/// scale, the [BrandColors] extension, and calm, restrained component defaults.
/// Only what differs from Material 3's baseline is overridden.
///
/// This is where raw design values become the running theme. Features must
/// consume tokens (`Theme.of(context)`, `context.brand`, `AppSpacing`, …) and
/// never hardcode colors, sizes, radii or durations. See `docs/DESIGN_SYSTEM.md`.
abstract final class AppTheme {
  static ThemeData get light => _base(Brightness.light, BrandColors.light);
  static ThemeData get dark => _base(Brightness.dark, BrandColors.dark);

  static ThemeData _base(Brightness brightness, BrandColors brand) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      // ThemeData applies this family (and the scheme's text colors) to the
      // metrics-only TextTheme, so every text style renders in Inter.
      fontFamily: 'Inter',
      textTheme: AppTypography.textTheme,
      // Brand-semantic tokens, reachable via `context.brand`.
      extensions: <ThemeExtension<dynamic>>[brand],
      scaffoldBackgroundColor: colorScheme.surface,
      // Restraint: a flat, calm app bar rather than an elevated one.
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 1,
      ),
      // Soft, rounded cards with minimal (tonal) elevation — no heavy shadow.
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        color: colorScheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
      ),
      // Inputs use the default card radius and no loud focus borders.
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: AppRadii.borderMd),
      ),
      // Dividers are used sparingly; keep them faint when they do appear.
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
    );
  }
}
