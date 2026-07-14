import 'package:flutter/material.dart';

/// The **Pole²** brand wordmark.
///
/// This is the ONLY place the product name is typeset as a logo. It is drawn in
/// Work Sans SemiBold (the reserved brand face — the rest of the UI stays on
/// Inter) and follows the wordmark rules in `docs/BRAND_BIBLE.md`:
///
///  * only the `P` is capitalized — `Pole`, never `POLE`;
///  * slightly negative tracking (~-2.5%) so it reads as one compact unit;
///  * the superscript `²` is ~68% of the cap height, tucked close to the final
///    `e`, and never visually detached from the word.
///
/// The `²` is rendered as a raised, down-scaled `2` (not the Unicode
/// superscript glyph) so its size and position are controlled precisely and
/// consistently across platforms. Colour defaults to the ambient text colour,
/// so the wordmark adapts to light and dark surfaces on its own.
class PoleWordmark extends StatelessWidget {
  const PoleWordmark({
    super.key,
    this.size = 28,
    this.color,
    this.semanticLabel = 'Pole²',
  });

  /// Cap-ish size of the `Pole` letters in logical pixels.
  final double size;

  /// Overrides the wordmark colour; defaults to the ambient text colour.
  final Color? color;

  /// Read out by screen readers as the product name.
  final String semanticLabel;

  static const String _family = 'Work Sans';
  static const List<FontVariation> _semiBold = [FontVariation('wght', 600)];

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? DefaultTextStyle.of(context).style.color ?? Theme.of(context).colorScheme.onSurface;

    final base = TextStyle(
      fontFamily: _family,
      fontVariations: _semiBold,
      fontWeight: FontWeight.w600, // fallback for platforms ignoring variations
      fontSize: size,
      height: 1.0,
      letterSpacing: -size * 0.025, // compact optical tracking
      color: resolved,
    );

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            const TextSpan(text: 'Pole'),
            WidgetSpan(
              alignment: PlaceholderAlignment.top,
              child: Transform.translate(
                // Pull the exponent in toward the final `e` and drop it from the
                // ascent line so its top sits near the cap top of `Pole`.
                offset: Offset(-size * 0.03, size * 0.11),
                child: Text(
                  '2',
                  style: base.copyWith(fontSize: size * 0.68),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
