import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_icon_size.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import 'turtle_mascot.dart';

/// Stable identity of a quick action — decoupled from its (localized) label, so
/// callers route by identity, never by translated text. These map to internal
/// domain concepts (object → the record, document → Evidence/File, reminder →
/// Event, note → Event, detail → Attribute) which are never named in the UI.
enum QuickAction { object, photo, document, reminder, note, detail }

/// The six actions, in stable order around the shell. Slot 0 is the top cell;
/// the rest follow clockwise. Fixed order = fixed positions = muscle memory.
/// This is the single source of truth for the on-shell ordering.
const List<QuickAction> quickActionOrder = <QuickAction>[
  QuickAction.object, // top          — primary, the main record
  QuickAction.photo, // top-right     — improved capture, easy thumb reach
  QuickAction.document, // bottom-right
  QuickAction.reminder, // bottom
  QuickAction.note, // bottom-left
  QuickAction.detail, // top-left
];

/// The localized label for a quick action.
String quickActionLabel(AppLocalizations l10n, QuickAction action) =>
    switch (action) {
      QuickAction.object => l10n.actionObject,
      QuickAction.photo => l10n.actionPhoto,
      QuickAction.document => l10n.actionDocument,
      QuickAction.reminder => l10n.actionReminder,
      QuickAction.note => l10n.actionNote,
      QuickAction.detail => l10n.actionDetail,
    };

IconData _iconFor(QuickAction action) => switch (action) {
      QuickAction.object => Icons.auto_awesome_outlined,
      QuickAction.photo => Icons.photo_camera_outlined,
      QuickAction.document => Icons.description_outlined,
      QuickAction.reminder => Icons.notifications_outlined,
      QuickAction.note => Icons.sticky_note_2_outlined,
      QuickAction.detail => Icons.label_outline,
    };

/// The bloomed shell: exactly six regular perimeter hexagons around the turtle,
/// which stays calmly present at the centre and rises gently to the screen's
/// optical centre as the shell opens (so the whole shape is balanced, and a
/// bloom triggered from a low resting position never clips). See
/// `turtle_launcher.dart`. Interruptible, and collapses to an instant reveal
/// under Reduce Motion.
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

  /// The radius of the six-cell ring, clamped so labels never leave safe bounds
  /// on narrow phones. Derived from tokens + the live viewport — no per-screen
  /// magic numbers.
  double _radius(Size viewport) {
    final labelHalf = (_hexSize + AppSpacing.xl) / 2;
    // The most horizontal cells sit 30° off vertical (cos30 ≈ 0.866).
    final maxByWidth =
        (viewport.width / 2 - labelHalf - AppSpacing.md) / math.cos(math.pi / 6);
    final ideal = turtleSize * 1.18;
    return math.max(turtleSize * 0.8, math.min(ideal, maxByWidth));
  }

  /// The optical centre of the screen (a touch above true centre reads as
  /// "centred" to the eye).
  Offset _opticalCentre(Size viewport, EdgeInsets padding) =>
      Offset(viewport.width / 2, padding.top + (viewport.height - padding.top) * 0.44);

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
    // Slot 0 at the top (-90°), clockwise in 60° steps → six-cell perimeter.
    final angle = (-90 + 60 * i) * math.pi / 180;

    final start = 0.05 * i;
    final end = (0.6 + 0.05 * i).clamp(0.0, 1.0).toDouble();
    final progress = ((base - start) / (end - start)).clamp(0.0, 1.0).toDouble();
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
            child: _HexAction(
              action: action,
              emphasized: action == QuickAction.object,
              onTap: () => onSelect(action),
            ),
          ),
        ),
      ),
    );
  }
}

class _HexAction extends StatelessWidget {
  const _HexAction({
    required this.action,
    required this.emphasized,
    required this.onTap,
  });

  final QuickAction action;
  final bool emphasized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = quickActionLabel(AppLocalizations.of(context), action);
    final fill =
        emphasized ? scheme.primaryContainer : scheme.surfaceContainerHigh;
    final iconColor = emphasized ? scheme.onPrimaryContainer : scheme.primary;

    return Semantics(
      button: true,
      label: label,
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
                  child: Icon(_iconFor(action),
                      size: AppIconSize.lg, color: iconColor),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: TurtleShellMenu._hexSize + AppSpacing.xl,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style:
                    theme.textTheme.labelSmall?.copyWith(color: scheme.onSurface),
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
    canvas.drawPath(path, Paint()..color = fill..isAntiAlias = true);
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
