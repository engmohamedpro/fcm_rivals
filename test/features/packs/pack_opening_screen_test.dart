// Pack opening sequence (GDD 5.6): tap → charge → burst → nationality and
// position walkout → card flip → stats count up → NAME reveal → keep
// button. The player's name is hidden until the stats have appeared.
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
      nationality: 'Brazil',
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

    // Walkout (timeline ~0.32–0.40 of 8s): flag, nationality, position —
    // but NOT the name: the identity is held back until the stats land.
    await tester.pump(const Duration(milliseconds: 3300));
    expect(find.text(flagEmojiFor('Brazil')), findsOneWidget);
    expect(find.text('BRAZIL'), findsOneWidget);
    expect(find.text('ST'), findsOneWidget);
    expect(find.text('TEST STRIKER'), findsNothing);

    // Card flip with stats counting up (~0.70 of 8s): rating and
    // attributes appear, the name plate still masked.
    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.text('ATT'), findsOneWidget);
    expect(find.text('TEST STRIKER'), findsNothing);

    // Stats complete exactly at t = 0.88 (7040ms of 8s): final rating
    // has landed, the name is still masked for one more beat.
    await tester.pump(const Duration(milliseconds: 840));
    expect(find.text('87'), findsOneWidget);
    expect(find.text('TEST STRIKER'), findsNothing);
    // Name reveal (0.88–0.97 of 8s): the identity lands AFTER the stats —
    // on the card plate AND the celebration banner below it.
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('TEST STRIKER'), findsWidgets);
    expect(find.text('91'), findsOneWidget);
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
