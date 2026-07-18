import 'package:path_provider/path_provider.dart';

import 'restore_swapper.dart';

/// Resolves restore state before the normal database opens. Called once from
/// `main()` before `runApp`. Best-effort and never throws — a bootstrap failure
/// must not prevent the app from starting.
///
/// Recovery cleanup is authorized *only* inside [RestoreSwapper.run] — by a
/// confirmed marker or a completed rollback. The bootstrap never deletes a
/// recovery snapshot merely because a marker is absent; it only sweeps unmarked
/// staging (and only when no swap is in flight).
Future<void> runRestoreBootstrap() async {
  try {
    final docs = await getApplicationDocumentsDirectory();
    final swapper = RestoreSwapper(docs);
    final outcome = swapper.run();

    // Never sweep anything on the fatal path — everything is preserved for
    // manual recovery. Staging is transient and safe to sweep otherwise; the
    // swapper guards it against sweeping while a swap/confirmation is pending.
    if (outcome.kind != RestoreOutcomeKind.fatal) {
      swapper.sweepStaging();
    }
  } catch (_) {
    // Never block startup on a bootstrap error.
  }
}
