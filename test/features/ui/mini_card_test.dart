// Mini card regression: the stamina bar's FILL must render with real
// width and height (a previous implementation used a FractionallySizedBox
// with only widthFactor, collapsing the fill to zero height so the bar
// looked empty at every value), and the stat row must show all three
// attribute columns.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/ui/country_flag.dart' show flagEmojiFor;
import 'package:fcm_rivals/core/ui/fcm_style.dart';
import 'package:fcm_rivals/core/ui/player_card.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    backgroundColor: Colors.black,
    body: Center(child: child),
  ),
);


void main() {
  group('T-0066: country flag on the mini card', () {
    testWidgets('renders the flag emoji under the position code', (
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

    testWidgets('flag: null renders no flag slot (layout unchanged)', (
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
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('⚽'), findsNothing);
      // No emoji text of any mapped flag leaks in.
      expect(
        find.textContaining(flagEmojiFor('Egypt')),
        findsNothing,
      );
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
            // Even a stray flag value must not render on a ghost.
            flag: '🇪🇬',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('🇪🇬'), findsNothing);
    });

    testWidgets('RTL pump renders the flag without overflow', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: FcmMiniCard(
                  overall: 80,
                  position: 'ST',
                  name: 'Player',
                  rarity: CardRarity.fromOverall(80),
                  width: 56,
                  flag: flagEmojiFor('Egypt'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Emoji are direction-neutral: present, and no overflow errors.
      expect(find.text(flagEmojiFor('Egypt')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('stamina bar fill renders with real width and height', (
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
          stamina: 80,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The fill is a Positioned box of width 0.8 × track width inside a
    // 5px-tall track; find its DecoratedBox and measure both extents.
    final fills = find
        .descendant(
          of: find.byType(FcmMiniCard),
          matching: find.byType(DecoratedBox),
        )
        .evaluate();
    var foundFill = false;
    for (final e in fills) {
      final box = e.renderObject as RenderBox;
      if (box.size.height > 0 && box.size.width > 0 && box.size.width < 56) {
        // The stamina fill: 0.8 × 56 = 44.8 wide, 5 tall.
        expect(box.size.width, closeTo(44.8, 1.0));
        expect(box.size.height, greaterThan(0));
        foundFill = true;
      }
    }
    expect(
      foundFill,
      isTrue,
      reason: 'the stamina fill must render with real width and height',
    );
  });

  testWidgets('mini card shows the three stat columns', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        FcmMiniCard(
          overall: 80,
          position: 'ST',
          name: 'Player',
          rarity: CardRarity.fromOverall(80),
          width: 64,
          stats: const [
            (label: 'ATT', value: 82),
            (label: 'SUP', value: 75),
            (label: 'DEF', value: 40),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ATT'), findsOneWidget);
    expect(find.text('SUP'), findsOneWidget);
    expect(find.text('DEF'), findsOneWidget);
    expect(find.text('82'), findsOneWidget);
    expect(find.text('75'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
  });

  testWidgets('keeper card shows GK stats', (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        FcmMiniCard(
          overall: 84,
          position: 'GK',
          name: 'Keeper',
          rarity: CardRarity.fromOverall(84),
          width: 64,
          stats: const [
            (label: 'GK', value: 88),
            (label: 'DEF', value: 60),
            (label: 'SUP', value: 55),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 'GK' appears twice: the position code on the shield and the stat
    // column label under it.
    expect(find.text('GK'), findsNWidgets(2));
    expect(find.text('88'), findsOneWidget);
  });

  testWidgets('full card carries name, stats and stamina together', (
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
          stamina: 45,
          stats: const [
            (label: 'ATT', value: 70),
            (label: 'SUP', value: 80),
            (label: 'DEF', value: 65),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MIDFIELDER'), findsOneWidget);
    expect(find.text('ATT'), findsOneWidget);
    // A 45% fill on a 64-wide track ≈ 28.8 logical pixels of fill width.
    final fills = find
        .descendant(
          of: find.byType(FcmMiniCard),
          matching: find.byType(DecoratedBox),
        )
        .evaluate();
    var foundFill = false;
    for (final e in fills) {
      final box = e.renderObject as RenderBox;
      if (box.size.height > 0 && box.size.width < 64) {
        expect(box.size.width, closeTo(28.8, 1.5));
        foundFill = true;
      }
    }
    expect(foundFill, isTrue);
  });
}
