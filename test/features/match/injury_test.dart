import 'dart:math' as math;

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/match/injury.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = defaultInjuryConfig;

  double chanceAt({Position position = Position.st, int level = 0}) {
    return injuryChanceForMinute(
      config: config,
      position: position,
      medicalCentreLevel: level,
    );
  }

  group('injury risk model (GDD 11.7 — flat base risk, the fatigue ramp is '
      'gone with the stamina system, owner request 2026-11-14)', () {
    test('the Medical Centre strictly reduces risk at every level 0-5', () {
      var previous = chanceAt(level: 0);
      for (var level = 1; level <= 5; level++) {
        final risk = chanceAt(level: level);
        expect(risk, lessThan(previous), reason: 'level $level');
        previous = risk;
      }
      // The hook is 0.6 pp/level consumed as a fraction: level 5 → −3%.
      expect(chanceAt(level: 5),
          closeTo(config.baseRiskPerMinuteAtFullStamina * 0.97, 1e-12));
    });

    test('position workload applies: midfield > striker > keeper', () {
      final cm = chanceAt(position: Position.cm);
      final st = chanceAt(position: Position.st);
      final gk = chanceAt(position: Position.gk);
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
