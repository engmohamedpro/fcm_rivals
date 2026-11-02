// Pack opening sequence (GDD 5.6): tap → charge → burst → nationality, name
// and position walkout → card flip → stats count up → keep button.
//
// The screen has repeating idle animations, so the test advances time with
// explicit pumps instead of pumpAndSettle.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/core/ui/country_flag.dart';
import 'package:fcm_rivals/features/packs/pack_opening_screen.dart';

BasePlayer _player({int overall = 87}) => BasePlayer(
      playerId: 1,
      name: 'Test Striker',
      position: Position.st,
      age: 24,
      nationality: 'Brazil',
      club: 'Test FC',
      leagueCode: 'GB1',
      marketValueEur: 90000000,
      baseStats: BaseStats(
          overall: overall, attack: 91, support: 72, defence: 40, goalkeeping: 0),
    );

void main() {
  testWidgets('sequence runs from sealed pack to the revealed stat card',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PackOpeningScreen(players: [_player()]),
    ));

    // Sealed pack waits for a tap; the keep button is not offered yet.
    expect(find.text('TAP TO OPEN'), findsOneWidget);
    final keepOpacity = tester
        .widget<AnimatedOpacity>(find.byKey(const ValueKey('keep-fade')));
    expect(keepOpacity.opacity, 0);

    await tester.tap(find.text('TAP TO OPEN'));
    await tester.pump();
    expect(find.text('TAP TO OPEN'), findsNothing);

    // Walkout (timeline ~0.40–0.48 of 8s): flag, nationality, position, name.
    await tester.pump(const Duration(milliseconds: 3900));
    expect(find.text(flagEmojiFor('Brazil')), findsOneWidget);
    expect(find.text('BRAZIL'), findsOneWidget);
    expect(find.text('ST'), findsOneWidget);
    expect(find.text('TEST STRIKER'), findsOneWidget);

    // Done (past 0.88): card shows final rating and attributes, button live.
    await tester.pump(const Duration(milliseconds: 3600));
    expect(find.text('87'), findsOneWidget);
    expect(find.text('91'), findsOneWidget);
    expect(find.text('ATT'), findsOneWidget);
    expect(find.text('GOLD'), findsOneWidget);
    // The fade-in itself takes 300ms after the done mark.
    await tester.pump(const Duration(milliseconds: 400));
    final done = tester
        .widget<AnimatedOpacity>(find.byKey(const ValueKey('keep-fade')));
    expect(done.opacity, 1);
  });

  testWidgets('skip jumps ahead without waiting for the full timeline',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PackOpeningScreen(players: [_player(overall: 55)]),
    ));
    await tester.tap(find.text('TAP TO OPEN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('SKIP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // After the first skip the card flip is under way; skip again to the end.
    await tester.tap(find.text('SKIP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('BRONZE'), findsOneWidget);
    expect(find.text('KEEP PLAYER'), findsOneWidget);
  });
}
