// Regression tests for the tactics setup surface:
//
//  * the control card's top row carries formation / style / mentality and
//    CLOSES with the team rating — one line, no overflow, at any width
//    (a previous rating + Auto Pick + TACTICS row overflowed ~40px on
//    phones; the actions now live on their own full-width row below);
//  * showStamina toggles the stamina bars and showStats the stat rows
//    (the Tactics tab hides both, the pre-match phase shows them).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/core/ui/player_card.dart' show FcmMiniCard;
import 'package:fcm_rivals/features/match/tactics.dart';
import 'package:fcm_rivals/features/squad/squad_engine.dart' show PlayerCard;
import 'package:fcm_rivals/features/squad/squad_view.dart';

PlayerCard _card(int id, Position position, {int stamina = 100}) =>
    PlayerCard(
      ownedId: id,
      upgradeLevel: 0,
      staminaPercent: stamina,
      base: BasePlayer(
        playerId: 1000 + id,
        name: 'Player $id',
        position: position,
        nationality: 'Egypt',
        marketValueEur: 5_000_000,
        baseStats: const BaseStats(
            overall: 80, attack: 82, support: 75, defence: 40, goalkeeping: 0),
      ),
    );

Widget _host({
  bool showStamina = true,
  bool showStats = true,
  List<PlayerCard>? bench,
}) =>
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SingleChildScrollView(
          child: TacticsSetupView(
            formationCode: '4-3-3',
            style: PlayingStyle.balanced,
            mentality: Mentality.balanced,
            xi: const {},
            bench: bench ?? const [],
            reserves: const [],
            onFormation: (_) {},
            onStyle: (_) {},
            onMentality: (_) {},
            onAutoPick: () {},
            showStamina: showStamina,
            showStats: showStats,
          ),
        ),
      ),
    );

/// Number of 5px-tall decorated boxes under the mini cards: the stamina
/// track (and its fill) — zero means no stamina bar is rendered.
int _staminaTracks() {
  var count = 0;
  for (final e in find
      .descendant(
        of: find.byType(FcmMiniCard),
        matching: find.byType(DecoratedBox),
      )
      .evaluate()) {
    if ((e.renderObject as RenderBox).size.height == 5) count++;
  }
  return count;
}

void main() {
  testWidgets('setup row closes with the team rating, actions below',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(340, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.text('TEAM RATING'), findsOneWidget);
    expect(find.text('FORMATION'), findsOneWidget);
    expect(find.text('STYLE'), findsOneWidget);
    expect(find.text('MENTALITY'), findsOneWidget);
    expect(find.text('Auto Pick'), findsOneWidget);
    expect(find.text('TACTICS'), findsOneWidget);

    // The rating ends the setup row: right of FORMATION, on its line.
    final formation = tester.getTopLeft(find.text('FORMATION'));
    final rating = tester.getTopLeft(find.text('TEAM RATING'));
    expect(rating.dx, greaterThan(formation.dx));
    expect((rating.dy - formation.dy).abs(), lessThan(4));

    // The action buttons sit on the full-width row under the setup row.
    final ratingBottom = tester.getBottomLeft(find.text('TEAM RATING'));
    final autoPick = tester.getTopLeft(find.text('Auto Pick'));
    final tactics = tester.getTopLeft(find.text('TACTICS'));
    expect(autoPick.dy, greaterThan(ratingBottom.dy));
    expect((tactics.dy - autoPick.dy).abs(), lessThan(8));
  });

  testWidgets('bench and reserves always show their full quota of slots',
      (WidgetTester tester) async {
    // One bench player, no reserves: 6 bench placeholders + all 5
    // reserve placeholders render after the real card.
    await tester.pumpWidget(_host(bench: [_card(1, Position.st)]));
    await tester.pumpAndSettle();

    expect(find.text('Bench (1/7)'), findsOneWidget);
    expect(find.text('Reserves (0/5)'), findsOneWidget);
    expect(find.byType(FcmMiniCard), findsOneWidget);
    expect(find.text('EMPTY'), findsNWidgets(6 + 5));

    // The placeholders sit after the real card in the bench strip.
    final cardLeft = tester.getTopLeft(find.byType(FcmMiniCard).first);
    final firstEmpty = tester.getTopLeft(find.text('EMPTY').first);
    expect(firstEmpty.dx, greaterThan(cardLeft.dx));

    // Even a completely empty squad keeps both sections visible.
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(find.text('Bench (0/7)'), findsOneWidget);
    expect(find.text('Reserves (0/5)'), findsOneWidget);
    expect(find.text('EMPTY'), findsNWidgets(7 + 5));
  });

  testWidgets('stamina bars render only when shown',
      (WidgetTester tester) async {
    final bench = [_card(1, Position.st, stamina: 50)];

    await tester.pumpWidget(_host(bench: bench));
    await tester.pumpAndSettle();
    expect(find.byType(FcmMiniCard), findsOneWidget);
    expect(_staminaTracks(), greaterThan(0),
        reason: 'stamina bar shown when enabled');

    await tester.pumpWidget(_host(bench: bench, showStamina: false));
    await tester.pumpAndSettle();
    expect(_staminaTracks(), 0,
        reason: 'no stamina bar when showStamina is false');
  });

  testWidgets('stat rows render only when shown',
      (WidgetTester tester) async {
    final bench = [_card(1, Position.st)];

    await tester.pumpWidget(_host(bench: bench));
    await tester.pumpAndSettle();
    expect(find.text('ATT'), findsOneWidget);
    expect(find.text('SUP'), findsOneWidget);
    expect(find.text('DEF'), findsOneWidget);

    // The Tactics tab's shape: no stats, no stamina — just the shield
    // and the surname.
    await tester.pumpWidget(
        _host(bench: bench, showStamina: false, showStats: false));
    await tester.pumpAndSettle();
    expect(find.text('ATT'), findsNothing);
    expect(find.text('SUP'), findsNothing);
    expect(find.text('DEF'), findsNothing);
  });
}
