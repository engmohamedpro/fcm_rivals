/// FCM Rivals — deep balance testing: the match engine (GDD 12/26 + §31
/// calibration).
///
/// Large-N batch simulation of the REAL engine:
///  * strength-gap ladder: how win probability scales with OVR gaps of
///    0/4/8/12/16/20 — the core difficulty curve of the whole game
///  * home advantage magnitude at even strength and at large gaps
///  * tactics matrix: every playing style vs balanced, every mentality
///    vs balanced — no style may dominate, the mentality ladder must not
///    be inverted. (These are the tests that catch the two shipped
///    imbalances: possession styles and the aggressive-mentality trap.)
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
  Position.gk, Position.lb, Position.cb, Position.cb, Position.rb,
  Position.lm, Position.cm, Position.cm, Position.rm,
  Position.st, Position.st,
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
  PlayingStyle homeStyle = PlayingStyle.balanced,
  Mentality homeMentality = Mentality.balanced,
  String awayFormation = '4-4-2',
  PlayingStyle awayStyle = PlayingStyle.balanced,
  Mentality awayMentality = Mentality.balanced,
}) =>
    MatchEngine(
      seed: seed,
      home: MatchTeamInput(
        teamId: 1,
        teamName: 'Home',
        formationCode: homeFormation,
        style: homeStyle,
        mentality: homeMentality,
        starters: _squad(100, 'H', homeOverall),
        bench: const [],
      ),
      away: MatchTeamInput(
        teamId: 2,
        teamName: 'Away',
        formationCode: awayFormation,
        style: awayStyle,
        mentality: awayMentality,
        starters: _squad(300, 'A', awayOverall),
        bench: const [],
      ),
    );

class Batch {
  Batch(this.matches, this.homeWins, this.draws, this.awayWins, this.goals,
      this.homeGoals, this.shots, this.staminaEnd);

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
  PlayingStyle homeStyle = PlayingStyle.balanced,
  Mentality homeMentality = Mentality.balanced,
  String awayFormation = '4-4-2',
  PlayingStyle awayStyle = PlayingStyle.balanced,
  Mentality awayMentality = Mentality.balanced,
}) {
  var hw = 0, d = 0, aw = 0, goals = 0, homeGoals = 0, shots = 0;
  var staminaSum = 0.0;
  var staminaN = 0;
  for (var m = 0; m < matches; m++) {
    final engine = _engine(seedBase + m,
        homeOverall: homeOverall,
        awayOverall: awayOverall,
        homeFormation: homeFormation,
        homeStyle: homeStyle,
        homeMentality: homeMentality,
        awayFormation: awayFormation,
        awayStyle: awayStyle,
        awayMentality: awayMentality);
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
  return Batch(matches, hw, d, aw, goals, homeGoals, shots,
      staminaN == 0 ? 0 : staminaSum / staminaN);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('strength-gap ladder (the core difficulty curve)', () {
    // 800 matches per rung: win-rate CI ≈ ±1.7%.
    const n = 800;
    final results = <int, Batch>{};
    setUpAll(() {
      for (final gap in [0, 4, 8, 12, 16, 20]) {
        results[gap] = runBatch(n, 1000 + gap * 10,
            homeOverall: 70 + gap, awayOverall: 70);
      }
    });

    test('win probability rises monotonically with the OVR gap', () {
      for (final gap in [4, 8, 12, 16, 20]) {
        expect(results[gap]!.homeWinRate,
            greaterThan(results[gap - 4]!.homeWinRate),
            reason: 'gap $gap did not beat gap ${gap - 4}');
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

    test('the underdog still scores: goals stay realistic at every gap',
        () {
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

  group('tactics matrix — styles (identical squads, 4-4-2 both)', () {
    const n = 600;
    test('every style has an effect but none dominates', () {
      final swings = <String, double>{};
      for (final style in PlayingStyle.values) {
        if (style == PlayingStyle.balanced) continue;
        final b = runBatch(n, 7000 + style.index * 100,
            homeOverall: 70,
            awayOverall: 70,
            homeFormation: '4-4-2',
            awayFormation: '4-4-2',
            homeStyle: style);
        swings[style.name] = b.homeWinRate;
        expect(b.homeWinRate, inInclusiveRange(0.35, 0.62),
            reason:
                '${style.name} win rate ${b.homeWinRate.toStringAsFixed(2)}');
      }
      final sorted = swings.values.toList()..sort();
      expect(sorted.last - sorted.first, greaterThan(0.04),
          reason: 'styles look inert: $swings');
    });

    test('possession styles actually hold the ball; direct styles shoot',
        () {
      const n = 300;
      final possessionStats = <String, double>{};
      for (final style in [
        PlayingStyle.tikiTaka,
        PlayingStyle.balanced,
        PlayingStyle.longBall
      ]) {
        var possSum = 0.0;
        var matches = 0;
        for (var m = 0; m < n; m++) {
          final engine = _engine(8000 + m,
              homeOverall: 70,
              awayOverall: 70,
              homeFormation: '4-4-2',
              awayFormation: '4-4-2',
              homeStyle: style);
          engine.simulateToEnd();
          final stats =
              computeStats(engine.events, homeTeamId: 1, awayTeamId: 2);
          if (stats.home.possessionMinutes + stats.away.possessionMinutes > 0) {
            possSum += stats.possessionPercent(stats.home);
            matches++;
          }
        }
        possessionStats[style.name] = possSum / matches;
      }
      expect(possessionStats['tikiTaka']!,
          greaterThan(possessionStats['balanced']!));
      expect(possessionStats['balanced']!,
          greaterThan(possessionStats['longBall']!));
    });
  });

  group('tactics matrix — mentalities', () {
    const n = 600;
    test('both mentality extremes stay viable; attacking plays more goals',
        () {
      // The aggressive end must not be a trap: veryAttacking's win rate
      // sits in the same band as veryDefensive's (each trades draws for
      // its own flavour of risk), and neither extreme dominates.
      final veryDef = runBatch(n, 10000,
          homeOverall: 70,
          awayOverall: 70,
          homeFormation: '4-4-2',
          awayFormation: '4-4-2',
          homeMentality: Mentality.veryDefensive);
      final veryAtt = runBatch(n, 11000,
          homeOverall: 70,
          awayOverall: 70,
          homeFormation: '4-4-2',
          awayFormation: '4-4-2',
          homeMentality: Mentality.veryAttacking);
      expect(veryAtt.homeWinRate, inInclusiveRange(0.38, 0.55));
      expect(veryDef.homeWinRate, inInclusiveRange(0.38, 0.55));
      expect(veryAtt.avgGoals, greaterThan(veryDef.avgGoals + 0.3));
    });

    test('mentality ladder: no step is dominant, none is a trap', () {
      final rates = <double>[];
      for (final mentality in Mentality.values) {
        final b = runBatch(400, 12000 + mentality.index * 50,
            homeOverall: 70,
            awayOverall: 70,
            homeFormation: '4-4-2',
            awayFormation: '4-4-2',
            homeMentality: mentality);
        rates.add(b.homeWinRate);
      }
      for (var i = 0; i < rates.length; i++) {
        expect(rates[i], inInclusiveRange(0.36, 0.56),
            reason: '${Mentality.values[i].name} → ${rates[i]}');
      }
      expect((rates.first - rates.last).abs(), lessThan(0.05),
          reason: 'ladder $rates');
    });
  });

  group('formations (identical squads & tactics)', () {
    test('no formation dominates: all within 40-60% vs 4-4-2 baseline', () {
      const n = 500;
      for (final formation in formations) {
        if (formation.code == '4-4-2') continue;
        final b = runBatch(
            n,
            13000 +
                formation.slots.first.y.toInt() * 7 +
                formation.slots.length,
            homeOverall: 70,
            awayOverall: 70,
            homeFormation: formation.code,
            awayFormation: '4-4-2');
        expect(b.homeWinRate, inInclusiveRange(0.40, 0.60),
            reason:
                '${formation.code} vs 4-4-2: ${b.homeWinRate.toStringAsFixed(2)}');
      }
    });
  });

  group('stamina & style workload', () {
    test('high-press styles drain more stamina than low blocks', () {
      const n = 250;
      double avgEnd(PlayingStyle style) {
        var sum = 0.0;
        var count = 0;
        for (var m = 0; m < n; m++) {
          final engine = _engine(14000 + m,
              homeOverall: 70,
              awayOverall: 70,
              homeFormation: '4-4-2',
              awayFormation: '4-4-2',
              homeStyle: style);
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

      final gegen = avgEnd(PlayingStyle.gegenpressing);
      final lowBlock = avgEnd(PlayingStyle.lowBlock);
      expect(gegen, lessThan(lowBlock - 3),
          reason: 'gegenpressing $gegen vs low block $lowBlock');
      final balanced = avgEnd(PlayingStyle.balanced);
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
            Object.hash(e.minute, e.type.index, e.side.index,
                e.primaryPlayerId, e.secondaryPlayerId, e.xg),
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
        changed.queueCommand(ChangeMentalityCommand(
            atMinute: 60,
            side: MatchSide.home,
            mentality: Mentality.attacking));
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
