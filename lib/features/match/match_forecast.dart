/// FCM Rivals — pre-match opponent analysis (GDD 13 pre-match screen).
///
/// Computes the head-to-head forecast the user sees before kick-off from
/// the FULL squad lists of both clubs — starting XI, bench and reserves
/// all count alike. The run is deliberately neutral: no tactics, no
/// mentality, no stamina drain, no red cards or injuries — a like-for-like
/// measure of squad quality on paper, so changing formation, style or
/// who starts cannot move the numbers. Goal probabilities follow the same
/// funnel constants as the live engine (GDD 12.3 steps 1-8).
///
/// Pure Dart, no UI, no database — everything arrives as plain values so
/// the module stays unit-testable (GDD development rule 4).
library;

import '../../core/domain/crest.dart' show CrestSpec;
import 'chemistry.dart';
import 'dart:math' as math;

import '../squad/squad_engine.dart';
import 'tactics.dart';
import 'match_engine.dart';

/// Outcome probabilities and supporting numbers for one fixture forecast.
class MatchForecast {
  const MatchForecast({
    required this.samples,
    required this.winPercent,
    required this.drawPercent,
    required this.lossPercent,
    required this.avgUserGoals,
    required this.avgOpponentGoals,
    required this.cleanSheetPercent,
    required this.userTotals,
    required this.opponentTotals,
    this.userChemistry = 0,
    this.opponentChemistry = 0,
  });

  final int samples;

  /// User win/draw/loss share of the simulated matches, whole percents.
  final int winPercent;
  final int drawPercent;
  final int lossPercent;

  /// Average goals per match for each side.
  final double avgUserGoals;
  final double avgOpponentGoals;

  /// Share of simulated matches in which the user conceded none.
  final int cleanSheetPercent;

  /// Neutral squad-quality totals (every player, no tactics or condition).
  final TeamTotals userTotals;
  final TeamTotals opponentTotals;

  /// Nationality chemistry percent of each side's STARTING XI (T-0067
  /// formula; T-0069 display) — what the engine multiplies onto the four
  /// totals during the match.
  final int userChemistry;
  final int opponentChemistry;

  /// Overall strength 0..100 for bar comparisons.
  int strength(TeamTotals t) =>
      ((t.attack + t.defence + t.goalkeeping) / 3).round().clamp(0, 100);

  int get attackAdvantage =>
      (userTotals.attack - opponentTotals.attack).round();
  int get defenceAdvantage =>
      (userTotals.defence - opponentTotals.defence).round();
}

/// Inputs for one forecast: every player of both squads (XI + bench +
/// reserves). Attributes are taken raw — stamina is ignored, and there is
/// no formation, style or mentality to apply.
class ForecastInput {
  const ForecastInput({required this.userSquad, required this.opponentSquad});

  final List<MatchPlayer> userSquad;
  final List<MatchPlayer> opponentSquad;
}

/// Everything the pre-match analysis screen shows (GDD 13): fixture names,
/// the Monte-Carlo forecast, the opponent's recent form and their top
/// players. Constructed by the season store; rendered by the pre-match
/// screen.
class PreMatchData {
  const PreMatchData({
    required this.fixtureLabel,
    required this.userClubName,
    required this.opponentClubName,
    required this.userAtHome,
    required this.forecast,
    required this.opponentForm,
    required this.opponentPosition,
    required this.userPosition,
    required this.opponentKeyMen,
    this.userFormationCode = '4-3-3',
    this.userTactics = const TeamTactics(),
    this.userMentality = Mentality.balanced,
    this.userSquad = const {},
    this.userCrest,
    this.opponentCrest,
  });

  /// e.g. 'League · Round 3'.
  final String fixtureLabel;
  final String userClubName;
  final String opponentClubName;

  /// Both clubs' crests — shown instead of initials in the analysis
  /// header. Null falls back to the initials circle.
  final CrestSpec? userCrest;
  final CrestSpec? opponentCrest;

  /// Whether the user hosts (drives the HOME/AWAY chip).
  final bool userAtHome;

  /// Monte-Carlo forecast of the real fixture (never null).
  final MatchForecast forecast;

  /// Opponent's last five league results, newest last: W / D / L.
  final List<String> opponentForm;

  /// League positions for both clubs (table context).
  final int opponentPosition;
  final int userPosition;

  /// Opponent's three highest-rated players in the whole squad: identity
  /// plus raw attributes, rendered as collection-style cards.
  final List<
    ({
      String name,
      String position,
      int overall,
      int attack,
      int support,
      int defence,
      int goalkeeping,
    })
  >
  opponentKeyMen;

  /// The club's persisted formation / custom tactics / mentality (GDD 10)
  /// — the starting point of the pre-match tactics selection.
  final String userFormationCode;
  final TeamTactics userTactics;
  final Mentality userMentality;

  /// The user's persisted squad (slot index → card) for the tactics phase:
  /// the starting XI, bench and reserves rendered like the Team tab plus
  /// match-day stamina bars (GDD 11).
  final Map<int, PlayerCard> userSquad;
}

/// Runs the Monte-Carlo forecast over the two full squad lists.
///
/// [samples] full matches are simulated; each minute draws 0/1/2 attack
/// segments exactly like the live engine, possession goes to the side
/// with the better support quality, and every segment runs the engine's
/// chance → shot accuracy → goalkeeper reaction funnel on the squad's
/// neutral totals. No stamina, cards, injuries, tactics or home edge are
/// modelled. [forecastSeed] makes the whole forecast reproducible for
/// tests and replay records.
MatchForecast forecastMatch({
  required ForecastInput input,
  int samples = 120,
  int forecastSeed = 777001,
  MatchEngineConfig config = defaultMatchEngineConfig,
  math.Random? random,
}) {
  final rnd = random ?? math.Random(forecastSeed);

  // Neutral squad quality: every player, natural position, raw attributes.
  final userTotals = squadQualityTotals(input.userSquad);
  final opponentTotals = squadQualityTotals(input.opponentSquad);

  // Starting-XI chemistry (T-0069): the first 11 of each squad list are
  // the starters (slot order — same convention as the totals wiring).
  List<MatchPlayer> startersOf(List<MatchPlayer> squad) =>
      squad.take(11).toList();
  final userChemistry = chemistryPercentOf([
    for (final p in startersOf(input.userSquad)) p.nationality,
  ]);
  final opponentChemistry = chemistryPercentOf([
    for (final p in startersOf(input.opponentSquad)) p.nationality,
  ]);

  var wins = 0, draws = 0, losses = 0;
  var userGoals = 0, opponentGoals = 0, cleanSheets = 0;

  for (var i = 0; i < samples; i++) {
    var ug = 0, og = 0;
    for (var minute = 0; minute < 90; minute++) {
      final segments = _drawSegmentCount(rnd, config.segmentWeights);
      for (var s = 0; s < segments; s++) {
        final userPoss =
            userTotals.support / (userTotals.support + opponentTotals.support);
        if (rnd.nextDouble() < userPoss) {
          ug += _segmentGoals(rnd, config, userTotals.attack, opponentTotals);
        } else {
          og += _segmentGoals(rnd, config, opponentTotals.attack, userTotals);
        }
      }
    }
    userGoals += ug;
    opponentGoals += og;
    if (og == 0) cleanSheets++;
    if (ug > og) {
      wins++;
    } else if (ug < og) {
      losses++;
    } else {
      draws++;
    }
  }
  // Asserted by the sum-to-100 invariant: every sample is a win, draw or
  // loss, so the remainder percent is exactly the loss share.
  assert(wins + draws + losses == samples);

  // Third percent as the remainder so the three always sum to exactly
  // 100 (rounding each independently can drift to 99 or 101).
  final winP = (100 * wins / samples).round();
  final drawP = (100 * draws / samples).round();

  return MatchForecast(
    samples: samples,
    winPercent: winP,
    drawPercent: drawP,
    lossPercent: (100 - winP - drawP).clamp(0, 100),
    avgUserGoals: userGoals / samples,
    avgOpponentGoals: opponentGoals / samples,
    cleanSheetPercent: (100 * cleanSheets / samples).round(),
    userTotals: userTotals,
    opponentTotals: opponentTotals,
    userChemistry: userChemistry,
    opponentChemistry: opponentChemistry,
  );
}

/// P(0/1/2 attack segments per minute), same weights as the engine.
int _drawSegmentCount(math.Random rnd, List<double> weights) {
  final roll = rnd.nextDouble();
  if (roll < weights[0]) return 0;
  if (roll < weights[0] + weights[1]) return 1;
  return 2;
}

/// Goals scored by one attack segment (GDD 12.3 steps 4-8 with the
/// engine's funnel constants, neutralised): chance creation from the
/// attack-vs-defence ratio, then shot accuracy and goalkeeper reaction
/// against the defending squad's keeper quality. No fouls, cards,
/// penalties or free kicks — nothing but squad quality decides.
int _segmentGoals(
  math.Random rnd,
  MatchEngineConfig c,
  double attack,
  TeamTotals def,
) {
  final attackRatio = attack / (attack + def.defence);
  final chanceP = (c.chanceBase + c.chanceScale * attackRatio).clamp(
    0.05,
    c.chanceMax,
  );
  if (rnd.nextDouble() >= chanceP) return 0;

  // The shot model mirrors the engine's _attackChance/_shoot constants:
  // big-chance share, on-target bonus, goal factor and the bounded
  // shooter-vs-keeper edge must move together with the engine's
  // calibration or the forecast silently disagrees with the match it
  // previews.
  final big = rnd.nextDouble() < 0.28;
  final onTargetP =
      (c.onTargetBase + c.onTargetScale * (attack / 100) + (big ? 0.36 : 0.0))
          .clamp(0.10, 0.95);
  final goalP =
      (c.goalBase +
              c.goalScale *
                  (attack / (attack + def.goalkeeping * 1.5)) *
                  (big ? 1.85 : 1.0) +
              c.goalDiffScale * ((attack - def.goalkeeping) / 100))
          .clamp(0.04, 0.88);

  if (rnd.nextDouble() < c.blockChance) return 0;
  if (rnd.nextDouble() < onTargetP / (1 - c.blockChance) &&
      rnd.nextDouble() < goalP) {
    return 1;
  }
  return 0;
}
