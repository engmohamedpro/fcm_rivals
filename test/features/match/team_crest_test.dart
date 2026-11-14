/// Team crests replace letters circles on the match surfaces.
///
/// Covers the three behaviours shipped:
///  1. the live match header renders the clubs' crests (not the letters
///     circles) for both sides when specs are supplied;
///  2. the pre-match analysis team-vs-team chips render the crests the
///     PreMatchData carries (user + opponent), falling back to initials
///     when no spec is supplied;
///  3. CrestSpec.derived is deterministic and spreads distinct specs
///     across different opponent names (the friendly-opponent source).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/crest.dart';
import 'package:fcm_rivals/core/ui/fcm_club_badge.dart';
import 'package:fcm_rivals/core/ui/fcm_crest.dart';
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/match_forecast.dart';
import 'package:fcm_rivals/features/match/match_header.dart';
import 'package:fcm_rivals/features/match/pre_match_analysis.dart';

void main() {
  testWidgets(
    'live header: crest chips replace the letters circles',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: MatchHeader(
              home: 'FC Rivals',
              away: 'Al Ahly',
              homeCrest: CrestSpec.legacy(0),
              awayCrest: CrestSpec.legacy(4),
              scoreHome: 1,
              scoreAway: 0,
              minute: 34,
              fullTime: false,
              userIsHome: true,
              paused: false,
              speed: 1,
              onTogglePause: () {},
              onSetSpeed: (_) {},
            ),
          ),
        ),
      );

      // Both sides paint their crest — two FcmCrest instances on screen.
      expect(find.byType(FcmCrest), findsNWidgets(2));
      // The letters-circle fallback must NOT appear: the scoreline is a
      // broadcast row — crest, abbreviation, score (owner request
      // 2026-11-13), never initials.
      expect(
        find.text('FR'),
        findsNothing,
        reason: 'user chip must show the crest, not initials',
      );
      expect(
        find.text('AA'),
        findsNothing,
        reason: 'opponent chip must show the crest, not initials',
      );
      // Broadcast abbreviations replace the full club names.
      expect(find.text('FCR'), findsOneWidget);
      expect(find.text('ALA'), findsOneWidget);
      expect(find.text('FC Rivals'), findsNothing);
      expect(find.text('Al Ahly'), findsNothing);
      // The broadcast strip's competition column splits 'League ·
      // Round 3'-style tags, but this header carries no label — no
      // phantom column text.
      expect(find.text('Round 3'), findsNothing);
    },
  );

  testWidgets('analysis chips: initials fallback when no spec', (
    tester,
  ) async {
    const data = PreMatchData(
      fixtureLabel: 'League · Round 3',
      userClubName: 'FC Rivals',
      opponentClubName: 'Al Ahly',
      userAtHome: true,
      forecast: MatchForecast(
        samples: 1000,
        winPercent: 45,
        drawPercent: 30,
        lossPercent: 25,
        avgUserGoals: 1.8,
        avgOpponentGoals: 1.1,
        cleanSheetPercent: 28,
        userTotals: TeamTotals(
          attack: 70,
          support: 68,
          defence: 65,
          goalkeeping: 60,
        ),
        opponentTotals: TeamTotals(
          attack: 66,
          support: 64,
          defence: 62,
          goalkeeping: 58,
        ),
      ),
      opponentForm: ['W', 'D', 'L', 'W', 'D'],
      opponentPosition: 5,
      userPosition: 12,
      opponentSquad: const [],
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: AnalysisPhase(data: data),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No specs supplied → the letters fallback owns the ONE badge
    // (T-0131: the team-vs-team card is gone; the opponent's badge
    // leads THEIR starting XI card, the user side is not rendered).
    expect(find.byType(FcmCrest), findsNothing);
    expect(find.text('AA'), findsOneWidget);
    expect(find.text('FR'), findsNothing);
  });

  testWidgets(
    'analysis chips: crests render when PreMatchData carries them',
    (tester) async {
      const data = PreMatchData(
        fixtureLabel: 'League · Round 3',
        userClubName: 'FC Rivals',
        opponentClubName: 'Al Ahly',
        userAtHome: true,
        forecast: MatchForecast(
          samples: 1000,
          winPercent: 45,
          drawPercent: 30,
          lossPercent: 25,
          avgUserGoals: 1.8,
          avgOpponentGoals: 1.1,
          cleanSheetPercent: 28,
          userTotals: TeamTotals(
            attack: 70,
            support: 68,
            defence: 65,
            goalkeeping: 60,
          ),
          opponentTotals: TeamTotals(
            attack: 66,
            support: 64,
            defence: 62,
            goalkeeping: 58,
          ),
        ),
        opponentForm: ['W', 'D', 'L', 'W', 'D'],
        opponentPosition: 5,
        userPosition: 12,
        opponentSquad: const [],
        userCrest: CrestSpec(
          shape: CrestShape.shield,
          primaryIndex: 0,
          secondaryIndex: 2,
          icon: CrestIcon.star,
        ),
        opponentCrest: CrestSpec(
          shape: CrestShape.round,
          primaryIndex: 7,
          secondaryIndex: 11,
          icon: CrestIcon.lion,
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: AnalysisPhase(data: data),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // T-0131: the team-vs-team card is gone — ONE crest on the
      // opponent's starting XI card, no initials, and the user club
      // name no longer renders anywhere in the analysis phase.
      expect(find.byType(FcmCrest), findsOneWidget);
      expect(find.text('FR'), findsNothing);
      expect(find.text('AA'), findsNothing);
      expect(find.text('FC Rivals'), findsNothing);
      expect(find.text('Al Ahly'), findsOneWidget);
    },
  );

  testWidgets(
    'friendly session: opponent crest derives from the name',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: MatchHeader(
              home: 'FC Rivals',
              away: 'Al Ahly',
              homeCrest: CrestSpec.legacy(0),
              awayCrest: CrestSpec.derived('Al Ahly'),
              scoreHome: 0,
              scoreAway: 0,
              minute: 1,
              fullTime: false,
              userIsHome: true,
              paused: false,
              speed: 1,
              onTogglePause: () {},
              onSetSpeed: (_) {},
            ),
          ),
        ),
      );
      expect(find.byType(FcmClubBadge), findsNWidgets(2));
      expect(find.byType(FcmCrest), findsNWidgets(2));
      expect(find.text('AA'), findsNothing);
    },
  );

  test('CrestSpec.derived: deterministic and distinct across names', () {
    final a1 = CrestSpec.derived('Al Ahly');
    final a2 = CrestSpec.derived('Al Ahly');
    expect(a1, a2, reason: 'same name must always wear the same crest');

    // Distinctness across a spread of opponent names: no two of these
    // may collide on EVERY dimension (shape+colours+icon+pattern).
    final names = [
      'Al Ahly',
      'Zamalek',
      'Pyramids',
      'Ismaily',
      'Ceramica',
      'Masry',
      'Gouna',
      'Farco',
      'ENPPI',
      'Ittihad',
    ];
    final specs = {for (final n in names) CrestSpec.derived(n): n};
    expect(specs.length, names.length,
        reason: 'every opponent name must own a distinct badge');

    // Contrast guard by construction: primary never equals secondary.
    for (final s in specs.keys) {
      expect(s.primaryIndex, isNot(s.secondaryIndex));
    }
  });
}
