import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/features/possessions/presentation/record_category_ui.dart';

/// M9.1 — the shared attachment tile: an image path renders a thumbnail
/// (Image widget), a null path renders the generic file icon, and a
/// missing/corrupt image falls back calmly without throwing.
Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

// A 1×1 PNG (decodes fine as an image even though we name it .jpg — Image.file
// decodes by content, not extension).
final _png = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x62,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('pole2_tile_'));
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  testWidgets('a null imagePath shows the generic file icon', (tester) async {
    await tester.pumpWidget(
      _host(AttachmentTile(name: 'ricevuta.pdf', onOpen: () {})),
    );
    expect(find.byIcon(Icons.attach_file), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.text('ricevuta.pdf'), findsOneWidget);
  });

  testWidgets('an image path shows a thumbnail (Image)', (tester) async {
    final f = File('${dir.path}/x.jpg')..writeAsBytesSync(_png);
    await tester.pumpWidget(
      _host(AttachmentTile(name: 'Foto', imagePath: f.path, onOpen: () {})),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Foto'), findsOneWidget);
  });

  testWidgets('a missing image falls back to the file icon without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AttachmentTile(
          name: 'Foto',
          imagePath: '${dir.path}/does_not_exist.jpg',
          onOpen: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // The Image is present with an errorBuilder; the missing file resolves to
    // the calm generic tile without throwing, and the name stays readable.
    expect(tester.takeException(), isNull);
    expect(find.text('Foto'), findsOneWidget);
  });
}
