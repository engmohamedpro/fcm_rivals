/// FCM Rivals — scripted tactics tuning sweep (review
/// 2026-11-05_tactics_phase3-balance-bands-and-sweep, Task 1).
///
/// Scores a tuning candidate (instruction-anchor overrides + a compose
/// rule + the engine press-bill slope) against every pinned balance
/// band WITHOUT editing the model: the candidate is installed through
/// the `TuningOverrides` seam (`lib/features/match/tactics.dart`), the
/// harness runs, and the seam is restored in a `finally`. One line per
/// case: measured value, band, PASS/FAIL; plus a final fails count.
///
/// BANDS (identical to `test/balance/match_engine_balance_test.dart`;
/// re-listed here by design so candidates can be scored while the
/// suite keeps enforcing the same numbers):
///  * phase-1/2/3 singles: W 46-54% each (≥2,000 sims);
///  * the full 3x3x3x4 matrix: every combo W 38-60% (≥300/combo);
///  * full-stack in-possession extremes: W 40-58%, goals 2.4-3.1;
///  * gegenpress rebuild: W ≤ 58%, stamina@75' below baseline, late
///    goals conceded (75'+) ≥ +15% vs baseline;
///  * park-the-bus: W 40-58% and measured possession share 30-42%;
///  * cross-phase corners allStandard/allAttack/allDefence: W ≤ 58%,
///    goals 2.4-3.2, draws 20-34%, allAttack no-collapse (W ≥ 38%);
///  * global anchors: default-vs-default goals 2.6-2.9, draws 22-30%.
///
/// SEARCH ORDER (coordinate descent, documented per review Task 1):
///  S1 cost damp (0.70 shipped → 0.78/0.85): moves multi-instruction
///     stacks toward linear costs — lowers the max-possession stack
///     (its chance bills bite harder) and lifts allAttack (its chance
///     benefits compose stronger);
///  S2 possession hoarding damp (1.0 shipped → 0.85/0.7/0.55): tames
///     the playOut×slow stack only;
///  S3 the review's named offenders: high-press stamina/defence
///     (1.30/1.28 → 1.24-1.16), Fast Counter possession (0.85 →
///     0.90/0.92);
///  S4 park-the-bus compensation: deep 0.91 → 0.88, low 0.94 → 0.90
///     (keeps the counter stack's possession share in 30-42 after S3
///     raises the Fast Counter bill);
///  S5 possession-anchor trims (playOut/slow) only if the matrix worst
///     still rides the 60 boundary;
///  S6 press-bill slope — last resort, never taken unless S1-S5 leave
///     fails (the coefficient moved twice already; the review forbids
///     a third move while per-instruction anchors can move instead).
/// Each step is accepted only if the SCREEN fails count drops; the
/// accepted candidate then gets a FULL-precision validation run.
///
/// USAGE (the engine chain imports flutter/foundation, so this runs
/// under the flutter test runner like tool/simulation_report_test.dart):
///   flutter test tool/tactics_tuning_sweep.dart                     # baseline: score SHIPPED
///   SWEEP_MODE=candidate SWEEP_ABOVE=0.7 ... flutter test tool/...  # score one candidate
///   SWEEP_MODE=search    flutter test tool/tactics_tuning_sweep.dart  # run the descent
///   SWEEP_MODE=gate      flutter test tool/tactics_tuning_sweep.dart  # SHIPPED must score zero fails
/// Candidate knobs (all optional, shipped defaults when unset):
///   SWEEP_COST, SWEEP_STAMINA_DAMP, SWEEP_ABOVE, SWEEP_BELOW,
///   SWEEP_HP_STAMINA, SWEEP_HP_DEFENCE, SWEEP_HP_CHANCE,
///   SWEEP_FC_POSS, SWEEP_FC_CHANCE, SWEEP_FC_SHOT,
///   SWEEP_DEEP_POSS, SWEEP_LOW_POSS, SWEEP_PLAYOUT_POSS,
///   SWEEP_SLOW_POSS, SWEEP_PB_SLOPE, SWEEP_GATE=1.
/// Seeds: 700000+ blocks, disjoint from the suite's 1000-91xxx blocks.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/base_stats_generator.dart';
import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/match_report.dart';
import 'package:fcm_rivals/features/match/tactics.dart';

// ---------------------------------------------------------------------------
// Harness (mirrors test/balance/match_engine_balance_test.dart; disjoint
// seed ranges: the sweep uses 700000+, the suite 1000-91xxx)
// ---------------------------------------------------------------------------

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

int _valueForOverall(int overall) =>
    (50_000_000 * math.pow(2, (overall - 84) / 4)).round();

List<MatchPlayer> _squad(int base, String prefix) {
  final gen = const BaseStatsGenerator();
  final value = _valueForOverall(70);
  return [
    for (var i = 0; i < _positions.length; i++)
      MatchPlayer(
        playerId: base + i,
        name: '$prefix $i',
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
  TeamTactics homeTactics = const TeamTactics(),
}) => MatchEngine(
  seed: seed,
  home: MatchTeamInput(
    teamId: 1,
    teamName: 'Home',
    formationCode: '4-4-2',
    tactics: homeTactics,
    mentality: Mentality.balanced,
    starters: _squad(100, 'H'),
    bench: const [],
  ),
  away: MatchTeamInput(
    teamId: 2,
    teamName: 'Away',
    formationCode: '4-4-2',
    tactics: const TeamTactics(),
    mentality: Mentality.balanced,
    starters: _squad(300, 'A'),
    bench: const [],
  ),
);

/// Which seed pool the harness draws from. `sweep` (default): the
/// 700000+ blocks, disjoint from the suite. `suite`: the SAME blocks
/// the balance suite uses (21000/23000/25000/31xxx-48xxx) so a
/// candidate can be scored against the suite's ground truth without
/// editing the suite. A candidate is accepted only when it is green
/// on BOTH pools — the suite is the final gate, the sweep pool
/// guards against overfitting its seeds.
const bool _suiteSeeds = bool.fromEnvironment(
  'SWEEP_SEEDS_SUITE',
  defaultValue: false,
);

/// Logical seed bases per pool: [sweep, suite]. Suite values mirror
/// test/balance/match_engine_balance_test.dart's blocks so a `suite`
/// run reproduces the suite's numbers.
const _seedPools = <String, int>{
  'p1singles': 21000,
  'stacks': 23000,
  'matrix': 25000,
  'p2singles': 31000,
  'p2stacks': 33000,
  'bill': 36000,
  'lateBill': 37000,
  'p3singles': 41000,
  'gegenpress': 43000,
  'gegenStamina': 44000,
  'gegenLate': 45000,
  'parkTheBus': 46000,
  'parkShare': 47000,
  'corners': 48000,
  'globals': 7000,
};

int _seedBase(String pool) {
  if (!_suiteSeeds) {
    // Sweep pool: fixed 700000+ spacing, never colliding with the
    // suite's 1000-91xxx blocks.
    const order = [
      'p1singles',
      'stacks',
      'bill',
      'p2singles',
      'p3singles',
      'gegenpress',
      'parkTheBus',
      'corners',
      'matrix',
      'globals',
      'parkShare',
      'gegenStamina',
      'gegenLate',
    ];
    return 700000 + order.indexOf(pool) * 1000;
  }
  return _seedPools[pool]!;
}

class SweepBatch {
  const SweepBatch(
    this.matches,
    this.homeWins,
    this.draws,
    this.goals,
    this.stamina75,
  );

  final int matches;
  final int homeWins;
  final int draws;
  final int goals;
  final double stamina75;

  double get homeWinRate => homeWins / matches;
  double get drawRate => draws / matches;
  double get avgGoals => goals / matches;
}

/// Runs [matches] seeded sims. When [measureStamina75] the run stops at
/// 75' and the returned [SweepBatch.stamina75] is the home side's
/// average stamina at that minute (0 when not requested).
SweepBatch runSweepBatch(
  int matches,
  int seedBase, {
  TeamTactics homeTactics = const TeamTactics(),
  bool measureStamina75 = false,
}) {
  var hw = 0, d = 0, goals = 0;
  var staminaSum = 0.0;
  var staminaN = 0;
  for (var m = 0; m < matches; m++) {
    final engine = _engine(seedBase + m, homeTactics: homeTactics);
    if (measureStamina75) {
      while (!engine.isFinished && engine.state.minute < 75) {
        engine.advanceMinute();
      }
      for (final p in engine.playersOf(MatchSide.home)) {
        if (p.minutesPlayed >= 74) {
          staminaSum += p.stamina;
          staminaN++;
        }
      }
    } else {
      engine.simulateToEnd();
    }
    final s = engine.state;
    if (s.scoreHome > s.scoreAway) {
      hw++;
    } else if (s.scoreHome == s.scoreAway) {
      d++;
    }
    goals += s.scoreHome + s.scoreAway;
  }
  return SweepBatch(
    matches,
    hw,
    d,
    goals,
    staminaN == 0 ? 0 : staminaSum / staminaN,
  );
}

/// Late goals conceded by the home side (the tactics side) from 75' on.
int _lateGoalsConceded(int matches, int seedBase, TeamTactics homeTactics) {
  var late = 0;
  for (var m = 0; m < matches; m++) {
    final engine = _engine(seedBase + m, homeTactics: homeTactics);
    for (final e in engine.simulateToEnd()) {
      if (e.type == MatchEventType.goal &&
          e.side == MatchSide.away &&
          e.minute >= 75) {
        late++;
      }
    }
  }
  return late;
}

/// Measured possession share of the home side over [matches] sims.
double _possessionShare(int matches, int seedBase, TeamTactics homeTactics) {
  var possSum = 0.0;
  var counted = 0;
  for (var m = 0; m < matches; m++) {
    final engine = _engine(seedBase + m, homeTactics: homeTactics);
    engine.simulateToEnd();
    final stats = computeStats(engine.events, homeTeamId: 1, awayTeamId: 2);
    if (stats.home.possessionMinutes + stats.away.possessionMinutes > 0) {
      possSum += stats.possessionPercent(stats.home);
      counted++;
    }
  }
  return counted == 0 ? 0 : possSum / counted;
}

// ---------------------------------------------------------------------------
// The pinned stacks
// ---------------------------------------------------------------------------

TeamTactics _maxPossession() => const TeamTactics(
  inPossession: InPossessionTactics(
    buildUp: BuildUpStyle.playOut,
    tempo: AttackTempo.slow,
    width: AttackWidth.narrow,
    finalThird: FinalThirdApproach.workBallIntoBox,
  ),
);

TeamTactics _maxDirect() => const TeamTactics(
  inPossession: InPossessionTactics(
    buildUp: BuildUpStyle.longBall,
    tempo: AttackTempo.fast,
    width: AttackWidth.wide,
    finalThird: FinalThirdApproach.shootOnSight,
  ),
);

TeamTactics _parkTheBus() => const TeamTactics(
  outOfPossession: OutOfPossessionTactics(
    defensiveLine: DefensiveLine.deep,
    pressing: PressingIntensity.low,
  ),
  transitions: TransitionTactics(attackOnRecovery: AttackOnRecovery.fast),
);

TeamTactics _gegenpress() => const TeamTactics(
  outOfPossession: OutOfPossessionTactics(
    defensiveLine: DefensiveLine.high,
    pressing: PressingIntensity.high,
  ),
  transitions: TransitionTactics(
    counterPress: CounterPress.immediate,
    restDefence: RestDefence.aggressive,
  ),
);

TeamTactics _allAttack() => const TeamTactics(
  inPossession: InPossessionTactics(
    buildUp: BuildUpStyle.longBall,
    tempo: AttackTempo.fast,
    width: AttackWidth.wide,
    finalThird: FinalThirdApproach.shootOnSight,
  ),
  outOfPossession: OutOfPossessionTactics(
    defensiveLine: DefensiveLine.high,
    pressing: PressingIntensity.high,
    tackling: TacklingAggression.aggressive,
    offsideTrap: true,
  ),
  transitions: TransitionTactics(
    counterPress: CounterPress.immediate,
    attackOnRecovery: AttackOnRecovery.fast,
    restDefence: RestDefence.aggressive,
  ),
);

TeamTactics _allDefence() => const TeamTactics(
  inPossession: InPossessionTactics(
    buildUp: BuildUpStyle.playOut,
    tempo: AttackTempo.slow,
    width: AttackWidth.narrow,
    finalThird: FinalThirdApproach.workBallIntoBox,
  ),
  outOfPossession: OutOfPossessionTactics(
    defensiveLine: DefensiveLine.deep,
    pressing: PressingIntensity.low,
    tackling: TacklingAggression.clean,
  ),
  transitions: TransitionTactics(
    counterPress: CounterPress.retreat,
    attackOnRecovery: AttackOnRecovery.patient,
    restDefence: RestDefence.conservative,
  ),
);

const _p1Singles = <String, TeamTactics>{
  'playOut': TeamTactics(
    inPossession: InPossessionTactics(buildUp: BuildUpStyle.playOut),
  ),
  'longBall': TeamTactics(
    inPossession: InPossessionTactics(buildUp: BuildUpStyle.longBall),
  ),
  'slow': TeamTactics(
    inPossession: InPossessionTactics(tempo: AttackTempo.slow),
  ),
  'fast': TeamTactics(
    inPossession: InPossessionTactics(tempo: AttackTempo.fast),
  ),
  'narrow': TeamTactics(
    inPossession: InPossessionTactics(width: AttackWidth.narrow),
  ),
  'wide': TeamTactics(
    inPossession: InPossessionTactics(width: AttackWidth.wide),
  ),
  'workBall': TeamTactics(
    inPossession: InPossessionTactics(
      finalThird: FinalThirdApproach.workBallIntoBox,
    ),
  ),
  'earlyCrosses': TeamTactics(
    inPossession: InPossessionTactics(
      finalThird: FinalThirdApproach.earlyCrosses,
    ),
  ),
  'shootOnSight': TeamTactics(
    inPossession: InPossessionTactics(
      finalThird: FinalThirdApproach.shootOnSight,
    ),
  ),
};

const _p2Singles = <String, TeamTactics>{
  'deep': TeamTactics(
    outOfPossession: OutOfPossessionTactics(defensiveLine: DefensiveLine.deep),
  ),
  'highLine': TeamTactics(
    outOfPossession: OutOfPossessionTactics(defensiveLine: DefensiveLine.high),
  ),
  'lowPress': TeamTactics(
    outOfPossession: OutOfPossessionTactics(pressing: PressingIntensity.low),
  ),
  'highPress': TeamTactics(
    outOfPossession: OutOfPossessionTactics(pressing: PressingIntensity.high),
  ),
  'clean': TeamTactics(
    outOfPossession: OutOfPossessionTactics(tackling: TacklingAggression.clean),
  ),
  'aggressive': TeamTactics(
    outOfPossession: OutOfPossessionTactics(
      tackling: TacklingAggression.aggressive,
    ),
  ),
  'trap': TeamTactics(
    outOfPossession: OutOfPossessionTactics(offsideTrap: true),
  ),
};

const _p3Singles = <String, TeamTactics>{
  'retreat': TeamTactics(
    transitions: TransitionTactics(counterPress: CounterPress.retreat),
  ),
  'immediate': TeamTactics(
    transitions: TransitionTactics(counterPress: CounterPress.immediate),
  ),
  'patient': TeamTactics(
    transitions: TransitionTactics(attackOnRecovery: AttackOnRecovery.patient),
  ),
  'fastCounter': TeamTactics(
    transitions: TransitionTactics(attackOnRecovery: AttackOnRecovery.fast),
  ),
  'restConservative': TeamTactics(
    transitions: TransitionTactics(restDefence: RestDefence.conservative),
  ),
  'restAggressive': TeamTactics(
    transitions: TransitionTactics(restDefence: RestDefence.aggressive),
  ),
};

// ---------------------------------------------------------------------------
// Scoring
// ---------------------------------------------------------------------------

class CaseRow {
  const CaseRow(this.name, this.measured, this.band, this.pass);
  final String name;
  final String measured;
  final String band;
  final bool pass;
}

int _fails(List<CaseRow> rows) => rows.where((r) => !r.pass).length;

bool _inBand(double v, double lo, double hi) => v >= lo && v <= hi;

/// Scores every pinned band under the CURRENT TuningOverrides.current.
///
/// [precision]: 1.0 = the review's Ns (singles 2,000; stacks/rebuilds
/// 3,000; corners 1,200; matrix 320/combo; globals 10,000) — the
/// number a candidate is ACCEPTED on. [matrix] false skips the
/// 108-combo block (the expensive part) for fast search screening;
/// [globals] false skips the default-vs-default anchors (unaffected by
/// any tactic-anchor candidate) during screening.
List<CaseRow> scoreBands({
  double precision = 1.0,
  bool matrix = true,
  bool globals = true,
}) {
  final rows = <CaseRow>[];
  int n(double base) => (base * precision).round();

  void addW(String name, double w, double lo, double hi) => rows.add(
    CaseRow(
      name,
      '${(w * 100).toStringAsFixed(1)}%',
      '${(lo * 100).toStringAsFixed(0)}-${(hi * 100).toStringAsFixed(0)}%',
      _inBand(w, lo, hi),
    ),
  );

  // Singles: phases 1-3, one row each (the named offenders included).
  for (final group in [_p1Singles, _p2Singles, _p3Singles]) {
    for (final e in group.entries) {
      final b = runSweepBatch(n(2000), _seedBase('p1singles'), homeTactics: e.value);
      addW(e.key, b.homeWinRate, .46, .54);
    }
  }

  // Full-stack in-possession extremes.
  for (final (name, tac) in [
    ('maxPossession', _maxPossession()),
    ('maxDirect', _maxDirect()),
  ]) {
    final b = runSweepBatch(n(3000), _seedBase('stacks'), homeTactics: tac);
    addW('$name W', b.homeWinRate, .40, .58);
    rows.add(
      CaseRow(
        '$name goals',
        b.avgGoals.toStringAsFixed(2),
        '2.4-3.1',
        _inBand(b.avgGoals, 2.4, 3.1),
      ),
    );
  }

  // Gegenpress rebuild: win rate + the stamina/late-goal bill.
  {
    final b = runSweepBatch(n(3000), _seedBase('gegenpress'), homeTactics: _gegenpress());
    rows.add(
      CaseRow(
        'gegenpress W',
        '${(b.homeWinRate * 100).toStringAsFixed(1)}%',
        '<=58%',
        b.homeWinRate <= .58,
      ),
    );
    final billN = n(1500);
    final baseStamina = runSweepBatch(
      billN,
      _seedBase('gegenStamina'),
      measureStamina75: true,
    ).stamina75;
    final gegenStamina = runSweepBatch(
      billN,
      _seedBase('gegenStamina'),
      homeTactics: _gegenpress(),
      measureStamina75: true,
    ).stamina75;
    rows.add(
      CaseRow(
        'gegenpress stamina@75',
        gegenStamina.toStringAsFixed(1),
        '< ${baseStamina.toStringAsFixed(1)} (baseline)',
        gegenStamina < baseStamina,
      ),
    );
    final baseLate = _lateGoalsConceded(billN, _seedBase('gegenLate'), const TeamTactics());
    final gegenLate = _lateGoalsConceded(billN, _seedBase('gegenLate'), _gegenpress());
    final ratio = baseLate == 0 ? 99.0 : gegenLate / baseLate;
    rows.add(
      CaseRow(
        'gegenpress late goals',
        '${(ratio * 100).toStringAsFixed(0)}%',
        '>= +15%',
        ratio >= 1.15,
      ),
    );
  }

  // Park the bus: win rate + measured possession share.
  {
    final b = runSweepBatch(n(3000), _seedBase('parkTheBus'), homeTactics: _parkTheBus());
    addW('parkTheBus W', b.homeWinRate, .40, .58);
    final share = _possessionShare(n(500), _seedBase('parkShare'), _parkTheBus());
    rows.add(
      CaseRow(
        'parkTheBus possession',
        share.toStringAsFixed(1),
        '30-42%',
        _inBand(share, 30, 42),
      ),
    );
  }

  // Cross-phase corners.
  for (final (name, tac) in [
    ('allStandard', const TeamTactics()),
    ('allAttack', _allAttack()),
    ('allDefence', _allDefence()),
  ]) {
    final b = runSweepBatch(n(1200), _seedBase('corners'), homeTactics: tac);
    rows.add(
      CaseRow(
        '$name W',
        '${(b.homeWinRate * 100).toStringAsFixed(1)}%',
        '<=58%',
        b.homeWinRate <= .58,
      ),
    );
    rows.add(
      CaseRow(
        '$name goals',
        b.avgGoals.toStringAsFixed(2),
        '2.4-3.2',
        _inBand(b.avgGoals, 2.4, 3.2),
      ),
    );
    rows.add(
      CaseRow(
        '$name draws',
        '${(b.drawRate * 100).toStringAsFixed(1)}%',
        '20-34%',
        _inBand(b.drawRate, .20, .34),
      ),
    );
    if (name == 'allAttack') {
      rows.add(
        CaseRow(
          'allAttack no-collapse',
          '${(b.homeWinRate * 100).toStringAsFixed(1)}%',
          '>=38%',
          b.homeWinRate >= .38,
        ),
      );
    }
  }

  // The 3x3x3x4 matrix: worst combo + out-of-band count.
  if (matrix) {
    var worst = 0.0;
    var worstName = '';
    var out = 0;
    for (final bu in BuildUpStyle.values) {
      for (final t in AttackTempo.values) {
        for (final w in AttackWidth.values) {
          for (final f in FinalThirdApproach.values) {
            final tac = TeamTactics(
              inPossession: InPossessionTactics(
                buildUp: bu,
                tempo: t,
                width: w,
                finalThird: f,
              ),
            );
            final b = runSweepBatch(n(320), _seedBase('matrix'), homeTactics: tac);
            if (!_inBand(b.homeWinRate, .38, .60)) out++;
            if (b.homeWinRate > worst) {
              worst = b.homeWinRate;
              worstName = '${bu.name}+${t.name}+${w.name}+${f.name}';
            }
          }
        }
      }
    }
    rows.add(
      CaseRow(
        'matrix worst ($worstName)',
        '${(worst * 100).toStringAsFixed(1)}%',
        'each 38-60% ($out combo out)',
        out == 0,
      ),
    );
  }

  // Global anchors: default-vs-default.
  if (globals) {
    final b = runSweepBatch(n(10000), _seedBase('globals'));
    rows.add(
      CaseRow(
        'default goals',
        b.avgGoals.toStringAsFixed(2),
        '2.6-2.9',
        _inBand(b.avgGoals, 2.6, 2.9),
      ),
    );
    rows.add(
      CaseRow(
        'default draws',
        '${(b.drawRate * 100).toStringAsFixed(1)}%',
        '22-30%',
        _inBand(b.drawRate, .22, .30),
      ),
    );
  }

  return rows;
}

void _printRows(String label, List<CaseRow> rows) {
  final sb = StringBuffer()
    ..writeln('=== $label — ${_fails(rows)} fail(s) of ${rows.length} ===');
  for (final r in rows) {
    sb.writeln(
      '${r.pass ? 'PASS' : 'FAIL'}  ${r.name.padRight(26)} '
      'measured ${r.measured.padRight(10)} band ${r.band}',
    );
  }
  // ignore: avoid_print
  print(sb.toString());
}

// ---------------------------------------------------------------------------
// Candidates
// ---------------------------------------------------------------------------

class SweepCandidate {
  /// Defaults mirror the CURRENT shipped anchors in tactics.dart
  /// (sweep-tuned 2026-11-05, attempt 3) — the search departs from
  /// there, and the suite-accepted winner lands back into the code.
  const SweepCandidate({
    this.costDamp = 0.85,
    this.staminaDamp = 0.55,
    this.aboveDamp = 1.0,
    this.belowDamp = 1.0,
    this.hpStamina = 1.33,
    this.hpDefence = 1.28,
    this.hpChance = 1.04,
    this.fcPoss = 0.90,
    this.fcChance = 1.10,
    this.fcShot = 1.03,
    this.deepPoss = 0.88,
    this.lowPoss = 0.90,
    this.playOutPoss = 1.05,
    this.slowPoss = 1.02,
    this.pbSlope = 2.0,
  });

  final double costDamp;
  final double staminaDamp;
  final double aboveDamp;
  final double belowDamp;
  final double hpStamina;
  final double hpDefence;
  final double hpChance;
  final double fcPoss;
  final double fcChance;
  final double fcShot;
  final double deepPoss;
  final double lowPoss;
  final double playOutPoss;
  final double slowPoss;
  final double pbSlope;

  Map<InstructionOption, TacticModifiers> _instructions() => {
    PressingIntensity.high: TacticModifiers(
      defence: hpDefence,
      chance: hpChance,
      stamina: hpStamina,
    ),
    AttackOnRecovery.fast: TacticModifiers(
      possession: fcPoss,
      chance: fcChance,
      shotQuality: fcShot,
    ),
    DefensiveLine.deep: TacticModifiers(defence: 1.05, possession: deepPoss),
    PressingIntensity.low: TacticModifiers(
      defence: 1.02,
      stamina: 0.88,
      possession: lowPoss,
    ),
    BuildUpStyle.playOut: TacticModifiers(
      possession: playOutPoss,
      passAccuracy: 1.05,
      chance: 0.94,
    ),
    AttackTempo.slow: TacticModifiers(
      possession: slowPoss,
      chance: 0.95,
      stamina: 0.94,
    ),
  };

  ComposeRule _compose() => ComposeRule(
    costStackDamp: costDamp,
    staminaStackDamp: staminaDamp,
    possessionStackDampAbove: aboveDamp,
    possessionStackDampBelow: belowDamp,
  );

  void install() {
    TuningOverrides.current = TuningOverrides.withValues(
      instructions: _instructions(),
      compose: _compose(),
      pressBillSlope: pbSlope,
    );
  }

  /// One-line fingerprint for logs.
  String get fingerprint =>
      'cost=$costDamp sta=$staminaDamp above=$aboveDamp below=$belowDamp '
      'hp=$hpDefence/$hpChance/$hpStamina fc=$fcPoss/$fcChance/$fcShot '
      'deep=$deepPoss low=$lowPoss po=$playOutPoss slow=$slowPoss pb=$pbSlope';

  static SweepCandidate fromEnv() {
    double d(String k, double fallback) {
      final v = Platform.environment[k];
      if (v == null || v.isEmpty) return fallback;
      return double.tryParse(v) ?? fallback;
    }

    return SweepCandidate(
      costDamp: d('SWEEP_COST', 0.85),
      staminaDamp: d('SWEEP_STAMINA_DAMP', 0.55),
      aboveDamp: d('SWEEP_ABOVE', 1.0),
      belowDamp: d('SWEEP_BELOW', 1.0),
      hpStamina: d('SWEEP_HP_STAMINA', 1.33),
      hpDefence: d('SWEEP_HP_DEFENCE', 1.28),
      hpChance: d('SWEEP_HP_CHANCE', 1.04),
      fcPoss: d('SWEEP_FC_POSS', 0.90),
      fcChance: d('SWEEP_FC_CHANCE', 1.10),
      fcShot: d('SWEEP_FC_SHOT', 1.03),
      deepPoss: d('SWEEP_DEEP_POSS', 0.88),
      lowPoss: d('SWEEP_LOW_POSS', 0.90),
      playOutPoss: d('SWEEP_PLAYOUT_POSS', 1.05),
      slowPoss: d('SWEEP_SLOW_POSS', 1.02),
      pbSlope: d('SWEEP_PB_SLOPE', 2.0),
    );
  }
}

// ---------------------------------------------------------------------------
// Search (coordinate descent, order documented in the header)
// ---------------------------------------------------------------------------

void main() {
  test('tactics tuning sweep', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final env = Platform.environment;
    final mode = env['SWEEP_MODE'] ?? 'baseline';
    final gate = env['SWEEP_GATE'] == '1';
    // ignore: avoid_print
    print('SWEEP mode=$mode gate=$gate');

    try {
      if (mode == 'baseline') {
        TuningOverrides.current = TuningOverrides.none;
        final rows = scoreBands();
        _printRows('SHIPPED BASELINE (full precision)', rows);
        // Informational by default: the known red bands are the
        // starting point of the search. Gate mode turns this into a
        // CI check (zero fails required) after the anchors land.
        if (gate) expect(_fails(rows), 0, reason: 'gate: shipped bands red');
      } else if (mode == 'candidate') {
        final c = SweepCandidate.fromEnv();
        // ignore: avoid_print
        print('candidate: ${c.fingerprint}');
        c.install();
        final rows = scoreBands();
        _printRows('CANDIDATE (full precision)', rows);
        if (gate) {
          expect(_fails(rows), 0, reason: 'candidate left bands red');
        }
      } else if (mode == 'gate') {
        TuningOverrides.current = TuningOverrides.none;
        final rows = scoreBands();
        _printRows('GATE: shipped constants', rows);
        expect(_fails(rows), 0, reason: 'shipped constants left bands red');
      } else if (mode == 'search') {
        _runSearch();
      } else {
        fail('unknown SWEEP_MODE $mode');
      }
    } finally {
      TuningOverrides.current = TuningOverrides.none;
    }
  });
}

// ---------------------------------------------------------------------------
// The search driver
// ---------------------------------------------------------------------------

void _runSearch() {
  // Screen = full-precision bands at half N, no matrix, no globals.
  int screen(SweepCandidate c) {
    c.install();
    return _fails(scoreBands(precision: 0.5, matrix: false, globals: false));
  }

  var best = const SweepCandidate();
  best.install();
  var bestFails = _fails(
    scoreBands(precision: 0.5, matrix: false, globals: false),
  );
  // ignore: avoid_print
  print('S0 baseline screen: $bestFails fails');

  // S1: cost damp (linear-ize stacked costs/benefits).
  for (final v in [0.78, 0.85]) {
    final c = SweepCandidate(costDamp: v);
    final f = screen(c);
    if (f < bestFails) {
      bestFails = f;
      best = c;
    }
    // ignore: avoid_print
    print('S1 cost=$v -> $f (best $bestFails)');
  }

  // S2: possession-hoarding damp.
  for (final v in [0.85, 0.7, 0.55]) {
    final c = SweepCandidate(costDamp: best.costDamp, aboveDamp: v);
    final f = screen(c);
    if (f < bestFails) {
      bestFails = f;
      best = c;
    }
    // ignore: avoid_print
    print('S2 above=$v -> $f (best $bestFails)');
  }

  // S3a: high-press stamina, then defence.
  for (final s in [1.24, 1.20, 1.16]) {
    final c = SweepCandidate(
      costDamp: best.costDamp,
      aboveDamp: best.aboveDamp,
      hpStamina: s,
    );
    final f = screen(c);
    if (f < bestFails) {
      bestFails = f;
      best = c;
    }
    // ignore: avoid_print
    print('S3a hpStamina=$s -> $f (best $bestFails)');
  }
  for (final dv in [1.22, 1.16]) {
    final c = SweepCandidate(
      costDamp: best.costDamp,
      aboveDamp: best.aboveDamp,
      hpStamina: best.hpStamina,
      hpDefence: dv,
    );
    final f = screen(c);
    if (f < bestFails) {
      bestFails = f;
      best = c;
    }
    // ignore: avoid_print
    print('S3b hpDefence=$dv -> $f (best $bestFails)');
  }

  // S3c: Fast Counter possession bill.
  for (final p in [0.90, 0.92, 0.94]) {
    final c = SweepCandidate(
      costDamp: best.costDamp,
      aboveDamp: best.aboveDamp,
      hpStamina: best.hpStamina,
      hpDefence: best.hpDefence,
      fcPoss: p,
    );
    final f = screen(c);
    if (f < bestFails) {
      bestFails = f;
      best = c;
    }
    // ignore: avoid_print
    print('S3c fcPoss=$p -> $f (best $bestFails)');
  }

  // S4: park-the-bus compensation (deep + low possession).
  for (final (dp, lp) in [(0.88, 0.92), (0.88, 0.90), (0.86, 0.90)]) {
    final c = SweepCandidate(
      costDamp: best.costDamp,
      aboveDamp: best.aboveDamp,
      hpStamina: best.hpStamina,
      hpDefence: best.hpDefence,
      fcPoss: best.fcPoss,
      deepPoss: dp,
      lowPoss: lp,
    );
    final f = screen(c);
    if (f < bestFails) {
      bestFails = f;
      best = c;
    }
    // ignore: avoid_print
    print('S4 deep=$dp low=$lp -> $f (best $bestFails)');
  }

  // S5: possession-anchor trims if the maxPossession stack still rides.
  for (final (po, sl) in [(1.04, 1.02), (1.04, 1.03), (1.05, 1.02)]) {
    final c = SweepCandidate(
      costDamp: best.costDamp,
      aboveDamp: best.aboveDamp,
      hpStamina: best.hpStamina,
      hpDefence: best.hpDefence,
      fcPoss: best.fcPoss,
      deepPoss: best.deepPoss,
      lowPoss: best.lowPoss,
      playOutPoss: po,
      slowPoss: sl,
    );
    final f = screen(c);
    if (f < bestFails) {
      bestFails = f;
      best = c;
    }
    // ignore: avoid_print
    print('S5 playOut=$po slow=$sl -> $f (best $bestFails)');
  }

  // S6: press-bill slope, only if still red.
  for (final v in [1.8, 1.6]) {
    final c = SweepCandidate(
      costDamp: best.costDamp,
      aboveDamp: best.aboveDamp,
      hpStamina: best.hpStamina,
      hpDefence: best.hpDefence,
      fcPoss: best.fcPoss,
      deepPoss: best.deepPoss,
      lowPoss: best.lowPoss,
      playOutPoss: best.playOutPoss,
      slowPoss: best.slowPoss,
      pbSlope: v,
    );
    final f = screen(c);
    if (f < bestFails) {
      bestFails = f;
      best = c;
    }
    // ignore: avoid_print
    print('S6 pbSlope=$v -> $f (best $bestFails)');
  }

  // ignore: avoid_print
  print('SEARCH WINNER: ${best.fingerprint}');
  best.install();
  final rows = scoreBands();
  _printRows('WINNER VALIDATION (full precision)', rows);
  expect(_fails(rows), 0, reason: 'search winner left bands red');
}
