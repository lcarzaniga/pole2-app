import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_icon_size.dart';
import '../../../../app/theme/app_motion.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/brand/turtle_launcher.dart';
import '../../../../shared/brand/turtle_shell_menu.dart';

/// The first experience: a calm home waiting to preserve something.
///
/// This is deliberately NOT an "empty database". There is no count of zero, no
/// call to complete anything, no accusation. The turtle is the hero — large and
/// central — with quiet words above it and a light privacy line grounding the
/// base. When the shell blooms open, the surrounding chrome gently recedes so
/// the moment has the screen to itself. See `BRAND_UX_MANIFESTO.md` §7.
class HomeEmptyState extends StatefulWidget {
  const HomeEmptyState({super.key, required this.onQuickAction});

  /// Invoked with the chosen quick action from the bloomed shell. The Home
  /// screen decides what each does.
  final ValueChanged<QuickAction> onQuickAction;

  @override
  State<HomeEmptyState> createState() => _HomeEmptyStateState();
}

class _HomeEmptyStateState extends State<HomeEmptyState> {
  /// The turtle leads the first-run composition as the hero — now roughly twice
  /// its former presence. It is a visual target, not a fixed number: capped by
  /// the screen width, by an absolute maximum, and by the size whose bloomed
  /// shell still fits (so opening it never clips), then floored so it always
  /// reads big. Head, legs and tail are never clipped because the Spacer-based
  /// column and the mascot's own square box scale together.
  double _heroSize(double screenWidth) {
    final byShell = TurtleShellMenu.maxTurtleForWidth(screenWidth);
    return math.max(
        132.0, math.min(280.0, math.min(screenWidth * 0.66, byShell)));
  }

  bool _shellOpen = false;

  /// Chrome that recedes while the shell is open, so nothing competes with the
  /// bloom. Opacity-only, so the turtle's position never shifts.
  Widget _recede(Widget child) => AnimatedOpacity(
        opacity: _shellOpen ? 0 : 1,
        duration: AppDurations.short,
        curve: AppCurves.gentle,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final turtleSize = _heroSize(MediaQuery.of(context).size.width);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
            children: [
              const Spacer(flex: 3),
              _recede(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.homeEmptyTitle,
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.homeEmptyBody,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // A generous, fixed gap keeps the copy and the turtle reading as
              // one calm cluster rather than two drifting halves.
              const SizedBox(height: AppSpacing.xxxl),
              TurtleLauncher(
                size: turtleSize,
                onOpenChanged: (open) => setState(() => _shellOpen = open),
                onAction: widget.onQuickAction,
              ),
              const SizedBox(height: AppSpacing.lg),
              _recede(
                Text(
                  l10n.homeEmptyCta,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const Spacer(flex: 5),
              _recede(const _PrivacyLine()),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
    );
  }
}

/// A quiet, proud statement of privacy — a light line, not a heavy badge.
/// The lock icon already carries "private", so the words stay minimal.
class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.lock_outline,
          size: AppIconSize.sm,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        // Flexible so the line wraps calmly rather than overflowing on narrow
        // phones (e.g. a 360dp Galaxy S23).
        Flexible(
          child: Text(
            AppLocalizations.of(context).privacyLine,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
