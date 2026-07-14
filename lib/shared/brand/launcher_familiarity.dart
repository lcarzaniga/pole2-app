import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How many successful shell openings before the turtle stops offering its
/// discreet "you can touch me" idle cue. Discoverability, not engagement: once
/// the user clearly knows, the guardian goes quiet.
const int kFamiliarThreshold = 4;

/// Locally-persisted count of how many times the launcher shell has been opened.
/// Stored via [SharedPreferences] — on-device only, no analytics, no cloud.
class LauncherFamiliarity extends Notifier<int> {
  static const String _key = 'launcher_open_count';

  @override
  int build() {
    _load();
    return 0;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_key) ?? 0;
  }

  /// Records one successful open and persists it.
  Future<void> recordOpen() async {
    final next = state + 1;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, next);
  }
}

final launcherFamiliarityProvider =
    NotifierProvider<LauncherFamiliarity, int>(LauncherFamiliarity.new);

/// Whether the idle cue should run right now. Pure, so it is unit-testable.
///
/// It never runs while Reduce Motion is on, while the app is backgrounded, or
/// while the shell is open — and it stops for good once the user is familiar.
bool shouldShowIdleCue({
  required int opens,
  required bool reduceMotion,
  required bool appActive,
  required bool shellOpen,
}) {
  if (reduceMotion || !appActive || shellOpen) return false;
  return opens < kFamiliarThreshold;
}

/// The delay until the next idle cue: ~25–37s while unfamiliar, stretching to
/// ~38–52s as the user learns, with slight variation so it never feels metronomic.
Duration idleCueDelay(int opens, {math.Random? random}) {
  final r = random ?? math.Random();
  final base = opens < 2 ? 25 : 38;
  final span = opens < 2 ? 13 : 15;
  return Duration(seconds: base + r.nextInt(span));
}
