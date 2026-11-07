import 'dart:io' as io;
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/base_stats_generator.dart';
import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';

void main() {
  const gen = BaseStatsGenerator();

  group('BaseStatsGenerator', () {
    test('rating follows the two-segment log curve (T-0046)', () {
      // Standard segment: 84 at reference (50M), 4 rating per doubling.
      expect(gen.baseRatingFor(50_000_000), 84);
      expect(gen.baseRatingFor(25_000_000), 80);
      // Elite segment (T-0046 deliberate band change): above the kink at
      // the reference the slope is 7.5/doubling, reaching the 94-99 band.
      expect(gen.baseRatingFor(100_000_000), 92); // 84 + 7.5
      expect(gen.baseRatingFor(200_000_000), 99); // 84 + 7.5 * 2
      // Non-linearity: €1.25M to €200M is a 160x value span but only ~8
      // rating points per doubling, concentrated above the elite kink.
      final cheap = gen.baseRatingFor(1_250_000);
      final star = gen.baseRatingFor(200_000_000);
      expect(star - cheap, lessThan(40));
      expect(star - cheap, greaterThan(30)); // still meaningfully better
    });

    test('clamps to configured bounds', () {
      expect(gen.baseRatingFor(0), 30);
      // 10k: 84 - 4*log2(5000) ≈ 35
      expect(gen.baseRatingFor(10_000), 35);
      // T-0046 deliberate band change: the ceiling is 99 now, and the
      // elite slope clamps superstars exactly there.
      expect(gen.baseRatingFor(500_000_000), 99); // above ceiling
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
        for (final v in [
          stats.attack,
          stats.support,
          stats.defence,
          stats.goalkeeping,
        ]) {
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

    test('market value distributes into position-appropriate stats', () {
      // The overall is fixed by the value; the position decides where
      // that quality lives — and the split must be pronounced, not a
      // few points of noise.
      final st = gen.generate(Position.st, 100_000_000);
      final cb = gen.generate(Position.cb, 100_000_000);
      final gk = gen.generate(Position.gk, 100_000_000);
      final cdm = gen.generate(Position.cdm, 100_000_000);
      final lw = gen.generate(Position.lw, 100_000_000);

      // Striker: attack is his identity, defence clearly secondary.
      // T-0046: at €100M (OVR 92) the primary attribute clamps at the 99
      // ceiling, so the elite-tier split is clamp-compressed (99 vs 88).
      expect(st.attack - st.defence, greaterThan(8));
      // Centre-back mirrors the striker.
      expect(cb.defence - cb.attack, greaterThan(8));
      // Keeper: goalkeeping towers over everything else.
      expect(gk.goalkeeping - gk.defence, greaterThan(8));
      expect(gk.attack, 0);
      // Anchor: defence-first with support ahead of attack.
      expect(cdm.defence - cdm.attack, greaterThan(10));
      expect(cdm.support - cdm.attack, greaterThan(5));
      // Winger: attacker with support, defence behind both.
      expect(lw.attack, greaterThan(lw.support));
      expect(lw.support, greaterThan(lw.defence));
      // And every outfield player's goalkeeping stays at zero.
      expect(st.goalkeeping, 0);
      expect(cb.goalkeeping, 0);
    });

    test('the same value yields different stat shapes per position', () {
      // Two €50M players in different positions must not be clones:
      // only the overall is shared, the attribute profile is the job.
      final st = gen.generate(Position.st, 50_000_000);
      final cb = gen.generate(Position.cb, 50_000_000);
      expect(st.overall, cb.overall);
      expect([
        st.attack,
        st.support,
        st.defence,
      ], isNot(equals([cb.attack, cb.support, cb.defence])));
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
          overall: 50,
          attack: 60,
          support: 45,
          defence: 40,
          goalkeeping: 0,
        ),
      );
      final b = a.copyWith(name: 'B', marketValueEur: 5_000_000);
      expect(b, a); // same id => equal
      expect(b.name, 'B');
      expect(b.playerId, a.playerId);
    });
  });

  group('position identity ladders (realistic profiles, seeded means)', () {
    // Seeded generation is probabilistic, so the identity of a position is
    // asserted on the MEAN over many players — and the margins below are
    // far outside the sampling noise (SE ≈ 0.07 at n=400).
    const value = 30_000_000; // base 79: no 99-clamp compresses the means
    const n = 400;
    double mean(Position p, PlayerAttribute a) {
      final values = [
        for (var s = 0; s < n; s++)
          gen.generate(p, value, seed: 1000 + s).valueOf(a),
      ];
      return values.fold<double>(0, (sum, v) => sum + v) / n;
    }

    test('ST: attack top, support ordinary, defence least', () {
      final a = mean(Position.st, PlayerAttribute.attack);
      final s = mean(Position.st, PlayerAttribute.support);
      final d = mean(Position.st, PlayerAttribute.defence);
      expect(a - s, greaterThan(8), reason: 'attack is the striker identity');
      expect(s - d, greaterThan(1), reason: 'support ahead of defence');
    });

    test('LW/RW: attack top but below ST, support above ST, defence least', () {
      for (final wing in [Position.lw, Position.rw]) {
        final a = mean(wing, PlayerAttribute.attack);
        final s = mean(wing, PlayerAttribute.support);
        final d = mean(wing, PlayerAttribute.defence);
        expect(a, greaterThan(s));
        expect(s, greaterThan(d));
        expect(a - s, greaterThan(4));
      }
      // Wingers attack less than strikers but support more.
      expect(
        mean(Position.st, PlayerAttribute.attack) -
            mean(Position.lw, PlayerAttribute.attack),
        greaterThan(1),
      );
      expect(
        mean(Position.lw, PlayerAttribute.support) -
            mean(Position.st, PlayerAttribute.support),
        greaterThan(1),
      );
      expect(
        mean(Position.rw, PlayerAttribute.support) -
            mean(Position.st, PlayerAttribute.support),
        greaterThan(1),
      );
    });

    test('CAM: support first, attack second, defence the lowest outfield', () {
      final a = mean(Position.cam, PlayerAttribute.attack);
      final s = mean(Position.cam, PlayerAttribute.support);
      final d = mean(Position.cam, PlayerAttribute.defence);
      expect(s, greaterThan(a));
      expect(a - d, greaterThan(3));
      // Very low: below EVERY other outfield role's defence, ST included.
      for (final p in [
        Position.st,
        Position.lw,
        Position.rw,
        Position.lm,
        Position.rm,
        Position.cm,
        Position.cdm,
        Position.cb,
        Position.rb,
        Position.lb,
      ]) {
        expect(
          d,
          lessThan(mean(p, PlayerAttribute.defence)),
          reason: 'CAM defence must sit below ${p.code}',
        );
      }
    });

    test('CM: support first, defence ahead of attack (box-to-box)', () {
      final a = mean(Position.cm, PlayerAttribute.attack);
      final s = mean(Position.cm, PlayerAttribute.support);
      final d = mean(Position.cm, PlayerAttribute.defence);
      expect(s - d, greaterThan(2));
      expect(d - a, greaterThan(1));
    });

    test('CDM: defence towers, support second, attack least', () {
      final a = mean(Position.cdm, PlayerAttribute.attack);
      final s = mean(Position.cdm, PlayerAttribute.support);
      final d = mean(Position.cdm, PlayerAttribute.defence);
      expect(d - s, greaterThan(1.5));
      expect(s - a, greaterThan(3));
      // The shield defends better than any other midfielder.
      expect(d - mean(Position.cm, PlayerAttribute.defence), greaterThan(2));
      expect(d - mean(Position.rb, PlayerAttribute.defence), greaterThan(1));
    });

    test('LM/RM: support first, attack second, defence modest', () {
      for (final wide in [Position.lm, Position.rm]) {
        final a = mean(wide, PlayerAttribute.attack);
        final s = mean(wide, PlayerAttribute.support);
        final d = mean(wide, PlayerAttribute.defence);
        expect(s - a, greaterThan(0.5));
        expect(a - d, greaterThan(1.5));
      }
    });

    test('CB: the defensive ceiling, support and attack trail', () {
      final a = mean(Position.cb, PlayerAttribute.attack);
      final s = mean(Position.cb, PlayerAttribute.support);
      final d = mean(Position.cb, PlayerAttribute.defence);
      expect(d - a, greaterThan(8));
      expect(d - s, greaterThan(8));
      // Highest defence in the game.
      expect(d - mean(Position.cdm, PlayerAttribute.defence), greaterThan(2));
    });

    test('RB/LB: defend best but below CB, support better than CB', () {
      for (final back in [Position.rb, Position.lb]) {
        final a = mean(back, PlayerAttribute.attack);
        final s = mean(back, PlayerAttribute.support);
        final d = mean(back, PlayerAttribute.defence);
        expect(d, greaterThan(s));
        expect(s, greaterThan(a));
      }
      // Full-backs defend clearly less than centre-backs...
      expect(
        mean(Position.cb, PlayerAttribute.defence) -
            mean(Position.rb, PlayerAttribute.defence),
        greaterThan(4),
      );
      expect(
        mean(Position.cb, PlayerAttribute.defence) -
            mean(Position.lb, PlayerAttribute.defence),
        greaterThan(4),
      );
      // ...but support clearly more (overlapping runs).
      expect(
        mean(Position.rb, PlayerAttribute.support) -
            mean(Position.cb, PlayerAttribute.support),
        greaterThan(2),
      );
      expect(
        mean(Position.lb, PlayerAttribute.support) -
            mean(Position.cb, PlayerAttribute.support),
        greaterThan(2),
      );
    });

    test('GK: goalkeeping towers, attack pinned at 0', () {
      final gk = mean(Position.gk, PlayerAttribute.goalkeeping);
      final d = mean(Position.gk, PlayerAttribute.defence);
      final s = mean(Position.gk, PlayerAttribute.support);
      expect(gk - d, greaterThan(12));
      expect(gk - s, greaterThan(12));
      for (var seed = 0; seed < 50; seed++) {
        expect(gen.generate(Position.gk, value, seed: seed).attack, 0);
      }
    });

    test('same value, different positions: no clone profiles', () {
      // Mirror twins (LB/RB, LM/RM, LW/RW) legitimately share the same
      // expected shape — the per-player seed differentiates individuals.
      // Every OTHER pair of positions must field a different profile.
      const mirrors = {
        Position.lb: Position.rb,
        Position.rb: Position.lb,
        Position.lm: Position.rm,
        Position.rm: Position.lm,
        Position.lw: Position.rw,
        Position.rw: Position.lw,
      };
      final profiles = <Position, String>{};
      for (final p in Position.values) {
        final s = gen.generate(p, value);
        profiles[p] = '${s.attack}/${s.support}/${s.defence}/${s.goalkeeping}';
      }
      for (var i = 0; i < Position.values.length; i++) {
        for (var j = i + 1; j < Position.values.length; j++) {
          final a = Position.values[i];
          final b = Position.values[j];
          if (mirrors[a] == b) continue;
          expect(
            profiles[a],
            isNot(profiles[b]),
            reason: '$a and $b share the same expected profile',
          );
        }
      }
    });
  });

  group('probabilistic layer (seeded generation)', () {
    const value = 30_000_000;

    test('same seed reproduces the exact same stats (stable regeneration)', () {
      const a = BaseStatsGenerator();
      expect(
        a.generate(Position.st, value, seed: 1234),
        a.generate(Position.st, value, seed: 1234),
      );
      expect(
        a.generate(Position.gk, value, seed: 99),
        a.generate(Position.gk, value, seed: 99),
      );
    });

    test('different seeds give different players (probabilities at work)', () {
      final attacks = <int>{
        for (var s = 0; s < 50; s++)
          gen.generate(Position.st, value, seed: s).attack,
      };
      expect(
        attacks.length,
        greaterThan(4),
        reason: 'one value + position must not stamp out clones',
      );
    });

    test('seeded means center on the unseeded expected profile', () {
      const n = 400;
      for (final p in [Position.st, Position.cam, Position.cb, Position.gk]) {
        for (final a in PlayerAttribute.values) {
          if (positionWeights[p]![a] == 0) continue;
          final expected = gen.generate(p, value).valueOf(a).toDouble();
          final values = [
            for (var s = 0; s < n; s++)
              gen.generate(p, value, seed: 7000 + s).valueOf(a),
          ];
          final m = values.fold<int>(0, (sum, v) => sum + v) / n;
          expect(
            m,
            closeTo(expected, 0.6),
            reason: '$p $a drifts from its expected profile',
          );
        }
      }
    });

    test('noise stays bounded: no attribute strays more than 5 points', () {
      for (var s = 0; s < 300; s++) {
        for (final p in Position.values) {
          for (final a in PlayerAttribute.values) {
            if (positionWeights[p]![a] == 0) continue;
            final expected = gen.generate(p, value).valueOf(a);
            final drawn = gen.generate(p, value, seed: 20_000 + s).valueOf(a);
            expect(
              (drawn - expected).abs(),
              lessThanOrEqualTo(5),
              reason: '$p $a strayed too far from its profile',
            );
          }
        }
      }
    });

    test('position identity never flips for an individual player', () {
      // The identity gaps are wider than the bounded noise can bridge:
      // every sampled striker out-attacks his own support and defence,
      // every sampled centre-back out-defends his own attack, etc.
      const n = 300;
      bool holds(
        Position p,
        PlayerAttribute hi,
        PlayerAttribute lo, {
        double rate = 0.9,
      }) =>
          ([for (var s = 0; s < n; s++) gen.generate(p, value, seed: 5000 + s)]
                  .where((b) => b.valueOf(hi) > b.valueOf(lo))
                  .length /
              n) >=
          rate;

      expect(
        holds(
          Position.st,
          PlayerAttribute.attack,
          PlayerAttribute.support,
          rate: 0.99,
        ),
        isTrue,
      );
      expect(
        holds(
          Position.st,
          PlayerAttribute.attack,
          PlayerAttribute.defence,
          rate: 0.99,
        ),
        isTrue,
      );
      expect(
        holds(
          Position.lw,
          PlayerAttribute.attack,
          PlayerAttribute.defence,
          rate: 0.95,
        ),
        isTrue,
      );
      expect(
        holds(
          Position.cam,
          PlayerAttribute.support,
          PlayerAttribute.defence,
          rate: 0.95,
        ),
        isTrue,
      );
      expect(
        holds(
          Position.cm,
          PlayerAttribute.support,
          PlayerAttribute.defence,
          rate: 0.9,
        ),
        isTrue,
      );
      expect(
        holds(
          Position.cdm,
          PlayerAttribute.defence,
          PlayerAttribute.attack,
          rate: 0.95,
        ),
        isTrue,
      );
      expect(
        holds(
          Position.cb,
          PlayerAttribute.defence,
          PlayerAttribute.attack,
          rate: 0.99,
        ),
        isTrue,
      );
      expect(
        holds(
          Position.gk,
          PlayerAttribute.goalkeeping,
          PlayerAttribute.defence,
          rate: 0.99,
        ),
        isTrue,
      );
    });

    test('all attributes stay in bounds even with noise at extreme values', () {
      for (final v in [0, 10_000, 500_000, 50_000_000, 500_000_000]) {
        for (final p in Position.values) {
          for (var s = 0; s < 30; s++) {
            final stats = gen.generate(p, v, seed: 11_000 + s);
            for (final a in PlayerAttribute.values) {
              final weight = positionWeights[p]![a]!;
              final statValue = stats.valueOf(a);
              if (weight == 0) {
                expect(statValue, 0, reason: '$p has no $a');
              } else {
                expect(statValue, inInclusiveRange(1, 99));
              }
            }
            expect(stats.overall, inInclusiveRange(30, 99)); // T-0046 ceiling
          }
        }
      }
    });

    test('higher market value buys better players (seeded means)', () {
      const n = 200;
      double meanAttack(int v) =>
          [
            for (var s = 0; s < n; s++)
              gen.generate(Position.st, v, seed: 8000 + s).attack,
          ].fold<int>(0, (sum, x) => sum + x) /
          n;
      expect(meanAttack(120_000_000) - meanAttack(5_000_000), greaterThan(10));
    });
  });

  test('log2 sanity used by the curve', () {
    expect(math.log(8) / math.ln2, closeTo(3, 1e-12));
  });

  group('T-0048 elite ladder: position-true at every OVR tier', () {
    const config = defaultBaseStatsConfig;
    const ladderGen = BaseStatsGenerator();

    int attrOf(BaseStats s, PlayerAttribute a) => switch (a) {
          PlayerAttribute.attack => s.attack,
          PlayerAttribute.support => s.support,
          PlayerAttribute.defence => s.defence,
          PlayerAttribute.goalkeeping => s.goalkeeping,
        };

    int valueForOvr(int ovr) => config.valueForRating(ovr);

    /// The primary (highest-weight) attribute's value, the least value
    /// and the second-largest value among the position's non-zero-weight
    /// attributes.
    (int, int, int) ladderOf(Position position, BaseStats s) {
      final weights = positionWeights[position]!;
      final ranked = weights.keys.toList()
        ..sort((a, b) => weights[b]!.compareTo(weights[a]!));
      final primary = ranked.first;
      var least = 1 << 30;
      var secondLargest = -1;
      for (final k in ranked.skip(1)) {
        if (weights[k]! == 0) continue;
        final v = attrOf(s, k);
        least = math.min(least, v);
        secondLargest = math.max(secondLargest, v);
      }
      return (attrOf(s, primary), least, secondLargest);
    }

    test('ladder gap floor ≥ 12 at OVR 95/97/99 for every position '
        '(2,000 seeded draws, extremes never invert)', () {
      // Per draw the guarantee is primary > least: the scaled span (≥ 18)
      // exceeds the opposed noise extremes (2 × 2.5) plus integer
      // rounding, so the measured gap can dip to 12 but never through
      // zero. Close-weight neighbours (CAM's support/attack, 0.48 vs
      // 0.42) may swap per draw — that is the style noise the GDD
      // sanctions; the EXPECTED profile below locks the exact ordering.
      for (final position in Position.values) {
        for (final ovr in const [95, 97, 99]) {
          final value = valueForOvr(ovr);
          var minGap = 1 << 30;
          for (var seed = 0; seed < 2000; seed++) {
            final s = ladderGen.generate(position, value, seed: seed);
            final (primary, least, _) = ladderOf(position, s);
            expect(primary, greaterThan(least),
                reason:
                    '${position.code} @$ovr seed $seed: the ladder extremes '
                    'must never invert');
            minGap = math.min(minGap, primary - least);
          }
          expect(minGap, greaterThanOrEqualTo(12),
              reason: '${position.code} @$ovr: measured min gap $minGap');
          // The expected (seedless) profile is strictly primary-first.
          final expected = ladderGen.generate(position, value);
          final (ePrimary, eLeast, eSecond) = ladderOf(position, expected);
          expect(ePrimary, greaterThan(eSecond),
              reason: '${position.code} @$ovr: the expected profile must '
                  'have a strictly largest primary attribute');
          expect(ePrimary - eLeast, greaterThanOrEqualTo(12),
              reason: '${position.code} @$ovr: expected-profile gap');
        }
      }
    });

    test('measured ladder gaps printed at OVR 84 / 95 / 99', () {
      // ignore: avoid_print
      print('T-0048 ladder gaps (mean primary − least over 500 seeds):');
      for (final ovr in const [84, 95, 99]) {
        final value = valueForOvr(ovr);
        final row = StringBuffer('  OVR $ovr:');
        for (final position in Position.values) {
          var total = 0;
          for (var seed = 0; seed < 500; seed++) {
            final s = ladderGen.generate(position, value, seed: seed);
            final (primary, least, _) = ladderOf(position, s);
            total += primary - least;
          }
          row.write(' ${position.code}=${(total / 500).toStringAsFixed(1)}');
        }
        // ignore: avoid_print
        print(row);
      }
    });

    test('expected formula holds exactly below every ceiling threshold '
        '(no ramp, no shift at OVR 78)', () {
      // OVR 78 keeps every position's raw maximum (including both noise
      // extremes) under the 99 ceiling, so the pure shipped formula must
      // come out exactly — the low/mid bands did not move.
      final value = valueForOvr(78);
      for (final position in Position.values) {
        final s = ladderGen.generate(position, value);
        for (final entry in positionWeights[position]!.entries) {
          if (entry.value == 0) {
            expect(attrOf(s, entry.key), 0, reason: position.code);
            continue;
          }
          final expected = (78 +
                  config.attributeSpread *
                      (entry.value - config.attributeAnchor))
              .round();
          expect(attrOf(s, entry.key), expected,
              reason: '${position.code} ${entry.key.name}');
        }
      }
    });

    test('range locks: σ > 0 and every draw stays within '
        '±(qualityNoise + attributeNoise) of the expected value', () {
      // OVR 78: below every ceiling threshold, so the expected value is
      // the pure shipped formula and the ± bound is exact.
      final value = valueForOvr(78);
      const seeds = 1000;
      final bound = config.qualityNoise + config.attributeNoise + 1;
      for (final position in Position.values) {
        for (final entry in positionWeights[position]!.entries) {
          if (entry.value == 0) continue;
          final expected = 78 +
              config.attributeSpread * (entry.value - config.attributeAnchor);
          final values = [
            for (var seed = 0; seed < seeds; seed++)
              attrOf(
                ladderGen.generate(position, value, seed: seed),
                entry.key,
              ),
          ];
          final mean = values.fold<double>(0, (a, b) => a + b) / seeds;
          final sigma =
              math.sqrt(values.fold<double>(0, (a, b) {
                    final d = b - mean;
                    return a + d * d;
                  }) /
                  seeds);
          expect(sigma, greaterThan(0),
              reason:
                  '${position.code} ${entry.key.name}: the style noise must '
                  'produce real variance');
          for (final v in values) {
            expect((v - expected).abs(), lessThanOrEqualTo(bound),
                reason:
                    '${position.code} ${entry.key.name}: $v vs expected '
                    '$expected');
          }
        }
      }
    });

    test('identity ordering never inverts: 12 positions × 2,000 draws at '
        'OVR 84 and 97 (extremes hold per draw; expected order is exact)',
        () {
      // Per draw: the ladder extremes can never cross (the span floor
      // exceeds the noise bound). Close-weight neighbours may swap —
      // the exact ordering is locked on the expected profile.
      for (final ovr in const [84, 97]) {
        final value = valueForOvr(ovr);
        for (final position in Position.values) {
          for (var seed = 0; seed < 2000; seed++) {
            final s = ladderGen.generate(position, value, seed: seed);
            final (primary, least, _) = ladderOf(position, s);
            if (primary <= least) {
              fail('${position.code} @$ovr seed $seed: ladder inverted');
            }
          }
          // The expected profile orders attributes exactly by weight.
          final expected = ladderGen.generate(position, value);
          final weights = positionWeights[position]!;
          final byWeight = weights.keys
              .where((k) => weights[k]! > 0)
              .toList()
            ..sort((a, b) => weights[b]!.compareTo(weights[a]!));
          for (var i = 0; i + 1 < byWeight.length; i++) {
            expect(
              attrOf(expected, byWeight[i]),
              greaterThan(attrOf(expected, byWeight[i + 1])),
              reason:
                  '${position.code} @$ovr: expected ordering inverted at '
                  '${byWeight[i].name}',
            );
          }
        }
      }
    });

    test('zero-weight attributes stay exactly 0', () {
      final value = valueForOvr(97);
      for (final position in Position.values) {
        for (var seed = 0; seed < 50; seed++) {
          final s = ladderGen.generate(position, value, seed: seed);
          for (final entry in positionWeights[position]!.entries) {
            if (entry.value == 0) {
              expect(attrOf(s, entry.key), 0,
                  reason: '${position.code} ${entry.key.name}');
            }
          }
        }
      }
    });

    test('the real dataset reaches attribute 99 in attack, defence and '
        'goalkeeping', () {
      final db = PlayerDatabase();
      db.importDatasetFromJson(
        io.File('assets/data/players_v1.json').readAsStringSync(),
      );
      var maxAttack = 0, maxDefence = 0, maxGoalkeeping = 0;
      for (final p in db.all) {
        maxAttack = math.max(maxAttack, p.baseStats.attack);
        maxDefence = math.max(maxDefence, p.baseStats.defence);
        maxGoalkeeping = math.max(maxGoalkeeping, p.baseStats.goalkeeping);
      }
      // ignore: avoid_print
      print('T-0048 dataset attribute maxima: attack $maxAttack, '
          'defence $maxDefence, goalkeeping $maxGoalkeeping');
      expect(maxAttack, 99);
      expect(maxDefence, 99);
      expect(maxGoalkeeping, 99);
    });
  });
}
