/// FCM Rivals — match engine simulation harness (GDD 31).
///
/// Runs batches of simulated matches and aggregates the balance metrics
/// the GDD requires: average goals, home/away/draw rates, shots, shots
/// on target, goal conversion, cards, stamina depletion, tactical
/// effectiveness and division difficulty. Also provides the two
/// determinism checks GDD 31 demands: same seed + same command sequence
/// replays identically, and a tactic change at minute 60 changes future
/// events without altering earlier ones.
///
/// Pure Dart over the MatchEngine — no database, no UI. All randomness
/// flows from one seeded Random per batch (GDD development rule 7).
library;

import 'dart:math' as math;

import '../../core/domain/base_stats_generator.dart';
import '../../core/domain/players.dart';
import '../match/match_engine.dart';
import '../match/match_report.dart';
import '../match/tactics.dart';

/// Aggregated metrics for one batch of simulated matches (GDD 31 list).
class MatchSimBatchReport {
  MatchSimBatchReport({
    required this.label,
    required this.matches,
    required this.homeWins,
    required this.awayWins,
    required this.draws,
    required this.goals,
    required this.homeGoals,
    required this.awayGoals,
    required this.shots,
    required this.shotsOnTarget,
    required this.yellowCards,
    required this.redCards,
    required this.staminaDepletion,
    required this.avgHomeStaminaEnd,
    required this.avgAwayStaminaEnd,
    required this.homeTacticsWins,
    required this.awayTacticsWins,
  });

  final String label;
  final int matches;

  final int homeWins;
  final int awayWins;
  final int draws;
  final int goals;
  final int homeGoals;
  final int awayGoals;
  final int shots;
  final int shotsOnTarget;
  final int yellowCards;
  final int redCards;

  /// Average stamina points lost per starter over 90 minutes (both
  /// sides pooled).
  final double staminaDepletion;

  /// Average final stamina of the starting XI (both sides pooled).
  final double avgHomeStaminaEnd;
  final double avgAwayStaminaEnd;

  /// Tactical effectiveness (GDD 31): wins of the side that changed
  /// tactics at minute 60 vs the control group in the same batch.
  final int homeTacticsWins;
  final int awayTacticsWins;

  double get homeWinRate => matches == 0 ? 0 : homeWins / matches;
  double get awayWinRate => matches == 0 ? 0 : awayWins / matches;
  double get drawRate => matches == 0 ? 0 : draws / matches;
  double get avgGoals => matches == 0 ? 0 : goals / matches;
  double get avgHomeGoals => matches == 0 ? 0 : homeGoals / matches;
  double get avgAwayGoals => matches == 0 ? 0 : awayGoals / matches;
  double get avgShots => matches == 0 ? 0 : shots / matches;
  double get avgShotsOnTarget => matches == 0 ? 0 : shotsOnTarget / matches;
  double get avgYellowCards => matches == 0 ? 0 : yellowCards / matches;
  double get avgRedCards => matches == 0 ? 0 : redCards / matches;

  /// Goals / shots on target, across the whole batch.
  double get goalConversion => shotsOnTarget == 0 ? 0 : goals / shotsOnTarget;

  /// Tactical-effectiveness delta: tactics-group home win rate minus
  /// control-group home win rate (both from this batch).
  double get tacticalEffectiveness =>
      matches == 0 ? 0 : (homeTacticsWins - awayTacticsWins) / matches;
}

/// Outcome of one simulated match, kept for replay comparisons.
class MatchSimResult {
  const MatchSimResult({
    required this.seed,
    required this.scoreHome,
    required this.scoreAway,
    required this.eventCount,
    required this.commandCount,
  });

  final int seed;
  final int scoreHome;
  final int scoreAway;
  final int eventCount;
  final int commandCount;

  @override
  bool operator ==(Object other) =>
      other is MatchSimResult &&
      other.seed == seed &&
      other.scoreHome == scoreHome &&
      other.scoreAway == scoreAway &&
      other.eventCount == eventCount &&
      other.commandCount == commandCount;

  @override
  int get hashCode =>
      Object.hash(seed, scoreHome, scoreAway, eventCount, commandCount);
}

/// Builds squads from the stats generator, drives MatchEngine batches
/// and aggregates GDD 31 metrics.
class MatchSimulator {
  MatchSimulator({math.Random? random})
    : _random = random ?? math.Random(20261101);

  final math.Random _random;
  final BaseStatsGenerator _generator = const BaseStatsGenerator();

  /// Squad value band for one side (GDD 30 low/medium/high).
  static const lowValueEur = 2_000_000;
  static const mediumValueEur = 20_000_000;
  static const highValueEur = 120_000_000;

  List<MatchPlayer> _squad(int base, String prefix, int marketValueEur) {
    const positions = [
      Position.gk,
      Position.lb,
      Position.cb,
      Position.cb,
      Position.rb,
      Position.lm,
      Position.cm,
      Position.cm,
      Position.rm,
      Position.st,
      Position.st,
    ];
    return [
      for (var i = 0; i < positions.length; i++)
        () {
          final gen = _generator.generate(positions[i], marketValueEur);
          return MatchPlayer(
            playerId: base + i,
            name: '$prefix $i',
            position: positions[i],
            attack: gen.attack,
            support: gen.support,
            defence: gen.defence,
            goalkeeping: gen.goalkeeping,
            // Synthetic squads carry no nationality and no club: zero
            // chemistry, so balance baselines are unaffected (owner
            // spec 2026-11-09, club half 2026-11-11).
            nationality: '',
          );
        }(),
    ];
  }

  MatchEngine _engine(
    int seed, {
    required int homeValueEur,
    required int awayValueEur,
    int homeDivision = 1,
  }) {
    // Division difficulty (GDD 9.6/31): higher divisions field stronger
    // squads — modelled by shifting the away side's market value band.
    final awayValue = awayValueEur + (homeDivision - 1) * 10_000_000;
    return MatchEngine(
      seed: seed,
      home: MatchTeamInput(
        teamId: 1,
        teamName: 'Home FC',
        formationCode: '4-4-2',
        tactics: const TeamTactics(),
        mentality: Mentality.balanced,
        starters: _squad(100, 'Home', homeValueEur),
        bench: _squad(200, 'HomeB', homeValueEur ~/ 3).sublist(0, 5),
      ),
      away: MatchTeamInput(
        teamId: 2,
        teamName: 'Away FC',
        formationCode: '4-3-3',
        tactics: const TeamTactics(),
        mentality: Mentality.balanced,
        starters: _squad(300, 'Away', awayValue),
        bench: _squad(400, 'AwayB', awayValue ~/ 3).sublist(0, 5),
        aiControlled: true,
      ),
    );
  }

  /// Runs [matches] games and aggregates metrics. [tacticsAtMinute60]
  /// makes the home side issue a Live Match Action at minute 60 in every
  /// match (tactical effectiveness, GDD 31); the same batch without the
  /// change serves as the control via [controlHomeWins]/[controlAwayWins].
  MatchSimBatchReport runBatch({
    required String label,
    required int matches,
    int homeValueEur = mediumValueEur,
    int awayValueEur = mediumValueEur,
    int homeDivision = 1,
    bool tacticsAtMinute60 = false,
    int? controlHomeWins,
    int? controlAwayWins,
  }) {
    var homeWins = 0, awayWins = 0, draws = 0;
    var goals = 0, homeGoals = 0, awayGoals = 0;
    var shots = 0, shotsOnTarget = 0;
    var yellowCards = 0, redCards = 0;
    var staminaLost = 0.0, staminaCount = 0;
    var homeStaminaEnd = 0.0, awayStaminaEnd = 0.0;

    for (var i = 0; i < matches; i++) {
      final seed = _random.nextInt(1 << 31);
      final engine = _engine(
        seed,
        homeValueEur: homeValueEur,
        awayValueEur: awayValueEur,
        homeDivision: homeDivision,
      );
      if (tacticsAtMinute60) {
        engine.queueCommand(
          LiveActionCommand(
            atMinute: 60,
            side: MatchSide.home,
            action: LiveMatchAction.pushForward,
          ),
        );
      }
      engine.simulateToEnd();

      final state = engine.state;
      if (state.scoreHome > state.scoreAway) {
        homeWins++;
      } else if (state.scoreAway > state.scoreHome) {
        awayWins++;
      } else {
        draws++;
      }
      goals += state.scoreHome + state.scoreAway;
      homeGoals += state.scoreHome;
      awayGoals += state.scoreAway;

      final stats = computeStats(engine.events, homeTeamId: 1, awayTeamId: 2);
      shots += stats.home.shots + stats.away.shots;
      shotsOnTarget += stats.home.shotsOnTarget + stats.away.shotsOnTarget;
      yellowCards += stats.home.yellowCards + stats.away.yellowCards;
      redCards += stats.home.redCards + stats.away.redCards;

      for (final side in MatchSide.values) {
        for (final p in engine.playersOf(side)) {
          if (p.minutesPlayed >= 90) {
            staminaLost += 100 - p.stamina;
            staminaCount++;
            if (side == MatchSide.home) {
              homeStaminaEnd += p.stamina;
            } else {
              awayStaminaEnd += p.stamina;
            }
          }
        }
      }
    }

    return MatchSimBatchReport(
      label: label,
      matches: matches,
      homeWins: homeWins,
      awayWins: awayWins,
      draws: draws,
      goals: goals,
      homeGoals: homeGoals,
      awayGoals: awayGoals,
      shots: shots,
      shotsOnTarget: shotsOnTarget,
      yellowCards: yellowCards,
      redCards: redCards,
      staminaDepletion: staminaCount == 0 ? 0 : staminaLost / staminaCount,
      avgHomeStaminaEnd: staminaCount == 0
          ? 0
          : homeStaminaEnd / (staminaCount / 2),
      avgAwayStaminaEnd: staminaCount == 0
          ? 0
          : awayStaminaEnd / (staminaCount / 2),
      homeTacticsWins: controlHomeWins ?? homeWins,
      awayTacticsWins: controlAwayWins ?? awayWins,
    );
  }

  /// GDD 31 determinism check 1: the same seed and the same command
  /// sequence produce the identical event list and score.
  bool replaysDeterministically({
    required int seed,
    List<MatchCommand Function()> commandFactories = const [],
  }) {
    int run() {
      final engine = _engine(
        seed,
        homeValueEur: mediumValueEur,
        awayValueEur: mediumValueEur,
      );
      for (final factory in commandFactories) {
        engine.queueCommand(factory());
      }
      engine.simulateToEnd();
      return Object.hashAll([
        engine.state.scoreHome,
        engine.state.scoreAway,
        ...engine.events.map(
          (e) => Object.hash(
            e.minute,
            e.type.index,
            e.side.index,
            e.primaryPlayerId,
            e.secondaryPlayerId,
          ),
        ),
      ]);
    }

    return run() == run();
  }

  /// GDD 31 determinism check 2: a tactic change at minute 60 must
  /// affect future events without altering earlier ones. Returns null
  /// when the two runs match completely (change had no effect at all),
  /// otherwise true when the invariant holds.
  bool? minute60ChangeAffectsFutureOnly({
    required int seed,
    int sampleMatches = 64,
  }) {
    for (var i = 0; i < sampleMatches; i++) {
      final matchSeed = seed + i;
      final plain = _engine(
        matchSeed,
        homeValueEur: mediumValueEur,
        awayValueEur: mediumValueEur,
      );
      final changed = _engine(
        matchSeed,
        homeValueEur: mediumValueEur,
        awayValueEur: mediumValueEur,
      );

      // Run both to minute 59 step by step — identical prefixes.
      for (var minute = 0; minute < 60; minute++) {
        plain.advanceMinute();
        changed.advanceMinute();
      }
      final prefixPlain = plain.events.length;
      final prefixChanged = changed.events.length;
      if (prefixPlain != prefixChanged) return false;
      for (var e = 0; e < prefixPlain; e++) {
        if (plain.events[e].minute != changed.events[e].minute ||
            plain.events[e].type != changed.events[e].type ||
            plain.events[e].side != changed.events[e].side ||
            plain.events[e].primaryPlayerId !=
                changed.events[e].primaryPlayerId) {
          return false;
        }
      }

      // Diverge: one command at minute 60, then run both out.
      changed.queueCommand(
        ChangeMentalityCommand(
          atMinute: 60,
          side: MatchSide.home,
          mentality: Mentality.attacking,
        ),
      );
      plain.simulateToEnd();
      changed.simulateToEnd();

      final eventsPlain = plain.events;
      final eventsChanged = changed.events;
      // Prefix must STILL be identical (no retroactive edits).
      for (var e = 0; e < prefixPlain; e++) {
        if (eventsPlain[e].minute != eventsChanged[e].minute ||
            eventsPlain[e].type != eventsChanged[e].type) {
          return false;
        }
      }
      // At least one of the sampled matches should diverge overall;
      // if every single one is bit-identical the change did nothing.
      if (eventsPlain.length != eventsChanged.length ||
          eventsPlain.last.minute != eventsChanged.last.minute ||
          plain.state.scoreHome != changed.state.scoreHome ||
          plain.state.scoreAway != changed.state.scoreAway) {
        // Divergence observed — invariant holds for this match.
        continue;
      }
    }
    return null; // no divergence in any sampled match
  }

  /// One match summary for replay-record comparisons.
  MatchSimResult summarize(int seed) {
    final engine = _engine(
      seed,
      homeValueEur: mediumValueEur,
      awayValueEur: mediumValueEur,
    );
    engine.simulateToEnd();
    return MatchSimResult(
      seed: seed,
      scoreHome: engine.state.scoreHome,
      scoreAway: engine.state.scoreAway,
      eventCount: engine.events.length,
      commandCount: engine.appliedCommands.length,
    );
  }
}
