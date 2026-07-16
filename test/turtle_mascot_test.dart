// Smoke tests for the Kobe mascot (canonical geometry, §10c).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_kobe/shared/brand/turtle_mascot.dart';

Widget _host({required bool reduce}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: TurtleMascot(size: 120)),
      ),
    );

void main() {
  testWidgets('renders at rest under reduce-motion, no pending timer',
      (tester) async {
    await tester.pumpWidget(_host(reduce: true));
    expect(find.byType(TurtleMascot), findsOneWidget);
    // reduce-motion holds Kobe still and schedules no idle timer.
  });

  testWidgets('schedules idle when motion is allowed and disposes cleanly',
      (tester) async {
    await tester.pumpWidget(_host(reduce: false));
    expect(find.byType(TurtleMascot), findsOneWidget);
    // Replacing the tree disposes the mascot; dispose() must cancel the idle
    // Timer, otherwise the test fails with "A Timer is still pending".
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
