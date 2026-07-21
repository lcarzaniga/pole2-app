import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/app_session.dart';
import 'features/backup/domain/safe_path.dart';
import 'features/backup/restore/restore_bootstrap.dart';
import 'features/possessions/application/possession_providers.dart';
import 'features/possessions/media/photo_import.dart';

/// Application entry point.
///
/// Installs the Riverpod scope and loads locale data for `intl` (needed for
/// localized dates/numbers) before running the app.
///
/// **Before anything can open the database**, resolve a pending local restore
/// (M6.1): if a restore was confirmed, the swap/rollback happens here — while no
/// Drift connection exists — so live data is never overwritten while open, and a
/// failure rolls back automatically. A no-op when there's nothing pending.
///
/// **After the database is available**, reconcile leftover staged photo imports
/// (M8.2D): abandoned temporary captures and promoted-but-uncommitted files from
/// a previous process are resolved idempotently before normal editing resumes.
Future<void> main() async {
  // Mark process start now, so the storage-cleanup session cutoff (M8.2C) can
  // never mistake a file created during this session for a pre-existing orphan.
  captureAppSessionStart();
  WidgetsFlutterBinding.ensureInitialized();
  await runRestoreBootstrap();
  await initializeDateFormatting();

  // One container shared by reconciliation and the app, so there is exactly one
  // database. Reconciliation is best-effort and never blocks startup on error.
  final container = ProviderContainer();
  await _reconcilePhotoImports(container);

  runApp(
    UncontrolledProviderScope(container: container, child: const KobeApp()),
  );
}

/// Idempotent M8.2D startup reconciliation, using the live database to decide
/// whether a promoted final file is actually referenced by a committed row.
Future<void> _reconcilePhotoImports(ProviderContainer container) async {
  try {
    final dao = container.read(possessionsDaoProvider);
    await reconcilePhotoImports(
      isReferenced: (finalRel) async {
        final surviving = <String>{
          for (final raw in await dao.survivingFileRelativePaths())
            ?normalizeRelativePath(raw),
        };
        return surviving.contains(finalRel);
      },
    );
  } catch (_) {
    // Never let reconciliation break startup; M8.2C recovers anything missed.
  }
}
