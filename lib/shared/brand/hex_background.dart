import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_texture.dart';

/// A very faint honeycomb texture painted behind its [child].
///
/// This is the hexagon-shell motif used as *identity and texture* — never
/// decoration. It is deliberately barely-there: large, low-contrast cells that
/// register subconsciously as "structure and order" without drawing attention
/// or adding visual noise. The line color derives from the theme, so it stays
/// subtle in both light and dark.
class HexBackground extends StatelessWidget {
  const HexBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // outlineVariant reads much fainter on a dark surface than a light one, so
    // we lift its opacity in dark to keep the texture *equally* subtle-present
    // in both themes rather than vanishing in dark.
    final isDark = theme.brightness == Brightness.dark;
    final line = theme.colorScheme.outlineVariant.withValues(
        alpha: isDark ? AppTexture.darkLineOpacity : AppTexture.lightLineOpacity);
    return CustomPaint(
      painter: _HexTexturePainter(line: line),
      child: child,
    );
  }
}

class _HexTexturePainter extends CustomPainter {
  _HexTexturePainter({required this.line});

  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    // Large cells relative to width → a calm, sparse honeycomb.
    final hexR = size.width * AppTexture.cellRadiusFactor;
    final hStep = 1.5 * hexR;
    final vStep = math.sqrt(3) * hexR;
    final paint = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = true;

    for (double x = -hexR; x <= size.width + hexR; x += hStep) {
      final column = (x / hStep).round();
      final yShift = column.isOdd ? vStep / 2 : 0.0;
      for (double y = -vStep; y <= size.height + vStep; y += vStep) {
        canvas.drawPath(_hexagon(Offset(x, y + yShift), hexR), paint);
      }
    }
  }

  Path _hexagon(Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = (60 * i) * math.pi / 180;
      final v = center + Offset(math.cos(a), math.sin(a)) * radius;
      i == 0 ? path.moveTo(v.dx, v.dy) : path.lineTo(v.dx, v.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_HexTexturePainter old) => old.line != line;
}
