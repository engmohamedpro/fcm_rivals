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
/// SEARCH ORDER (coordinate descent, anchor pass 2026-11-06 on the
/// ALIGNED harness — the four suite reds it targets: `fast` single
/// 45.3% W, matrix worst 61.0% W, allDefence goals 2.38, gegenpress
/// late ratio 1.118):
///  R1 fast single W (band 46-54): AttackTempo.fast chance
///     1.05 → 1.06/1.07 — lifts the fast single and the fast-carrying
///     stacks (maxDirect, allAttack, the matrix fast rows);
///  R2 matrix worst (band ≤60): playOut possession 1.06 → 1.05 or
///     slow possession 1.03 → 1.02 — shaves the hoarding combos while
///     keeping each single's own W row in band;
///  R3 allDefence goals (band ≥2.4): workBall shotQuality 1.08 →
///     1.09/1.10 — a conversion-side lever: more finished goals
///     without moving chance creation, so the W rows barely move;
///  R4 gegenpress late ≥ +15%: staminaStackDamp 0.55 → 0.60/0.65 —
///     the stacked-stamina compose factor moves the gegenpress and
///     allAttack BILL without touching any single (singles never
///     stack); the press-bill slope stays frozen per the review's
///     third-move ban;
///  R5 hpStamina 1.30 → 1.32, R4's fallback (moves the highPress
///     single as well — only if the compose lever proves short).
/// Each step is accepted only if the SCREEN fails count drops; the
/// accepted candidate then gets a FULL-precision validation run on
/// BOTH pools — the suite pool first, because on the aligned harness
/// it IS the suite's ground truth.
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
///   SWEEP_FC_POSS, SWEEP_FC_CHANCE, SWEEP_FC_SHOT, SWEEP_PATIENT_POSS,
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
  // Each phase draws from ITS OWN seed base so a suite-pool run
  // reproduces the balance suite's numbers exactly (p1 21000, p2
  // 31000, p3 41000 — match_engine_balance_test.dart's blocks); the
  // previous single p1singles base for all three masked the p2/p3
  // suite rows the anchor pass must close.
  const groupSeeds = {
    _p1Singles: 'p1singles',
    _p2Singles: 'p2singles',
    _p3Singles: 'p3singles',
  };
  for (final group in [_p1Singles, _p2Singles, _p3Singles]) {
    for (final e in group.entries) {
      final b = runSweepBatch(
        n(2000),
        _seedBase(groupSeeds[group]!),
        homeTactics: e.value,
      );
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
            // Matrix N mirrors the suite block EXACTLY (300 sims/combo
            // at seed base 25000, match_engine_balance_test.dart) so a
            // suite-pool run reproduces the suite's matrix test
            // seed-for-seed. The previous 320/combo spacing sampled a
            // different distribution and scored the matrix row green
            // while the suite ran red at 61.0% (anchor pass
            // 2026-11-06, task
            // `2026-11-06_tactics_phase3-anchor-pass-and-gates`).
            final b = runSweepBatch(n(300), _seedBase('matrix'), homeTactics: tac);
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
  /// (verified 2026-11-06 against every enum constant after the final
  /// trims landed: cost 0.84, stamina 0.60, possession hoard 0.70 /
  /// cede 1.0, hp 1.34/1.16/1.30, fc 0.91/1.12/1.03, deep 0.92, low
  /// 0.86, playOut 1.06, slow 1.03, fast 1.06/0.97/0.99/1.02, work
  /// ball shot quality 1.10, patient 1.05/0.96, press-bill slope 4.2).
  /// A candidate object that changes ONE knob therefore departs from
  /// shipped on exactly that knob — the search steps stay
  /// interpretable. (The pre-alignment revision carried attempt-3
  /// values here while claiming to mirror shipped, which confounded
  /// every "single-knob" screen of that search.)
  ///
  /// Final-trim knobs (anchor pass 2026-11-06): `fastChance`,
  /// `fastPoss`, `fastPassAcc` and `fastStamina` mirror the
  /// `AttackTempo.fast` bundle, `workBallShotQ` mirrors
  /// `FinalThirdApproach.workBallIntoBox.shotQuality` and
  /// `patientChance` mirrors `AttackOnRecovery.patient.chance` — the
  /// levers the final trims needed: the first group addresses the
  /// `fast` single, the last two address the allDefence goals floor
  /// (transitions never appear in the matrix, so `patientChance` is
  /// isolated from the matrix worst combo) without editing the model.
  const SweepCandidate({
    this.costDamp = 0.84,
    this.staminaDamp = 0.60,
    this.aboveDamp = 0.70,
    this.belowDamp = 1.0,
    this.hpStamina = 1.30,
    this.hpDefence = 1.34,
    this.hpChance = 1.16,
    this.fcPoss = 0.91,
    this.fcChance = 1.12,
    this.fcShot = 1.03,
    this.patientPoss = 1.05,
    this.patientChance = 0.96,
    this.deepPoss = 0.92,
    this.lowPoss = 0.86,
    this.playOutPoss = 1.06,
    this.slowPoss = 1.03,
    this.fastChance = 1.06,
    this.fastPoss = 0.97,
    this.fastPassAcc = 0.99,
    this.fastStamina = 1.02,
    this.workBallShotQ = 1.10,
    this.pbSlope = 4.2,
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
  final double patientPoss;
  final double patientChance;
  final double deepPoss;
  final double lowPoss;
  final double playOutPoss;
  final double slowPoss;
  final double fastChance;
  final double fastPoss;
  final double fastPassAcc;
  final double fastStamina;
  final double workBallShotQ;
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
    AttackOnRecovery.patient: TacticModifiers(
      possession: patientPoss,
      chance: patientChance,
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
    AttackTempo.fast: TacticModifiers(
      possession: fastPoss,
      chance: fastChance,
      passAccuracy: fastPassAcc,
      stamina: fastStamina,
    ),
    FinalThirdApproach.workBallIntoBox: TacticModifiers(
      chance: 0.92,
      shotQuality: workBallShotQ,
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
      'pat=$patientPoss/$patientChance deep=$deepPoss low=$lowPoss po=$playOutPoss '
      'slow=$slowPoss fast=$fastChance/$fastPoss/$fastPassAcc/$fastStamina '
      'wb=$workBallShotQ pb=$pbSlope';

  static SweepCandidate fromEnv() {
    double d(String k, double fallback) {
      final v = Platform.environment[k];
      if (v == null || v.isEmpty) return fallback;
      return double.tryParse(v) ?? fallback;
    }

    return SweepCandidate(
      costDamp: d('SWEEP_COST', 0.84),
      staminaDamp: d('SWEEP_STAMINA_DAMP', 0.60),
      aboveDamp: d('SWEEP_ABOVE', 0.70),
      belowDamp: d('SWEEP_BELOW', 1.0),
      hpStamina: d('SWEEP_HP_STAMINA', 1.30),
      hpDefence: d('SWEEP_HP_DEFENCE', 1.34),
      hpChance: d('SWEEP_HP_CHANCE', 1.16),
      fcPoss: d('SWEEP_FC_POSS', 0.91),
      fcChance: d('SWEEP_FC_CHANCE', 1.12),
      fcShot: d('SWEEP_FC_SHOT', 1.03),
      patientPoss: d('SWEEP_PATIENT_POSS', 1.05),
      patientChance: d('SWEEP_PATIENT_CHANCE', 0.96),
      deepPoss: d('SWEEP_DEEP_POSS', 0.92),
      lowPoss: d('SWEEP_LOW_POSS', 0.86),
      playOutPoss: d('SWEEP_PLAYOUT_POSS', 1.06),
      slowPoss: d('SWEEP_SLOW_POSS', 1.03),
      fastChance: d('SWEEP_FAST_CHANCE', 1.06),
      fastPoss: d('SWEEP_FAST_POSS', 0.97),
      fastPassAcc: d('SWEEP_FAST_PASSACC', 0.99),
      fastStamina: d('SWEEP_FAST_STAMINA', 1.02),
      workBallShotQ: d('SWEEP_WORKBALL_SHOTQ', 1.10),
      pbSlope: d('SWEEP_PB_SLOPE', 4.2),
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
  // Screens RANK candidates (half N, bands only); ONLY a full-precision
  // run on BOTH pools accepts one. R2's matrix row is invisible to the
  // bands-only screen, so it gets its own half-N matrix screen.
  int screen(SweepCandidate c) {
    c.install();
    final rows = scoreBands(precision: 0.5, matrix: false, globals: false);
    _printRows('SCREEN ${c.fingerprint}', rows);
    return _fails(rows);
  }

  int screenMatrix(SweepCandidate c) {
    c.install();
    final rows = scoreBands(precision: 0.5, matrix: true, globals: false);
    _printRows('MATRIX SCREEN ${c.fingerprint}', rows);
    return _fails(rows);
  }

  TuningOverrides.current = TuningOverrides.none;
  var best = const SweepCandidate();
  var bestFails = screen(best);
  // ignore: avoid_print
  print('R0 baseline screen: $bestFails fails');

  // R1: the `fast` single (45.3% suite at shipped, band 46-54).
  for (final v in [1.06, 1.07]) {
    final c = SweepCandidate(fastChance: v);
    final f = screen(c);
    if (f < bestFails) {
      bestFails = f;
      best = c;
    }
    // ignore: avoid_print
    print('R1 fastChance=$v -> $f (best $bestFails)');
  }

  // R2: the matrix worst combo (61.0% suite, band <=60). Screened WITH
  // the matrix at half N; possession trims on top of the accepted R1.
  for (final c in [
    SweepCandidate(fastChance: best.fastChance, playOutPoss: 1.05),
    SweepCandidate(fastChance: best.fastChance, slowPoss: 1.02),
  ]) {
    final f = screenMatrix(c);
    if (f < bestFails) {
      bestFails = f;
      best = c;
    }
    // ignore: avoid_print
    print(
      'R2 po=${c.playOutPoss} slow=${c.slowPoss} -> $f (best $bestFails)',
    );
  }

  // R3: the allDefence goals floor (2.38 suite, band >=2.4).
  for (final v in [1.09, 1.10]) {
    final c = SweepCandidate(
      fastChance: best.fastChance,
      playOutPoss: best.playOutPoss,
      slowPoss: best.slowPoss,
      workBallShotQ: v,
    );
    final f = screen(c);
    if (f < bestFails) {
      bestFails = f;
      best = c;
    }
    // ignore: avoid_print
    print('R3 workBallShotQ=$v -> $f (best $bestFails)');
  }

  // R4: the gegenpress late bill (1.118 suite, >=1.15 required).
  for (final v in [0.60, 0.65]) {
    final c = SweepCandidate(
      fastChance: best.fastChance,
      playOutPoss: best.playOutPoss,
      slowPoss: best.slowPoss,
      workBallShotQ: best.workBallShotQ,
      staminaDamp: v,
    );
    final f = screen(c);
    if (f < bestFails) {
      bestFails = f;
      best = c;
    }
    // ignore: avoid_print
    print('R4 staminaDamp=$v -> $f (best $bestFails)');
  }

  // R5 fallback: hpStamina, only if R4 left the bill red.
  if (_fails(scoreBands(precision: 0.5, matrix: false, globals: false)) >
      0) {
    for (final v in [1.32]) {
      final c = SweepCandidate(
        fastChance: best.fastChance,
        playOutPoss: best.playOutPoss,
        slowPoss: best.slowPoss,
        workBallShotQ: best.workBallShotQ,
        staminaDamp: best.staminaDamp,
        hpStamina: v,
      );
      final f = screen(c);
      if (f < bestFails) {
        bestFails = f;
        best = c;
      }
      // ignore: avoid_print
      print('R5 hpStamina=$v -> $f (best $bestFails)');
    }
  }

  // ignore: avoid_print
  print('SEARCH WINNER: ${best.fingerprint}');
  best.install();
  final rows = scoreBands();
  _printRows('WINNER VALIDATION (full precision)', rows);
  expect(_fails(rows), 0, reason: 'search winner left bands red');
}
