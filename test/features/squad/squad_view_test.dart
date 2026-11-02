// Regression: the tactics control card's action row (rating + Auto Pick +
// TACTICS) used to size itself to its content and overflowed by ~40px on
// phone widths (yellow/black stripes beside the TACTICS button). The card
// now measures the available width: one line when everything fits, the
// action buttons stacked under the rating when it does not.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/features/match/tactics.dart';
import 'package:fcm_rivals/features/squad/squad_view.dart';

Widget _host() => MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SingleChildScrollView(
          child: TacticsSetupView(
            formationCode: '4-3-3',
            style: PlayingStyle.balanced,
            mentality: Mentality.balanced,
            xi: const {},
            bench: const [],
            reserves: const [],
            onFormation: (_) {},
            onStyle: (_) {},
            onMentality: (_) {},
            onAutoPick: () {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('control card with Auto Pick fits a phone-width screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(340, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.text('TEAM RATING'), findsOneWidget);
    expect(find.text('Auto Pick'), findsOneWidget);
    expect(find.text('TACTICS'), findsOneWidget);

    // Narrow: the actions sit below the rating, so the TACTICS button
    // starts lower than the rating label ends — nothing shares its line.
    final label = tester.getBottomLeft(find.text('TEAM RATING'));
    final tactics = tester.getTopLeft(find.text('TACTICS'));
    expect(tactics.dy, greaterThan(label.dy));
  });

  testWidgets('wide screens keep rating and actions on one line',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.text('Auto Pick'), findsOneWidget);
    expect(find.text('TACTICS'), findsOneWidget);

    // Wide: rating on the left, both buttons to its right on the same row.
    final label = tester.getTopLeft(find.text('TEAM RATING'));
    final autoPick = tester.getTopLeft(find.text('Auto Pick'));
    final tactics = tester.getTopLeft(find.text('TACTICS'));
    expect(autoPick.dx, greaterThan(label.dx));
    expect(tactics.dx, greaterThan(autoPick.dx));
    expect((tactics.dy - label.dy).abs(), lessThan(25));
  });
}
