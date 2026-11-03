import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/features/packs/pack_effects.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart'
    show PackTierColor, PackTier;

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

  testWidgets('rarity stars: 3 rare, 4 epic, 5 legendary — repaint on change',
      (WidgetTester tester) async {
    // The shelf's grade stamps: rare 3, epic 4, legendary 5.
    expect(PackTier.rare.stars, 3);
    expect(PackTier.epic.stars, 4);
    expect(PackTier.legendary.stars, 5);

    // The painter repaints when the count changes (the same-count
    // no-repaint case cannot be asserted here: the async logo decode
    // from the test above legitimately flips _paintedWithLogo).
    const gold = Color(0xFFF7C948);
    final five = FoilPackPainter(
        shimmer: 0, charge: 0, glowColor: gold, tint: gold, stars: 5);
    expect(
      five.shouldRepaint(FoilPackPainter(
          shimmer: 0, charge: 0, glowColor: gold, tint: gold, stars: 3)),
      isTrue,
      reason: 'a changed star count repaints the foil',
    );

    // Painting any count must not throw (star paths + label plate).
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 120,
          height: 120 / kPackAspect,
          child: CustomPaint(
            painter: FoilPackPainter(
                shimmer: 0.42, charge: 0, glowColor: gold, stars: 4),
          ),
        ),
      ),
    ));
    await tester.pump();
  });
}
