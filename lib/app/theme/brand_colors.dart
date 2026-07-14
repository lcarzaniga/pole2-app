import 'package:flutter/material.dart';

/// Brand-semantic colors that Material 3's generated roles don't express.
///
/// These encode manifesto emotions (`kept` = "it's safe now", `attention` =
/// calm heads-up). They differ between light and dark and must interpolate on
/// theme change, so they live in a [ThemeExtension] (unlike the invariant
/// spacing/motion tokens). See `docs/DESIGN_SYSTEM.md` §1.3.
///
/// Access from a widget via `context.brand.kept`.
///
/// NOTE: `error` (Material's red) stays quarantined for genuine failures only.
/// Warnings, upcoming expirations and reminders use [attention] — calm amber,
/// never alarm.
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({
    required this.kept,
    required this.onKept,
    required this.attention,
    required this.onAttention,
    required this.shellTint,
  });

  /// "It's safe now" confirmation — a calm green settle, not a celebratory pop.
  final Color kept;
  final Color onKept;

  /// Calm heads-up (e.g. warranty approaching). Muted amber — never alarm red.
  final Color attention;
  final Color onAttention;

  /// The subtle hexagon-shell background texture; barely-there brand presence.
  final Color shellTint;

  static const BrandColors light = BrandColors(
    kept: Color(0xFF2F6E5C),
    onKept: Color(0xFFFFFFFF),
    attention: Color(0xFF8A6D2F),
    onAttention: Color(0xFFFFFFFF),
    shellTint: Color(0xFFE7F1EC),
  );

  static const BrandColors dark = BrandColors(
    kept: Color(0xFF7FD6BE),
    onKept: Color(0xFF06251C),
    attention: Color(0xFFE4C079),
    onAttention: Color(0xFF241B06),
    shellTint: Color(0xFF16221D),
  );

  @override
  BrandColors copyWith({
    Color? kept,
    Color? onKept,
    Color? attention,
    Color? onAttention,
    Color? shellTint,
  }) {
    return BrandColors(
      kept: kept ?? this.kept,
      onKept: onKept ?? this.onKept,
      attention: attention ?? this.attention,
      onAttention: onAttention ?? this.onAttention,
      shellTint: shellTint ?? this.shellTint,
    );
  }

  @override
  BrandColors lerp(covariant ThemeExtension<BrandColors>? other, double t) {
    if (other is! BrandColors) return this;
    return BrandColors(
      kept: Color.lerp(kept, other.kept, t)!,
      onKept: Color.lerp(onKept, other.onKept, t)!,
      attention: Color.lerp(attention, other.attention, t)!,
      onAttention: Color.lerp(onAttention, other.onAttention, t)!,
      shellTint: Color.lerp(shellTint, other.shellTint, t)!,
    );
  }
}

/// Ergonomic access to [BrandColors] from any widget: `context.brand.kept`.
extension BrandColorsX on BuildContext {
  BrandColors get brand => Theme.of(this).extension<BrandColors>()!;
}
