import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/database/tables/enums.dart';
import 'package:project_kobe/core/providers/database_provider.dart';
import 'package:project_kobe/features/possessions/presentation/possession_detail_screen.dart';
import 'package:project_kobe/l10n/app_localizations.dart';

/// M9 UX correction — the collapsed timeline card shows the record's category
/// label and its dates, and never previews the user's note/description text.
Widget _app(AppDatabase db, String possessionId) {
  final router = GoRouter(
    initialLocation: '/d',
    routes: [
      GoRoute(
        path: '/d',
        builder: (_, _) => PossessionDetailScreen(id: possessionId),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWith((ref) {
        ref.onDispose(db.close);
        return db;
      }),
    ],
    child: MaterialApp.router(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('collapsed record card shows the category + validity, never the '
      'note text', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final p = await db.possessionsDao.createPossession(title: 'Caldaia');
    await db.evidenceDao.createRecordWithAttachments(
      possessionId: p.id,
      kind: EventKind.warranty,
      at: DateTime(2026, 7, 22),
      endsAt: DateTime(2028, 7, 22),
      notes: 'CONTENUTO PRIVATO della nota',
    );
    await db.evidenceDao.createRecordWithAttachments(
      possessionId: p.id,
      kind: EventKind.note,
      at: DateTime(2026, 7, 22),
      notes: 'SEGRETO personale',
    );

    await tester.pumpWidget(_app(db, p.id));
    await tester.pumpAndSettle();

    // Category labels are shown; the private note/description text is not.
    expect(find.text('Garanzia'), findsOneWidget);
    expect(find.text('Nota'), findsWidgets);
    expect(find.textContaining('CONTENUTO PRIVATO'), findsNothing);
    expect(find.textContaining('SEGRETO'), findsNothing);
    // Validity is still surfaced on the collapsed card.
    expect(find.textContaining('Valido fino al'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
