// Pack opening sequence (GDD 5.6): the sealed pack tears itself open
// IMMEDIATELY (the timeline runs from the first frame — no wait, no
// tap-to-open step, no close control) → charge →
// burst → nationality and position walkout → card flip → stats count up
// → NAME reveal → SELL / KEEP buttons. The player's name is hidden until
// the stats have appeared.
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

BasePlayer _player({int overall = 75}) => BasePlayer(
  playerId: 1,
  name: 'Test Striker',
  position: Position.st,
  nationality: 'Brazil',
  marketValueEur: 90000000,
  baseStats: BaseStats(
    overall: overall,
    attack: 91,
    support: 72,
    defence: 40,
    goalkeeping: 0,
  ),
);

/// One frame so the first-build controller kick renders — the sequence
/// starts with it, so tests simply pump the time they need.
Future<void> _autoOpen(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Future<void> _revealAll(WidgetTester tester) async {
  await _autoOpen(tester);
  // The full 8s sequence, then the button fade-in.
  await tester.pump(const Duration(seconds: 8));
  await tester.pump(const Duration(milliseconds: 400));
}

/// A legendary pull (82+): rating 91, runs the long 13s sequence.
BasePlayer _legend() => _player(overall: 89);

void main() {
  testWidgets('the pack tears itself open immediately — no tap, no wait', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: PackOpeningScreen(players: [_player()])),
    );
    // The sequence starts with the first frame: no prompt, no close
    // control, and the timeline is already moving (the walkout lands
    // exactly on the schedule the timeline defines, with no 1100ms
    // beat in front of it).
    expect(find.text('TAP TO OPEN'), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
    final idle = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('keep-fade')),
    );
    expect(idle.opacity, 0);
    expect(find.text(flagEmojiFor('Brazil')), findsNothing);

    // 3.3s in — mid-walkout on the untampered 8s timeline — the flag
    // and position have arrived without any tap.
    await tester.pump(const Duration(milliseconds: 3300));
    expect(find.text(flagEmojiFor('Brazil')), findsOneWidget);
    expect(find.text('ST'), findsOneWidget);
  });

  testWidgets('the sealed pack wears the store cell tier metal', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PackOpeningScreen(
          players: [_player()],
          packTint: const Color(0xFF8B5CF6), // rare amethyst
        ),
      ),
    );
    // Painting with a tint must not throw; the close control is gone
    // throughout — there is no sealed-pause to escape anymore.
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byIcon(Icons.close), findsNothing);
    await _autoOpen(tester);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('sequence runs from sealed pack to the revealed stat card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: PackOpeningScreen(players: [_player()])),
    );

    // The action row is never offered before the timeline's done mark.
    expect(find.text('TAP TO OPEN'), findsNothing);
    final keepOpacity = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('keep-fade')),
    );
    expect(keepOpacity.opacity, 0);

    // The sequence is underway from the first frame — no tap needed.
    await _autoOpen(tester);

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
    expect(find.text('75'), findsOneWidget);
    expect(find.text('TEST STRIKER'), findsNothing);
    // Name reveal (0.88–0.97 of 8s): the identity lands AFTER the stats,
    // on the card's name plate — nothing duplicates it below the card.
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('TEST STRIKER'), findsOneWidget);
    expect(find.text('91'), findsOneWidget);
    // The fade-in itself takes 300ms after the done mark.
    await tester.pump(const Duration(milliseconds: 400));
    final done = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('keep-fade')),
    );
    expect(done.opacity, 1);
  });

  testWidgets('no skip control — the reveal always plays in full', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PackOpeningScreen(
          players: [_player(overall: 55)],
          ownedIds: const [77],
          onSell: (ownedId) async {},
        ),
      ),
    );
    await _autoOpen(tester);
    // Halfway through the timeline there is still no way to skip.
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('SKIP'), findsNothing);
    // The action row exists but stays invisible until the done mark.
    final mid = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('keep-fade')),
    );
    expect(mid.opacity, 0);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('BACK'), findsOneWidget);
    // SELL carries the player's coin value (overall 55 → the economy's
    // sell price of a 90M-market-value player) behind the same C coin
    // glyph as the top-bar balance.
    final sellValue = const EconomyEngine().sellPriceOf(_player(overall: 55));
    expect(find.text('SELL'), findsOneWidget);
    expect(find.text(FcmCoinChip.compact(sellValue)), findsOneWidget);
    expect(find.byType(FcmCoinGlyph), findsOneWidget);
    final done = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('keep-fade')),
    );
    expect(done.opacity, 1);
  });

  testWidgets('SELL sells an earlier card and advances to the next', (
    tester,
  ) async {
    final sold = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PackOpeningScreen(
          players: [_player(), _player(overall: 60)],
          ownedIds: const [501, 502],
          onSell: (ownedId) async => sold.add(ownedId),
        ),
      ),
    );
    await _revealAll(tester);

    // T-0085 order: resolver first, SELL last.
    await tester.tap(find.textContaining('SELL'));
    await tester.pump();
    // The sale ran for the FIRST player's owned id…
    expect(sold, [501]);
    // …and the sequence advanced to the second (last) player, whose
    // action row now offers BACK (T-0085) with SELL after it.
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('BACK'), findsOneWidget);
    expect(find.text('KEEP PLAYER'), findsNothing);
  });

  testWidgets('NEXT PLAYER advances without selling', (tester) async {
    final sold = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PackOpeningScreen(
          players: [_player(), _player(overall: 60)],
          ownedIds: const [501, 502],
          onSell: (ownedId) async => sold.add(ownedId),
        ),
      ),
    );
    await _revealAll(tester);

    await tester.tap(find.text('NEXT PLAYER  1/2'));
    await tester.pump();
    expect(sold, isEmpty);
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 400));
    // The last card's resolver is BACK now (T-0085).
    expect(find.text('BACK'), findsOneWidget);
    expect(find.text('KEEP PLAYER'), findsNothing);
  });

  testWidgets('no onSell callback — SELL is hidden, KEEP works alone', (
    tester,
  ) async {
    // Pushed like the store does (a pop on MaterialApp's home route
    // would be a no-op, so the reveal is always tested as a route).
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => PackOpeningScreen(players: [_player()]),
              ),
            ),
            child: const Text('PUSH'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('PUSH'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _revealAll(tester);
    expect(find.textContaining('SELL'), findsNothing);
    expect(find.text('KEEP PLAYER'), findsNothing);
    // Preview draws: the single full-width resolver is BACK (T-0085).
    expect(find.text('BACK'), findsOneWidget);
    await tester.tap(find.text('BACK'), warnIfMissed: false);
    // The pop runs synchronously; the fullscreen-dialog exit
    // transition then unwinds across the next frames.
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // The single player is kept and the reveal pops back to the pusher.
    expect(find.byType(PackOpeningScreen), findsNothing);
    expect(find.text('PUSH'), findsOneWidget);
  });

  testWidgets('T-0085: BACK pops the reveal without selling or chaining', (
    tester,
  ) async {
    final sold = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<bool>(
                fullscreenDialog: true,
                builder: (_) => PackOpeningScreen(
                  players: [_player()],
                  ownedIds: const [501],
                  onSell: (ownedId) async => sold.add(ownedId),
                  chainInfo: const PackChainInfo(
                    price: 26_000,
                    balance: 50_000,
                    ownedCount: 0,
                    title: 'Rare Global Pack',
                  ),
                ),
              ),
            ),
            child: const Text('PUSH'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('PUSH'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _revealAll(tester);

    // The chain capsule is offered (affordable), but BACK resolves the
    // card WITHOUT chaining: the route pops with NO result — not `true`.
    await tester.tap(find.text('BACK'), warnIfMissed: false);
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(PackOpeningScreen), findsNothing);
    expect(sold, isEmpty, reason: 'BACK keeps the card — no sale');
    expect(find.text('PUSH'), findsOneWidget);
  });

  testWidgets(
    'T-0085: SELL on the LAST card stays on the reveal — SOLD mark, '
    'no double sell, chain still tappable',
    (tester) async {
      var sellCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PackOpeningScreen(
            players: [_player()],
            ownedIds: const [501],
            onSell: (ownedId) async => sellCalls++,
            chainInfo: const PackChainInfo(
              price: 26_000,
              balance: 50_000,
              ownedCount: 3,
              title: 'Rare Global Pack',
            ),
          ),
        ),
      );
      await _revealAll(tester);

      // SELL the last card: the screen STAYS (T-0085)…
      await tester.tap(find.textContaining('SELL'));
      await tester.pump();
      expect(find.byType(PackOpeningScreen), findsOneWidget);
      expect(sellCalls, 1);

      // …the card is visibly sold: the steel button reads SOLD with no
      // coin value and no enabled SELL remains…
      expect(find.text('SOLD'), findsOneWidget);
      expect(
        find.text(FcmCoinChip.compact(
          EconomyEngine().sellPriceOf(_player()),
        )),
        findsNothing,
        reason: 'the sold card shows no price anymore',
      );

      // …a second tap on the sold mark does NOT sell again…
      await tester.tap(find.text('SOLD'), warnIfMissed: false);
      await tester.pump();
      expect(sellCalls, 1, reason: 'the sold card cannot sell twice');

      // …and the chain capsule is still offered — BACK too.
      expect(find.text('OPEN ANOTHER'), findsOneWidget);
      expect(find.text('FREE ×3'), findsOneWidget);
      expect(find.text('BACK'), findsOneWidget);

      // BACK then still pops the reveal.
      await tester.tap(find.text('BACK'), warnIfMissed: false);
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(PackOpeningScreen), findsNothing);
    },
  );

  testWidgets('T-0085: the action row order mirrors in Arabic (RTL)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: PackOpeningScreen(
            players: [_player(), _player(overall: 60)],
            ownedIds: const [501, 502],
            onSell: (ownedId) async {},
          ),
        ),
      ),
    );
    await _revealAll(tester);

    // In RTL the resolver still sits at the row's START — the RIGHT
    // edge — and SELL at the END (LEFT edge): Row order follows the
    // text direction, so the T-0085 layout mirrors automatically.
    final next = tester.getTopRight(find.text('NEXT PLAYER  1/2'));
    final sell = tester.getTopLeft(find.textContaining('SELL'));
    expect(next.dx, greaterThan(sell.dx),
        reason: 'RTL: NEXT PLAYER starts at the right edge');

    // Advance to the last card: BACK at the start (right), SELL last
    // (left).
    await tester.tap(find.text('NEXT PLAYER  1/2'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 400));
    final back = tester.getTopRight(find.text('BACK'));
    final sellLast = tester.getTopLeft(find.textContaining('SELL'));
    expect(back.dx, greaterThan(sellLast.dx),
        reason: 'RTL: BACK starts at the right edge, SELL ends at the left');
  });

  testWidgets('a legendary pull runs a much longer, special timeline', (
    tester,
  ) async {
    // The standard reveal is 8s; the legendary one is the T-0051
    // tightened 13s — 1.625×, still a clearly longer, special timeline.
    expect(
      kLegendaryRevealDuration.inMilliseconds,
      greaterThan(kStandardRevealDuration.inMilliseconds),
    );

    await tester.pumpWidget(
      MaterialApp(home: PackOpeningScreen(players: [_legend()])),
    );
    await _autoOpen(tester);

    // At the old test's fraction (8s of 17s ≈ 0.47 — 6.1s of 13s), the
    // legend is still building: no buttons, no name, no stat card yet.
    await tester.pump(const Duration(milliseconds: 6100));
    final mid = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('keep-fade')),
    );
    expect(mid.opacity, 0);
    expect(find.text('TEST STRIKER'), findsNothing);
    expect(find.text('LEGENDARY PULL!'), findsNothing);
    // T-0101: the suspense captions are gone — nothing floats above
    // the card while the silhouette waits.
    expect(find.text('A LEGEND IS COMING…'), findsNothing);
  });

  testWidgets(
    'legendary walkout lands flag then position — the RATING and the NAME '
    'only appear on the card',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: PackOpeningScreen(players: [_legend()])),
      );
      await _autoOpen(tester);

      // Clue 1 (~0.30–0.37 of the 13s timeline): the flag, and nothing
      // else yet.
      await tester.pump(const Duration(milliseconds: 4300));
      expect(find.text(flagEmojiFor('Brazil')), findsOneWidget);
      expect(find.text('TEST STRIKER'), findsNothing);

      // Clue 2 (~0.385–0.455): the position.
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('ST'), findsOneWidget);

      // Right up to the flip (0.60 = 7.8s) NO rating is on screen: the
      // overall must not be spoiled before the card is revealed.
      await tester.pump(const Duration(milliseconds: 1600)); // ~7.4s
      expect(find.text('91'), findsNothing);
      expect(find.text('TEST STRIKER'), findsNothing);

      // Card flipped, stats counting up — the rating shows for the first
      // time, on the card — and the name is still redacted
      // (name starts at 0.89 = 11.6s).
      await tester.pump(const Duration(milliseconds: 3700)); // ~11.1s
      expect(find.text('ATT'), findsOneWidget);
      // T-0101: no caption above the card anymore.
      expect(find.text('WHO IS IT?'), findsNothing);
      expect(find.text('TEST STRIKER'), findsNothing);
      final stillHidden = tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('keep-fade')),
      );
      expect(stillHidden.opacity, 0);

      // The name types in, then the finale banner and the action row.
      await tester.pump(const Duration(milliseconds: 1550)); // ~12.6s
      expect(find.text('TEST STRIKER'), findsOneWidget);
      // T-0101: the pull banner is gone too.
      expect(find.text('LEGENDARY PULL!'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump(const Duration(milliseconds: 400));
      final done = tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('keep-fade')),
      );
      expect(done.opacity, 1);
      expect(find.text('BACK'), findsOneWidget);
    },
  );

  testWidgets('after a legend, the next player plays his own timeline', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PackOpeningScreen(players: [_legend(), _player(overall: 60)]),
      ),
    );
    await _autoOpen(tester);
    await tester.pump(kLegendaryRevealDuration);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('NEXT PLAYER  1/2'), findsOneWidget);

    await tester.tap(find.text('NEXT PLAYER  1/2'));
    await tester.pump();
    // The rare player runs the standard 8s timeline (from the walkout
    // mark): well inside 8s the action row is back and he is KEPT last.
    await tester.pump(kStandardRevealDuration);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('BACK'), findsOneWidget);
  });

  testWidgets('premium 90+ pull: the red timeline — mystery caption, '
      'localized PREMIUM banner, the reveal outlives the golden 13s', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: PackOpeningScreen(players: [_player(overall: 91)])),
    );
    await _autoOpen(tester);

    // T-0101: no caption on the premium pacing either (mysteryIn
    // 0.19-0.27 of the 20s timeline — the card alone carries the
    // reveal).
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('A LEGEND IS COMING…'), findsNothing);

    // Where the GOLDEN reveal is already done (12.7s of 13s), the red
    // one is still holding the name back — longer by design, not
    // padding.
    await tester.pump(const Duration(seconds: 11));
    expect(find.text('WHO IS IT?'), findsNothing);
    expect(find.text('TEST STRIKER'), findsNothing);

    // The name lands (nameIn starts at 0.865 of 20s); no banner
    // accompanies it — T-0101 removed the text overlays above the
    // card.
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('PREMIUM PULL!'), findsNothing);
    expect(find.text('TEST STRIKER'), findsOneWidget);
    expect(find.text('WHO IS IT?'), findsNothing);

    // The second finale wave (finale2 0.975-1.0) fires AFTER the
    // buttons are up — the sequence runs to its end without crashing.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('PREMIUM PULL!'), findsNothing);
  });
}
