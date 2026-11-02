// Regression tests for the tactics setup surface:
//
//  * the control card's top row carries formation / style / mentality and
//    CLOSES with the team rating — one line, no overflow, at any width
//    (a previous rating + Auto Pick + TACTICS row overflowed ~40px on
//    phones; the actions now live on their own full-width row below);
//  * showStamina toggles the stamina bars (the Tactics tab hides them,
//    the pre-match phase shows them).
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
        age: 25,
        nationality: 'Egypt',
        club: 'Al Ahly',
        leagueCode: 'EG1',
        marketValueEur: 5_000_000,
        baseStats: const BaseStats(
            overall: 80, attack: 82, support: 75, defence: 40, goalkeeping: 0),
      ),
    );

Widget _host({bool showStamina = true, List<PlayerCard>? bench}) =>
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
}
