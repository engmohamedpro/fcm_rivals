// Regression tests for the pre-match analysis phase (GDD 13):
//
//  * the analysis phase shows a BACK action that exits the matchday
//    build-up before anything is committed (the fixture stays unplayed);
//    hosts can substitute their own exit via onExit;
//  * later phases step back through the build-up, not out of it.
import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/features/match/match_engine.dart' show TeamTotals;
import 'package:fcm_rivals/features/match/match_forecast.dart';
import 'package:fcm_rivals/features/match/pre_match_screen.dart';
import 'package:fcm_rivals/features/match/tactics.dart';

MatchForecast get _forecast => MatchForecast(
      samples: 100,
      winPercent: 45,
      drawPercent: 30,
      lossPercent: 25,
      avgUserGoals: 1.6,
      avgOpponentGoals: 1.1,
      cleanSheetPercent: 33,
      userTotals: TeamTotals(
          attack: 70, support: 68, defence: 65, goalkeeping: 60),
      opponentTotals: TeamTotals(
          attack: 72, support: 64, defence: 61, goalkeeping: 58),
    );

PreMatchData get _data => PreMatchData(
      fixtureLabel: 'League · Round 1',
      userClubName: 'FC Rivals',
      opponentClubName: 'Al Ahly',
      userAtHome: true,
      forecast: _forecast,
      opponentForm: const ['W', 'D', 'L'],
      opponentPosition: 5,
      userPosition: 12,
      opponentKeyMen: const [(name: 'Omar Gamal', overall: 84)],
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

Future<void> _openPreMatch(WidgetTester tester,
    {VoidCallback? onExit,
    void Function(MatchPepTalk?)? onKickOff}) async {
  // A tall surface so all three analysis cards are on screen at once
  // (the default 800x600 test viewport cuts the third card off).
  tester.view.physicalSize = const Size(800, 1700);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_home());
  await tester.pump();
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  await tester.pump();
  unawaited(navigator.push(MaterialPageRoute<void>(
    builder: (_) => PreMatchScreen(
      data: _data,
      onKickOff: onKickOff ?? (_) {},
      onExit: onExit,
    ),
  )));
  await _settle(tester, frames: 10);
}

void main() {
  testWidgets('analysis phase shows a BACK that exits the matchday',
      (WidgetTester tester) async {
    await _openPreMatch(tester);

    expect(find.text('MATCH FORECAST'), findsOneWidget);
    expect(find.text('STRENGTH'), findsOneWidget);
    expect(find.text('THEIR SEASON'), findsOneWidget);
    expect(find.text('BACK'), findsOneWidget);

    // BACK pops the route: back on the season tab, nothing kicked off.
    await tester.tap(find.text('BACK'));
    await _settle(tester, frames: 10);
    expect(find.text('SEASON TAB'), findsOneWidget);
    expect(find.text('MATCH FORECAST'), findsNothing);
  });

  testWidgets('onExit replaces the default pop', (WidgetTester tester) async {
    var exited = false;
    await _openPreMatch(tester, onExit: () => exited = true);

    await tester.tap(find.text('BACK'));
    await _settle(tester, frames: 10);

    expect(exited, isTrue, reason: 'host exit callback ran');
    // The screen itself is still on stage — the host decides what pops.
    expect(find.text('MATCH FORECAST'), findsOneWidget);
  });

  testWidgets('BACK from the tactics phase steps back to the analysis',
      (WidgetTester tester) async {
    await _openPreMatch(tester);

    await tester.tap(find.text('CONTINUE'));
    await _settle(tester, frames: 10);
    expect(find.text('Set up for this match'), findsOneWidget);

    await tester.tap(find.text('BACK'));
    await _settle(tester, frames: 10);
    expect(find.text('MATCH FORECAST'), findsOneWidget,
        reason: 'BACK steps back one phase, not out of the matchday');
  });
}
