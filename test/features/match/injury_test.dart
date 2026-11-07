import 'dart:math' as math;

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/match/injury.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = defaultInjuryConfig;

  double chanceAt(double stamina, {Position position = Position.st, int level = 0}) {
    return injuryChanceForMinute(
      config: config,
      stamina: stamina,
      position: position,
      medicalCentreLevel: level,
    );
  }

  group('injury risk model (GDD 11.7)', () {
    test('risk ≈ 0 at full stamina (the documented floor, not zero)', () {
      final risk = chanceAt(100);
      // Exactly the base risk at the default striker workload.
      expect(risk, closeTo(config.baseRiskPerMinuteAtFullStamina, 1e-12));
      expect(risk, lessThan(0.001));
    });

    test('monotonic grid 100→0: flat at/above the threshold, strictly '
        'increasing below it', () {
      var previous = chanceAt(100);
      for (var stamina = 95; stamina >= 0; stamina -= 5) {
        final risk = chanceAt(stamina.toDouble());
        if (stamina >= config.fatigueRiskThreshold) {
          expect(risk, previous, reason: 'flat at stamina $stamina');
        } else {
          expect(risk, greaterThan(previous),
              reason: 'strictly increasing at stamina $stamina');
        }
        previous = risk;
      }
    });

    test('the fatigue ramp is quadratic and bounded by maxRiskPerMinute', () {
      // Halving the distance below the threshold quarters the ramp factor.
      final at60 = chanceAt(60);
      final at35 = chanceAt(35);
      final t60 = (70 - 60) / 70;
      final t35 = (70 - 35) / 70;
      final expectedRatio =
          (1 + config.fatigueRiskSlope * t35 * t35) /
          (1 + config.fatigueRiskSlope * t60 * t60);
      expect(at35 / at60, closeTo(expectedRatio, 1e-9));
      // The spent central midfielder hits the documented per-minute cap:
      // 0.0002 × 15 × 1.18 = 0.00354 → clamped.
      expect(chanceAt(0, position: Position.cm), config.maxRiskPerMinute);
    });

    test('the Medical Centre strictly reduces risk at every level 0-5', () {
      for (final stamina in [90.0, 70.0, 40.0, 10.0]) {
        var previous = chanceAt(stamina, level: 0);
        for (var level = 1; level <= 5; level++) {
          final risk = chanceAt(stamina, level: level);
          expect(risk, lessThan(previous),
              reason: 'level $level at stamina $stamina');
          previous = risk;
        }
      }
      // The hook is 0.6 pp/level consumed as a fraction: level 5 → −3%.
      expect(chanceAt(100, level: 5),
          closeTo(config.baseRiskPerMinuteAtFullStamina * 0.97, 1e-12));
    });

    test('position workload applies: midfield > striker > keeper', () {
      final cm = chanceAt(40, position: Position.cm);
      final st = chanceAt(40, position: Position.st);
      final gk = chanceAt(40, position: Position.gk);
      expect(cm, greaterThan(st));
      expect(st, greaterThan(gk));
    });

    test('the per-match cap guard constant exists for the engine (T-0054)',
        () {
      expect(config.maxInjuriesPerTeamPerMatch, 2);
      expect(config.expectedMatchesOut, closeTo(1.925, 1e-9));
    });
  });

  group('rollInjury (seeded severity roll)', () {
    RandomDraw drawFrom(math.Random random) => random.nextDouble;

    test('is deterministic per seed', () {
      final a = List.generate(
        500,
        (_) => rollInjury(
          config: config,
          chancePerMinute: 0.5,
          draw: drawFrom(math.Random(77)),
        ),
      );
      final b = List.generate(
        500,
        (_) => rollInjury(
          config: config,
          chancePerMinute: 0.5,
          draw: drawFrom(math.Random(77)),
        ),
      );
      expect(a, equals(b));
    });

    test('returns null when the draw misses, and never a zero-matches injury',
        () {
      expect(
        rollInjury(config: config, chancePerMinute: 0, draw: () => 0.999999),
        isNull,
      );
      expect(
        rollInjury(config: config, chancePerMinute: 1, draw: () => 0.0),
        isNotNull,
      );
      // Every miss consumes exactly one draw (the engine's budget contract).
      var draws = 0;
      rollInjury(config: config, chancePerMinute: 0.5, draw: () {
        draws++;
        return 0.999;
      });
      expect(draws, 1);
    });

    test('distribution sanity: kind shares and mean matchesOut locked', () {
      const draws = 50000;
      final random = math.Random(20261107);
      final counts = <InjuryKind, int>{};
      var totalMatchesOut = 0;
      var injuries = 0;
      for (var i = 0; i < draws; i++) {
        final injury = rollInjury(
          config: config,
          chancePerMinute: 1,
          draw: drawFrom(random),
        );
        if (injury == null) continue;
        injuries++;
        counts[injury.kind] = (counts[injury.kind] ?? 0) + 1;
        totalMatchesOut += injury.matchesOut;
      }
      final knockShare = counts[InjuryKind.knock]! / injuries;
      final muscleShare = counts[InjuryKind.muscle]! / injuries;
      final seriousShare = counts[InjuryKind.serious]! / injuries;
      final meanMatchesOut = totalMatchesOut / injuries;
      // ignore: avoid_print
      print('injury distribution over $draws seeded draws: '
          'knock ${knockShare.toStringAsFixed(4)} / '
          'muscle ${muscleShare.toStringAsFixed(4)} / '
          'serious ${seriousShare.toStringAsFixed(4)} / '
          'mean matchesOut ${meanMatchesOut.toStringAsFixed(4)}');
      // Bands are ~13σ wide at n=50k — they lock the shipped weights
      // (0.55/0.35/0.10, E[matchesOut] 1.925) without flaking.
      expect(knockShare, inInclusiveRange(0.52, 0.58));
      expect(muscleShare, inInclusiveRange(0.32, 0.38));
      expect(seriousShare, inInclusiveRange(0.08, 0.12));
      expect(meanMatchesOut, inInclusiveRange(1.85, 2.00));
      expect(meanMatchesOut,
          closeTo(config.expectedMatchesOut, 0.05));
    });
  });
}
