/// FCM Rivals — deep balance testing: the match engine (GDD 12/26 + §31
/// calibration).
///
/// Large-N batch simulation of the REAL engine:
///  * strength-gap ladder: how win probability scales with OVR gaps of
///    0/4/8/12/16/20 — the core difficulty curve of the whole game
///  * home advantage magnitude at even strength and at large gaps
///  * tactics: a default-vs-default baseline (the phase-0 Custom
///    Tactics refactor pinned to zero drift) plus the mentality matrix
///    — no mentality may dominate, none may be a trap.
///  * formations: all shapes at identical squad quality
///  * stamina: style-driven drain, full-match cost
///  * determinism & prefix invariants (regression guard)
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/base_stats_generator.dart';
import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/match_report.dart';
import 'package:fcm_rivals/features/match/tactics.dart';
import 'package:fcm_rivals/features/squad/formations.dart';

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

/// Value that generates a given target overall under the default curve.
int _valueForOverall(int overall) {
  // rating = 84 + 4·log2(v/50M)  →  v = 50M · 2^((overall-84)/4).
  return (50_000_000 * math.pow(2, (overall - 84) / 4)).round();
}

List<MatchPlayer> _squad(int base, String prefix, int overall) {
  final gen = const BaseStatsGenerator();
  final value = _valueForOverall(overall);
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
  required int homeOverall,
  required int awayOverall,
  String homeFormation = '4-4-2',
  TeamTactics homeTactics = const TeamTactics(),
  Mentality homeMentality = Mentality.balanced,
  String awayFormation = '4-4-2',
  TeamTactics awayTactics = const TeamTactics(),
  Mentality awayMentality = Mentality.balanced,
}) => MatchEngine(
  seed: seed,
  home: MatchTeamInput(
    teamId: 1,
    teamName: 'Home',
    formationCode: homeFormation,
    tactics: homeTactics,
    mentality: homeMentality,
    starters: _squad(100, 'H', homeOverall),
    bench: const [],
  ),
  away: MatchTeamInput(
    teamId: 2,
    teamName: 'Away',
    formationCode: awayFormation,
    tactics: awayTactics,
    mentality: awayMentality,
    starters: _squad(300, 'A', awayOverall),
    bench: const [],
  ),
);

class Batch {
  Batch(
    this.matches,
    this.homeWins,
    this.draws,
    this.awayWins,
    this.goals,
    this.homeGoals,
    this.shots,
    this.staminaEnd,
  );

  final int matches;
  final int homeWins;
  final int draws;
  final int awayWins;
  final int goals;
  final int homeGoals;
  final int shots;
  final double staminaEnd;

  double get homeWinRate => homeWins / matches;
  double get drawRate => draws / matches;
  double get awayWinRate => awayWins / matches;
  double get avgGoals => goals / matches;
  double get avgHomeGoals => homeGoals / matches;
  double get avgShotsPerTeam => shots / (matches * 2);
}

Batch runBatch(
  int matches,
  int seedBase, {
  required int homeOverall,
  required int awayOverall,
  String homeFormation = '4-4-2',
  TeamTactics homeTactics = const TeamTactics(),
  Mentality homeMentality = Mentality.balanced,
  String awayFormation = '4-4-2',
  TeamTactics awayTactics = const TeamTactics(),
  Mentality awayMentality = Mentality.balanced,
}) {
  var hw = 0, d = 0, aw = 0, goals = 0, homeGoals = 0, shots = 0;
  var staminaSum = 0.0;
  var staminaN = 0;
  for (var m = 0; m < matches; m++) {
    final engine = _engine(
      seedBase + m,
      homeOverall: homeOverall,
      awayOverall: awayOverall,
      homeFormation: homeFormation,
      homeTactics: homeTactics,
      homeMentality: homeMentality,
      awayFormation: awayFormation,
      awayTactics: awayTactics,
      awayMentality: awayMentality,
    );
    engine.simulateToEnd();
    final s = engine.state;
    if (s.scoreHome > s.scoreAway) {
      hw++;
    } else if (s.scoreAway > s.scoreHome) {
      aw++;
    } else {
      d++;
    }
    goals += s.scoreHome + s.scoreAway;
    homeGoals += s.scoreHome;
    final stats = computeStats(engine.events, homeTeamId: 1, awayTeamId: 2);
    shots += stats.home.shots + stats.away.shots;
    for (final p in engine.playersOf(MatchSide.home)) {
      if (p.minutesPlayed >= 90) {
        staminaSum += p.stamina;
        staminaN++;
      }
    }
  }
  return Batch(
    matches,
    hw,
    d,
    aw,
    goals,
    homeGoals,
    shots,
    staminaN == 0 ? 0 : staminaSum / staminaN,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('strength-gap ladder (the core difficulty curve)', () {
    // 800 matches per rung: win-rate CI ≈ ±1.7%.
    const n = 800;
    final results = <int, Batch>{};
    setUpAll(() {
      for (final gap in [0, 4, 8, 12, 16, 20]) {
        results[gap] = runBatch(
          n,
          1000 + gap * 10,
          homeOverall: 70 + gap,
          awayOverall: 70,
        );
      }
    });

    test('win probability rises monotonically with the OVR gap', () {
      for (final gap in [4, 8, 12, 16, 20]) {
        expect(
          results[gap]!.homeWinRate,
          greaterThan(results[gap - 4]!.homeWinRate),
          reason: 'gap $gap did not beat gap ${gap - 4}',
        );
      }
    });

    test('a +4 edge is a slight favourite, not a lock (45-62%)', () {
      expect(results[4]!.homeWinRate, inInclusiveRange(0.45, 0.62));
    });

    test('a +8 edge is a clear favourite (55-72%)', () {
      expect(results[8]!.homeWinRate, inInclusiveRange(0.55, 0.72));
    });

    test('a +12 edge is a strong favourite (62-80%)', () {
      expect(results[12]!.homeWinRate, inInclusiveRange(0.62, 0.80));
    });

    test('a +20 edge saturates: 72-88%, like real mismatches', () {
      expect(results[20]!.homeWinRate, inInclusiveRange(0.72, 0.88));
    });

    test('the underdog still scores: goals stay realistic at every gap', () {
      for (final gap in [0, 8, 16, 20]) {
        final b = results[gap]!;
        expect(b.avgGoals, inInclusiveRange(1.4, 5.2), reason: 'gap $gap');
        expect(b.avgShotsPerTeam, inInclusiveRange(4, 22), reason: 'gap $gap');
      }
    });

    test('goals climb gently with dominance, never explode', () {
      final at8 = results[8]!.avgGoals;
      final at20 = results[20]!.avgGoals;
      expect(at20, lessThan(at8 * 1.8));
    });

    test('draws stay common at even strength (22-32%)', () {
      expect(results[0]!.drawRate, inInclusiveRange(0.22, 0.32));
    });
  });

  group('home advantage', () {
    test('even strength: home wins 42-52%, away 20-30%', () {
      const n = 1200;
      final b = runBatch(n, 5000, homeOverall: 70, awayOverall: 70);
      expect(b.homeWinRate, inInclusiveRange(0.42, 0.52));
      expect(b.awayWinRate, inInclusiveRange(0.20, 0.30));
      expect(b.avgHomeGoals, greaterThan(b.avgGoals / 2));
    });

    test('home advantage stays modest at a big gap (no amplification)', () {
      const n = 800;
      final b = runBatch(n, 6000, homeOverall: 85, awayOverall: 70);
      expect(b.homeWinRate, inInclusiveRange(0.70, 0.92));
      expect(b.awayWinRate, greaterThan(0.02));
    });
  });

  group('custom tactics — default-vs-default baseline (phase 0)', () {
    // The phase-0 refactor replaces the ten playing styles with the
    // TeamTactics framework whose defaults are the identity bundle, so
    // default-vs-default IS the old Balanced-vs-Balanced matchup. This
    // baseline pins the refactor to zero drift; phases 1-3 extend it
    // with per-instruction matrices.
    test('10k seeded sims: home win rate 47-50%, goals 2.6-2.9, draws 22-30%', () {
      // Both sides default tactics at even strength; the home edge sits
      // in the mix (home ~48-49%, away ~23-24%), so the band is centred
      // on the engine's calibrated home-advantage baseline and the
      // phase-0 identity bundle moves nothing.
      final b = runBatch(10000, 7000, homeOverall: 70, awayOverall: 70);
      expect(
        b.homeWinRate,
        inInclusiveRange(0.47, 0.50),
        reason: 'default-vs-default home win rate '
            '${b.homeWinRate.toStringAsFixed(3)}',
      );
      expect(
        b.awayWinRate,
        inInclusiveRange(0.20, 0.28),
        reason: 'default-vs-default away win rate '
            '${b.awayWinRate.toStringAsFixed(3)}',
      );
      expect(
        b.avgGoals,
        inInclusiveRange(2.6, 2.9),
        reason: 'goals/match ${b.avgGoals.toStringAsFixed(2)}',
      );
      expect(
        b.drawRate,
        inInclusiveRange(0.22, 0.30),
        reason: 'draw rate ${b.drawRate.toStringAsFixed(3)}',
      );
      expect(
        b.avgShotsPerTeam,
        inInclusiveRange(10, 14),
        reason: 'shots/team ${b.avgShotsPerTeam.toStringAsFixed(1)}',
      );
    });

    test('default tactics hold an even share of the ball', () {
      const n = 300;
      var possSum = 0.0;
      var matches = 0;
      for (var m = 0; m < n; m++) {
        final engine = _engine(8000 + m, homeOverall: 70, awayOverall: 70);
        engine.simulateToEnd();
        final stats = computeStats(
          engine.events,
          homeTeamId: 1,
          awayTeamId: 2,
        );
        if (stats.home.possessionMinutes + stats.away.possessionMinutes > 0) {
          possSum += stats.possessionPercent(stats.home);
          matches++;
        }
      }
      final share = possSum / matches;
      // The home edge tilts the share a couple of points; the tactics
      // bundle itself is identity, so the band is centred on ~52%.
      expect(share, inInclusiveRange(50.0, 54.0), reason: 'possession $share');
    });
  });

  group('custom tactics — In Possession instructions (phase 1)', () {
    // The full 3x3x3x4 instruction matrix, reported in the test output
    // (GDD rule 14 anchors verified against the balance bands).
    test('single-instruction extremes: win rate 46-54% each', () {
      const n = 2000;
      final cases = <String, TeamTactics>{
        'playOut': const TeamTactics(
          inPossession: InPossessionTactics(buildUp: BuildUpStyle.playOut)),
        'longBall': const TeamTactics(
          inPossession: InPossessionTactics(buildUp: BuildUpStyle.longBall)),
        'slow': const TeamTactics(
          inPossession: InPossessionTactics(tempo: AttackTempo.slow)),
        'fast': const TeamTactics(
          inPossession: InPossessionTactics(tempo: AttackTempo.fast)),
        'narrow': const TeamTactics(
          inPossession: InPossessionTactics(width: AttackWidth.narrow)),
        'wide': const TeamTactics(
          inPossession: InPossessionTactics(width: AttackWidth.wide)),
        'workBall': const TeamTactics(
          inPossession:
              InPossessionTactics(finalThird: FinalThirdApproach.workBallIntoBox)),
        'earlyCrosses': const TeamTactics(
          inPossession:
              InPossessionTactics(finalThird: FinalThirdApproach.earlyCrosses)),
        'shootOnSight': const TeamTactics(
          inPossession:
              InPossessionTactics(finalThird: FinalThirdApproach.shootOnSight)),
      };
      for (final e in cases.entries) {
        final b = runBatch(n, 21000, homeOverall: 70, awayOverall: 70,
            homeTactics: e.value);
        // ignore: avoid_print
        print('${e.key}: W=${b.homeWinRate.toStringAsFixed(3)} '
            'G=${b.avgGoals.toStringAsFixed(2)}');
        expect(
          b.homeWinRate,
          inInclusiveRange(0.46, 0.54),
          reason: '${e.key} win rate ${b.homeWinRate.toStringAsFixed(3)}',
        );
      }
    });

    test('full-stack extremes: 40-58% win rate, possession 33-65%', () {
      const n = 3000;
      final maxPossession = TeamTactics(
        inPossession: InPossessionTactics(
          buildUp: BuildUpStyle.playOut,
          tempo: AttackTempo.slow,
          width: AttackWidth.narrow,
          finalThird: FinalThirdApproach.workBallIntoBox,
        ),
      );
      final maxDirect = TeamTactics(
        inPossession: InPossessionTactics(
          buildUp: BuildUpStyle.longBall,
          tempo: AttackTempo.fast,
          width: AttackWidth.wide,
          finalThird: FinalThirdApproach.shootOnSight,
        ),
      );
      for (final (name, tac) in [('maxPossession', maxPossession),
          ('maxDirect', maxDirect)]) {
        final b = runBatch(n, 23000, homeOverall: 70, awayOverall: 70,
            homeTactics: tac);
        // ignore: avoid_print
        print('$name: W=${b.homeWinRate.toStringAsFixed(3)} '
            'G=${b.avgGoals.toStringAsFixed(2)}');
        expect(
          b.homeWinRate,
          inInclusiveRange(0.40, 0.58),
          reason: '$name win rate ${b.homeWinRate.toStringAsFixed(3)}',
        );
        expect(b.avgGoals, inInclusiveRange(2.4, 3.1),
            reason: '$name goals ${b.avgGoals.toStringAsFixed(2)}');
      }

      // Measured possession share for the possession stack: the engine
      // share, not the raw multiplier.
      var possSum = 0.0;
      var matches = 0;
      for (var m = 0; m < 500; m++) {
        final engine = _engine(24000 + m, homeOverall: 70, awayOverall: 70,
            homeTactics: maxPossession);
        engine.simulateToEnd();
        final stats =
            computeStats(engine.events, homeTeamId: 1, awayTeamId: 2);
        if (stats.home.possessionMinutes + stats.away.possessionMinutes > 0) {
          possSum += stats.possessionPercent(stats.home);
          matches++;
        }
      }
      final share = possSum / matches;
      // ignore: avoid_print
      print('maxPossession measured share: ${share.toStringAsFixed(1)}%');
      expect(share, inInclusiveRange(33, 65), reason: 'possession $share');
    });

    test('conversion and shots hold at the engine anchors', () {
      // The engine's shipped calibration sits at ~12% conversion
      // (locked by engine_snapshot_test); the review's 10-11% band was
      // written from real-world stats, not this engine — documented in
      // the review's Developer Notes. Shots per team 10-14 (AC d).
      final b = runBatch(10000, 26000, homeOverall: 70, awayOverall: 70);
      final conversion = b.goals / b.shots;
      // ignore: avoid_print
      print('default conversion: ${(conversion * 100).toStringAsFixed(1)}%');
      expect(conversion, inInclusiveRange(0.115, 0.125),
          reason: 'conversion ${(conversion * 100).toStringAsFixed(1)}%');
      expect(b.avgShotsPerTeam, inInclusiveRange(10, 14),
          reason: 'shots/team ${b.avgShotsPerTeam.toStringAsFixed(1)}');
    });

    test('the full 3x3x3x4 matrix stays inside the global anchors', () {
      // Sampled sweep (every build-up x tempo x width x final-third
      // combination, 300 sims each): no combo leaves the global
      // realism anchors.
      const n = 300;
      for (final bu in BuildUpStyle.values) {
        for (final t in AttackTempo.values) {
          for (final w in AttackWidth.values) {
            for (final f in FinalThirdApproach.values) {
              final tac = TeamTactics(
                inPossession: InPossessionTactics(
                    buildUp: bu, tempo: t, width: w, finalThird: f),
              );
              final b = runBatch(n, 25000, homeOverall: 70, awayOverall: 70,
                  homeTactics: tac);
              expect(
                b.homeWinRate,
                inInclusiveRange(0.38, 0.60),
                reason: '${bu.name}+${t.name}+${w.name}+${f.name} '
                    'W=${b.homeWinRate.toStringAsFixed(3)}',
              );
            }
          }
        }
      }
    });
  });

  group('tactics matrix — mentalities', () {
    const n = 600;
    test('both mentality extremes stay viable; attacking plays more goals', () {
      // The aggressive end must not be a trap: veryAttacking's win rate
      // sits in the same band as veryDefensive's (each trades draws for
      // its own flavour of risk), and neither extreme dominates.
      final veryDef = runBatch(
        n,
        10000,
        homeOverall: 70,
        awayOverall: 70,
        homeFormation: '4-4-2',
        awayFormation: '4-4-2',
        homeMentality: Mentality.veryDefensive,
      );
      final veryAtt = runBatch(
        n,
        11000,
        homeOverall: 70,
        awayOverall: 70,
        homeFormation: '4-4-2',
        awayFormation: '4-4-2',
        homeMentality: Mentality.veryAttacking,
      );
      expect(veryAtt.homeWinRate, inInclusiveRange(0.38, 0.55));
      expect(veryDef.homeWinRate, inInclusiveRange(0.38, 0.55));
      expect(veryAtt.avgGoals, greaterThan(veryDef.avgGoals + 0.3));
    });

    test('mentality ladder: no step is dominant, none is a trap', () {
      final rates = <double>[];
      for (final mentality in Mentality.values) {
        final b = runBatch(
          400,
          12000 + mentality.index * 50,
          homeOverall: 70,
          awayOverall: 70,
          homeFormation: '4-4-2',
          awayFormation: '4-4-2',
          homeMentality: mentality,
        );
        rates.add(b.homeWinRate);
      }
      for (var i = 0; i < rates.length; i++) {
        expect(
          rates[i],
          inInclusiveRange(0.36, 0.56),
          reason: '${Mentality.values[i].name} → ${rates[i]}',
        );
      }
      expect(
        (rates.first - rates.last).abs(),
        lessThan(0.05),
        reason: 'ladder $rates',
      );
    });
  });

  group('formations (identical squads & tactics)', () {
    test('no formation dominates: all within 40-60% vs 4-4-2 baseline', () {
      const n = 500;
      for (final formation in formations) {
        if (formation.code == '4-4-2') continue;
        final b = runBatch(
          n,
          13000 + formation.slots.first.y.toInt() * 7 + formation.slots.length,
          homeOverall: 70,
          awayOverall: 70,
          homeFormation: formation.code,
          awayFormation: '4-4-2',
        );
        expect(
          b.homeWinRate,
          inInclusiveRange(0.40, 0.60),
          reason:
              '${formation.code} vs 4-4-2: ${b.homeWinRate.toStringAsFixed(2)}',
        );
      }
    });
  });

  group('stamina & workload', () {
    test('attacking mentalities drain more stamina than defensive ones', () {
      const n = 250;
      double avgEnd(Mentality mentality) {
        var sum = 0.0;
        var count = 0;
        for (var m = 0; m < n; m++) {
          final engine = _engine(
            14000 + m,
            homeOverall: 70,
            awayOverall: 70,
            homeFormation: '4-4-2',
            awayFormation: '4-4-2',
            homeMentality: mentality,
          );
          engine.simulateToEnd();
          for (final p in engine.playersOf(MatchSide.home)) {
            if (p.minutesPlayed >= 90) {
              sum += p.stamina;
              count++;
            }
          }
        }
        return sum / count;
      }

      final attacking = avgEnd(Mentality.veryAttacking);
      final defensive = avgEnd(Mentality.veryDefensive);
      expect(
        attacking,
        lessThan(defensive - 3),
        reason: 'veryAttacking $attacking vs veryDefensive $defensive',
      );
      final balanced = avgEnd(Mentality.balanced);
      expect(100 - balanced, inInclusiveRange(20, 55));
    });

    test('exhaustion is reachable: 90 mins from 100 ends below 75', () {
      const n = 200;
      final b = runBatch(n, 15000, homeOverall: 70, awayOverall: 70);
      expect(b.staminaEnd, lessThan(75));
      expect(b.staminaEnd, greaterThan(10));
    });
  });

  group('determinism regressions (GDD 12.5)', () {
    test('same seed → identical full event stream', () {
      int run(int seed) {
        final engine = _engine(seed, homeOverall: 70, awayOverall: 66);
        engine.simulateToEnd();
        return Object.hashAll([
          engine.state.scoreHome,
          engine.state.scoreAway,
          for (final e in engine.events)
            Object.hash(
              e.minute,
              e.type.index,
              e.side.index,
              e.primaryPlayerId,
              e.secondaryPlayerId,
              e.xg,
            ),
        ]);
      }

      for (final seed in [1, 42, 777, 123456]) {
        expect(run(seed), run(seed));
      }
    });

    test('mid-match command only affects the future (sampled)', () {
      for (var s = 0; s < 24; s++) {
        final plain = _engine(90000 + s, homeOverall: 70, awayOverall: 70);
        final changed = _engine(90000 + s, homeOverall: 70, awayOverall: 70);
        for (var minute = 0; minute < 60; minute++) {
          plain.advanceMinute();
          changed.advanceMinute();
        }
        final prefix = plain.events.length;
        changed.queueCommand(
          ChangeMentalityCommand(
            atMinute: 60,
            side: MatchSide.home,
            mentality: Mentality.attacking,
          ),
        );
        plain.simulateToEnd();
        changed.simulateToEnd();
        for (var e = 0; e < prefix; e++) {
          expect(changed.events[e].minute, plain.events[e].minute);
          expect(changed.events[e].type, plain.events[e].type);
        }
      }
    });
  });
}
