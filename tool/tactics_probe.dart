/// Working probe (not part of the shipped tooling yet): measures how
/// each tuning knob moves the failing bands, ALWAYS departing from the
/// SHIPPED constants — a candidate sets ONLY the knobs it names, every
/// other value stays shipped. This fixes the confound that broke the
/// committed search (SweepCandidate defaults carried attempt-3 values).
///
/// Usage:
///   flutter test tool/tactics_probe.dart --dart-define=PROBE_SPECS="cost=0.85;above=0.8|cost=0.78"
///   (specs separated by |, knobs by ;)
///   flutter test tool/tactics_probe.dart            # baseline only
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/base_stats_generator.dart';
import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/match_report.dart';
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

const _suiteSeeds = bool.fromEnvironment(
  'PROBE_SEEDS_SUITE',
  defaultValue: false,
);

int _seedBase(String pool) {
  if (!_suiteSeeds) {
    const order = [
      'singles',
      'stacks',
      'gegenpress',
      'parkTheBus',
      'corners',
      'parkShare',
    ];
    return 700000 + order.indexOf(pool) * 1000;
  }
  const suite = {
    'singles': 21000,
    'stacks': 23000,
    'gegenpress': 43000,
    'parkTheBus': 46000,
    'corners': 48000,
    'parkShare': 47000,
  };
  return suite[pool]!;
}

class _Batch {
  const _Batch(this.matches, this.homeWins, this.draws, this.goals);
  final int matches;
  final int homeWins;
  final int draws;
  final int goals;
  double get homeWinRate => homeWins / matches;
  double get drawRate => draws / matches;
  double get avgGoals => goals / matches;
}

_Batch _run(int matches, int seedBase, {TeamTactics homeTactics = const TeamTactics()}) {
  var hw = 0, d = 0, goals = 0;
  for (var m = 0; m < matches; m++) {
    final engine = _engine(seedBase + m, homeTactics: homeTactics);
    engine.simulateToEnd();
    final s = engine.state;
    if (s.scoreHome > s.scoreAway) {
      hw++;
    } else if (s.scoreHome == s.scoreAway) {
      d++;
    }
    goals += s.scoreHome + s.scoreAway;
  }
  return _Batch(matches, hw, d, goals);
}

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

const _singles = <String, TeamTactics>{
  'playOut': TeamTactics(inPossession: InPossessionTactics(buildUp: BuildUpStyle.playOut)),
  'longBall': TeamTactics(inPossession: InPossessionTactics(buildUp: BuildUpStyle.longBall)),
  'slow': TeamTactics(inPossession: InPossessionTactics(tempo: AttackTempo.slow)),
  'fast': TeamTactics(inPossession: InPossessionTactics(tempo: AttackTempo.fast)),
  'narrow': TeamTactics(inPossession: InPossessionTactics(width: AttackWidth.narrow)),
  'wide': TeamTactics(inPossession: InPossessionTactics(width: AttackWidth.wide)),
  'workBall': TeamTactics(inPossession: InPossessionTactics(finalThird: FinalThirdApproach.workBallIntoBox)),
  'earlyCrosses': TeamTactics(inPossession: InPossessionTactics(finalThird: FinalThirdApproach.earlyCrosses)),
  'shootOnSight': TeamTactics(inPossession: InPossessionTactics(finalThird: FinalThirdApproach.shootOnSight)),
  'deep': TeamTactics(outOfPossession: OutOfPossessionTactics(defensiveLine: DefensiveLine.deep)),
  'highLine': TeamTactics(outOfPossession: OutOfPossessionTactics(defensiveLine: DefensiveLine.high)),
  'lowPress': TeamTactics(outOfPossession: OutOfPossessionTactics(pressing: PressingIntensity.low)),
  'highPress': TeamTactics(outOfPossession: OutOfPossessionTactics(pressing: PressingIntensity.high)),
  'clean': TeamTactics(outOfPossession: OutOfPossessionTactics(tackling: TacklingAggression.clean)),
  'aggressive': TeamTactics(outOfPossession: OutOfPossessionTactics(tackling: TacklingAggression.aggressive)),
  'trap': TeamTactics(outOfPossession: OutOfPossessionTactics(offsideTrap: true)),
  'retreat': TeamTactics(transitions: TransitionTactics(counterPress: CounterPress.retreat)),
  'immediate': TeamTactics(transitions: TransitionTactics(counterPress: CounterPress.immediate)),
  'patient': TeamTactics(transitions: TransitionTactics(attackOnRecovery: AttackOnRecovery.patient)),
  'fastCounter': TeamTactics(transitions: TransitionTactics(attackOnRecovery: AttackOnRecovery.fast)),
  'restConservative': TeamTactics(transitions: TransitionTactics(restDefence: RestDefence.conservative)),
  'restAggressive': TeamTactics(transitions: TransitionTactics(restDefence: RestDefence.aggressive)),
};

/// Installs SHIPPED + only the named knobs.
void _install(Map<String, double> knobs) {
  TacticModifiers mod(
    double possession,
    double chance,
    double stamina,
    double defence,
  ) => TacticModifiers(
    possession: possession,
    chance: chance,
    stamina: stamina,
    defence: defence,
  );

  final instructions = <InstructionOption, TacticModifiers>{};
  void override(InstructionOption o, TacticModifiers m) => instructions[o] = m;

  if (knobs.containsKey('hpStamina') ||
      knobs.containsKey('hpDefence') ||
      knobs.containsKey('hpChance')) {
    override(
      PressingIntensity.high,
      mod(
        1.0,
        knobs['hpChance'] ?? 1.04,
        knobs['hpStamina'] ?? 1.30,
        knobs['hpDefence'] ?? 1.28,
      ),
    );
  }
  if (knobs.containsKey('fcPoss') ||
      knobs.containsKey('fcChance') ||
      knobs.containsKey('fcShot')) {
    override(
      AttackOnRecovery.fast,
      TacticModifiers(
        possession: knobs['fcPoss'] ?? 0.85,
        chance: knobs['fcChance'] ?? 1.10,
        shotQuality: knobs['fcShot'] ?? 1.03,
      ),
    );
  }
  if (knobs.containsKey('deepPoss')) {
    override(
      DefensiveLine.deep,
      TacticModifiers(defence: 1.05, possession: knobs['deepPoss']!),
    );
  }
  if (knobs.containsKey('lowPoss')) {
    override(
      PressingIntensity.low,
      TacticModifiers(
        defence: 1.02,
        stamina: 0.88,
        possession: knobs['lowPoss']!,
      ),
    );
  }
  if (knobs.containsKey('playOutPoss')) {
    override(
      BuildUpStyle.playOut,
      TacticModifiers(
        possession: knobs['playOutPoss']!,
        passAccuracy: 1.05,
        chance: 0.94,
      ),
    );
  }
  if (knobs.containsKey('slowPoss')) {
    override(
      AttackTempo.slow,
      TacticModifiers(
        possession: knobs['slowPoss']!,
        chance: 0.95,
        stamina: 0.94,
      ),
    );
  }
  if (knobs.containsKey('patientPoss')) {
    override(
      AttackOnRecovery.patient,
      TacticModifiers(possession: knobs['patientPoss']!, chance: 0.94),
    );
  }

  TuningOverrides.current = TuningOverrides.withValues(
    instructions: instructions,
    compose: ComposeRule(
      costStackDamp: knobs['cost'] ?? 0.70,
      staminaStackDamp: knobs['staminaDamp'] ?? 0.55,
      possessionStackDampAbove: knobs['above'] ?? 1.0,
      possessionStackDampBelow: knobs['below'] ?? 1.0,
    ),
    pressBillSlope: knobs['pbSlope'] ?? 2.0,
  );
}

void main() {
  test('probe', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const n = 800;
    final specsRaw = const String.fromEnvironment('PROBE_SPECS');
    final specs = <Map<String, double>>[
      if (specsRaw.isEmpty) {} else ...specsRaw.split('|').map((s) {
        final knobs = <String, double>{};
        for (final kv in s.split(';')) {
          if (kv.trim().isEmpty) continue;
          final i = kv.indexOf('=');
          knobs[kv.substring(0, i)] = double.parse(kv.substring(i + 1));
        }
        return knobs;
      }),
    ];

    try {
      for (final knobs in specs) {
        _install(knobs);
        final label = knobs.isEmpty
            ? 'SHIPPED'
            : knobs.entries.map((e) => '${e.key}=${e.value}').join(' ');
        // ignore: avoid_print
        print('=== PROBE $label ===');

        final sw = Stopwatch()..start();
        final sb = StringBuffer();
        void w(String name, double v) =>
            sb.writeln('  ${name.padRight(16)} ${(v * 100).toStringAsFixed(1)}');

        for (final e in _singles.entries) {
          w(e.key, _run(n, _seedBase('singles'), homeTactics: e.value).homeWinRate);
        }
        void stack(String name, TeamTactics tac) {
          final b = _run(n, _seedBase('stacks'), homeTactics: tac);
          sb.writeln(
            '  ${name.padRight(16)} ${(b.homeWinRate * 100).toStringAsFixed(1)}'
            '  G=${b.avgGoals.toStringAsFixed(2)}',
          );
        }

        stack('maxPossession', _maxPossession());
        stack('maxDirect', _maxDirect());
        w('gegenpress', _run(n, _seedBase('gegenpress'), homeTactics: _gegenpress()).homeWinRate);
        w('parkTheBus', _run(n, _seedBase('parkTheBus'), homeTactics: _parkTheBus()).homeWinRate);
        for (final (name, tac) in [
          ('allAttack', _allAttack()),
          ('allDefence', _allDefence()),
        ]) {
          final b = _run(n, _seedBase('corners'), homeTactics: tac);
          sb.writeln(
            '  ${name.padRight(16)} ${(b.homeWinRate * 100).toStringAsFixed(1)}'
            '  G=${b.avgGoals.toStringAsFixed(2)}'
            '  D=${(b.drawRate * 100).toStringAsFixed(1)}',
          );
        }
        final globals = _run(n, _seedBase('corners') + 500);
        sb.writeln(
          '  ${'globals'.padRight(16)} W=${(globals.homeWinRate * 100).toStringAsFixed(1)}'
          '  G=${globals.avgGoals.toStringAsFixed(2)}'
          '  D=${(globals.drawRate * 100).toStringAsFixed(1)}',
        );
        final parkShare = _possessionShare(
          300,
          _seedBase('parkShare'),
          _parkTheBus(),
        );
        sb.writeln('  parkShare        ${parkShare.toStringAsFixed(1)}');
        // ignore: avoid_print
        print(sb.toString().trimRight());
        // ignore: avoid_print
        print('  [${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s]');
      }
    } finally {
      TuningOverrides.current = TuningOverrides.none;
    }
  });
}
