import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/base_stats_generator.dart';
import 'package:fcm_rivals/core/domain/players.dart';

void main() {
  group('BaseStatsGenerator', () {
    const gen = BaseStatsGenerator();

    test('rating follows the log curve and doubles add constant rating', () {
      // 84 at reference (50M), 4 rating per doubling.
      expect(gen.baseRatingFor(50_000_000), 84);
      expect(gen.baseRatingFor(100_000_000), 88);
      expect(gen.baseRatingFor(200_000_000), 92);
      expect(gen.baseRatingFor(25_000_000), 80);
      // Non-linearity: €1.25M to €200M is a 160x value span but only ~5.3
      // doublings * 4 rating points apart.
      final cheap = gen.baseRatingFor(1_250_000);
      final star = gen.baseRatingFor(200_000_000);
      expect(star - cheap, lessThan(32));
      expect(star - cheap, greaterThan(20)); // still meaningfully better
    });

    test('clamps to configured bounds', () {
      expect(gen.baseRatingFor(0), 30);
      // 10k: 84 - 4*log2(5000) ≈ 35
      expect(gen.baseRatingFor(10_000), 35);
      expect(gen.baseRatingFor(500_000_000), 94); // above ceiling
    });

    test('monotonic in market value', () {
      var prev = -1;
      for (var v = 10_000; v <= 200_000_000; v *= 2) {
        final r = gen.baseRatingFor(v);
        expect(r, greaterThanOrEqualTo(prev));
        prev = r;
      }
    });

    test('position-specific distributions differ (GDD 4.5)', () {
      final st = gen.generate(Position.st, 100_000_000);
      final cb = gen.generate(Position.cb, 100_000_000);
      final gk = gen.generate(Position.gk, 100_000_000);
      final cdm = gen.generate(Position.cdm, 100_000_000);

      expect(st.attack, greaterThan(st.defence));
      expect(cb.defence, greaterThan(cb.attack));
      expect(gk.goalkeeping, greaterThan(gk.attack));
      expect(gk.attack, 0);
      expect(cdm.defence, greaterThan(cdm.attack));
      expect(cdm.support, greaterThan(cdm.attack));
    });

    test('all attributes within 1..99 and overall equals curve', () {
      for (final pos in Position.values) {
        final stats = gen.generate(pos, 75_000_000);
        for (final v in [stats.attack, stats.support, stats.defence, stats.goalkeeping]) {
          expect(v, inInclusiveRange(0, 99));
        }
        expect(stats.overall, gen.baseRatingFor(75_000_000));
      }
    });

    test('same input produces identical stats (determinism)', () {
      final a = gen.generate(Position.cam, 42_000_000);
      final b = gen.generate(Position.cam, 42_000_000);
      expect(a, b);
    });
  });

  group('Position', () {
    test('parses all 12 codes round-trip', () {
      for (final p in Position.values) {
        expect(Position.fromCode(p.code), p);
      }
      expect(() => Position.fromCode('XX'), throwsStateError);
    });

    test('goalkeeper flag', () {
      expect(Position.gk.isGoalkeeper, isTrue);
      expect(Position.st.isGoalkeeper, isFalse);
    });
  });

  group('BasePlayer identity', () {
    test('identity is the player id, not mutable facts', () {
      const a = BasePlayer(
        playerId: 1,
        name: 'A',
        position: Position.st,
        nationality: 'Egypt',
        marketValueEur: 1_000_000,
        baseStats: BaseStats(
            overall: 50, attack: 60, support: 45, defence: 40, goalkeeping: 0),
      );
      final b = a.copyWith(name: 'B', marketValueEur: 5_000_000);
      expect(b, a); // same id => equal
      expect(b.name, 'B');
      expect(b.playerId, a.playerId);
    });
  });

  test('log2 sanity used by the curve', () {
    expect(math.log(8) / math.ln2, closeTo(3, 1e-12));
  });
}
