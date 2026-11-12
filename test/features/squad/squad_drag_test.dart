// Hold-and-drag swapping on the tactics surface: a long press picks a
// card up, dropping it on another card reports (dragged, target) to the
// owner; surfaces that do not enable swapping have no draggable cards.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/match/tactics.dart';
import 'package:fcm_rivals/features/squad/formations.dart';
import 'package:fcm_rivals/features/squad/squad_drag.dart';
import 'package:fcm_rivals/features/squad/squad_engine.dart' show PlayerCard;
import 'package:fcm_rivals/features/squad/squad_swap.dart';
import 'package:fcm_rivals/features/squad/squad_view.dart';

PlayerCard _card(int id, Position position) => PlayerCard(
  ownedId: id,
  upgradeLevel: 0,
  base: BasePlayer(
    playerId: 1000 + id,
    name: 'First Surn$id',
    position: position,
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

final _f433 = formationByCode('4-3-3');

Map<int, PlayerCard> _squad() {
  final squad = <int, PlayerCard>{};
  for (var i = 0; i < 11; i++) {
    squad[i] = _card(i, _f433.slots[i].position);
  }
  const bench = [
    Position.gk,
    Position.cb,
    Position.lb,
    Position.cm,
    Position.st,
    Position.rw,
    Position.cdm,
  ];
  for (var i = 0; i < 7; i++) {
    squad[11 + i] = _card(11 + i, bench[i]);
  }
  const reserves = [
    Position.st,
    Position.cam,
    Position.rb,
    Position.lw,
    Position.cb,
  ];
  for (var i = 0; i < 5; i++) {
    squad[18 + i] = _card(18 + i, reserves[i]);
  }
  return squad;
}

typedef _Drop = ({PlayerCard dragged, SquadDropTarget target});

Widget _host(
  Map<int, PlayerCard> squad, {
  List<_Drop>? drops,
  bool swap = true,
}) {
  final xi = {for (var i = 0; i < 11; i++) i: squad[i]!};
  final bench = [for (var i = 11; i < 18; i++) squad[i]!];
  final reserves = [for (var i = 18; i < 23; i++) squad[i]!];
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: TacticsSetupView(
          formationCode: '4-3-3',
          tactics: const TeamTactics(),
          mentality: Mentality.balanced,
          xi: xi,
          bench: bench,
          reserves: reserves,
          onFormation: (_) {},
          onTactics: (_) {},
          onMentality: (_) {},
          showStamina: false,
          showStats: false,
          swapping: swap
              ? SquadSwapping(
                  rejection: (dragged, target) => planSquadDrop(
                    formation: _f433,
                    squad: squad,
                    dragged: dragged,
                    target: target,
                  ).rejection,
                  onSwap: (dragged, target) =>
                      drops?.add((dragged: dragged, target: target)),
                )
              : null,
        ),
      ),
    ),
  );
}

/// Holds [from] long enough to pick it up, carries it onto [to], drops it.
Future<void> _drag(WidgetTester tester, Finder from, Finder to) async {
  // Both positions are read BEFORE the card is lifted: while it is held
  // its name exists twice (the dimmed original and the floating copy).
  final fromPos = tester.getCenter(from);
  final toPos = tester.getCenter(to);
  final gesture = await tester.startGesture(fromPos);
  await tester.pump(const Duration(milliseconds: 700)); // long press
  await gesture.moveTo(toPos);
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('with swapping on, every card is a hold-to-drag card', (
    WidgetTester tester,
  ) async {
    bigScreen(tester);
    await tester.pumpWidget(_host(_squad()));
    await tester.pump(const Duration(seconds: 2));
    // 11 starters + 7 bench + 5 reserves.
    expect(find.byType(LongPressDraggable<PlayerCard>), findsNWidgets(23));
    // T-0093: the hint sentence is gone — nothing renders it anymore
    // (asserted once more on the Team tab in squad_screen_test).
    expect(
      find.text('Hold a player and drop him on another to swap'),
      findsNothing,
    );
  });

  testWidgets('a pool card already placed (gold check) cannot be picked up', (
    WidgetTester tester,
  ) async {
    bigScreen(tester);
    final squad = _squad();
    final cards = [squad[0]!, squad[1]!, squad[2]!];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SquadDragHost(
            swapping: SquadSwapping(
              rejection: (_, _) => null,
              onSwap: (_, _) {},
            ),
            child: SquadCardRow(
              cards: cards,
              selectedIds: {cards[0].ownedId, cards[1].ownedId},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    // Only the one card that is not placed yet can be held.
    expect(find.byType(LongPressDraggable<PlayerCard>), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is SquadDraggable && w.card.ownedId == cards[2].ownedId,
      ),
      findsOneWidget,
    );
  });

  testWidgets('without swapping there is nothing to drag', (
    WidgetTester tester,
  ) async {
    bigScreen(tester);
    await tester.pumpWidget(_host(_squad(), swap: false));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(LongPressDraggable<PlayerCard>), findsNothing);
    expect(find.byType(DragTarget<PlayerCard>), findsNothing);
  });

  testWidgets('dropping a bench player on a starter reports the swap', (
    WidgetTester tester,
  ) async {
    bigScreen(tester);
    final squad = _squad();
    final drops = <_Drop>[];
    await tester.pumpWidget(_host(squad, drops: drops));
    await tester.pump(const Duration(seconds: 2));

    // Bench striker (id 15) onto the starting striker (id 9).
    await _drag(tester, find.text('F. Surn15'), find.text('F. Surn9'));
    expect(drops, hasLength(1));
    expect(drops.single.dragged.ownedId, 15);
    expect(drops.single.target.card?.ownedId, 9);
  });

  testWidgets('a pitch player can be dropped on the reserves too', (
    WidgetTester tester,
  ) async {
    bigScreen(tester);
    final drops = <_Drop>[];
    await tester.pumpWidget(_host(_squad(), drops: drops));
    await tester.pump(const Duration(seconds: 2));

    // Reserve striker (id 18) onto the starting striker (id 9).
    await _drag(tester, find.text('F. Surn18'), find.text('F. Surn9'));
    expect(drops.single.dragged.ownedId, 18);
    expect(drops.single.target.card?.ownedId, 9);
  });

  testWidgets('a drop is reported even when the rules refuse it — the owner '
      'explains why', (WidgetTester tester) async {
    bigScreen(tester);
    final squad = _squad();
    final drops = <_Drop>[];
    await tester.pumpWidget(_host(squad, drops: drops));
    await tester.pump(const Duration(seconds: 2));

    // Bench CB (id 12) onto the starting striker (id 9): refused by the
    // rules, but the owner is told so it can show the reason.
    await _drag(tester, find.text('F. Surn12'), find.text('F. Surn9'));
    expect(drops, hasLength(1));
    final verdict = planSquadDrop(
      formation: _f433,
      squad: squad,
      dragged: drops.single.dragged,
      target: drops.single.target,
    );
    expect(verdict.isAccepted, isFalse);
    expect(verdict.rejection, contains('needs a ST'));
  });

  testWidgets('dropping a card on itself does nothing', (
    WidgetTester tester,
  ) async {
    bigScreen(tester);
    final drops = <_Drop>[];
    await tester.pumpWidget(_host(_squad(), drops: drops));
    await tester.pump(const Duration(seconds: 2));
    await _drag(tester, find.text('F. Surn15'), find.text('F. Surn15'));
    expect(drops, isEmpty);
  });

  testWidgets('a quick tap still works — only a long press drags', (
    WidgetTester tester,
  ) async {
    bigScreen(tester);
    final drops = <_Drop>[];
    final tapped = <int>[];
    final squad = _squad();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TacticsSetupView(
              formationCode: '4-3-3',
              tactics: const TeamTactics(),
              mentality: Mentality.balanced,
              xi: {for (var i = 0; i < 11; i++) i: squad[i]!},
              bench: [for (var i = 11; i < 18; i++) squad[i]!],
              reserves: [for (var i = 18; i < 23; i++) squad[i]!],
              onFormation: (_) {},
              onTactics: (_) {},
              onMentality: (_) {},
              showStamina: false,
              showStats: false,
              onPlayerTap: (c) => tapped.add(c.ownedId),
              swapping: SquadSwapping(
                rejection: (_, _) => null,
                onSwap: (d, t) => drops.add((dragged: d, target: t)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('F. Surn15'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tapped, [15]);
    expect(drops, isEmpty);
  });
}
