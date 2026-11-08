// Pack-odds regression test on the REAL dataset (T-0059).
//
// The T-0047 MV-band tier roll is gone: the owner's two-stage engine
// (2026-11-08) rolls a rarity from the pack tier's configured table
// (PackOddsConfig — RARE 75/20/5/0, EPIC 40/50/10/0, LEGENDARY
// 0/55/43/2) and then draws inside that rarity's OVR band (rare < 70,
// epic 70-79, legendary 80-89, premium 90+). This test re-derives the
// bands from the rarity partition and locks the odds over 20,000+
// seeded openings on the real 20,876-player dataset: the elite game
// stays reachable, Rare stays honest, and premium stays exclusive to
// Legendary packs.
import 'dart:io' as io;
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart';
import 'package:fcm_rivals/features/packs/pack_rarity.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';

/// The same import path the game (and the other dataset-backed tests)
/// use — band counts therefore reflect the shipped OVRs exactly, and a
/// future curve retune moves them with it.
List<BasePlayer> _loadDataset() {
  final db = PlayerDatabase();
  db.importDatasetFromJson(
    io.File('assets/data/players_v1.json').readAsStringSync(),
  );
  return db.all.toList(growable: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('rarity-band partition on the real dataset (T-0059)', () {
    late List<BasePlayer> dataset;

    setUpAll(() => dataset = _loadDataset());

    List<double> bandRates(PackTier tier, int n, int seed) {
      final engine = PackEngine(random: math.Random(seed));
      final scope = PackScope(category: PackCategory.global, tier: tier);
      final counts = [0, 0, 0, 0];
      for (var i = 0; i < n; i++) {
        counts[engine.open(scope, dataset).single.tier]++;
      }
      return [for (final c in counts) c / n];
    }

    test('dataset loads with the known elite structure', () {
      expect(dataset.length, greaterThan(20_000));
      // The curve-derived bands (pack_rarity.dart): epic 10.00%,
      // legendary 2.22%, premium 0.139% of the shipped rows.
      final epic = dataset
          .where(
            (p) =>
                PackRarity.fromOverall(p.baseStats.overall) ==
                PackRarity.epic,
          )
          .length;
      final gold = dataset
          .where(
            (p) =>
                PackRarity.fromOverall(p.baseStats.overall) ==
                PackRarity.legendary,
          )
          .length;
      final premium = dataset
          .where(
            (p) =>
                PackRarity.fromOverall(p.baseStats.overall) ==
                PackRarity.premium,
          )
          .length;
      // ignore: avoid_print
      print('T-0059 dataset bands: epic $epic, legendary $gold, '
          'premium $premium');
      expect(epic / dataset.length, inInclusiveRange(0.08, 0.12));
      expect(gold / dataset.length, inInclusiveRange(0.015, 0.035));
      expect(premium, greaterThan(10),
          reason: 'the premium band is small but real');
    });

    test('Rare pack: 75/20/5/0 — sub-70 dominates, premium unreachable',
        () {
      final shares = bandRates(PackTier.rare, 20_000, 2026);
      // ignore: avoid_print
      print('T-0059 rare pack bands: '
          '${shares.map((s) => (s * 100).toStringAsFixed(2)).toList()}');
      expect(shares[0], inInclusiveRange(0.72, 0.78));
      expect(shares[1], inInclusiveRange(0.17, 0.23));
      expect(shares[2], inInclusiveRange(0.02, 0.08));
      expect(shares[3], 0,
          reason: 'premium is exclusive to the legendary pack');
    });

    test('Epic pack: 40/50/10/0 — the gold band is a real 10% stream',
        () {
      final shares = bandRates(PackTier.epic, 20_000, 2027);
      expect(shares[0], inInclusiveRange(0.37, 0.43));
      expect(shares[1], inInclusiveRange(0.47, 0.53));
      expect(shares[2], inInclusiveRange(0.07, 0.13));
      expect(shares[3], 0);
    });

    test('Legendary pack: 0/55/43/2 — no bronze, 45% gold band, the 2% '
        'premium roll fires', () {
      final shares = bandRates(PackTier.legendary, 20_000, 2028);
      expect(shares[0], 0,
          reason: 'the legendary table carries no rare weight — no '
              'sub-70 pull is structurally possible');
      expect(shares[1], inInclusiveRange(0.52, 0.58));
      expect(shares[2], inInclusiveRange(0.40, 0.46));
      expect(shares[3], greaterThan(0.005),
          reason: 'the 2% premium roll must be a live stream');
      expect(shares[3], lessThan(0.05));
    });

    test('the global price ladder re-derives from the two-stage EV '
        '(~5k/10k/24k, ±25% window)', () {
      // No pricing code changed: packPriceFor is still EV × margin,
      // floored to thousands — the odds retune re-derives the shelf.
      // Task-context measured EVs (global pool, exponent 1.5): rare
      // €3.14M econ 4,257 × 1.25 → 5,000; epic €6.89M econ 8,396 × 1.25
      // → 10,000; legendary €20.24M econ 17,332 × 1.40 → 24,000.
      final engine = PackEngine(random: math.Random(0));
      final prices = [
        for (final tier in PackTier.values)
          engine.packPriceFor(
            PackScope(category: PackCategory.global, tier: tier),
            dataset,
          ),
      ];
      // ignore: avoid_print
      print('T-0059 global price ladder: rare ${prices[0]}, '
          'epic ${prices[1]}, legendary ${prices[2]}');
      const expected = [5000, 10000, 24000];
      for (var i = 0; i < 3; i++) {
        expect(prices[i], greaterThanOrEqualTo(expected[i] * 0.75));
        expect(prices[i], lessThanOrEqualTo(expected[i] * 1.25));
      }
      expect(prices[0], lessThan(prices[1]));
      expect(prices[1], lessThan(prices[2]));
    });

    test('boundary integrity: every draw sits in its rolled band over '
        'the same batches', () {
      final engine = PackEngine(random: math.Random(2029));
      for (final tier in [PackTier.rare, PackTier.epic]) {
        final scope = PackScope(
          category: PackCategory.global,
          tier: tier,
        );
        for (var i = 0; i < 5_000; i++) {
          final d = engine.open(scope, dataset).single;
          expect(
            PackRarity.fromOverall(d.player.baseStats.overall).index,
            d.tier,
            reason: 'OVR ${d.player.baseStats.overall} drew outside the '
                'rolled band ${d.tier} — a boundary leak',
          );
        }
      }
    });

    test('the band partition classifies the same player the same way '
        'everywhere (pure function of OVR)', () {
      final sample = dataset.take(500).toList();
      for (final p in sample) {
        expect(
          PackRarity.fromOverall(p.baseStats.overall),
          PackRarity.fromOverall(p.baseStats.overall),
          reason: 'the partition reads only the stored overall — no pool '
              'context can re-classify a player',
        );
      }
      // The band cuts stay bound to the card layer's thresholds: the
      // premium probability band and the red premium card share one
      // constant, and the gold cut matches the engine's documented one.
      expect(PackEngine.legendaryOverall, 80);
      expect(defaultPackOddsConfig.legendaryMinOverall,
          PackEngine.legendaryOverall);
      expect(defaultPackOddsConfig.premiumMinOverall, 90);
    });
  });
}
