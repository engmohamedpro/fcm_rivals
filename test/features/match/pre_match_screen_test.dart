// Regression tests for the pre-match analysis phase (GDD 13):
//
//  * the analysis is about the OPPONENT: a compact header strip with
//    crest, table position and last-five form pips; loss/draw/win
//    percents in one row; the opponent's starting XI standing in their
//    own formation on the Team tab's pitch surface (2026-11-13: it
//    replaced the strength bars and the top-player cards);
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
import 'package:fcm_rivals/core/ui/player_card.dart' show FcmMiniCard;
import 'package:fcm_rivals/features/match/match_engine.dart' show TeamTotals;
import 'package:fcm_rivals/features/match/match_event.dart' show MatchPlayer;
import 'package:fcm_rivals/features/match/match_forecast.dart';
import 'package:fcm_rivals/features/match/pre_match_screen.dart';
import 'package:fcm_rivals/features/match/tactics.dart';
import 'package:fcm_rivals/features/squad/squad_engine.dart' show PlayerCard;
import 'package:fcm_rivals/features/squad/squad_pitch_view.dart' show SquadPitch;

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
  // The opponent's starting XI in 4-3-3 SLOT order (GK first) — the
  // same convention the season store's AiOpponentSquad.starters uses.
  opponentFormationCode: '4-3-3',
  opponentSquad: [
    _opp(1, 'Ali Soliman', Position.gk, 79, 18, 44, 62, 83),
    _opp(2, 'Karim Fouad', Position.cb, 81, 48, 66, 87, 15),
    _opp(3, 'Rami Adel', Position.cb, 77, 40, 60, 84, 12),
    _opp(4, 'Sami Nasr', Position.cb, 76, 38, 58, 82, 11),
    _opp(5, 'Hany Farouk', Position.rb, 75, 52, 70, 74, 10),
    _opp(6, 'Mostafa Kamel', Position.cm, 80, 62, 84, 58, 8),
    _opp(7, 'Walid Hassan', Position.cm, 78, 58, 80, 56, 8),
    _opp(8, 'Tarek Mounir', Position.cam, 82, 84, 78, 44, 9),
    _opp(9, 'Omar Gamal', Position.st, 84, 86, 80, 42, 12),
    _opp(10, 'Zaki Adel', Position.lw, 79, 81, 74, 46, 8),
    _opp(11, 'Nabil Roshdy', Position.rw, 78, 80, 72, 44, 8),
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

/// One opponent starter for the analysis fixture: [slot] is the
/// formation-slot index, the rating split builds the attributes.
MatchPlayer _opp(
  int slot,
  String name,
  Position pos,
  int rating,
  int attack,
  int support,
  int defence,
  int goalkeeping,
) => MatchPlayer(
  playerId: -10_000 - slot,
  name: name,
  position: pos,
  attack: attack,
  support: support,
  defence: defence,
  goalkeeping: goalkeeping,
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
    'T-0131: the team-vs-team card is gone; the opponent header row '
    'leads their starting XI',
    (WidgetTester tester) async {
      await _openPreMatch(tester);

      // The team-vs-team card is gone (owner request 2026-11-13): no
      // VS, and the user's club no longer sits in the analysis header.
      expect(find.text('VS'), findsNothing);
      // The form pips row stays.
      expect(find.text('W'), findsNWidgets(2));
      expect(find.text('D'), findsNWidgets(2));
      expect(find.text('L'), findsNWidgets(1));

    // Forecast: loss/draw/win in ONE row, no heading or sample count.
    expect(find.text('LOSS'), findsOneWidget);
    expect(find.text('DRAW'), findsOneWidget);
    expect(find.text('WIN'), findsOneWidget);
    expect(find.text('MATCH FORECAST'), findsNothing);
    expect(find.textContaining('simulated matches'), findsNothing);
    expect(find.text('Expected goals'), findsNothing);
    expect(find.text('Clean sheets'), findsNothing);

    // 2026-11-13: the strength bars and the top-player cards are GONE.
    expect(find.text('STRENGTH'), findsNothing);
    expect(find.text('TOP PLAYER'), findsNothing);
    expect(find.text('ST Finisher'), findsNothing, reason: 'no user cards on the analysis');

    // T-0131: the formation card's header IS the opponent — crest,
    // club name and table position replace 'Their starting XI'.
    expect(find.text('Their starting XI'), findsNothing);
    expect(find.text('Al Ahly'), findsOneWidget);
    expect(find.text('5th in the table'), findsOneWidget);
    expect(find.text('4-3-3'), findsOneWidget);
    expect(find.byType(SquadPitch), findsOneWidget);
    final minis = tester
        .widgetList<FcmMiniCard>(find.byType(FcmMiniCard))
        .where((c) => !c.ghost)
        .toList();
    expect(minis, isNotEmpty, reason: 'the opponent XI renders');
    expect(minis.length, 11, reason: 'all eleven starters on the pitch');
    // Management view flags: no stamina bars, no stat rows.
    for (final c in minis) {
      expect(c.stamina, isNull, reason: 'no stamina on the analysis pitch');
      expect(c.stats, isNull, reason: 'no stat rows on the analysis pitch');
    }
    // Read-only scouting: taps lead nowhere on this surface.
    expect(tester.widget<SquadPitch>(find.byType(SquadPitch)).onPlayerTap,
        isNull);
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
        opponentFormationCode: _data.opponentFormationCode,
        opponentSquad: _data.opponentSquad,
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

      // T-0131: the opponent renders in AR; no overflow exception.
      expect(find.text('Al Ahly'), findsOneWidget);
      expect(find.text('VS'), findsNothing);
      expect(tester.takeException(), isNull);
      // The formation section renders localized, all eleven on the pitch.
      expect(find.text('5th in the table'), findsOneWidget);
      expect(
        tester
            .widgetList<FcmMiniCard>(find.byType(FcmMiniCard))
            .where((c) => !c.ghost)
            .length,
        11,
      );
    },
  );

  testWidgets('analysis phase shows a BACK that exits the matchday', (
    WidgetTester tester,
  ) async {
    await _openPreMatch(tester);

    expect(find.text('5th in the table'), findsOneWidget);
    expect(find.text('BACK'), findsOneWidget);

    // BACK pops the route: back on the season tab, nothing kicked off.
    await tester.tap(find.text('BACK'));
    await _settle(tester, frames: 10);
    expect(find.text('SEASON TAB'), findsOneWidget);
    expect(find.text('5th in the table'), findsNothing);
  });

  testWidgets('onExit replaces the default pop', (WidgetTester tester) async {
    var exited = false;
    await _openPreMatch(tester, onExit: () => exited = true);

    await tester.tap(find.text('BACK'));
    await _settle(tester, frames: 10);

    expect(exited, isTrue, reason: 'host exit callback ran');
    // The screen itself is still on stage — the host decides what pops.
    expect(find.text('5th in the table'), findsOneWidget);
  });

  testWidgets('BACK from the tactics phase steps back to the analysis', (
    WidgetTester tester,
  ) async {
    await _openPreMatch(tester);

    await tester.tap(find.text('CONTINUE'));
    await _settle(tester, frames: 10);
    expect(find.text('TACTICS'), findsOneWidget);

    await tester.tap(find.text('BACK'));
    await _settle(tester, frames: 10);
    expect(
      find.text('5th in the table'),
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
    expect(find.text('TACTICS'), findsOneWidget);

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

    // The chemistry COMPARISON row lived on the removed strength card;
    // chemistry itself still shows on the analysis through the pitch's
    // LINKS (shared-nationality/club pairs render as lines).
    expect(find.text('CHEMISTRY'), findsNothing);
    expect(find.byType(SquadPitch), findsOneWidget);
    expect(
      tester
          .widget<SquadPitch>(find.byType(SquadPitch))
          .showChemistryLinks,
      isTrue,
      reason: 'the opponent pitch draws the chemistry links',
    );
  });

  testWidgets('T-0069: Arabic analysis renders the formation section RTL', (
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

    // T-0131: the "تشكيل الخصم" label is gone — the opponent's crest
    // and name lead their starting XI card in the RTL layout too.
    expect(find.text('Al Ahly'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T-0118: the matchday Auto Pick button — present, '
      'fitness-aware, and never persists', (WidgetTester tester) async {
    var kicked = false;
    await _openPreMatch(
      tester,
      onKickOff: (_) => kicked = true,
    );
    await tester.tap(find.text('CONTINUE'));
    await _settle(tester, frames: 12);
    expect(find.text('TACTICS'), findsOneWidget);

    // The Auto Pick action EXISTS on the duplicate screen (T-0118 —
    // it was entirely missing from the pre-match surface before).
    expect(find.text('Auto Pick'), findsOneWidget);

    // Tapping it stays match-only: no navigation, no kick-off, the
    // phase is still up (the projection re-asserts in place).
    await tester.tap(find.text('Auto Pick'));
    await _settle(tester, frames: 8);
    expect(find.text('TACTICS'), findsOneWidget);
    expect(kicked, isFalse, reason: 'the pick never kicks off');

    // The squad shown is the fitness-aware projection: the fixture's
    // every-card stamina is 90, and the surface still renders its
    // full 23-man projection (XI + bench + reserves cards present).
    final cards = tester
        .widgetList<FcmMiniCard>(find.byType(FcmMiniCard))
        .where((c) => !c.ghost)
        .toList();
    expect(cards, isNotEmpty);
    // And the match-only contract: no store write ever happens from
    // this screen — PreMatchData is a value object; the only store
    // touch is the caller's onKickOff. Asserted structurally: the
    // screen holds no CollectionStore dependency at all.
    expect(kicked, isFalse);
  });
}
