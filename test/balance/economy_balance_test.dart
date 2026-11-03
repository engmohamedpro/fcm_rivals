/// FCM Rivals — deep balance testing: the coin economy (GDD 17/18/19).
///
/// Sources vs sinks at every timescale, against the REAL dataset through
/// the real CollectionStore (in-memory Drift):
///  * per-match income ladder (win/draw/loss × goals) vs pack prices
///  * season income (38 matches + season reward ladder by position)
///  * sinks: pack tiers, upgrade curve, facility curve
///  * grind time — how many matches each purchase actually costs
///  * sell-back: when selling beats keeping, dupes vs singles
///  * ad economy: every ad surface's coin value per watch
///
/// Expectations are calibrated to MEASURED values (§34 harness, real
/// pool): rare ≈ 1,046 / epic ≈ 3,905 / legendary ≈ 11,358 coins (the
/// legendary tier prices at its 1.4x premium margin, rebalance Ch.8).
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/ads/ad_engine.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/economy/economy_engine.dart';
import 'package:fcm_rivals/features/facilities/facilities.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/features/season/season_engine.dart';

BasePlayer _fakePlayer(int marketValue) => BasePlayer(
      playerId: 1,
      name: 'Test',
      position: Position.st,
      nationality: 'Egypt',
      marketValueEur: marketValue,
      baseStats: const BaseStats(
          overall: 70, attack: 74, support: 60, defence: 45, goalkeeping: 0),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final economy = const EconomyEngine();
  final config = economy.config;

  group('income ladder (per match)', () {
    test('loss / draw / win rewards: 1.5k base, +250/goal, ×1.5 on win', () {
      final loss0 = economy.matchReward(goalsFor: 0, won: false);
      final draw0 = economy.matchReward(goalsFor: 0, won: false);
      final win0 = economy.matchReward(goalsFor: 0, won: true);
      final win3 = economy.matchReward(goalsFor: 3, won: true);
      expect(loss0, 1500);
      expect(draw0, 1500);
      expect(win0, 2250);
      expect(win3, 3375);
    });

    test('an average season of 38 matches banks 70k-160k before sinks',
        () {
      var total = 0;
      const wins = 14, draws = 10, losses = 14;
      const avgGoalsFor = 1.3;
      for (var i = 0; i < wins; i++) {
        total += economy.matchReward(
            goalsFor: (avgGoalsFor + 0.7).round(), won: true);
      }
      for (var i = 0; i < draws; i++) {
        total += economy.matchReward(goalsFor: avgGoalsFor.round(), won: false);
      }
      for (var i = 0; i < losses; i++) {
        total += economy.matchReward(goalsFor: 1, won: false);
      }
      expect(total, inInclusiveRange(70_000, 160_000));
    });

    test('season reward ladder: champion > promoted > mid > relegated', () {
      final season = const SeasonEngine();
      final champion = season.seasonRewardCoins(division: 1, position: 1);
      final promoted2 = season.seasonRewardCoins(division: 1, position: 3);
      final mid = season.seasonRewardCoins(division: 1, position: 10);
      final relegated = season.seasonRewardCoins(division: 1, position: 19);
      expect(champion, greaterThan(promoted2));
      expect(promoted2, greaterThan(mid));
      expect(mid, greaterThan(relegated));
      expect(champion, 20_000);
      expect(relegated, 5_000);
      // A title win can never dwarf a season of match rewards.
      expect(champion, lessThan(0.25 * 90_000));
    });

    test('higher divisions pay more (ladder incentive)', () {
      final season = const SeasonEngine();
      final d1 = season.seasonRewardCoins(division: 1, position: 5);
      final d4 = season.seasonRewardCoins(division: 4, position: 5);
      expect(d4, greaterThan(d1));
      expect(d4, lessThan(d1 * 2));
    });
  });

  group('grind times — what a coin actually costs (real dataset)', () {
    late List<StorePackOffer> offers;
    setUpAll(() async {
      final db = AppDatabase(NativeDatabase.memory());
      try {
        final store = CollectionStore(db: db);
        await store.applyDatasetUpdate(
            PlayerDataset.fromJson(
                File('assets/data/players_v1.json').readAsStringSync()));
        offers = await store.getStoreOffers();
      } finally {
        await db.close();
      }
    });

    test('global pack prices sit in the 1k-30k band across tiers', () {
      // Measured on the shipped dataset: rare ~1,046, epic ~3,905,
      // legendary ~10,141 — EV-priced off the real pool.
      final globals = offers
          .where((o) => o.category == PackCategory.global)
          .toList()
        ..sort((a, b) => a.price.compareTo(b.price));
      expect(globals, hasLength(3));
      expect(globals.first.price, inInclusiveRange(600, 3_000));
      expect(globals.last.price, inInclusiveRange(6_000, 30_000));
      // The tier ladder itself is steep: legendary costs ~8-12x rare.
      expect(globals.last.price / globals.first.price,
          inInclusiveRange(6, 16));
    });

    test('rare packs are pocket change; legendary is ~2-8 matches', () {
      // Measured after the legendary-margin rebalance (Ch.8): rare
      // ~1,046 (~0.4 matches), legendary ~11,358 (~4.7 matches at
      // 2.4k/match; was 10,141/4.2 at the flat 1.25x margin). Rare pulls
      // median OVR ~40, so the cheap price is honest filler pricing.
      const perMatch = 2400;
      final rare = offers
          .firstWhere((o) =>
              o.category == PackCategory.global && o.tier == PackTier.rare)
          .price;
      final legendary = offers
          .firstWhere((o) =>
              o.category == PackCategory.global && o.tier == PackTier.legendary)
          .price;
      expect(rare / perMatch, inInclusiveRange(0.15, 1.5));
      expect(legendary / perMatch, inInclusiveRange(2, 8));
    });

    test('position packs track the global price with a real pool spread',
        () {
      // Measured (legendary tier): the RM pack lands ~58% of global, RW
      // ~104% — the EV of a filtered pool genuinely differs because
      // position value distributions differ (the RM pool is cheaper on
      // average). Kept as a measured band: 50%-115% of same-tier global.
      final globalByTier = {
        for (final o in offers.where((o) => o.category == PackCategory.global))
          o.tier: o.price,
      };
      for (final o
          in offers.where((o) => o.category == PackCategory.position)) {
        final reference = globalByTier[o.tier]!;
        expect(o.price, inInclusiveRange((reference * 0.50).round(),
            (reference * 1.15).round()),
            reason:
                '${o.title} at ${o.price} vs global ${o.tier.name} $reference');
      }
    });

    test('starting coins buy a sensible opening haul (3+ rare packs)', () {
      final rare = offers
          .firstWhere((o) =>
              o.category == PackCategory.global && o.tier == PackTier.rare)
          .price;
      expect(config.startingCoins / rare, greaterThan(3));
      final legendary = offers
          .firstWhere((o) =>
              o.category == PackCategory.global && o.tier == PackTier.legendary)
          .price;
      expect(config.startingCoins / legendary, lessThan(6));
    });
  });

  group('sink curves — upgrades & facilities', () {
    test('upgrade curve: affordable early, steep late, capped', () {
      final ev2m = economy.economicValueOf(2_000_000);
      final costs = [
        for (var level = 0; level < 5; level++)
          economy.upgradeCostOf(_fakePlayer(2_000_000), level),
      ];
      expect(costs[0], closeTo(ev2m * 0.35 * 1.5, 5));
      for (var i = 1; i < costs.length; i++) {
        expect(costs[i], closeTo(costs[i - 1] * 1.5, 2));
      }
      final total = costs.fold<int>(0, (a, c) => a + c);
      expect(total, inInclusiveRange(10_000, 120_000));
      final star = economy.upgradeCostOf(_fakePlayer(50_000_000), 0);
      expect(star, greaterThan(15_000));
    });

    test('sell-after-upgrade never exceeds the coins spent upgrading', () {
      final player = _fakePlayer(10_000_000);
      var spent = 0;
      for (var level = 0; level < 5; level++) {
        spent += economy.upgradeCostOf(player, level);
      }
      final sellAt5 = economy.sellPriceOfUpgraded(player, 5);
      expect(sellAt5, lessThan(spent));
      // Measured: a fully-upgraded €10M player resells at ~13% of the
      // coins invested in his levels — upgrades are a pure progression
      // sink, never a money loop. Kept ≥ 8% so resale stays non-zero
      // but clearly value-losing.
      expect(sellAt5, greaterThan(spent * 0.08));
    });

    test('facility curve: first level cheap, full building a season project',
        () {
      const costs = defaultFacilitiesCosts;
      final level1 = costs.upgradeCost(0);
      final level10 = costs.upgradeCost(9);
      expect(level1, 4_000); // ~2 match rewards
      expect(level10, greaterThan(80_000));
      final full = costs.investedAt(10);
      // Rebalanced (Ch.8): the final three levels taper (1.22 instead of
      // 1.55), so one building's full 10 levels ≈ 400k and the whole
      // 6-building campus ≈ 2.4M — at ~90k net season income that's a
      // 20+ season project: still the deepest sink in the game, but a
      // finishable one. Was ~575k/3.45M (~38 seasons) before the taper.
      expect(full, inInclusiveRange(380_000, 440_000));
      expect(full * 6, inInclusiveRange(2_280_000, 2_640_000));
    });

    test('facility payoff is slight by design: level 5 ≈ +4.5% attribute',
        () {
      const costs = defaultFacilitiesCosts;
      final invested5 = costs.investedAt(5);
      expect(invested5, inInclusiveRange(15_000, 60_000));
    });

    test('regression lock: campus stays a deep but finishable sink', () {
      // The Ch.8 rebalance bands, as hard numbers: a full building
      // within ±10% of 400k, the campus within ±10% of 2.4M. Failing
      // this means the facility curve regressed to the unreachable
      // ~575k-per-building (or collapsed to a shallow sink).
      const costs = defaultFacilitiesCosts;
      expect(costs.investedAt(10), inInclusiveRange(360_000, 440_000));
      expect(costs.investedAt(10) * 6, inInclusiveRange(2_160_000, 2_640_000));
      // Levels 1-7 unchanged from the original curve.
      expect(costs.upgradeCost(0), 4_000);
      expect(costs.upgradeCost(6), 55_500);
    });
  });

  group('sell-back & duplicate decisions', () {
    test("selling a duplicate recovers 60% EV vs the pack's 125% price", () {
      final ev = 6_000.0; // a €2M pull
      final price = ev * config.packMarginMultiplier;
      final loss = price - ev * config.sellingPercentage;
      expect(loss / price, inInclusiveRange(0.4, 0.6));
    });

    test('merging a duplicate is free value vs selling it', () {
      final player = _fakePlayer(5_000_000);
      final sale = economy.sellPriceOf(player);
      final upgradeCost = economy.upgradeCostOf(player, 0);
      expect(upgradeCost, greaterThan(sale * 0.8));
    });
  });

  group('ad economy (GDD 19) — value per watch', () {
    const ads = AdEngine();

    test('daily reward multiplier: +50% of one match reward ≈ +1.2k', () {
      final normal = economy.matchReward(goalsFor: 1, won: true);
      final boosted = ads.boostedMatchReward(normal);
      expect(boosted - normal, closeTo(normal * 0.5, 1));
      expect(boosted - normal, inInclusiveRange(800, 2_000));
    });

    test('season multiplier: +25% of a season reward — the biggest ad', () {
      final normal =
          const SeasonEngine().seasonRewardCoins(division: 1, position: 1);
      final boosted = ads.boostedSeasonReward(normal);
      expect(boosted - normal, 5_000);
    });

    test('upgrade discount: 20% off, floored at 50 coins', () {
      expect(ads.discountedUpgradeCost(1000), 800);
      expect(ads.discountedUpgradeCost(40), 40);
      expect(ads.discountedUpgradeCost(50), 50);
    });

    test('selling bonus: +20% on a sale', () {
      expect(ads.sellingBonus(1000), 1200);
    });

    test('boosted recovery: +15% of natural recovery, whole points, capped',
        () {
      final boosted = ads.boostedRecovery(
          staminaAfterNaturalRecovery: 80, naturalRecovery: 30);
      expect(boosted, 85); // 84.5 rounds to a whole stamina point
      final capped = ads.boostedRecovery(
          staminaAfterNaturalRecovery: 95, naturalRecovery: 30);
      // The raw sum lands at 99.5; the result is rounded so the ad
      // delivers exactly the 100 the UI promises.
      expect(capped, 100);
    });

    test('ad caps keep daily grind bounded (8 ads/day max)', () {
      final cfg = ads.config;
      expect(cfg.dailyLimitPerKind, 3);
      expect(cfg.dailyTotalLimit, 8);
    });
  });
}
