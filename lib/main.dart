import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';

/// Application entry point.
///
/// Installs the Riverpod [ProviderScope] and loads locale data for `intl`
/// (needed for localized dates/numbers) before running the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  runApp(const ProviderScope(child: KobeApp()));
}
