import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'features/backup/restore/restore_bootstrap.dart';

/// Application entry point.
///
/// Installs the Riverpod [ProviderScope] and loads locale data for `intl`
/// (needed for localized dates/numbers) before running the app.
///
/// **Before anything can open the database**, resolve a pending local restore
/// (M6.1): if a restore was confirmed, the swap/rollback happens here — while no
/// Drift connection exists — so live data is never overwritten while open, and a
/// failure rolls back automatically. A no-op when there's nothing pending.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await runRestoreBootstrap();
  await initializeDateFormatting();
  runApp(const ProviderScope(child: KobeApp()));
}
