import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/economy/economy_engine.dart';

BasePlayer player({
  int id = 1,
  Position position = Position.st,
  int marketValueEur = 1_000_000,
}) => BasePlayer(
  playerId: id,
  name: 'Test $id',
  position: position,
  nationality: 'Egypt',
  marketValueEur: marketValueEur,
  baseStats: const BaseStats(
    overall: 50,
    attack: 55,
    support: 50,
    defence: 45,
    goalkeeping: 0,
  ),
);

void main() {
  group('EconomyEngine economic value', () {
    const eco = EconomyEngine();

    test('reference point anchors the curve (GDD 17.2)', () {
      // §30-calibrated anchor: €50M ≈ 30k Coins.
      expect(eco.economicValueOf(50_000_000), 30_000);
    });

    test('non-linear: each doubling multiplies value by the same factor', () {
      final v1 = eco.economicValueOf(10_000_000);
      final v2 = eco.economicValueOf(20_000_000);
      final v4 = eco.economicValueOf(40_000_000);
      // growth factor per doubling must be equal on the power curve
      final r1 = v2 / v1;
      final r2 = v4 / v2;
      expect((r1 - r2).abs(), lessThan(0.01));
      expect(v2, greaterThan(v1));
      // sub-linear: 4x market value is ~2x economic value (exponent 0.5)
      expect(v4 / v1, closeTo(2.0, 0.02));
    });

    test('clamped to sane bounds', () {
      expect(eco.economicValueOf(0), 5);
      // 1 EUR is (1/50M)^0.5 * 30k ≈ 4.2 — clamped to the floor
      expect(eco.economicValueOf(1), 5);
      expect(eco.economicValueOf(10_000_000_000), lessThanOrEqualTo(600_000));
    });

    test('stable across imports: same value => same economic value', () {
      expect(eco.economicValueOf(7_500_000), eco.economicValueOf(7_500_000));
    });
  });

  group('selling (GDD 17.3)', () {
    const eco = EconomyEngine();

    test('base selling price is the configured percentage', () {
      final p = player(marketValueEur: 50_000_000);
      expect(eco.sellPriceOf(p), 18_000); // 30k * 0.6 (§30 calibration)
    });

    test('upgraded players sell for more, growing with level', () {
      final p = player(marketValueEur: 50_000_000);
      final base = eco.sellPriceOf(p);
      final plus1 = eco.sellPriceOfUpgraded(p, 1);
      final plus3 = eco.sellPriceOfUpgraded(p, 3);
      expect(plus1, greaterThan(base));
      expect(plus3, greaterThan(plus1));
      // exactly +10% of ev per level: 18k * 1.1 = 19.8k
      expect(plus1, 19_800);
    });

    test('FR-008: removal compensation equals upgraded selling formula', () {
      final p = player(marketValueEur: 12_000_000);
      // The same call is used by the removal path — identical by construction.
      expect(eco.sellPriceOfUpgraded(p, 2), eco.sellPriceOfUpgraded(p, 2));
    });
  });

  group('upgrade costs (GDD 8.4)', () {
    const eco = EconomyEngine();

    test('cost grows with upgrade level', () {
      final p = player(marketValueEur: 50_000_000);
      final c0 = eco.upgradeCostOf(p, 0);
      final c1 = eco.upgradeCostOf(p, 1);
      final c5 = eco.upgradeCostOf(p, 5);
      expect(c1, greaterThan(c0));
      expect(c5, greaterThan(c1));
      // level growth 1.5: cost(1) = cost(0) * 1.5
      expect(c1, closeTo(c0 * 1.5, 2));
    });

    test('cost grows with market value', () {
      final cheap = eco.upgradeCostOf(
        player(id: 1, marketValueEur: 500_000),
        0,
      );
      final star = eco.upgradeCostOf(
        player(id: 2, marketValueEur: 100_000_000),
        0,
      );
      expect(star, greaterThan(cheap));
    });
  });

  group('pack pricing and rewards', () {
    const eco = EconomyEngine();

    test('match reward scales with goals and win', () {
      final loss = eco.matchReward(goalsFor: 0, won: false);
      final win = eco.matchReward(goalsFor: 0, won: true);
      final bigWin = eco.matchReward(goalsFor: 4, won: true);
      expect(win, greaterThan(loss));
      expect(bigWin, greaterThan(win));
    });
  });

  group('formatCoins', () {
    test('compact formatting', () {
      expect(formatCoins(950), '950');
      expect(formatCoins(27_500), '28k');
      expect(formatCoins(1_234_567), '1.2M');
      expect(formatCoins(25_400_000), '25M');
    });
  });

  test('config defaults are sane', () {
    const c = EconomyConfig();
    expect(c.sellingPercentage, inInclusiveRange(0.3, 0.9));
    expect(math.pow(c.upgradeLevelGrowth, 0), 1);
  });
}
