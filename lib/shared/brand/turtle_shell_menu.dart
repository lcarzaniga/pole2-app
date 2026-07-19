import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_icon_size.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import 'turtle_mascot.dart';

/// Stable identity of a creation path — decoupled from its (localized) label, so
/// callers route by identity, never by translated text. **Both paths create the
/// same domain entity (a possession)**; they differ only in how the user starts:
/// from a photo, or from a name.
enum QuickAction { photo, object }

/// The two creation paths, in stable order around the shell: "Dalla foto" blooms
/// upper-right (easy thumb reach), "Dal nome" upper-left. Fixed order = fixed
/// positions = muscle memory, and the order assistive tech reads.
const List<QuickAction> quickActionOrder = <QuickAction>[
  QuickAction.photo, // upper-right — start from a photograph
  QuickAction.object, // upper-left  — start from a name
];

/// The bloom angle (degrees; -90 = straight up) for the cell in slot [i]. Two
/// balanced cells straddle the top, so neither overlaps Kobe nor the edges.
const List<double> _slotAnglesDeg = <double>[-45, -135];

/// The short, visible label for a creation path. Both read as *ways to start* —
/// never as different kinds of content.
String quickActionLabel(AppLocalizations l10n, QuickAction action) =>
    switch (action) {
      QuickAction.photo => l10n.actionPhoto,
      QuickAction.object => l10n.actionObject,
    };

/// The complete spoken label for assistive tech — a full sentence, so the action
/// is understandable without seeing the icon.
String quickActionSemanticLabel(AppLocalizations l10n, QuickAction action) =>
    switch (action) {
      QuickAction.photo => l10n.a11yActionPhoto,
      QuickAction.object => l10n.a11yActionObject,
    };

IconData _iconFor(QuickAction action) => switch (action) {
  QuickAction.photo => Icons.photo_camera_outlined,
  QuickAction.object => Icons.edit_outlined,
};

/// The bloomed shell: the two creation cells ("Dalla foto", "Dal nome") unfold
/// as balanced perimeter hexagons around the turtle, which stays calmly present
/// at the centre and rises gently to the screen's optical centre as the shell
/// opens (so the whole shape is balanced, and a bloom triggered from a low
/// resting position never clips). See `turtle_launcher.dart`. Interruptible, and
/// collapses to an instant reveal under Reduce Motion.
class TurtleShellMenu extends StatelessWidget {
  const TurtleShellMenu({
    super.key,
    required this.animation,
    required this.link,
    required this.targetKey,
    required this.turtleSize,
    required this.onDismiss,
    required this.onSelect,
  });

  final Animation<double> animation;
  final LayerLink link;

  /// Key on the resting turtle, so we can measure where it sits and rise from
  /// there to the screen's optical centre.
  final GlobalKey targetKey;
  final double turtleSize;
  final VoidCallback onDismiss;
  final ValueChanged<QuickAction> onSelect;

  static const double _hexSize = 64;

  /// Half the height of a cell's icon-tile-plus-label stack, with a little
  /// margin. The top cell's label sits between the cell and the turtle, so the
  /// ring must clear the turtle's footprint by at least this much for the label
  /// to stay tappable (and to read as unfolding from the shell, not under it).
  static const double _columnClear = 52;

  /// A label-width floor on the radius, so a cell's label always has room.
  static double get _labelSafe => _hexSize + AppSpacing.xl;

  /// The widest ring [width] allows before a cell's label leaves safe bounds.
  /// A conservative cap: the two cells sit 45° off vertical (cos45 ≈ 0.707),
  /// so the historical cos30 bound (≈ 0.866) still clears them with margin.
  static double _maxByWidth(double width) =>
      (width / 2 - _labelSafe / 2 - AppSpacing.md) / math.cos(math.pi / 6);

  /// The largest turtle whose bloomed shell still fits within [width] — the two
  /// labelled cells around it, each clearing the turtle. Kobe is a visual
  /// target, so callers cap its size with this on narrow screens rather than
  /// letting the shell clip.
  static double maxTurtleForWidth(double width) =>
      2 * (_maxByWidth(width) - _columnClear);

  /// The radius of the cell ring. Hugs the shell so the cells read as scutes
  /// unfolding from it, but never so tight that a label falls inside the turtle
  /// (which would make it untappable), never below the label-safe minimum, and
  /// never wider than the viewport allows.
  double _radius(Size viewport) {
    final hug = turtleSize / 2 + _columnClear;
    return math.max(_labelSafe, math.min(hug, _maxByWidth(viewport.width)));
  }

  /// The optical centre of the screen (a touch above true centre reads as
  /// "centred" to the eye).
  Offset _opticalCentre(Size viewport, EdgeInsets padding) => Offset(
    viewport.width / 2,
    padding.top + (viewport.height - padding.top) * 0.44,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mq = MediaQuery.of(context);
    final radius = _radius(mq.size);
    final half = radius + turtleSize;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final base = animation.value;

        // Rise from the resting turtle to the optical centre as we open.
        var rise = Offset.zero;
        final box = targetKey.currentContext?.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final turtleCentre = box.localToGlobal(box.size.center(Offset.zero));
          final delta = _opticalCentre(mq.size, mq.padding) - turtleCentre;
          rise = delta * AppCurves.gentle.transform(base);
        }

        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                ignoring: base == 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDismiss,
                  child: ColoredBox(
                    color: scheme.scrim.withValues(alpha: 0.5 * base),
                  ),
                ),
              ),
            ),
            CompositedTransformFollower(
              link: link,
              targetAnchor: Alignment.center,
              followerAnchor: Alignment.center,
              offset: rise,
              child: SizedBox(
                width: half * 2,
                height: half * 2,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < quickActionOrder.length; i++)
                      _action(context, i, base, radius),
                    Semantics(
                      button: true,
                      label: AppLocalizations.of(context).a11yClose,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onDismiss,
                        child: Transform.scale(
                          scale: 1 + 0.04 * AppCurves.gentle.transform(base),
                          child: TurtleMascot(size: turtleSize),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _action(BuildContext context, int i, double base, double radius) {
    final action = quickActionOrder[i];
    // Two balanced cells straddling the top (see [_slotAnglesDeg]).
    final angle = _slotAnglesDeg[i] * math.pi / 180;

    final start = 0.05 * i;
    final end = (0.6 + 0.05 * i).clamp(0.0, 1.0).toDouble();
    final progress = ((base - start) / (end - start))
        .clamp(0.0, 1.0)
        .toDouble();
    final travel = AppCurves.gentle.transform(progress);
    final opacity = (progress / 0.55).clamp(0.0, 1.0).toDouble();

    final direction = Offset(math.cos(angle), math.sin(angle));
    return Transform.translate(
      offset: direction * radius * travel,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: 0.78 + 0.22 * travel,
          child: IgnorePointer(
            ignoring: travel < 0.9,
            child: _HexAction(action: action, onTap: () => onSelect(action)),
          ),
        ),
      ),
    );
  }
}

class _HexAction extends StatelessWidget {
  const _HexAction({required this.action, required this.onTap});

  final QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final label = quickActionLabel(l10n, action);
    final fill = scheme.surfaceContainerHigh;
    final iconColor = scheme.primary;

    return Semantics(
      button: true,
      label: quickActionSemanticLabel(l10n, action),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: TurtleShellMenu._hexSize,
              height: TurtleShellMenu._hexSize,
              child: CustomPaint(
                painter: _HexTilePainter(
                  fill: fill,
                  border: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
                child: Center(
                  child: Icon(
                    _iconFor(action),
                    size: AppIconSize.lg,
                    color: iconColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: TurtleShellMenu._hexSize + AppSpacing.xl,
              // The full spoken label lives on the outer Semantics node, so the
              // visible short label is excluded to avoid a doubled announcement.
              child: ExcludeSemantics(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HexTilePainter extends CustomPainter {
  _HexTilePainter({required this.fill, required this.border});

  final Color fill;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.25, 0)
      ..lineTo(w * 0.75, 0)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.75, h)
      ..lineTo(w * 0.25, h)
      ..lineTo(0, h * 0.5)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = fill
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_HexTilePainter old) =>
      old.fill != fill || old.border != border;
}
