// The mini card's face mirrors the big card: the identity stack
// (OVR → position → flag → crest) down the left and the portrait
// filling the band beside it — all five data points on a 64px shield.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/ui/fcm_style.dart';
import 'package:fcm_rivals/core/ui/mini_card.dart';

void main() {
  Widget host(FcmMiniCard card) => MaterialApp(
    home: Scaffold(
      backgroundColor: FcmColors.night,
      body: Center(child: card),
    ),
  );

  testWidgets('the mini face carries all five data points', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        FcmMiniCard(
          overall: 92,
          position: 'ST',
          name: 'Fouad',
          rarity: CardRarity.legendary,
          width: 64,
          flag: '🇪🇬',
          imageUrl: 'https://img.example/portrait.jpg',
          clubCrestUrl: 'https://img.example/crest.png',
        ),
      ),
    );
    // Identity stack: rating, position, flag.
    expect(find.text('92'), findsOneWidget);
    expect(find.text('ST'), findsOneWidget);
    expect(find.text('🇪🇬'), findsOneWidget);
    // Portrait + crest: two network images on the face.
    expect(find.byType(Image), findsNWidgets(2));
    // No overflow at the pitch size.
    expect(tester.takeException(), isNull);
  });

  testWidgets('the identity stack degrades per data point', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        const FcmMiniCard(
          overall: 75,
          position: 'CM',
          name: 'Salem',
          rarity: CardRarity.epic,
          width: 56,
        ),
      ),
    );
    // No flag, no crest, no portrait: the texts stand alone and the
    // painted silhouette keeps the band — nothing else renders.
    expect(find.text('75'), findsOneWidget);
    expect(find.text('CM'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ghost stays wordless — no data layer at all', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(
        FcmMiniCard(
          overall: 80,
          position: 'CM',
          name: 'Ghost',
          rarity: CardRarity.epic,
          width: 64,
          flag: '🇪🇬',
          imageUrl: 'https://img.example/portrait.jpg',
          clubCrestUrl: 'https://img.example/crest.png',
          ghost: true,
        ),
      ),
    );
    expect(find.text('80'), findsNothing);
    expect(find.text('GHOST'), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
