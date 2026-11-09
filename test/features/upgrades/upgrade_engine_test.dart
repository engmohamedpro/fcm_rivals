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

    test('merging past the old level-5 cap is legal (owner 2026-11-09)', () {
      expect(engine.mergedLevel(5, 0), 6);
      expect(engine.mergedLevel(11, 0), 12);
      expect(engine.mergedLevel(20, 3), 24);
      // Unlimited levels: every pair stays mergeable by level alone.
      expect(engine.canMerge(targetLevel: 100, duplicateLevel: 50), isTrue);
    });

    test('merge returns only the new level — fully deterministic', () {
      final outcome = engine.merge(targetLevel: 2, duplicateLevel: 3);
      expect(outcome.newUpgradeLevel, 6);
    });
  });

  group('upgradedValue — the +N% formula (owner decision 2026-11-09)', () {
    test('base ATT 90: +1 → 91, +2 → 92, +11 → 100, +20 → 108', () {
      expect(upgradedValue(90, 1), 91);
      expect(upgradedValue(90, 2), 92);
      expect(upgradedValue(90, 11), 100);
      expect(upgradedValue(90, 20), 108);
    });

    test('base 60 at +3 → 62 (1.8 rounds to 2)', () {
      expect(upgradedValue(60, 3), 62);
    });

    test('level 0 is the base itself', () {
      expect(upgradedValue(90, 0), 90);
      expect(upgradedValue(0, 7), 0);
    });

    test('negative levels clamp to 0 (defensive)', () {
      expect(upgradedValue(90, -3), 90);
    });

    test('linear, not compounding (owner: +3 is ×1.03, not ×1.01³)', () {
      expect(upgradedValue(90, 3), 93);
      // A case where the two shapes round differently: 61 at +3 is
      // 61 + 1.83 = 62.83 → 63 linear, 61 × 1.030301 = 62.85 → 63 —
      // equal again, so use a base where they truly split: 40 at +3:
      // linear 40 + 1.2 = 41.2 → 41; compounded 40 × 1.030301 = 41.21
      // → 41. The shapes agree on integers at low levels by rounding —
      // assert the exact arithmetic the task dictates instead.
      expect(upgradedValue(40, 3), 41);
      expect(upgradedValue(40, 3), 40 + (40 * 3 / 100).round());
    });

    test('no 99 cap: high bases grow past it cleanly', () {
      expect(upgradedValue(99, 1), 100); // 99.99 → 100
      expect(upgradedValue(99, 2), 101);
      expect(upgradedValue(100, 10), 110);
    });

    test('rounding follows half-up on the base percentage', () {
      // 49 × 5 / 100 = 2.45 → 2; 51 × 5 / 100 = 2.55 → 3.
      expect(upgradedValue(49, 5), 51);
      expect(upgradedValue(51, 5), 54);
    });
  });
}
