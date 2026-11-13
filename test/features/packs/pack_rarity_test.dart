// Pack rarity partition + odds configuration tests (T-0058).
//
// The four-band partition (RARE < 70, EPIC 70–79, LEGENDARY 80–89,
// PREMIUM 90+) is derived from OVR, never assigned. The dataset
// partition test runs the REAL import pipeline (PlayerDatabase →
// BaseStatsGenerator seeded per player id — the same `baseStats.overall`
// packs will see), prints the four pool sizes and shares, and band-locks
// them: the bands absorb the seeded quality noise (T-0049 measured 31
// premium, T-0047 measured 493 gold) and any small curve retune, while a
// mis-wired partition (off-by-one threshold, wrong band order) blows
// straight through them.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/ui/fcm_style.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart';
import 'package:fcm_rivals/features/packs/pack_rarity.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import '../../tm_bundle_io.dart'
    show loadTmDataset;


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('four-band partition on the real dataset', () {
    late List<int> overalls;

    setUpAll(() async {
      // Loaded on the platform thread: runAsync needs a Future-returning
      // closure and the bundle read is fast enough here.
      final dataset = loadTmDataset();
      final registry = PlayerDatabase();
      registry.importDataset(dataset);
      overalls = [
        for (final p in registry.all) p.baseStats.overall,
      ];
    });

    test('the four pool sizes print and band-lock', () {
      final pools = <PackRarity, int>{
        for (final band in PackRarity.values)
          band: overalls.where((o) => PackRarity.fromOverall(o) == band).length,
      };
      final premium = pools[PackRarity.premium]!;
      final legendary = pools[PackRarity.legendary]!;
      final epic = pools[PackRarity.epic]!;
      final rare = pools[PackRarity.rare]!;
      final gold = legendary + premium;

      // ignore: avoid_print
      print('T-0058 dataset partition (${overalls.length} rows): '
          'rare $rare (${(rare / overalls.length * 100).toStringAsFixed(2)}%)'
          ' | epic $epic (${(epic / overalls.length * 100).toStringAsFixed(2)}%)'
          ' | legendary $legendary '
          '(${(legendary / overalls.length * 100).toStringAsFixed(2)}%)'
          ' | premium $premium '
          '(${(premium / overalls.length * 100).toStringAsFixed(3)}%)'
          ' | gold $gold');

      // Curve-based references — the tm bundle (T-0124 F6 update,
      // supersedes the 2026-11-08 v3 numbers): premium 133, gold
      // ~597. The wider elite bands carry the deeper pool; the
      // wide bands keep their ±5% retune absorption.
      expect(premium, inInclusiveRange(120, 150),
          reason: 'the premium band must stay rare but non-empty');
      expect(gold, inInclusiveRange(560, 640),
          reason: 'the gold (legendary + premium) band carries the '
              'tm bundle\'s deeper elite pool');
      expect(legendary, gold - premium,
          reason: 'the bands partition — no overlap, no gaps');
      expect(epic, inInclusiveRange(1984, 2192),
          reason: 'epic must stay within ±5% of the curve-based 2,088');
      expect(rare, inInclusiveRange(17380, 19210),
          reason: 'rare must stay within ±5% of the curve-based 18,295');
      expect(rare + epic + legendary + premium, overalls.length,
          reason: 'every row lands in exactly one band');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('boundary edges (owner spec)', () {
    test('OVR 69/70/79/80/89/90 land in the documented bands', () {
      expect(PackRarity.fromOverall(69), PackRarity.rare);
      expect(PackRarity.fromOverall(70), PackRarity.epic);
      expect(PackRarity.fromOverall(79), PackRarity.epic);
      expect(PackRarity.fromOverall(80), PackRarity.legendary);
      expect(PackRarity.fromOverall(89), PackRarity.legendary);
      expect(PackRarity.fromOverall(90), PackRarity.premium);
    });

    test('the premium band and the red premium card share one threshold',
        () {
      // T-0047 bound the gold band to the card colour the same way: the
      // probability partition and the rendering threshold can never
      // drift apart silently.
      expect(defaultPackOddsConfig.premiumMinOverall,
          CardClass.premiumOverallThreshold);
      expect(defaultPackOddsConfig.premiumMinOverall, 90);
    });

    test('the legendary band and the gold rule share one threshold', () {
      expect(
        defaultPackOddsConfig.legendaryMinOverall,
        PackEngine.legendaryOverall,
      );
    });
  });

  group('PackOddsConfig validation', () {
    test('every default table sums to exactly 1 within 1e-9', () {
      // validate() throws on any bad table; the explicit sums are the
      // readable proof the reviewer asks for.
      defaultPackOddsConfig.validate();
      for (final tier in PackTier.values) {
        final t = defaultPackOddsConfig.oddsFor(tier);
        final sum = t.rare + t.epic + t.legendary + t.premium;
        expect(sum, closeTo(1.0, 1e-9), reason: '${tier.name} pack table');
        for (final w in [t.rare, t.epic, t.legendary, t.premium]) {
          expect(w, inInclusiveRange(0.0, 1.0));
        }
      }
    });

    test('premium stays exclusive to Legendary packs (owner matrix)', () {
      expect(defaultPackOddsConfig.rarePack.premium, 0.0);
      expect(defaultPackOddsConfig.epicPack.premium, 0.0);
      expect(defaultPackOddsConfig.legendaryPack.premium, greaterThan(0.0));
    });

    test('the owner matrix values are exactly the spec numbers', () {
      final rare = defaultPackOddsConfig.rarePack;
      final epic = defaultPackOddsConfig.epicPack;
      final legendary = defaultPackOddsConfig.legendaryPack;
      expect((rare.rare, rare.epic, rare.legendary, rare.premium),
          (0.75, 0.20, 0.05, 0.0));
      expect((epic.rare, epic.epic, epic.legendary, epic.premium),
          (0.40, 0.50, 0.10, 0.0));
      expect(
          (legendary.rare, legendary.epic, legendary.legendary,
              legendary.premium),
          (0.00, 0.55, 0.43, 0.02));
    });

    test('a broken table throws from validate() in any build', () {
      // The const constructor only asserts the band ordering (constant
      // expressions only); table sanity is validate()'s job so it holds
      // in release builds too.
      const overflowing = PackOddsConfig(
        rarePack: (rare: 1.2, epic: 0.0, legendary: 0.0, premium: 0.0),
      );
      expect(() => overflowing.validate(), throwsArgumentError);
      const drifting = PackOddsConfig(
        epicPack: (rare: 0.4, epic: 0.5, legendary: 0.1, premium: 0.01),
      );
      expect(() => drifting.validate(), throwsArgumentError);
      const valid = PackOddsConfig();
      expect(() => valid.validate(), returnsNormally);
    });

    test('the pity placeholder stays null (unused until T-0059/T-0060)',
        () {
      expect(defaultPackOddsConfig.pityGuaranteedRarityPulls, isNull);
    });
  });

  group('weightFor guards (owner formula)', () {
    test('the pure formula: (poolMinMv / mv)^exponent', () {
      expect(
        weightFor(marketValueEur: 4_000_000, poolMinMarketValueEur: 1_000_000,
            exponent: 1.5),
        closeTo(math.pow(0.25, 1.5).toDouble(), 1e-12),
      );
      // A candidate at the pool floor weighs exactly 1.
      expect(
        weightFor(marketValueEur: 1_000_000, poolMinMarketValueEur: 1_000_000,
            exponent: 1.5),
        1.0,
      );
      // Below the floor legitimately weighs MORE than 1 (relative).
      expect(
        weightFor(marketValueEur: 500_000, poolMinMarketValueEur: 1_000_000,
            exponent: 1.0),
        2.0,
      );
    });

    test('degenerate inputs clamp instead of producing NaN/Infinity', () {
      // mv ≤ 0 clamps to 1 before dividing.
      var w = weightFor(
        marketValueEur: 0,
        poolMinMarketValueEur: 1_000_000,
        exponent: 1.5,
      );
      expect(w.isFinite, isTrue);
      // poolMinMv ≤ 0 clamps to 1.
      w = weightFor(
        marketValueEur: 2_000_000,
        poolMinMarketValueEur: 0,
        exponent: 1.5,
      );
      expect(w.isFinite, isTrue);
      // Both degenerate → 1^exponent = 1.
      expect(
        weightFor(marketValueEur: 0, poolMinMarketValueEur: 0, exponent: 1.5),
        1.0,
      );
      w = weightFor(
        marketValueEur: -5,
        poolMinMarketValueEur: -5,
        exponent: 2.0,
      );
      expect(w.isNaN, isFalse);
      expect(w.isInfinite, isFalse);
      expect(w >= 0, isTrue);
    });

    test('the default exponent is the owner value', () {
      expect(defaultPackOddsConfig.marketValueExponent, 1.5);
    });
  });
}
