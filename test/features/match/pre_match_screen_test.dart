// Regression tests for the pre-match analysis phase (GDD 13):
//
//  * the analysis is about the OPPONENT: a compact header strip with
//    crest, table position and last-five form pips; loss/draw/win
//    percents in one row; the strength card; the opponent's top-3 rated
//    players as three collection-style cards side by side;
//  * the analysis phase shows a BACK action that exits the matchday
//    build-up before anything is committed (the fixture stays unplayed);
//    hosts can substitute their own exit via onExit;
//  * later phases step back through the build-up, not out of it.
import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/l10n/app_localizations.dart';
import 'package:fcm_rivals/features/match/pre_match_analysis.dart';
import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/core/ui/player_card.dart'
    show FcmPlayerCard, FcmMiniCard;
import 'package:fcm_rivals/features/match/match_engine.dart' show TeamTotals;
import 'package:fcm_rivals/features/match/match_forecast.dart';
import 'package:fcm_rivals/features/match/pre_match_screen.dart';
import 'package:fcm_rivals/features/match/tactics.dart';
import 'package:fcm_rivals/features/squad/squad_engine.dart' show PlayerCard;

MatchForecast get _forecast => MatchForecast(
  samples: 100,
  winPercent: 45,
  drawPercent: 30,
  lossPercent: 25,
  avgUserGoals: 1.6,
  avgOpponentGoals: 1.1,
  cleanSheetPercent: 33,
  userTotals: TeamTotals(attack: 70, support: 68, defence: 65, goalkeeping: 60),
  opponentTotals: TeamTotals(
    attack: 72,
    support: 64,
    defence: 61,
    goalkeeping: 58,
  ),
  userChemistry: 4,
  opponentChemistry: 2,
);

PreMatchData get _data => PreMatchData(
  fixtureLabel: 'League · Round 1',
  userClubName: 'FC Rivals',
  opponentClubName: 'Al Ahly',
  userAtHome: true,
  forecast: _forecast,
  opponentForm: const ['W', 'D', 'L', 'W', 'D'],
  opponentPosition: 5,
  userPosition: 12,
  opponentKeyMen: const [
    (
      name: 'Omar Gamal',
      position: 'ST',
      overall: 84,
      attack: 86,
      support: 80,
      defence: 42,
      goalkeeping: 12,
    ),
    (
      name: 'Karim Fouad',
      position: 'CB',
      overall: 81,
      attack: 48,
      support: 66,
      defence: 87,
      goalkeeping: 15,
    ),
    (
      name: 'Ali Soliman',
      position: 'GK',
      overall: 79,
      attack: 18,
      support: 44,
      defence: 62,
      goalkeeping: 83,
    ),
  ],
  // Enough owned players to fill the tactics phase's strips: a starting
  // XI for the 4-3-3 slots, plus one bench and one reserve card.
  userSquad: {
    0: _card(0, 'GK Guy', Position.gk, 82),
    1: _card(1, 'LB Lad', Position.lb, 78),
    2: _card(2, 'CB One', Position.cb, 80),
    3: _card(3, 'CB Two', Position.cb, 79),
    4: _card(4, 'RB Man', Position.rb, 77),
    5: _card(5, 'CM Ace', Position.cm, 81),
    6: _card(6, 'CM Two', Position.cm, 76),
    7: _card(7, 'CAM Star', Position.cam, 83),
    8: _card(8, 'LW Wing', Position.lw, 79),
    9: _card(9, 'ST Finisher', Position.st, 85),
    10: _card(10, 'RW Rover', Position.rw, 78),
    11: _card(11, 'Bench Boy', Position.st, 74),
    12: _card(12, 'Reserve Guy', Position.cm, 70),
  },
);

/// One owned card for the tactics-phase fixture: [slot] is the map key,
/// [name]/[pos]/[rating] build the base player.
PlayerCard _card(int slot, String name, Position pos, int rating) => PlayerCard(
  ownedId: slot,
  upgradeLevel: 0,
  staminaPercent: 90,
  base: BasePlayer(
    playerId: slot,
    name: name,
    position: pos,
    nationality: '',
    marketValueEur: 0,
    baseStats: BaseStats(
      attack: rating - 4,
      support: rating,
      defence: rating - 6,
      goalkeeping: pos == Position.gk ? rating : 10,
      overall: rating,
    ),
  ),
);

/// Marker page the pre-match route is pushed on top of.
Widget _home() => const MaterialApp(
  home: Scaffold(body: Center(child: Text('SEASON TAB'))),
);

/// Ambient animations (the backdrop's 26s loop) never settle, so pump
/// bounded frames instead of pumpAndSettle.
Future<void> _settle(WidgetTester tester, {int frames = 14}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _openPreMatch(
  WidgetTester tester, {
  VoidCallback? onExit,
  void Function(MatchPepTalk?)? onKickOff,
}) async {
  // A tall surface so the whole analysis fits on screen at once (the
  // default 800x600 test viewport cuts the lower cards off).
  tester.view.physicalSize = const Size(800, 1700);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_home());
  await tester.pump();
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  await tester.pump();
  unawaited(
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => PreMatchScreen(
          data: _data,
          onKickOff: onKickOff ?? (_) {},
          onExit: onExit,
        ),
      ),
    ),
  );
  await _settle(tester, frames: 10);
}

void main() {
  testWidgets(
    'T-0102: the header is team vs team — HOME club first, both '
    'orientations',
    (WidgetTester tester) async {
      await _openPreMatch(tester);

      // Both club names show, the user home: FC Rivals at the start.
      expect(find.text('Al Ahly'), findsOneWidget);
      expect(find.text('FC Rivals'), findsOneWidget);
      expect(find.text('VS'), findsOneWidget);
      // The table positions survive per side.
      expect(find.text('5th in the table'), findsOneWidget);
      expect(find.text('12th in the table'), findsOneWidget);
      // The form pips row stays.
      expect(find.text('W'), findsNWidgets(2));
      expect(find.text('D'), findsNWidgets(2));
      expect(find.text('L'), findsNWidgets(1));

      // Start-side order: the home club's name sits to the LEFT in LTR.
      final userDx = tester.getTopLeft(find.text('FC Rivals')).dx;
      final oppDx = tester.getTopLeft(find.text('Al Ahly')).dx;
      expect(userDx, lessThan(oppDx),
          reason: 'userAtHome: the user club is the HOME side, first');

    // Forecast: loss/draw/win in ONE row, no heading or sample count.
    expect(find.text('LOSS'), findsOneWidget);
    expect(find.text('DRAW'), findsOneWidget);
    expect(find.text('WIN'), findsOneWidget);
    expect(find.text('MATCH FORECAST'), findsNothing);
    expect(find.textContaining('simulated matches'), findsNothing);
    expect(find.text('Expected goals'), findsNothing);
    expect(find.text('Clean sheets'), findsNothing);

    // Strength: all five comparisons.
    expect(find.text('STRENGTH'), findsOneWidget);
    expect(find.text('OVERALL'), findsOneWidget);
    expect(find.text('ATTACK'), findsOneWidget);
    expect(find.text('SUPPORT'), findsOneWidget);
    expect(find.text('DEFENCE'), findsOneWidget);
    expect(find.text('GOALKEEPING'), findsOneWidget);

    // T-0102: the top section is the BEST PLAYER of each side — two
    // cards, home side's best first. The user's best from the squad
    // fixture is 'ST Finisher' (rating 85 → score (81+85+79)/3 = 82),
    // the opponent's best is the key-men head 'Omar Gamal'.
    expect(find.text('THEIR SEASON'), findsNothing);
    expect(find.text('TOP PLAYERS'), findsNothing);
    expect(find.text('TOP PLAYER'), findsOneWidget);
    expect(find.byType(FcmPlayerCard), findsNWidgets(2));
    final cards = tester.widgetList<FcmPlayerCard>(find.byType(FcmPlayerCard));
    final names = [for (final c in cards) c.player.name];
    expect(names, containsAll(['Omar Gamal', 'ST Finisher']));
    // Home order: the user's best sits first (left in LTR).
    expect(names.first, 'ST Finisher');
    final cardFinders = find
        .byType(FcmPlayerCard)
        .evaluate()
        .map((e) => find.byWidgetPredicate((w) => w == e.widget));
    final dyTop = tester.getTopLeft(cardFinders.first).dy;
    for (final f in cardFinders) {
      expect(
        tester.getTopLeft(f).dy,
        closeTo(dyTop, 1),
        reason: 'the two cards sit side by side in one row',
      );
    }
  });

  testWidgets(
    'T-0102: an AWAY fixture flips the header and card order, and the '
    'Arabic RTL pump mirrors without overflow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // userAtHome flipped: the opponent (home side) leads.
      final awayData = PreMatchData(
        fixtureLabel: _data.fixtureLabel,
        userClubName: _data.userClubName,
        opponentClubName: _data.opponentClubName,
        userAtHome: false,
        forecast: _data.forecast,
        opponentForm: _data.opponentForm,
        opponentPosition: _data.opponentPosition,
        userPosition: _data.userPosition,
        opponentKeyMen: _data.opponentKeyMen,
        userSquad: _data.userSquad,
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            backgroundColor: Colors.black,
            body: AnalysisPhase(data: awayData),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both sides render in AR; no overflow exception.
      expect(find.text('Al Ahly'), findsOneWidget);
      expect(find.text('FC Rivals'), findsOneWidget);
      expect(find.text('VS'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.text('TOP PLAYER'), findsOneWidget);
      expect(find.byType(FcmPlayerCard), findsNWidgets(2));
      // Away fixture: the opponent's best is the FIRST card.
      final names = [
        for (final c in tester.widgetList<FcmPlayerCard>(
          find.byType(FcmPlayerCard),
        ))
          c.player.name,
      ];
      expect(names.first, 'Omar Gamal');
    },
  );

  testWidgets('analysis phase shows a BACK that exits the matchday', (
    WidgetTester tester,
  ) async {
    await _openPreMatch(tester);

    expect(find.text('TOP PLAYER'), findsOneWidget);
    expect(find.text('BACK'), findsOneWidget);

    // BACK pops the route: back on the season tab, nothing kicked off.
    await tester.tap(find.text('BACK'));
    await _settle(tester, frames: 10);
    expect(find.text('SEASON TAB'), findsOneWidget);
    expect(find.text('TOP PLAYER'), findsNothing);
  });

  testWidgets('onExit replaces the default pop', (WidgetTester tester) async {
    var exited = false;
    await _openPreMatch(tester, onExit: () => exited = true);

    await tester.tap(find.text('BACK'));
    await _settle(tester, frames: 10);

    expect(exited, isTrue, reason: 'host exit callback ran');
    // The screen itself is still on stage — the host decides what pops.
    expect(find.text('TOP PLAYER'), findsOneWidget);
  });

  testWidgets('BACK from the tactics phase steps back to the analysis', (
    WidgetTester tester,
  ) async {
    await _openPreMatch(tester);

    await tester.tap(find.text('CONTINUE'));
    await _settle(tester, frames: 10);
    expect(find.text('Set up for this match'), findsOneWidget);

    await tester.tap(find.text('BACK'));
    await _settle(tester, frames: 10);
    expect(
      find.text('TOP PLAYER'),
      findsOneWidget,
      reason: 'BACK steps back one phase, not out of the matchday',
    );
  });

  testWidgets('tactics phase is the Team tab surface plus stamina', (
    WidgetTester tester,
  ) async {
    await _openPreMatch(tester);
    await tester.tap(find.text('CONTINUE'));
    await _settle(tester, frames: 12);
    expect(find.text('Set up for this match'), findsOneWidget);

    // The full 23-man strip: XI, bench and RESERVES all render.
    expect(find.textContaining('Reserves'), findsOneWidget);

    // Every FILLED card carries the match-day fitness bar and NO stat
    // row: the pre-match surface is the Team tab's plus stamina, nothing
    // else. Stamina comes from the fixture (90), stats are null. Ghost
    // cards (empty slots) are placeholders and carry neither.
    final cards = tester
        .widgetList<FcmMiniCard>(find.byType(FcmMiniCard))
        .where((c) => !c.ghost)
        .toList();
    expect(cards, isNotEmpty, reason: 'the tactics phase shows its squad');
    for (final c in cards) {
      expect(c.stamina, 90, reason: 'every card carries the stamina bar');
      expect(c.stats, isNull, reason: 'no stat rows on this surface');
    }
    // No stat-row labels leaked in through any other widget.
    expect(find.text('ATT'), findsNothing);
    expect(find.text('SUP'), findsNothing);
    expect(find.text('DEF'), findsNothing);
  });

  testWidgets('T-0069: the analysis shows both teams chemistry lines', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: AnalysisPhase(data: _data),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CHEMISTRY'), findsOneWidget);
    expect(find.text('+4%'), findsOneWidget);
    expect(find.text('+2%'), findsOneWidget);
  });

  testWidgets('T-0069: Arabic analysis shows الكيمياء with the percents', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: AnalysisPhase(data: _data),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الكيمياء'), findsOneWidget);
    expect(find.text('+4%'), findsOneWidget);
    expect(find.text('+2%'), findsOneWidget);
  });
}
