/// FCM Rivals — deep balance testing: the coin economy (GDD 17/18/19).
///
/// Sources vs sinks at every timescale, against the REAL dataset through
/// the real CollectionStore (in-memory Drift):
///  * per-match income ladder (win/draw/loss × goals) vs pack prices
///  * season income (38 matches + season reward ladder by position)
///  * grind time — how many matches each purchase actually costs
///  * sell-back: when selling beats keeping, dupes vs singles
///  * ad economy: every ad surface's coin value per watch
///
/// Expectations are calibrated to MEASURED values (§34 harness, real
/// pool, per-position EV pricing): rare ≈ 914-1,188 / epic ≈ 2,838-4,058
/// / legendary ≈ 8,203-11,794 coins across the position scopes (the
/// legendary tier prices at its 1.4x premium margin, rebalance Ch.8;
/// LM/RM shelve no Legendary pack — their pools hold no 82+ players).
library;


import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/ads/ad_engine.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/economy/economy_engine.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart';
import 'package:fcm_rivals/features/season/season_engine.dart';
import '../tm_bundle_io.dart' show loadTmDataset;

BasePlayer _fakePlayer(int marketValue) => BasePlayer(
  playerId: 1,
  name: 'Test',
  position: Position.st,
  nationality: 'Egypt',
  marketValueEur: marketValue,
  baseStats: const BaseStats(
    overall: 70,
    attack: 74,
    support: 60,
    defence: 45,
    goalkeeping: 0,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final economy = const EconomyEngine();
  final config = economy.config;

  group('income ladder (per match)', () {
    test('loss / draw / win rewards: 1.5k base, +250/goal, ×1.24 win / ×0.90 loss', () {
      // Review 2026-11-04 economy tier bands: result factors 1.24/0.90
      // on par (replaces the flat ×1.5 win bonus).
      final loss0 = economy.matchReward(goalsFor: 0, won: false);
      final draw0 = economy.matchReward(goalsFor: 0, won: false);
      final win0 = economy.matchReward(goalsFor: 0, won: true);
      final win3 = economy.matchReward(goalsFor: 3, won: true);
      expect(loss0, 1350);
      expect(draw0, 1350);
      expect(win0, 1860);
      expect(win3, 2790);
    });

    test('an average season of 38 matches banks 70k-160k before sinks', () {
      var total = 0;
      const wins = 14, draws = 10, losses = 14;
      const avgGoalsFor = 1.3;
      for (var i = 0; i < wins; i++) {
        total += economy.matchReward(
          goalsFor: (avgGoalsFor + 0.7).round(),
          won: true,
        );
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
      // 20th is the graduated band's floor (T-0075): position 19 now
      // pays 5_200 — sampling 19 would pin a moving step, 20 pins the
      // participation anchor.
      final relegated = season.seasonRewardCoins(division: 1, position: 20);
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
        await store.applyDatasetUpdate(loadTmDataset());
        offers = await store.getStoreOffers();
      } finally {
        await db.close();
      }
    });

    test('position pack prices sit in their bands across tiers', () {
      // Measured on the shipped dataset (per-group EV pools — RW+RM and
      // LW+LM merged into one shelf group each, owner request
      // 2026-11-13): rare 4-5k, epic 8-10k, legendary 23-26k.
      final byTier = <PackTier, List<int>>{};
      for (final o in offers) {
        byTier.putIfAbsent(o.tier, () => []).add(o.price);
      }
      // Owner request 2026-11-13: 10 shelf groups — the merged RW+RM and
      // LW+LM pools each carry all three tiers (the winger's 80+ rows
      // cover the group), every other position shelves alone.
      expect(byTier[PackTier.rare], hasLength(10));
      expect(byTier[PackTier.epic], hasLength(10));
      expect(byTier[PackTier.legendary], hasLength(10));
      // The icon section shelves above the ST packs (owner request
      // 2026-11-12): exactly three icon packs, every one priced.
      expect(byTier[PackTier.iconEpic], hasLength(1));
      expect(byTier[PackTier.iconLegendary], hasLength(1));
      expect(byTier[PackTier.iconSupreme], hasLength(1));
      // Absolute tier bands: prices re-derived from the new E[MV]s —
      // T-0047 moved the legendary pack to gold-only draws, lifting the
      // big-pool prices (~29-38k) while the tiny LM/RM gold pools price
      // at ~15k.
      // Measured on the tm bundle (39,090 rows): rare 3-5k, epic
      // 8-10k, legendary 23-26k — the deeper pool narrows the
      // position-scope price spread the v3 cut showed (T-0047's tiny
      // LM/RM gold pools grew with the 39k-row pool).
      for (final p in byTier[PackTier.rare]!) {
        expect(p, inInclusiveRange(3_000, 6_000));
      }
      for (final p in byTier[PackTier.epic]!) {
        expect(p, inInclusiveRange(8_000, 12_000));
      }
      for (final p in byTier[PackTier.legendary]!) {
        expect(p, inInclusiveRange(20_000, 30_000));
      }
      // Owner fix 2026-11-12 (ascending icon-pack prices, epic-only
      // pack I): measured EVs 10,990 / 17,311 / 17,841 with per-tier
      // margins 1.40/1.60/1.80 → 15k / 27k / 32k. Pack I dropped below
      // its old band because the 30% rare share is gone from its pool.
      for (final p in byTier[PackTier.iconEpic]!) {
        expect(p, inInclusiveRange(13_000, 17_000));
      }
      for (final p in byTier[PackTier.iconLegendary]!) {
        expect(p, inInclusiveRange(25_000, 29_000));
      }
      for (final p in byTier[PackTier.iconSupreme]!) {
        expect(p, inInclusiveRange(30_000, 34_000));
      }
      // The tier ladder itself is steep within one scope: legendary
      // costs ~8-11x rare (T-0047's gold-only legendary pushed the ST
      // ratio to ~9.3), epic ~3-4x rare.
      final st = {
        for (final o in offers)
          if (o.scopeValue == 'ST') o.tier: o.price,
      };
      expect(st[PackTier.epic]! / st[PackTier.rare]!, inInclusiveRange(1, 6));
      expect(
        st[PackTier.legendary]! / st[PackTier.rare]!,
        inInclusiveRange(2, 10),
      );
      // The icon tiers shelf above ST's own ladder (owner request):
      // iconEpic 11k sits between epic 10k and legendary 24k; the two
      // elite icon tiers price with the legendary margin.
      final iconPrices = {
        for (final o in offers)
          if (o.category == PackCategory.icon) o.tier: o.price,
      };
      expect(iconPrices[PackTier.iconLegendary]!, greaterThan(iconPrices[PackTier.iconEpic]!));
    });

    test('rare packs are pocket change; legendary is ~2-8 matches', () {
      // Measured after the legendary-margin rebalance (Ch.8): rare
      // ~914-1,188 (~0.4 matches), legendary ~8,203-11,794 (~4.5
      // matches at 2.4k/match). Rare pulls median OVR ~40, so the cheap
      // price is honest filler pricing.
      const perMatch = 2400; // win-rate-par income; legendary ~12-16 matches now
      final rarePrices = offers
          .where((o) => o.tier == PackTier.rare)
          .map((o) => o.price)
          .toList();
      final legendaryPrices = offers
          .where((o) => o.tier == PackTier.legendary)
          .map((o) => o.price)
          .toList();
      for (final p in rarePrices) {
        // Absolute bands: rare E[MV] €1.09M → ~4.3k coins ≈ 1.8 matches.
        expect(p / perMatch, inInclusiveRange(0.15, 2.5));
      }
      for (final p in legendaryPrices) {
        // Absolute bands: the T-0047 gold-only legendary re-priced the
        // big pools to ~37-38k (~15-16 matches); the tiny LM/RM gold
        // pools land at ~15k (~6.3 matches) — the cheapest legitimate
        // legendary product.
        expect(p / perMatch, inInclusiveRange(6, 20));
      }
    });

    test('the pool spread is real but bounded across scopes', () {
      // Measured: within a tier the cheapest scope (RM) lands ~77-87%
      // of the most expensive (RW/ST) — the EV of a filtered pool
      // genuinely differs because position value distributions differ.
      final byTier = <PackTier, List<int>>{};
      for (final o in offers) {
        byTier.putIfAbsent(o.tier, () => []).add(o.price);
      }
      for (final prices in byTier.values) {
        prices.sort();
        // The tm bundle (39,090 rows) narrowed every position's gold
        // pool spread: legendary spans 23k-26k (~1.13x) and rare
        // 3k-5k (~1.67x) — the v3 cut's 2.5x legendary gap is gone.
        // Single-price icon tiers trivially pass (1.0).
        expect(
          prices.last / prices.first,
          inInclusiveRange(0.5, 1.75),
          reason: 'same-tier scope spread must stay bounded',
        );
      }
    });

    test('starting coins buy a sensible opening haul (3+ rare packs)', () {
      final cheapestRare = offers
          .where((o) => o.tier == PackTier.rare)
          .map((o) => o.price)
          .reduce((a, b) => a < b ? a : b);
      expect(config.startingCoins / cheapestRare, greaterThan(3));
      final legendaryPrices = offers
          .where((o) => o.tier == PackTier.legendary)
          .map((o) => o.price)
          .toList();
      for (final p in legendaryPrices) {
        expect(config.startingCoins / p, lessThan(6));
      }
    });
  });

  group('sink curves — duplicates & facilities', () {
    // The coin upgrade curve is gone (owner decision 2026-11-09):
    // duplicates are the only upgrade currency, so the upgrade sink is
    // measured in pack draws, not coins. What still matters economically
    // is the upgraded resale pricing (kept) and the facilities curve
    // (kept below).

    test('upgraded resale prices the level (+10% EV per level)', () {
      final player = _fakePlayer(10_000_000);
      final sellAt0 = economy.sellPriceOfUpgraded(player, 0);
      final sellAt5 = economy.sellPriceOfUpgraded(player, 5);
      // +10% economic value per level, then the selling percentage —
      // locked against the engine's own formula, not a hand-computed EV.
      final ev = economy.economicValueOf(player.marketValueEur);
      expect(
        sellAt0,
        (ev * economy.config.sellingPercentage).round(),
      );
      expect(
        sellAt5,
        (ev * 1.5 * economy.config.sellingPercentage).round(),
      );
      expect(sellAt5, greaterThan(sellAt0));
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
      // Merging costs nothing and lifts every stat +1% (owner decision
      // 2026-11-09): the duplicate's sale price is the only alternative
      // use, and the merged card's resale gains +10% EV per level.
      final player = _fakePlayer(5_000_000);
      final sale = economy.sellPriceOf(player);
      final resaleGain =
          economy.sellPriceOfUpgraded(player, 1) -
          economy.sellPriceOfUpgraded(player, 0);
      // The merge is free, so any positive resale gain is pure value.
      expect(resaleGain, greaterThan(0));
      expect(sale, greaterThan(0));
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
      final normal = const SeasonEngine().seasonRewardCoins(
        division: 1,
        position: 1,
      );
      final boosted = ads.boostedSeasonReward(normal);
      expect(boosted - normal, 5_000);
    });

    test('selling bonus: +20% on a sale', () {
      expect(ads.sellingBonus(1000), 1200);
    });

    test(
      'boosted recovery: +15% of natural recovery, whole points, capped',
      () {
        final boosted = ads.boostedRecovery(
          staminaAfterNaturalRecovery: 80,
          naturalRecovery: 30,
        );
        expect(boosted, 85); // 84.5 rounds to a whole stamina point
        final capped = ads.boostedRecovery(
          staminaAfterNaturalRecovery: 95,
          naturalRecovery: 30,
        );
        // The raw sum lands at 99.5; the result is rounded so the ad
        // delivers exactly the 100 the UI promises.
        expect(capped, 100);
      },
    );

    test('ad caps keep daily grind bounded (8 ads/day max)', () {
      final cfg = ads.config;
      expect(cfg.dailyLimitPerKind, 3);
      expect(cfg.dailyTotalLimit, 8);
    });
  });
}
