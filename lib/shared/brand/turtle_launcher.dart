import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'launcher_familiarity.dart';
import 'turtle_mascot.dart';
import 'turtle_shell_menu.dart';

/// Open/close timing for the shell. Slightly faster to close than to open, and
/// within the calm 480–520 ms window from the brand spec.
const Duration _openDuration = Duration(milliseconds: 500);
const Duration _closeDuration = Duration(milliseconds: 380);

/// One pass of the idle-cue gloss across the shell.
const Duration _cueDuration = Duration(milliseconds: 1400);

/// The Turtle Launcher — the signature interaction (deliberately not a "+").
///
/// Tapping the resting turtle calmly opens its shell: it blooms into exactly six
/// hexagon actions around the turtle, which rises gently to the screen's optical
/// centre and stays present — never retracting, jumping or bouncing. The bloom
/// is a pure function of one [AnimationController], so it is fully interruptible.
/// Opening is [_openDuration]; closing a touch faster. A single gentle haptic
/// fires only on opening. Reduce Motion collapses it to an instant reveal.
///
/// While at rest, and only after a period of inactivity, the turtle offers one
/// restrained idle cue — a soft gold gloss across the shell — to hint that it
/// can be touched. The cue stops while the shell is open, while the app is
/// backgrounded, and under Reduce Motion, and it fades away once the user is
/// familiar (see [LauncherFamiliarity]). Discoverability, never engagement.
class TurtleLauncher extends ConsumerStatefulWidget {
  const TurtleLauncher({
    super.key,
    this.size = 112,
    this.onOpenChanged,
    this.onAction,
  });

  final double size;

  /// Notifies the parent when the shell opens (`true`) or closes (`false`),
  /// so nearby chrome (e.g. a hint) can recede while the bloom has focus.
  final ValueChanged<bool>? onOpenChanged;

  /// Called with the selected action's stable identity. The launcher stays
  /// feature-agnostic: the parent decides what each action does.
  final ValueChanged<QuickAction>? onAction;

  @override
  ConsumerState<TurtleLauncher> createState() => _TurtleLauncherState();
}

class _TurtleLauncherState extends ConsumerState<TurtleLauncher>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  final GlobalKey _targetKey = GlobalKey();
  late final AnimationController _controller;
  late final AnimationController _cue;
  Timer? _idleTimer;

  bool _pressed = false;
  bool _open = false;
  bool _overlayVisible = false;
  bool _appActive = true;
  int _opens = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: _openDuration,
      reverseDuration: _closeDuration,
    );
    _cue = AnimationController(vsync: this, duration: _cueDuration);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && _portal.isShowing) {
        _portal.hide();
        setState(() => _overlayVisible = false);
        _scheduleIdle();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleIdle();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _cue.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (!_appActive) {
      _idleTimer?.cancel();
      _cue.stop();
    } else {
      _scheduleIdle();
    }
  }

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  // --- Idle discoverability cue -------------------------------------------

  void _scheduleIdle() {
    _idleTimer?.cancel();
    if (!mounted) return;
    if (!shouldShowIdleCue(
      opens: _opens,
      reduceMotion: _reduceMotion,
      appActive: _appActive,
      shellOpen: _open,
    )) {
      return;
    }
    _idleTimer = Timer(idleCueDelay(_opens), _runCue);
  }

  Future<void> _runCue() async {
    if (!shouldShowIdleCue(
      opens: _opens,
      reduceMotion: _reduceMotion,
      appActive: _appActive,
      shellOpen: _open,
    )) {
      return;
    }
    await _cue.forward(from: 0);
    _scheduleIdle();
  }

  // --- Shell open / close --------------------------------------------------

  void _openShell() {
    if (_open) return;
    _idleTimer?.cancel();
    _cue.stop();
    setState(() {
      _open = true;
      _overlayVisible = true;
    });
    widget.onOpenChanged?.call(true);
    _portal.show();
    HapticFeedback.lightImpact();
    // Familiarity: one successful open. Persisted locally.
    ref.read(launcherFamiliarityProvider.notifier).recordOpen();
    if (_reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  void _closeShell() {
    if (!_open) return;
    setState(() => _open = false);
    widget.onOpenChanged?.call(false);
    if (_reduceMotion) {
      _controller.value = 0;
      _portal.hide();
      setState(() => _overlayVisible = false);
      _scheduleIdle();
    } else {
      _controller.reverse();
    }
  }

  void _onSelect(QuickAction action) {
    _closeShell();
    widget.onAction?.call(action);
  }

  @override
  Widget build(BuildContext context) {
    _opens = ref.watch(launcherFamiliarityProvider);

    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) => TurtleShellMenu(
        animation: _controller,
        link: _link,
        targetKey: _targetKey,
        turtleSize: widget.size,
        onDismiss: _closeShell,
        onSelect: _onSelect,
      ),
      child: CompositedTransformTarget(
        link: _link,
        child: Semantics(
          button: true,
          label: AppLocalizations.of(context).a11yKeepSomething,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: _openShell,
            child: AnimatedScale(
              scale: _pressed ? 0.96 : 1,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              // Hide the resting turtle while the overlay's (rising) turtle is
              // present, so there is exactly one turtle on screen.
              child: Opacity(
                opacity: _overlayVisible ? 0 : 1,
                child: ExcludeSemantics(
                  child: TurtleMascot(
                    key: _targetKey,
                    size: widget.size,
                    highlight: _cue,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
