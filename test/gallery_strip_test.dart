import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/core/database/app_database.dart';
import 'package:project_kobe/core/database/daos/possessions_dao.dart';
import 'package:project_kobe/features/possessions/presentation/widgets/gallery_strip.dart';
import 'package:project_kobe/l10n/app_localizations.dart';

// Built directly from row data classes — no database, so the widget test runs
// entirely under flutter_test's fake async (a live Drift stream would hang it).
PhotoWithFile _pf(String fileId) {
  final t = DateTime(2020);
  return PhotoWithFile(
    photo: PossessionPhoto(
      id: 'ph-$fileId',
      possessionId: 'p1',
      fileId: fileId,
      sortOrder: 0,
      createdAt: t,
      updatedAt: t,
    ),
    file: StoredFile(
      id: fileId,
      relativePath: 'photos/$fileId.jpg',
      mimeType: 'image/jpeg',
      byteSize: 1,
      createdAt: t,
    ),
  );
}

void main() {
  Widget wrap(Widget child) => MaterialApp(
    locale: const Locale('it'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: const [Locale('it')],
    home: Scaffold(body: child),
  );

  final photos = [_pf('a'), _pf('b'), _pf('c')];

  testWidgets('renders a thumbnail per photo plus a trailing add tile, and '
      'no docs path shows a safe placeholder', (tester) async {
    var opened = -1, added = 0;
    await tester.pumpWidget(
      wrap(
        GalleryStrip(
          photos: photos,
          coverFileId: 'a',
          docsPath: null, // → placeholders, never a file read in the test
          onOpen: (i) => opened = i,
          onAdd: () => added++,
        ),
      ),
    );
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('it'));
    // The add tile is present and labelled.
    expect(find.bySemanticsLabel(l10n.photoAddAnother), findsOneWidget);
    // Missing files degrade to a safe placeholder, never a broken image.
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNWidgets(3));

    // Tapping a thumbnail opens the viewer at that index.
    await tester.tap(find.byIcon(Icons.image_not_supported_outlined).first);
    expect(opened, 0);

    // Tapping the add tile invokes onAdd.
    await tester.tap(find.bySemanticsLabel(l10n.photoAddAnother));
    expect(added, 1);
  });

  testWidgets('the cover thumbnail carries a non-colour-only badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        GalleryStrip(
          photos: photos,
          coverFileId: 'a',
          docsPath: null,
          onOpen: (_) {},
          onAdd: () {},
        ),
      ),
    );
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('it'));
    // The cover has an explicit "Copertina" semantic label + a star icon.
    expect(find.bySemanticsLabel(l10n.photoIsCover), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
  });
}
