import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/upgrades/upgrade_engine.dart';

void main() {
  group('UpgradeEngine merge progression (GDD 8.1)', () {
    const engine = UpgradeEngine();

    test('base + base = +1', () {
      expect(engine.mergedLevel(0, 0), 1);
    });

    test('+1 + base = +2 (target is higher)', () {
      expect(engine.mergedLevel(1, 0), 2);
    });

    test('base + +1 = +2 (order does not matter for the sum)', () {
      expect(engine.mergedLevel(0, 1), 2);
    });

    test('+2 + +1 = +4 — compounding duplicates', () {
      expect(engine.mergedLevel(2, 1), 4);
    });

    test('canMerge respects the level cap', () {
      expect(engine.canMerge(targetLevel: 0, duplicateLevel: 0), isTrue);
      expect(
          engine.canMerge(
              targetLevel: UpgradeEngine.maxUpgradeLevel - 1,
              duplicateLevel: 0),
          isTrue);
      expect(
          engine.canMerge(
              targetLevel: UpgradeEngine.maxUpgradeLevel, duplicateLevel: 0),
          isFalse);
    });
  });

  group('UpgradeEngine attribute allocation (GDD 8.2)', () {
    const engine = UpgradeEngine();

    test('grants exactly one point per level gained', () {
      final gain = engine.allocateAttributeGain(
          position: Position.st, levelsGained: 3, random: math.Random(7));
      final total = gain.values.fold(0, (a, b) => a + b);
      expect(total, 3);
    });

    test('goalkeepers never gain Attack or outfield attributes only', () {
      for (var seed = 0; seed < 50; seed++) {
        final gain = engine.allocateAttributeGain(
            position: Position.gk, levelsGained: 4, random: math.Random(seed));
        expect(gain.containsKey(PlayerAttribute.attack), isFalse,
            reason: 'seed $seed');
      }
    });

    test('strikers never gain Goalkeeping', () {
      for (var seed = 0; seed < 50; seed++) {
        final gain = engine.allocateAttributeGain(
            position: Position.st, levelsGained: 4, random: math.Random(seed));
        expect(gain.containsKey(PlayerAttribute.goalkeeping), isFalse,
            reason: 'seed $seed');
      }
    });

    test('deterministic with the same seed (development rule 7)', () {
      final a = engine.allocateAttributeGain(
          position: Position.cam, levelsGained: 5, random: math.Random(42));
      final b = engine.allocateAttributeGain(
          position: Position.cam, levelsGained: 5, random: math.Random(42));
      expect(a, b);
    });

    test('allocation follows position weights statistically', () {
      // CB: defence weight 0.68 dominates over support 0.22 / attack 0.10
      var defencePicks = 0;
      const samples = 2000;
      for (var s = 0; s < samples; s++) {
        final gain = engine.allocateAttributeGain(
            position: Position.cb, levelsGained: 1, random: math.Random(s));
        if (gain.containsKey(PlayerAttribute.defence)) defencePicks++;
      }
      expect(defencePicks / samples, greaterThan(0.55));
      expect(defencePicks / samples, lessThan(0.8));
    });

    test('merge returns level plus consistent gain', () {
      final outcome = engine.merge(
        position: Position.cm,
        targetLevel: 0,
        duplicateLevel: 0,
        random: math.Random(3),
      );
      expect(outcome.newUpgradeLevel, 1);
      expect(outcome.attributeGain.values.fold(0, (a, b) => a + b), 1);
    });

    test('zero levels gained grants nothing', () {
      expect(
          engine.allocateAttributeGain(
              position: Position.st, levelsGained: 0, random: math.Random(1)),
          isEmpty);
    });
  });
}
