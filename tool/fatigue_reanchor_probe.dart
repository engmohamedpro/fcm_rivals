// T-0052 fatigue-decoupling re-anchor probe (developer tool, not a test).
//
// Measures the affected balance scenarios under candidate TuningOverrides
// (pressBillSlope, lateGameOpen shape) using the existing sweep seam, so
// the shipped knobs can be tuned against the locked bands WITHOUT touching
// any band. Run: dart run tool/fatigue_reanchor_probe.dart
import 'dart:math' as math;

import 'package:fcm_rivals/core/domain/base_stats_generator.dart';
import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/tactics.dart';

const _positions = [
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

/// Inverts the T-0046 two-segment curve (standard slope below the €50M
/// kink, 7.5/doubling above it).
int _valueForOverall(int overall) => overall <= 84
    ? (50_000_000 * math.pow(2, (overall - 84) / 4)).round()
    : (50_000_000 * math.pow(2, (overall - 84) / 7.5)).round();

List<MatchPlayer> _squad(int base, int overall) {
  final gen = const BaseStatsGenerator();
  final value = _valueForOverall(overall);
  return [
    for (var i = 0; i < _positions.length; i++)
      MatchPlayer(
        playerId: base + i,
        name: 'P $i',
        position: _positions[i],
        attack: gen.generate(_positions[i], value).attack,
        support: gen.generate(_positions[i], value).support,
        defence: gen.generate(_positions[i], value).defence,
        goalkeeping: gen.generate(_positions[i], value).goalkeeping,
      ),
  ];
}

MatchEngine _engine(
  int seed, {
  int homeOverall = 70,
  int awayOverall = 70,
  TeamTactics homeTactics = const TeamTactics(),
}) => MatchEngine(
  seed: seed,
  home: MatchTeamInput(
    teamId: 1,
    teamName: 'Home',
    formationCode: '4-4-2',
    tactics: homeTactics,
    mentality: Mentality.balanced,
    starters: _squad(100, homeOverall),
    bench: const [],
  ),
  away: MatchTeamInput(
    teamId: 2,
    teamName: 'Away',
    formationCode: '4-4-2',
    tactics: const TeamTactics(),
    mentality: Mentality.balanced,
    starters: _squad(300, awayOverall),
    bench: const [],
  ),
);

/// Goals by the AWAY side after 75' per match (home carries [tac]).
double lateConceded(TeamTactics tac, int n, int seedBase) {
  var late = 0;
  for (var m = 0; m < n; m++) {
    for (final e in _engine(seedBase + m, homeTactics: tac).simulateToEnd()) {
      if (e.type == MatchEventType.goal &&
          e.side == MatchSide.away &&
          e.minute >= 75) {
        late++;
      }
    }
  }
  return late / n;
}

/// Home win rate with [tac] vs a default opponent at even strength.
double winRate(TeamTactics tac, int n, int seedBase) {
  var hw = 0;
  for (var m = 0; m < n; m++) {
    final eng = _engine(seedBase + m, homeTactics: tac);
    eng.simulateToEnd();
    if (eng.state.scoreHome > eng.state.scoreAway) hw++;
  }
  return hw / n;
}

const highPress = TeamTactics(
  outOfPossession: OutOfPossessionTactics(pressing: PressingIntensity.high),
);
const highStack = TeamTactics(
  outOfPossession: OutOfPossessionTactics(
    pressing: PressingIntensity.high,
    defensiveLine: DefensiveLine.high,
    tackling: TacklingAggression.aggressive,
    offsideTrap: true,
  ),
);
const gegenpress = TeamTactics(
  outOfPossession: OutOfPossessionTactics(
    pressing: PressingIntensity.high,
    defensiveLine: DefensiveLine.high,
  ),
  transitions: TransitionTactics(
    counterPress: CounterPress.immediate,
    restDefence: RestDefence.aggressive,
  ),
);
const lowPress = TeamTactics(
  outOfPossession: OutOfPossessionTactics(pressing: PressingIntensity.low),
);
const parkTheBus = TeamTactics(
  outOfPossession: OutOfPossessionTactics(
    pressing: PressingIntensity.low,
    defensiveLine: DefensiveLine.deep,
  ),
  transitions: TransitionTactics(attackOnRecovery: AttackOnRecovery.fast),
);
const restAggressive = TeamTactics(
  transitions: TransitionTactics(restDefence: RestDefence.aggressive),
);

void main() {
  final saved = TuningOverrides.current;
  const n = 600;
  // ignore: avoid_print
  print('--- pressBillSlope sweep (n=$n) ---');
  for (final slope in const [4.2, 6.0, 8.0, 10.0, 12.0]) {
    TuningOverrides.current = TuningOverrides.withValues(pressBillSlope: slope);
    final pressLate = lateConceded(highPress, n, 37000);
    final baseLate = lateConceded(const TeamTactics(), n, 37000);
    final ratio = pressLate / baseLate;
    final gp = winRate(gegenpress, n, 46000);
    final hs = winRate(highStack, n, 24000);
    final hp = winRate(highPress, n, 21000);
    // ignore: avoid_print
    print(
      'slope=$slope: lateRatio=$ratio '
      '(press $pressLate vs base $baseLate) '
      'gegenW=$gp highStackW=$hs highPressW=$hp',
    );
  }
  TuningOverrides.current = saved;

  // ignore: avoid_print
  print('--- slope-independent scenarios (shipped knobs, n=$n) ---');
  TuningOverrides.current = saved;
  final lp = winRate(lowPress, n, 21000);
  final pb = winRate(parkTheBus, n, 48000);
  final ra = winRate(restAggressive, n, 21000);
  // ignore: avoid_print
  print('lowPressW=$lp parkTheBusW=$pb restAggressiveW=$ra');

  // Even-strength goal-timing tail (calibration seeds 0..1999).
  var maxGoals = 0;
  var sixPlus = 0;
  final buckets = List<int>.filled(6, 0);
  for (var m = 0; m < 2000; m++) {
    final eng = _engine(m, homeOverall: 70, awayOverall: 70);
    final events = eng.simulateToEnd();
    final goals = eng.state.scoreHome + eng.state.scoreAway;
    if (goals > maxGoals) maxGoals = goals;
    if (goals >= 6) sixPlus++;
    for (final e in events) {
      if (e.type != MatchEventType.goal) continue;
      buckets[e.minute <= 15
          ? 0
          : e.minute <= 30
          ? 1
          : e.minute <= 45
          ? 2
          : e.minute <= 60
          ? 3
          : e.minute <= 75
          ? 4
          : 5]++;
    }
  }
  final total = buckets.fold<int>(0, (a, b) => a + b);
  // ignore: avoid_print
  print(
    'even: maxGoals=$maxGoals share6Plus=${sixPlus / 2000} '
    'b5=${buckets[5] / total} b0=${buckets[0] / total}',
  );
}
