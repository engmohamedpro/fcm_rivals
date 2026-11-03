// Pack opening sequence (GDD 5.6): tap → charge → burst → nationality and
// position walkout → card flip → stats count up → NAME reveal → SELL /
// KEEP buttons. The player's name is hidden until the stats have appeared.
// The reveal is never skippable — the SKIP control is gone and the full
// timeline always plays; SELL sits left of KEEP, carries the player's coin
// value, and sells him through the caller's callback.
//
// The screen has repeating idle animations, so the test advances time with
// explicit pumps instead of pumpAndSettle.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/core/ui/country_flag.dart';
import 'package:fcm_rivals/core/ui/fcm_widgets.dart'
    show FcmCoinChip, FcmCoinGlyph;
import 'package:fcm_rivals/features/economy/economy_engine.dart';
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

Future<void> _revealAll(WidgetTester tester) async {
  await tester.tap(find.text('TAP TO OPEN'));
  await tester.pump();
  // The full 8s sequence, then the button fade-in.
  await tester.pump(const Duration(seconds: 8));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('sequence runs from sealed pack to the revealed stat card',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PackOpeningScreen(players: [_player()]),
    ));

    // Sealed pack waits for a tap; the action row is not offered yet.
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

    // No SKIP control exists anywhere in the timeline.
    expect(find.text('SKIP'), findsNothing);

    // Stats complete exactly at t = 0.88 (7040ms of 8s): final rating
    // has landed, the name is still masked for one more beat.
    await tester.pump(const Duration(milliseconds: 840));
    expect(find.text('87'), findsOneWidget);
    expect(find.text('TEST STRIKER'), findsNothing);
    // Name reveal (0.88–0.97 of 8s): the identity lands AFTER the stats,
    // on the card's name plate — nothing duplicates it below the card.
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('TEST STRIKER'), findsOneWidget);
    expect(find.text('91'), findsOneWidget);
    expect(find.text('LEGENDARY'), findsOneWidget);
    // The fade-in itself takes 300ms after the done mark.
    await tester.pump(const Duration(milliseconds: 400));
    final done = tester
        .widget<AnimatedOpacity>(find.byKey(const ValueKey('keep-fade')));
    expect(done.opacity, 1);
  });

  testWidgets('no skip control — the reveal always plays in full',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PackOpeningScreen(
        players: [_player(overall: 55)],
        ownedIds: const [77],
        onSell: (ownedId) async {},
      ),
    ));
    await tester.tap(find.text('TAP TO OPEN'));
    await tester.pump();
    // Halfway through the timeline there is still no way to skip.
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('SKIP'), findsNothing);
    // The action row exists but stays invisible until the done mark.
    final mid = tester
        .widget<AnimatedOpacity>(find.byKey(const ValueKey('keep-fade')));
    expect(mid.opacity, 0);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('RARE'), findsOneWidget);
    expect(find.text('KEEP PLAYER'), findsOneWidget);
    // SELL carries the player's coin value (overall 55 → the economy's
    // sell price of a 90M-market-value player) behind the same C coin
    // glyph as the top-bar balance.
    final sellValue =
        const EconomyEngine().sellPriceOf(_player(overall: 55));
    expect(find.text('SELL'), findsOneWidget);
    expect(find.text(FcmCoinChip.compact(sellValue)), findsOneWidget);
    expect(find.byType(FcmCoinGlyph), findsOneWidget);
    final done = tester
        .widget<AnimatedOpacity>(find.byKey(const ValueKey('keep-fade')));
    expect(done.opacity, 1);
  });

  testWidgets('SELL sells the revealed player and moves on', (tester) async {
    final sold = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: PackOpeningScreen(
        players: [_player(), _player(overall: 60)],
        ownedIds: const [501, 502],
        onSell: (ownedId) async => sold.add(ownedId),
      ),
    ));
    await _revealAll(tester);

    await tester.tap(find.textContaining('SELL'));
    await tester.pump();
    // The sale ran for the FIRST player's owned id…
    expect(sold, [501]);
    // …and the sequence advanced to the second (last) player, whose
    // action row offers KEEP PLAYER.
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('KEEP PLAYER'), findsOneWidget);
  });

  testWidgets('KEEP advances without selling', (tester) async {
    final sold = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: PackOpeningScreen(
        players: [_player(), _player(overall: 60)],
        ownedIds: const [501, 502],
        onSell: (ownedId) async => sold.add(ownedId),
      ),
    ));
    await _revealAll(tester);

    await tester.tap(find.text('NEXT PLAYER  1/2'));
    await tester.pump();
    expect(sold, isEmpty);
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('KEEP PLAYER'), findsOneWidget);
  });

  testWidgets('no onSell callback — SELL is hidden, KEEP works alone',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PackOpeningScreen(players: [_player()]),
    ));
    await _revealAll(tester);
    expect(find.textContaining('SELL'), findsNothing);
    expect(find.text('KEEP PLAYER'), findsOneWidget);
    await tester.tap(find.text('KEEP PLAYER'));
    await tester.pump();
    // The single player is kept and the screen pops.
    expect(find.text('TAP TO OPEN'), findsNothing);
  });
}
