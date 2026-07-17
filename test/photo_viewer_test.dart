import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/features/possessions/presentation/photo_viewer_screen.dart';

/// A 1×1 transparent PNG — valid bytes, so the Image widget never logs a decode
/// error during the test.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
  'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  testWidgets('shows the whole image (no crop) and allows zoom/pan', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoViewer(image: MemoryImage(_png), closeTooltip: 'Chiudi'),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.contain); // non-cropping, aspect preserved
    expect(find.byType(InteractiveViewer), findsOneWidget); // pinch-zoom + pan
  });

  testWidgets('the close button returns to the previous screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PhotoViewer(
                      image: MemoryImage(_png),
                      closeTooltip: 'Chiudi',
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
    expect(find.byType(PhotoViewer), findsOneWidget);

    // Closing pops back to the launching screen (as Android Back would too).
    await tester.tap(find.byTooltip('Chiudi'));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewer), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
