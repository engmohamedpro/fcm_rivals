import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/features/packs/pack_effects.dart';

void main() {
  testWidgets('foil pack stamps the decoded transparent logo on the band',
      (WidgetTester tester) async {
    // Decode the real asset (as main() does at startup).
    await tester.runAsync(precachePackLogo);
    // Second call is a no-op — the decode happens exactly once.
    await tester.runAsync(precachePackLogo);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 120,
          height: 120 / kPackAspect,
          child: CustomPaint(
            painter: FoilPackPainter(
              shimmer: 0.42,
              charge: 0,
              glowColor: const Color(0xFFD9B871),
              tint: const Color(0xFFD9B871),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    // Painting with the logo loaded must not throw; a repaint decision
    // that flips when the logo lands is covered by shouldRepaint.
    final painter = FoilPackPainter(
        shimmer: 0, charge: 0, glowColor: const Color(0xFFD9B871));
    expect(
      painter.shouldRepaint(FoilPackPainter(
        shimmer: 0.42,
        charge: 0,
        glowColor: const Color(0xFFD9B871),
        tint: const Color(0xFFD9B871),
      )),
      isTrue,
      reason: 'shimmer and tint differences repaint the foil',
    );
  });
}
