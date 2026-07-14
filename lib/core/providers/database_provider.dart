import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';

part 'database_provider.g.dart';

/// Single, app-wide [AppDatabase] instance.
///
/// `keepAlive` because the database must live for the whole app session;
/// features depend on this provider rather than constructing their own
/// connection, guaranteeing exactly one writer and one source of truth.
///
/// `onDispose` closes the connection so resources are released cleanly if the
/// provider container is ever torn down (e.g. in tests).
@Riverpod(keepAlive: true)
AppDatabase database(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
