import 'package:flutter/material.dart';

/// The type scale, mapped to Material 3 roles.
///
/// Only three weights are used — Regular (400), Medium (500), SemiBold (600).
/// No Bold/Black: loud weights break the calm. `height` is the line-height
/// multiplier (line-height ÷ font-size). Colors and the Inter font family are
/// applied by [ThemeData] (via `fontFamily` and the color scheme), so styles
/// here carry metrics only. See `docs/DESIGN_SYSTEM.md` §2.
abstract final class AppTypography {
  static const TextTheme textTheme = TextTheme(
    // Rare hero moment (empty-state welcome). 32 / 40
    displaySmall: TextStyle(
      fontSize: 32,
      height: 40 / 32,
      fontWeight: FontWeight.w400,
    ),
    // Screen titles, section heroes. 24 / 32
    headlineSmall: TextStyle(
      fontSize: 24,
      height: 32 / 24,
      fontWeight: FontWeight.w500,
    ),
    // Card / possession titles. 20 / 28
    titleLarge: TextStyle(
      fontSize: 20,
      height: 28 / 20,
      fontWeight: FontWeight.w500,
    ),
    // Sub-headers, list leading text. 16 / 24
    titleMedium: TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w500,
    ),
    // Primary reading text. 16 / 24
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w400,
    ),
    // Secondary text, descriptions. 14 / 20
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w400,
    ),
    // Buttons and actions. 14 / 20
    labelLarge: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w500,
    ),
    // Metadata, timestamps, quiet captions. 12 / 16
    labelSmall: TextStyle(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w500,
    ),
  );
}
