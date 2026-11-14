// Mini card regression: attribute-free layout.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/ui/country_flag.dart' show flagEmojiFor;
import 'package:fcm_rivals/core/ui/player_card.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    backgroundColor: Colors.black,
    body: Center(child: child),
  ),
);

void main() {
  group('T-0066: country flag on the mini card', () {
    testWidgets('renders the flag emoji on the card', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          FcmMiniCard(
            overall: 80,
            position: 'ST',
            name: 'Player',
            rarity: CardRarity.fromOverall(80),
            width: 56,
            flag: flagEmojiFor('Egypt'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(flagEmojiFor('Egypt')), findsOneWidget);
    });

    testWidgets('ghost cards never render a flag', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const FcmMiniCard(
            overall: 0,
            position: '',
            name: '',
            rarity: CardRarity.rare,
            width: 56,
            ghost: true,
            flag: '🇪🇬',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('🇪🇬'), findsNothing);
    });
  });

  testWidgets('mini card carries the name without attributes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FcmMiniCard(
          overall: 78,
          position: 'CM',
          name: 'Midfielder',
          rarity: CardRarity.fromOverall(78),
          width: 64,
              ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MIDFIELDER'), findsOneWidget);
    // Attributes/stats are intentionally omitted on small cards.
    expect(find.text('ATT'), findsNothing);
  });
}
