import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Kobe — the guardian, in the **canonical geometry** (docs/BRAND_BIBLE.md §10c),
/// reproduced 1:1 from the published landing (pole2.it). Drawn with a
/// [CustomPainter] so it needs no asset and stays crisp at any size / DPI.
///
/// Shell (the fixed identity): a vertical ellipse (w/h ≈ 0.86) engraved with a
/// central true regular flat-top hexagon (R = 0.70·rx) and six radial joints
/// through its vertices → exactly **7 scutes**. Plates are one continuous
/// surface; separation is the **grout joint** (dark edge · light groove · dark
/// edge), same construction on the border. Body: teardrop head, pointed tail,
/// two equal leg pairs.
///
/// Behaviour: the **shell never moves**; head+tail rotate one way and the front+
/// rear legs the opposite way in a calm idle posture after inactivity, then
/// settle. Honors "reduce motion" (holds still). The optional [highlight] drives
/// a brief soft shell glow (used as a caller-owned idle cue on the launcher).
class TurtleMascot extends StatefulWidget {
  const TurtleMascot({super.key, this.size = 96, this.highlight});

  /// Intrinsic illustration size (component-owned, not layout spacing).
  final double size;

  /// Optional soft-glow cue (0→1): a gentle warm glimmer over the shell. Null
  /// (the default) means no cue.
  final Animation<double>? highlight;

  @override
  State<TurtleMascot> createState() => _TurtleMascotState();
}

class _TurtleMascotState extends State<TurtleMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle; // one idle gesture (~840 ms)
  Timer? _timer;
  final math.Random _rng = math.Random();
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 840),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          _idle.value = 0;
          _schedule(); // a fresh random delay after each gesture
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reduce) {
      _timer?.cancel();
      _idle.value = 0;
    } else {
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (_reduce || !mounted) return;
    // ~25–50 s, matching the landing/§13a idle window.
    final delay = Duration(milliseconds: 25000 + _rng.nextInt(25000));
    _timer = Timer(delay, () {
      if (!mounted || _reduce) return;
      _idle.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _idle.dispose();
    super.dispose();
  }

  // Idle envelope: 0 → +1 (hold) → −1 (hold) → 0, matching the CSS keyframes.
  double _wave(double p) {
    double ease(double t) => t * t * (3 - 2 * t); // smoothstep
    if (p <= 0.28) return ease(p / 0.28);
    if (p <= 0.42) return 1;
    if (p <= 0.72) return 1 - 2 * ease((p - 0.42) / 0.30);
    if (p <= 0.86) return -1;
    return -1 + ease((p - 0.86) / 0.14);
  }

  @override
  Widget build(BuildContext context) {
    final cue = widget.highlight;
    final driver = cue == null
        ? _idle
        : Listenable.merge([_idle, cue]);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: driver,
        builder: (context, _) {
          final w = _reduce ? 0.0 : _wave(_idle.value);
          const d = math.pi / 180;
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _KobePainter(
              // head + tail tips to one side; front + rear legs to the other
              headRad: 3.6 * w * d,
              tailRad: -3.6 * w * d,
              frontRad: -2.4 * w * d,
              rearRad: 2.4 * w * d,
              glow: cue?.value ?? 0,
            ),
          );
        },
      ),
    );
  }
}

/// Paints Kobe in a 200-unit design space (from the landing), scaled to [size].
class _KobePainter extends CustomPainter {
  _KobePainter({
    required this.headRad,
    required this.tailRad,
    required this.frontRad,
    required this.rearRad,
    this.glow = 0,
  });

  final double headRad, tailRad, frontRad, rearRad, glow;

  // --- Canonical constants (published k12/k13 geometry, 200-unit space) -------
  static const double _cx = 100, _cy = 104, _sc = 0.9;
  static const double _rx = 57 * _sc, _ry = 66 * _sc; // 51.3 × 59.4 (w/h ≈ 0.86)
  static const double _hexRad = 0.70 * _rx; // central hexagon circumradius
  static const List<double> _angs = [0, 60, 120, 180, 240, 300];
  // grout widths (half-widths), scaled with the shell
  static const double _dIn = 1.0 * _sc, _dOut = 1.3 * _sc;
  static const double _lIn = 0.5 * _sc, _lOut = 0.78 * _sc;
  static const double _bw = 3.6 * _sc; // single dark rim (simplified border)

  static const Color _shell = AppColors.kobeShell;
  static const Color _body = AppColors.kobeBody;
  static const Color _grout = AppColors.kobeGrout;

  Offset _vertex(double deg) =>
      Offset(_cx + _hexRad * math.cos(deg * math.pi / 180),
          _cy + _hexRad * math.sin(deg * math.pi / 180));

  // ray from the shell centre through a vertex, out to the ellipse
  Offset _rayEllipse(Offset p) {
    final dx = p.dx - _cx, dy = p.dy - _cy;
    final ax = p.dx - _cx, ay = p.dy - _cy;
    final a = (dx * dx) / (_rx * _rx) + (dy * dy) / (_ry * _ry);
    final b = 2 * ((ax * dx) / (_rx * _rx) + (ay * dy) / (_ry * _ry));
    final c = (ax * ax) / (_rx * _rx) + (ay * ay) / (_ry * _ry) - 1;
    final t = (-b + math.sqrt(b * b - 4 * a * c)) / (2 * a);
    return Offset(p.dx + t * dx, p.dy + t * dy);
  }

  // tapered grout band (filled trapezoid centred on a joint)
  Path _band(Offset pi, Offset po, double hIn, double hOut) {
    final dx = po.dx - pi.dx, dy = po.dy - pi.dy;
    final l = math.sqrt(dx * dx + dy * dy);
    final px = -dy / (l == 0 ? 1 : l), py = dx / (l == 0 ? 1 : l);
    return Path()
      ..moveTo(pi.dx + px * hIn, pi.dy + py * hIn)
      ..lineTo(po.dx + px * hOut, po.dy + py * hOut)
      ..lineTo(po.dx - px * hOut, po.dy - py * hOut)
      ..lineTo(pi.dx - px * hIn, pi.dy - py * hIn)
      ..close();
  }

  Path _hexPath() {
    final path = Path();
    for (var i = 0; i < _angs.length; i++) {
      final v = _vertex(_angs[i]);
      i == 0 ? path.moveTo(v.dx, v.dy) : path.lineTo(v.dx, v.dy);
    }
    return path..close();
  }

  Path _headPath(double s) {
    final hx = _cx, yBase = _cy - _ry + 13;
    final nose = 10 * s, neck = 6 * s, hh = 33 * s;
    final yN = yBase - hh, nc = yN + nose, bh = neck * 2.0, yB = yBase + 6;
    final yk = yBase - 6 * s;
    return Path()
      ..moveTo(hx - nose, nc)
      ..arcToPoint(Offset(hx + nose, nc),
          radius: Radius.circular(nose), clockwise: true)
      ..cubicTo(hx + nose, nc + hh * 0.5, hx + neck, yk - 4, hx + neck, yk)
      ..cubicTo(hx + neck, yk + 7, hx + bh, yB - 6, hx + bh, yB)
      ..lineTo(hx - bh, yB)
      ..cubicTo(hx - bh, yB - 6, hx - neck, yk + 7, hx - neck, yk)
      ..cubicTo(hx - neck, yk - 4, hx - nose, nc + hh * 0.5, hx - nose, nc)
      ..close();
  }

  Path get _legShape => Path()
    ..moveTo(-7, -9)
    ..quadraticBezierTo(-12, -10, -13, -3)
    ..quadraticBezierTo(-14, 3, -10, 8)
    ..quadraticBezierTo(-5, 12, 4, 11)
    ..quadraticBezierTo(13, 10, 15, 2)
    ..quadraticBezierTo(16, -6, 9, -9)
    ..quadraticBezierTo(1, -12, -7, -9)
    ..close();

  Path _tailPath() => Path()
    ..moveTo(_cx - 5.5, _cy + _ry - 3)
    ..quadraticBezierTo(_cx, _cy + _ry + 2, _cx + 5.5, _cy + _ry - 3)
    ..lineTo(_cx, _cy + _ry + 15)
    ..close();

  // draw a body group rotated about the shell centre
  void _group(Canvas canvas, double rad, void Function() draw) {
    canvas.save();
    canvas.translate(_cx, _cy);
    canvas.rotate(rad);
    canvas.translate(-_cx, -_cy);
    draw();
    canvas.restore();
  }

  void _leg(Canvas canvas, double x, double y, double rotDeg, Paint p) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(rotDeg * math.pi / 180);
    canvas.scale(1.05);
    canvas.drawPath(_legShape, p);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200, size.height / 200);
    final bodyP = Paint()
      ..color = _body
      ..isAntiAlias = true;

    // Body groups (dark), UNDER the shell. Front+rear legs one way; head+tail
    // the other. Rear legs closer to the tail, front legs closer to the head.
    _group(canvas, rearRad, () {
      _leg(canvas, _cx - _rx * 0.90, _cy + _ry * 0.52, 150, bodyP);
      _leg(canvas, _cx + _rx * 0.90, _cy + _ry * 0.52, 30, bodyP);
    });
    _group(canvas, frontRad, () {
      _leg(canvas, _cx - _rx * 0.92, _cy - _ry * 0.42, 208, bodyP);
      _leg(canvas, _cx + _rx * 0.92, _cy - _ry * 0.42, -28, bodyP);
    });
    _group(canvas, tailRad, () => canvas.drawPath(_tailPath(), bodyP));
    _group(canvas, headRad, () => canvas.drawPath(_headPath(1.4), bodyP));

    // SHELL: the fixed anchor. One continuous surface + grout joints + border.
    final ellipse = Rect.fromCenter(
        center: const Offset(_cx, _cy), width: _rx * 2, height: _ry * 2);
    canvas.drawOval(ellipse, Paint()..color = _shell..isAntiAlias = true);

    // grout joints (six radial) + hexagon outline
    final darkBands = Path(), lightBands = Path();
    for (final a in _angs) {
      final vi = _vertex(a), vo = _rayEllipse(vi);
      darkBands.addPath(_band(vi, vo, _dIn, _dOut), Offset.zero);
      lightBands.addPath(_band(vi, vo, _lIn, _lOut), Offset.zero);
    }
    final hex = _hexPath();

    canvas.save();
    canvas.clipPath(Path()..addOval(ellipse));
    // subtle rim shadow (restrained dome cue)
    canvas.drawOval(
      ellipse,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 0.62,
          colors: const [Color(0x001D372F), Color(0x261D372F)],
          stops: const [0.58, 1.0],
        ).createShader(ellipse),
    );
    // dark edges, then light groove centred on them (dark · light · dark)
    canvas.drawPath(darkBands, Paint()..color = _body..isAntiAlias = true);
    canvas.drawPath(
        hex,
        Paint()
          ..color = _body
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * _dIn
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true);
    canvas.drawPath(lightBands, Paint()..color = _grout..isAntiAlias = true);
    canvas.drawPath(
        hex,
        Paint()
          ..color = _grout
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * _lIn
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true);
    // soft glow cue (optional), kept inside the shell clip
    if (glow > 0) {
      final g = glow.clamp(0.0, 1.0);
      final env = math.sin(math.pi * g);
      canvas.drawOval(
        ellipse,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: [
              AppColors.sunGold.withValues(alpha: 0.32 * env),
              AppColors.sunGold.withValues(alpha: 0),
            ],
          ).createShader(ellipse),
      );
    }
    canvas.restore();

    // outer border — one confident dark ellipse (simplified: reads as a clean
    // brand symbol, not a detailed drawing). Internal grout is unchanged.
    canvas.drawOval(
        ellipse,
        Paint()
          ..color = _body
          ..style = PaintingStyle.stroke
          ..strokeWidth = _bw
          ..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(_KobePainter old) =>
      old.headRad != headRad ||
      old.tailRad != tailRad ||
      old.frontRad != frontRad ||
      old.rearRad != rearRad ||
      old.glow != glow;
}
