/// FCM Rivals — pre-match opponent analysis (GDD 13 pre-match screen).
///
/// Computes the head-to-head forecast the user sees before kick-off:
/// win/draw/loss probabilities from a Monte-Carlo run of the REAL match
/// engine over the exact two squads (same code path that decides the
/// actual fixture, so the percentages are honest), plus side-by-side
/// strength totals and the opponent's recent league form.
///
/// Pure Dart, no UI, no database — everything arrives as plain values so
/// the module stays unit-testable (GDD development rule 4).
library;

import 'dart:math' as math;

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

  /// Effective team totals at kick-off (GDD 12.2 pipeline).
  final TeamTotals userTotals;
  final TeamTotals opponentTotals;

  /// Overall strength 0..100 for bar comparisons.
  int strength(TeamTotals t) =>
      ((t.attack + t.defence + t.goalkeeping) / 3).round().clamp(0, 100);

  int get attackAdvantage =>
      (userTotals.attack - opponentTotals.attack).round();
  int get defenceAdvantage =>
      (userTotals.defence - opponentTotals.defence).round();
}

/// Inputs for one forecast: both teams exactly as the fixture will start.
class ForecastInput {
  const ForecastInput({
    required this.userTeam,
    required this.opponentTeam,
    required this.userAtHome,
  });

  final MatchTeamInput userTeam;
  final MatchTeamInput opponentTeam;
  final bool userAtHome;
}

/// Everything the pre-match analysis screen shows (GDD 13): fixture names,
/// the Monte-Carlo forecast, the opponent's recent form and their key men.
/// Constructed by the season store; rendered by the pre-match screen.
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
  });

  /// e.g. 'League · Round 3'.
  final String fixtureLabel;
  final String userClubName;
  final String opponentClubName;

  /// Whether the user hosts (drives the HOME/AWAY chip).
  final bool userAtHome;

  /// Monte-Carlo forecast of the real fixture (never null).
  final MatchForecast forecast;

  /// Opponent's last five league results, newest last: W / D / L.
  final List<String> opponentForm;

  /// League positions for both clubs (table context).
  final int opponentPosition;
  final int userPosition;

  /// Opponent's highest-rated starters: name + overall.
  final List<({String name, int overall})> opponentKeyMen;
}

/// Runs the Monte-Carlo forecast with the real engine.
///
/// [samples] full matches are simulated from fresh seeds; each run is a
/// complete 90 minutes so red cards, stamina drift and AI tactical changes
/// all shape the outcome the user sees. [forecastSeed] makes the whole
/// forecast reproducible for tests and replay records.
MatchForecast forecastMatch({
  required ForecastInput input,
  int samples = 120,
  int forecastSeed = 777001,
  MatchEngineConfig config = defaultMatchEngineConfig,
  math.Random? random,
}) {
  final rnd = random ?? math.Random(forecastSeed);

  // Totals at kick-off: a fresh engine's minute-0 snapshot runs the exact
  // GDD 12.2 pipeline (stamina scaling → mentality → style → home
  // advantage) for both sides, including the home edge of the real venue.
  final probe = MatchEngine(
    seed: forecastSeed,
    config: config,
    home: input.userAtHome ? input.userTeam : input.opponentTeam,
    away: input.userAtHome ? input.opponentTeam : input.userTeam,
  );
  final userTotals = probe.totalsOf(
      input.userAtHome ? MatchSide.home : MatchSide.away);
  final opponentTotals = probe.totalsOf(
      input.userAtHome ? MatchSide.away : MatchSide.home);

  var wins = 0, draws = 0, losses = 0;
  var userGoals = 0, opponentGoals = 0, cleanSheets = 0;

  for (var i = 0; i < samples; i++) {
    final seed = rnd.nextInt(1 << 31);
    final engine = MatchEngine(
      seed: seed,
      config: config,
      home: input.userAtHome ? input.userTeam : input.opponentTeam,
      away: input.userAtHome ? input.opponentTeam : input.userTeam,
    );
    engine.simulateToEnd();
    final state = engine.state;
    final ug = input.userAtHome ? state.scoreHome : state.scoreAway;
    final og = input.userAtHome ? state.scoreAway : state.scoreHome;
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

  return MatchForecast(
    samples: samples,
    winPercent: (100 * wins / samples).round(),
    drawPercent: (100 * draws / samples).round(),
    lossPercent: (100 * losses / samples).round(),
    avgUserGoals: userGoals / samples,
    avgOpponentGoals: opponentGoals / samples,
    cleanSheetPercent: (100 * cleanSheets / samples).round(),
    userTotals: userTotals,
    opponentTotals: opponentTotals,
  );
}
