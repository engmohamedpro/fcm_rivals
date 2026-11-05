// Metric-snapshot regression harness (review 2026-11-04_tests).
//
// Locks the engine's full measured profile to a committed snapshot with
// per-metric tolerances, so any engine change that moves a metric beyond
// its tolerance fails CI instead of silently drifting.
//
// Regeneration (after a DELIBERATE rebalance, not to make a failing run
// pass):
//   REGEN_SNAPSHOT=1 flutter test test/features/match/engine_snapshot_test.dart
// then commit the updated test/features/match/engine_snapshot.json.
//
// The snapshot is generated from a fixed seed set (seeds 0..999, even
// strength 20M vs 20M) — deterministic given the engine version.
import 'dart:convert';
import 'dart:io';

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

List<MatchPlayer> _team(int base, int value) {
  final gen = const BaseStatsGenerator();
  return [
    for (var i = 0; i < 11; i++)
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

MatchEngine _engine(int seed) => MatchEngine(
  seed: seed,
  home: MatchTeamInput(
    teamId: 1,
    teamName: 'Home',
    formationCode: '4-4-2',
    tactics: const TeamTactics(),
    mentality: Mentality.balanced,
    starters: _team(100, 20_000_000),
    bench: const [],
    aiControlled: true,
  ),
  away: MatchTeamInput(
    teamId: 2,
    teamName: 'Away',
    formationCode: '4-3-3',
    tactics: const TeamTactics(),
    mentality: Mentality.balanced,
    starters: _team(300, 20_000_000),
    bench: const [],
    aiControlled: true,
  ),
);

/// Every metric the harness locks: [key, tolerance, value].
Map<String, double> _measure() {
  const n = 1000;
  var goals = 0,
      shots = 0,
      onTarget = 0,
      bigChances = 0,
      bigChanceGoals = 0,
      corners = 0,
      offsides = 0,
      fkShots = 0,
      yellows = 0,
      reds = 0,
      penalties = 0,
      penaltyGoals = 0,
      matches6 = 0;
  var xg = 0.0;
  var possSum = 0.0;
  var possN = 0;
  final buckets = List<int>.filled(6, 0);
  for (var m = 0; m < n; m++) {
    final eng = _engine(m);
    final events = eng.simulateToEnd();
    goals += eng.state.scoreHome + eng.state.scoreAway;
    if (eng.state.scoreHome + eng.state.scoreAway >= 6) matches6++;
    final stats = computeStats(events, homeTeamId: 1, awayTeamId: 2);
    if (stats.home.possessionMinutes + stats.away.possessionMinutes > 0) {
      possSum += stats.possessionPercent(stats.home);
      possN++;
    }
    for (final e in events) {
      switch (e.type) {
        case MatchEventType.shot:
          shots++;
          if (e.shotOutcome == ShotOutcome.goal ||
              e.shotOutcome == ShotOutcome.saved) {
            onTarget++;
          }
          if (e.quality == ChanceQuality.freeKick) fkShots++;
          if (e.quality == ChanceQuality.bigChance ||
              e.quality == ChanceQuality.penalty) {
            bigChances++;
            if (e.shotOutcome == ShotOutcome.goal) bigChanceGoals++;
          }
          xg += e.xg ?? 0;
          break;
        case MatchEventType.corner:
          corners++;
          break;
        case MatchEventType.offside:
          offsides++;
          break;
        case MatchEventType.card:
          if (e.metadata['card'] == 'yellow') {
            yellows++;
          } else {
            reds++;
          }
          break;
        case MatchEventType.penaltyAwarded:
          penalties++;
          break;
        case MatchEventType.goal:
          final b = e.minute <= 15
              ? 0
              : e.minute <= 30
              ? 1
              : e.minute <= 45
              ? 2
              : e.minute <= 60
              ? 3
              : e.minute <= 75
              ? 4
              : 5;
          buckets[b]++;
          if (e.metadata.isNotEmpty) {} // no-op: goal events carry xg
          break;
        default:
          break;
      }
    }
    penaltyGoals += events
        .where(
          (e) =>
              e.type == MatchEventType.shot &&
              e.quality == ChanceQuality.penalty &&
              e.shotOutcome == ShotOutcome.goal,
        )
        .length;
  }
  final totalGoals = buckets.fold<int>(0, (a, b) => a + b);
  return {
    'goalsPerMatch': goals / n,
    'share6Plus': matches6 / n,
    'shotsPerTeam': shots / (2 * n),
    'sotShare': onTarget / shots,
    'conversion': goals / shots,
    'xgPerShot': xg / shots,
    'bigChancesPerTeam': bigChances / (2 * n),
    'bigChanceConversion': bigChanceGoals / bigChances,
    'cornersPerMatch': corners / n,
    'offsidesPerMatch': offsides / n,
    'fkShotsPerTeam': fkShots / (2 * n),
    'yellowsPerMatch': yellows / n,
    'redsPerMatch': reds / n,
    'penaltyAwardsPerMatch': penalties / n,
    'penaltyConversion': penaltyGoals / penalties,
    'goalShare1to15': buckets[0] / totalGoals,
    'goalShare16to30': buckets[1] / totalGoals,
    'goalShare31to45': buckets[2] / totalGoals,
    'goalShare46to60': buckets[3] / totalGoals,
    'goalShare61to75': buckets[4] / totalGoals,
    'goalShare76to90': buckets[5] / totalGoals,
    'avgPossessionHome': possSum / possN,
  };
}

void main() {
  // Tolerances: half the calibration band width where one exists —
  // tight enough to catch drift, loose enough for the seeded sample's
  // own noise at n=1000.
  const tolerances = <String, double>{
    'goalsPerMatch': 0.10,
    'share6Plus': 0.010,
    'shotsPerTeam': 0.40,
    'sotShare': 0.015,
    'conversion': 0.010,
    'xgPerShot': 0.006,
    'bigChancesPerTeam': 0.15,
    'bigChanceConversion': 0.025,
    'cornersPerMatch': 0.40,
    'offsidesPerMatch': 0.25,
    'fkShotsPerTeam': 0.10,
    'yellowsPerMatch': 0.20,
    'redsPerMatch': 0.03,
    'penaltyAwardsPerMatch': 0.05,
    'penaltyConversion': 0.05,
    'goalShare1to15': 0.015,
    'goalShare16to30': 0.015,
    'goalShare31to45': 0.015,
    'goalShare46to60': 0.015,
    'goalShare61to75': 0.015,
    'goalShare76to90': 0.015,
    'avgPossessionHome': 1.0,
  };

  test('engine profile matches the committed snapshot', () {
    final measured = _measure();
    final regen = Platform.environment['REGEN_SNAPSHOT'] == '1';
    final file = File(
      'test/features/match/engine_snapshot.json',
    );
    final encoded = const JsonEncoder.withIndent('  ').convert(
      measured.map((k, v) => MapEntry(k, v.toStringAsFixed(4))),
    );

    if (regen) {
      file.writeAsStringSync(encoded);
      fail('Snapshot regenerated — commit engine_snapshot.json.');
    }

    expect(
      file.existsSync(),
      isTrue,
      reason: 'engine_snapshot.json missing — regenerate it (see header).',
    );
    final snapshot = jsonDecode(file.readAsStringSync())
        as Map<String, dynamic>;

    final failures = <String>[];
    for (final entry in tolerances.entries) {
      final key = entry.key;
      final tol = entry.value;
      final raw = snapshot[key];
      final expected = raw is num
          ? raw.toDouble()
          : raw is String
          ? double.tryParse(raw)
          : null;
      final actual = measured[key];
      if (expected == null || actual == null) {
        failures.add('$key: missing or malformed in snapshot');
        continue;
      }
      if ((expected - actual).abs() > tol) {
        failures.add(
          '$key: snapshot $expected, measured '
          '${actual.toStringAsFixed(4)} (tolerance $tol)',
        );
      }
    }
    expect(
      failures,
      isEmpty,
      reason:
          'Engine profile drifted beyond tolerance. If the change was '
          'deliberate, regenerate the snapshot (command in the file '
          'header) and commit it with your change.\n'
          '${failures.join('\n')}',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
