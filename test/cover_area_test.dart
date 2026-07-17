import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/features/possessions/presentation/widgets/cover_area.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('no photo: tapping the area adds a photo', (tester) async {
    var added = 0, viewed = 0, edited = 0;
    await tester.pumpWidget(
      wrap(
        CoverArea(
          height: 200,
          image: null,
          addLabel: 'Aggiungi una foto',
          editTooltip: 'Cambia foto',
          onAdd: () => added++,
          onView: () => viewed++,
          onEdit: () => edited++,
        ),
      ),
    );

    await tester.tap(find.text('Aggiungi una foto'));
    expect(added, 1);
    expect(viewed, 0);
    expect(edited, 0);
  });

  testWidgets('with photo: tapping the image opens the viewer, not edit', (
    tester,
  ) async {
    var viewed = 0, edited = 0;
    await tester.pumpWidget(
      wrap(
        CoverArea(
          height: 200,
          image: Container(key: const Key('cover-img')),
          addLabel: 'Aggiungi una foto',
          editTooltip: 'Cambia foto',
          viewLabel: 'Vedi la foto',
          onView: () => viewed++,
          onEdit: () => edited++,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('cover-img')));
    expect(viewed, 1);
    expect(edited, 0);
  });

  testWidgets(
    'with photo: tapping the pencil replaces, without opening viewer',
    (tester) async {
      var viewed = 0, edited = 0;
      await tester.pumpWidget(
        wrap(
          CoverArea(
            height: 200,
            image: Container(key: const Key('cover-img')),
            addLabel: 'Aggiungi una foto',
            editTooltip: 'Cambia foto',
            viewLabel: 'Vedi la foto',
            onView: () => viewed++,
            onEdit: () => edited++,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Cambia foto'));
      expect(edited, 1);
      expect(viewed, 0); // the pencil consumes its own tap
    },
  );
}
