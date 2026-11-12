import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/core/ui/fcm_style.dart';
import 'package:fcm_rivals/core/ui/player_card.dart';

BasePlayer _player({int overall = 91, String clubCrestUrl = ''}) =>
    BasePlayer(
      playerId: 7,
      name: 'Karim Fouad',
      position: Position.st,
      nationality: 'Egypt',
      marketValueEur: 50000000,
      clubCrestUrl: clubCrestUrl,
      baseStats: BaseStats(
        overall: overall,
        attack: 93,
        support: 72,
        defence: 40,
        goalkeeping: 0,
      ),
    );

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    backgroundColor: FcmColors.night,
    body: Center(child: child),
  ),
);

void main() {
  for (final rarity in CardRarity.values) {
    testWidgets('${rarity.label} card is one design at every size', (
      WidgetTester tester,
    ) async {
      for (final width in [56.0, 96.0, 160.0, 260.0, 320.0]) {
        await tester.pumpWidget(
          _host(
            FcmPlayerCard(
              player: _player(
                overall: switch (rarity) {
                  CardRarity.legendary => 91,
                  CardRarity.epic => 75,
                  CardRarity.rare => 60,
                },
              ),
              rarity: rarity,
              width: width,
              shine: 0.4,
              glow: 0.6,
            ),
          ),
        );
        final size = tester.getSize(find.byType(FcmPlayerCard));
        expect(size.width, closeTo(width, 0.01));
        expect(size.height, closeTo(width / kPlayerCardAspect, 0.01));
        expect(find.text('KARIM FOUAD'), findsOneWidget);
        expect(find.text('ATT'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'width $width');
      }
    });
  }

  testWidgets('card back renders at every size', (WidgetTester tester) async {
    for (final width in [56.0, 160.0, 320.0]) {
      await tester.pumpWidget(
        _host(FcmPlayerCardBack(width: width)),
      );
      await tester.pump();
      final size = tester.getSize(find.byType(FcmPlayerCardBack));
      expect(size.height, closeTo(width / kPlayerCardAspect, 0.01));
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets('upgrade badge and overridden stats show on the card', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FcmPlayerCard(
          player: _player(),
          rarity: CardRarity.legendary,
          overall: 95,
          upgradeLevel: 3,
          stats: const [
            (label: 'ATT', value: 99),
            (label: 'SUP', value: 80),
            (label: 'DEF', value: 50),
          ],
        ),
      ),
    );
    expect(find.text('95'), findsOneWidget);
    expect(find.text('+3'), findsOneWidget);
    expect(find.text('99'), findsOneWidget);
  });

  testWidgets('name is absent until revealed (plain fade)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FcmPlayerCard(
          player: _player(),
          rarity: CardRarity.epic,
          nameProgress: 0,
        ),
      ),
    );
    expect(find.text('KARIM FOUAD'), findsNothing);
  });

  testWidgets('legendary typewriter: no name until the first letter, '
      'then the name, never shifting', (WidgetTester tester) async {
    Widget card(double letters) => _host(
      FcmPlayerCard(
        player: _player(),
        rarity: CardRarity.legendary,
        nameLetters: letters,
      ),
    );
    await tester.pumpWidget(card(0));
    expect(find.text('KARIM FOUAD'), findsNothing);

    await tester.pumpWidget(card(0.3));
    expect(find.text('KARIM FOUAD'), findsOneWidget);
    final partial = tester.getSize(find.byType(FcmPlayerCard));

    await tester.pumpWidget(card(1));
    expect(find.text('KARIM FOUAD'), findsOneWidget);
    expect(tester.getSize(find.byType(FcmPlayerCard)), partial);
  });
}
