import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/features/possessions/presentation/widgets/photo_gallery_viewer.dart';

/// A 1×1 transparent PNG so the Image widgets never log a decode error.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
  'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

List<ImageProvider> _images(int n) =>
    List.generate(n, (_) => MemoryImage(_png));

void main() {
  String pos(int c, int t) => '$c di $t';

  testWidgets('shows the whole image (contain) and a position indicator only '
      'when there is more than one photo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoGalleryViewer(
          images: _images(3),
          initialIndex: 0,
          closeTooltip: 'Chiudi',
          positionLabel: pos,
        ),
      ),
    );
    await tester.pump();

    expect(tester.widget<Image>(find.byType(Image).first).fit, BoxFit.contain);
    expect(find.byType(InteractiveViewer), findsWidgets);
    expect(find.text('1 di 3'), findsOneWidget);
  });

  testWidgets('a single photo shows no position indicator', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoGalleryViewer(
          images: _images(1),
          initialIndex: 0,
          closeTooltip: 'Chiudi',
          positionLabel: pos,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('1 di 1'), findsNothing);
  });

  testWidgets('opens at the requested index', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoGalleryViewer(
          images: _images(4),
          initialIndex: 2,
          closeTooltip: 'Chiudi',
          positionLabel: pos,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('3 di 4'), findsOneWidget);
  });

  testWidgets('swiping moves to the next photo and updates the indicator', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoGalleryViewer(
          images: _images(3),
          initialIndex: 0,
          closeTooltip: 'Chiudi',
          positionLabel: pos,
        ),
      ),
    );
    await tester.pump();

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 di 3'), findsOneWidget);
  });

  testWidgets('the close button pops back', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PhotoGalleryViewer(
                      images: _images(2),
                      initialIndex: 0,
                      closeTooltip: 'Chiudi',
                      positionLabel: pos,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoGalleryViewer), findsOneWidget);

    await tester.tap(find.byTooltip('Chiudi'));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoGalleryViewer), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('renders app-bar actions for the current photo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoGalleryViewer(
          images: _images(2),
          initialIndex: 0,
          closeTooltip: 'Chiudi',
          positionLabel: pos,
          actionsBuilder: (context, current) =>
              Text('action-$current', key: const Key('action')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('action-0'), findsOneWidget);
  });
}
