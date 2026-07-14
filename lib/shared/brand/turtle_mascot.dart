import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';

/// The turtle mascot, at rest.
///
/// The guardian of Kobe — protection, patience, memory, home. It is a quiet
/// *presence*, never an assistant: it does not speak and it does not perform.
/// Its shell is a honeycomb of regular hexagons, making the brand's core motif
/// literal. Drawn entirely with a [CustomPainter] so it needs no image asset
/// and scales crisply at any size.
///
/// At rest it "breathes" — an almost imperceptible slow scale that signals a
/// calm, living guardian. This honors the OS "reduce motion" setting: when
/// reduced, the turtle simply holds still.
///
/// Colors are read from the active [ColorScheme]; nothing here is hardcoded.
class TurtleMascot extends StatefulWidget {
  const TurtleMascot({super.key, this.size = 96, this.highlight});

  /// Intrinsic illustration size (component-owned, not layout spacing).
  final double size;

  /// Optional idle-cue driver (0→1): a soft warm-gold gloss sweeps once across
  /// the shell when this runs. Null (the default) means no cue.
  final Animation<double>? highlight;

  @override
  State<TurtleMascot> createState() => _TurtleMascotState();
}

class _TurtleMascotState extends State<TurtleMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _breath;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _breath = Tween<double>(begin: 0.985, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.gentle),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final driver = widget.highlight == null
        ? _breath
        : Listenable.merge([_breath, widget.highlight!]);
    return AnimatedBuilder(
      animation: driver,
      builder: (context, _) {
        return Transform.scale(
          scale: _breath.value,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _TurtlePainter(
              body: scheme.primary,
              shellFill: scheme.primaryContainer,
              shellStroke: scheme.primary,
              hexLine: scheme.primary.withValues(alpha: 0.28),
              highlight: widget.highlight?.value ?? 0,
              highlightColor: AppColors.sunGold,
            ),
          ),
        );
      },
    );
  }
}

class _TurtlePainter extends CustomPainter {
  _TurtlePainter({
    required this.body,
    required this.shellFill,
    required this.shellStroke,
    required this.hexLine,
    this.highlight = 0,
    required this.highlightColor,
  });

  final Color body;
  final Color shellFill;
  final Color shellStroke;
  final Color hexLine;

  /// 0→1 sweep position of the idle-cue gloss (0 = no gloss drawn).
  final double highlight;
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    final r = s * 0.34;

    final bodyPaint = Paint()
      ..color = body
      ..isAntiAlias = true;

    // Limbs, drawn first so the shell overlaps them naturally.
    final legRadius = r * 0.22;
    for (final deg in const [45, 135, 225, 315]) {
      final a = deg * math.pi / 180;
      final legCenter = c + Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawCircle(legCenter, legRadius, bodyPaint);
    }

    // Head (12 o'clock).
    canvas.drawCircle(c + Offset(0, -(r + r * 0.16)), r * 0.26, bodyPaint);

    // Tail (6 o'clock).
    final tailBase = c + Offset(0, r);
    final tail = Path()
      ..moveTo(tailBase.dx - r * 0.12, tailBase.dy)
      ..lineTo(tailBase.dx + r * 0.12, tailBase.dy)
      ..lineTo(tailBase.dx, tailBase.dy + r * 0.24)
      ..close();
    canvas.drawPath(tail, bodyPaint);

    // Shell: a filled dome with a clipped honeycomb of regular hexagons.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(c, r, Paint()..color = shellFill);

    final hexR = r * 0.30;
    final hStep = 1.5 * hexR;
    final vStep = math.sqrt(3) * hexR;
    final hexPaint = Paint()
      ..color = hexLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, r * 0.03)
      ..isAntiAlias = true;

    for (double x = c.dx - r - hexR; x <= c.dx + r + hexR; x += hStep) {
      final column = ((x - c.dx) / hStep).round();
      final yShift = column.isOdd ? vStep / 2 : 0.0;
      for (double y = c.dy - r - vStep; y <= c.dy + r + vStep; y += vStep) {
        canvas.drawPath(_hexagon(Offset(x, y + yShift), hexR), hexPaint);
      }
    }

    // Idle cue: a soft warm-gold gloss travelling once across the shell. Kept
    // inside the shell clip, additive and low-alpha, so it reads as a gentle
    // glimmer of life — never a flash or a notification.
    if (highlight > 0) {
      final h = highlight.clamp(0.0, 1.0);
      final env = math.sin(math.pi * h); // fades in and out across the sweep
      final pos = Offset(
        c.dx + (h * 2 - 1) * r,
        c.dy + (h * 2 - 1) * r * 0.5,
      );
      final gloss = Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            highlightColor.withValues(alpha: 0.40 * env),
            highlightColor.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: pos, radius: r * 0.75));
      canvas.drawCircle(pos, r * 0.75, gloss);
    }
    canvas.restore();

    // Shell rim.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = shellStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06
        ..isAntiAlias = true,
    );
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
  bool shouldRepaint(_TurtlePainter old) =>
      old.body != body ||
      old.shellFill != shellFill ||
      old.shellStroke != shellStroke ||
      old.hexLine != hexLine ||
      old.highlight != highlight ||
      old.highlightColor != highlightColor;
}
