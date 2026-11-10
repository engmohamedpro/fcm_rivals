// Regression tests for the Tactics-tab full-card view: tapping a player
// opens a full-screen animated card moment. The user already knows this
// player — their own squad — so the name, rating, attributes and upgrade
// badge must be fully visible from the moment the card arrives: no card
// back, no dash-masked identity, no counting. A tap anywhere dismisses.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/core/ui/fcm_button.dart' show FcmButton;
import 'package:fcm_rivals/core/ui/player_card.dart'
    show FcmPlayerCard, FcmPlayerCardBack;
import 'package:fcm_rivals/features/squad/player_card_reveal.dart';
import 'package:fcm_rivals/features/squad/squad_engine.dart' show PlayerCard;

PlayerCard _card() => PlayerCard(
  ownedId: 7,
  upgradeLevel: 2,
  base: BasePlayer(
    playerId: 1007,
    name: 'Karim Fouad',
    position: Position.st,
    nationality: 'Egypt',
    marketValueEur: 5_000_000,
    baseStats: const BaseStats(
      overall: 80,
      attack: 82,
      support: 75,
      defence: 40,
      goalkeeping: 0,
    ),
  ),
);

Widget _host() => MaterialApp(
  home: Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: ElevatedButton(onPressed: () {}, child: const Text('REVEAL')),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(_host());
  final context = tester.element(find.text('REVEAL'));
  showPlayerCardReveal(context, card: _card());
  await tester.pump(); // first frame of the route + timeline
}

void main() {
  testWidgets('card zooms in face-up — identity and stats visible at once', (
    WidgetTester tester,
  ) async {
    await _open(tester);

    // Mid-entrance (~120ms): the face is already up with everything on
    // it — no card back, no masked name, no counting to wait for.
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byType(FcmPlayerCard), findsOneWidget);
    expect(find.byType(FcmPlayerCardBack), findsNothing);
    expect(find.text('KARIM FOUAD'), findsOneWidget);
    expect(find.text('ATT'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    expect(find.text('— — —'), findsNothing);
    expect(find.text('— · —'), findsNothing);

    // Entrance finished: identity unchanged, hint now in place.
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byType(FcmPlayerCard), findsOneWidget);
    expect(find.text('KARIM FOUAD'), findsOneWidget);
    expect(find.text('ATT'), findsOneWidget);
    expect(find.text('— — —'), findsNothing);
    expect(find.text('TAP TO CLOSE'), findsOneWidget);
  });

  testWidgets('a tap anywhere dismisses the card view', (
    WidgetTester tester,
  ) async {
    await _open(tester);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byType(FcmPlayerCard), findsOneWidget);

    // Corner AND centre both close it: the whole overlay is tappable.
    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FcmPlayerCard), findsNothing);
    expect(find.byType(FcmPlayerCardBack), findsNothing);
    expect(find.text('TAP TO CLOSE'), findsNothing);

    // Re-open and close from the centre (over the card) too.
    final context = tester.element(find.text('REVEAL'));
    showPlayerCardReveal(context, card: _card());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byType(FcmPlayerCard), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.byType(FcmPlayerCard)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FcmPlayerCard), findsNothing);
  });

  testWidgets('T-0090: showcase callers keep the plain TAP TO CLOSE', (
    WidgetTester tester,
  ) async {
    await _open(tester);
    await tester.pump(const Duration(milliseconds: 1500));
    // No callbacks wired: the hint, not the action bar.
    expect(find.text('TAP TO CLOSE'), findsOneWidget);
    expect(find.byKey(const ValueKey('reveal-back')), findsNothing);
    expect(find.byKey(const ValueKey('reveal-sell')), findsNothing);
    expect(find.byKey(const ValueKey('reveal-upgrade')), findsNothing);
  });

  testWidgets(
    'T-0090: the action bar shows BACK / SELL / UPGRADE — upgrade '
    'disabled without a duplicate',
    (WidgetTester tester) async {
      await tester.pumpWidget(_host());
      final context = tester.element(find.text('REVEAL'));
      showPlayerCardReveal(
        context,
        card: _card(),
        onSell: () async {},
        onUpgrade: (_) async {},
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      // The three localized actions replace the hint.
      expect(find.text('TAP TO CLOSE'), findsNothing);
      expect(find.byKey(const ValueKey('reveal-back')), findsOneWidget);
      expect(find.byKey(const ValueKey('reveal-sell')), findsOneWidget);
      final upgrade = tester.widget<FcmButton>(
        find.byKey(const ValueKey('reveal-upgrade')),
      );
      expect(upgrade.onPressed, isNull,
          reason: 'no other copy exists — UPGRADE is disabled');

      // BACK pops the view without any action running.
      await tester.tap(find.byKey(const ValueKey('reveal-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(FcmPlayerCard), findsNothing);
    },
  );

  testWidgets(
    'T-0090: UPGRADE with a duplicate runs the merge and the card '
    'levels up IN PLACE — the view stays open',
    (WidgetTester tester,
        {bool secondCall = false}) async {
      await tester.pumpWidget(_host());
      final context = tester.element(find.text('REVEAL'));
      PlayerCard? merged;
      showPlayerCardReveal(
        context,
        card: _card(),
        // One other copy of the same player.
        duplicates: [_card2()],
        onSell: () async {},
        onUpgrade: (duplicate) async {
          merged = _cardUpgraded();
        },
        onRefreshRegistered: (refresh) => _refreshHook = refresh,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.text('+2'), findsOneWidget, reason: 'level before');
      await tester.tap(find.byKey(const ValueKey('reveal-upgrade')));
      await tester.pump();
      expect(merged, isNotNull, reason: 'the upgrade callback ran');

      // The caller hands the stronger card back: +3 renders IN PLACE
      // and the view stays open.
      _refreshHook?.call(_cardUpgraded(), []);
      await tester.pump();
      expect(find.byType(FcmPlayerCard), findsOneWidget,
          reason: 'Requirement 5 — the view stays open after upgrade');
      expect(find.text('+3'), findsOneWidget);

      // Copies ran out: UPGRADE now disabled.
      final upgrade = tester.widget<FcmButton>(
        find.byKey(const ValueKey('reveal-upgrade')),
      );
      expect(upgrade.onPressed, isNull,
          reason: 'no copy remains — UPGRADE disabled');
    },
  );

  testWidgets('T-0090: SELL hands the card to the caller', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host());
    final context = tester.element(find.text('REVEAL'));
    var sold = false;
    showPlayerCardReveal(
      context,
      card: _card(),
      onSell: () async => sold = true,
      onUpgrade: (_) async {},
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));

    await tester.tap(find.byKey(const ValueKey('reveal-sell')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(sold, isTrue, reason: 'the sell callback ran (the caller pops)');
  });
}

void Function(PlayerCard card, List<PlayerCard> duplicates)?
    _refreshHook;

PlayerCard _card2() => PlayerCard(
  ownedId: 8,
  upgradeLevel: 0,
  base: _card().base,
);

PlayerCard _cardUpgraded() => PlayerCard(
  ownedId: 7,
  upgradeLevel: 3,
  base: _card().base,
);
