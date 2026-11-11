// The premium player card is ONE design at every size: the same widget
// tree, drawn in proportion to its width — from the 56px pitch card to
// the 320px reveal card. These tests pin that: it lays out without
// overflow at every size, shows the same identity at each, and the
// legendary typewriter / redacted name behave.
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
        // Same size ratio at every width.
        final size = tester.getSize(find.byType(FcmPlayerCard));
        expect(size.width, closeTo(width, 0.01));
        expect(size.height, closeTo(width / kPlayerCardAspect, 0.01));
        // Same identity on every size, no overflow exceptions thrown.
        expect(find.text('KARIM FOUAD'), findsOneWidget);
        expect(find.text('ATT'), findsOneWidget);
        expect(find.text('EGYPT'), findsOneWidget);
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

  testWidgets('club crest replaces the nationality name under the flag', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FcmPlayerCard(
          player: _player(
            clubCrestUrl:
                'https://img.a.transfermarkt.technology/wappen/head/281.png',
          ),
          rarity: CardRarity.epic,
        ),
      ),
    );
    // The crest is a network image under the flag; the fallback name is
    // not built while the crest URL is present.
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('EGYPT'), findsNothing);
    // The test HTTP client fails the download (400) — the card must
    // degrade to the nationality name, never to a blank slot.
    await tester.pumpAndSettle();
    expect(find.text('EGYPT'), findsOneWidget);
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
        maskName: true,
        maskPulse: 0.5,
      ),
    );
    await tester.pumpWidget(card(0));
    // Redacted: nothing readable anywhere on the card.
    expect(find.text('KARIM FOUAD'), findsNothing);

    await tester.pumpWidget(card(0.3));
    expect(find.text('KARIM FOUAD'), findsOneWidget);
    final partial = tester.getSize(find.byType(FcmPlayerCard));

    await tester.pumpWidget(card(1));
    expect(find.text('KARIM FOUAD'), findsOneWidget);
    // The card itself never resizes as letters land.
    expect(tester.getSize(find.byType(FcmPlayerCard)), partial);
  });

  testWidgets('mini card shares the premium face and keeps its layout', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FcmMiniCard(
          overall: 91,
          position: 'ST',
          name: 'Fouad',
          rarity: CardRarity.legendary,
          width: 56,
          stamina: 70,
        ),
      ),
    );
    expect(find.text('91'), findsOneWidget);
    expect(find.text('FOUAD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('cardPath is one chamfered silhouette that fits its box', () {
    const size = Size(100, 143);
    final b = cardPath(size).getBounds();
    expect(b.left, closeTo(0, 0.01));
    expect(b.top, closeTo(0, 0.01));
    expect(b.right, closeTo(100, 0.01));
    expect(b.bottom, closeTo(143, 0.01));
    // Top corners are cut: the very corner is outside the path.
    expect(cardPath(size).contains(const Offset(1, 1)), isFalse);
    expect(cardPath(size).contains(const Offset(50, 70)), isTrue);
  });
}
