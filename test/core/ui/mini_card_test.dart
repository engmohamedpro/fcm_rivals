// The mini card's face mirrors the new premium card style without attributes.
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

  testWidgets('the mini card renders rating, position, and name without attributes', (
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
    expect(find.text('92'), findsOneWidget);
    expect(find.text('ST'), findsOneWidget);
    expect(find.text('🇪🇬'), findsOneWidget);
    expect(find.text('FOUAD'), findsOneWidget);
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
    expect(tester.takeException(), isNull);
  });
}
