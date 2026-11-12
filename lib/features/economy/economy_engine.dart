/// FCM Rivals — Economy Engine (GDD 17, FR-009..FR-016).
///
/// Centralised, configuration-driven economy: economic value conversion,
/// selling prices (base and upgraded), upgrade costs and match rewards.
/// All numbers are pre-balance placeholders living in [EconomyConfig],
/// gathered in one place for simulation-driven tuning (GDD rule 14).
///
/// Pack pricing and odds parameters also live in [EconomyConfig]; the
/// tier-aware calculations live in the Pack Engine where the draw mechanics
/// are (GDD 17.1: the Economy Engine controls the parameters).
library;

import 'dart:math' as math;

import '../../core/domain/players.dart';

/// Tunable economy parameters (GDD 27).
class EconomyConfig {
  const EconomyConfig({
    this.valueReferenceEur = 50_000_000,
    // Calibrated by the §30 economy simulation: a full season (38 match
    // rewards + season reward) banks roughly 70–150k Coins, so the
    // reference economic value must live in that world — €50M ≈ 30k
    // Coins. The previous 10M anchor made dynamic pack prices (GDD 5.5)
    // cost ~5,900 match rewards, i.e. unbuyable forever.
    this.economicValueAtReference = 30_000,
    this.valueGrowthExponent = 0.5,
    this.minEconomicValue = 5,
    this.maxEconomicValue = 600_000,
    this.sellingPercentage = 0.6,
    this.packMarginMultiplier = 1.25,
    // Rebalance Ch.8: at the flat 1.25x margin a Legendary pack was the
    // cheapest power-per-coin purchase in the store (~4.2 matches per
    // elite pull vs 7+ for Rare/Epic), so the elite tier pays its own
    // premium. 1.40x lands it at ~4.7 matches — still the best deal per
    // pull, but no longer a dominant strategy.
    this.legendaryPackMarginMultiplier = 1.40,
    // Icon-tier margins (owner fix 2026-11-12: ascending icon-pack
    // prices, first lowest, third highest). Measured EVs on the shipped
    // bundle are 10,990 / 17,311 / 17,841 — II and III sit close, so a
    // shared margin rounds them onto the same plate. These margins
    // ladder the shelf 15k < 27k < 32k, every tier above the ST
    // Legendary pack (24k), each price still pure EV × margin.
    this.iconEpicPackMarginMultiplier = 1.40,
    this.iconLegendaryPackMarginMultiplier = 1.60,
    this.iconSupremePackMarginMultiplier = 1.80,
    this.baseMatchReward = 1_500,
    this.matchRewardPerGoal = 250,
    // Performance-driven income spread (review
    // 2026-11-04_economy_pack-tier-bands-and-elite-ceiling): rewards
    // must visibly answer the result. Losses pay 80-90% of the par
    // reward, wins 120-135% — a ~±20% band around par measured END-TO-END
    // (result factor + the goals that come with the result), versus the
    // old flat draw bonus that moved 30%→60% win rate by only Δ13%.
    // With winners scoring ~1.8 and losers ~0.9 goals, 0.90/1.24 lands
    // the total at loss ≈ 88% of par and win ≈ 133%.
    this.matchRewardLossFactor = 0.90,
    this.matchRewardWinFactor = 1.24,
    this.startingCoins = 25_000,
    // Squad capacity: a club may own at most this many DISTINCT players
    // (extra copies of one player are upgrade fodder and count once).
    this.baseSquadCapacity = 30,
    // Slots are sold in blocks. Calibrated against the §30 simulation
    // numbers: a par match pays ~1.9k Coins and a store pack costs
    // ~15-25k, so the first block (8k ≈ 4 matches ≈ 1.6k per slot) is a
    // light, early sink, and each later block costs 4k more — the 10th
    // block is 44k (~9k per slot, still under half a pack per slot) —
    // so growing the club stays a steady coin sink without ever
    // out-pricing the packs that fill the slots.
    this.squadSlotsPerPurchase = 5,
    this.squadSlotBasePrice = 8_000,
    this.squadSlotPriceStep = 4_000,
  });

  /// Stable reference market value so imports don't shift every player's
  /// value (GDD 17.5).
  final int valueReferenceEur;

  /// Economic value (Coins) assigned at the reference market value.
  final int economicValueAtReference;

  /// Sub-linear growth exponent: ev = evRef * (v / vRef)^exponent.
  /// Each doubling of market value multiplies economic value by
  /// 2^exponent, so a €200M superstar is worth ~20x a €500k prospect,
  /// never 400x — the curve compresses instead of exploding.
  final double valueGrowthExponent;

  final int minEconomicValue;
  final int maxEconomicValue;

  /// Percentage of economic value returned when selling (GDD 17.3).
  final double sellingPercentage;

  /// Pack price = expected economic value of contents * margin (GDD 5.5).
  final double packMarginMultiplier;

  /// Premium margin for Legendary-tier packs specifically (rebalance
  /// Ch.8). Rare and Epic pay [packMarginMultiplier]; Legendary pays this
  /// higher margin so elite power scales in price faster than in odds.
  final double legendaryPackMarginMultiplier;

  /// Per-tier margins of the three icon packs (owner fix 2026-11-12):
  /// ascending prices — Icon Epic lowest, Icon Supreme highest — while
  /// every price stays economy-derived (EV × margin). See the constructor
  /// comment for the measured calibration.
  final double iconEpicPackMarginMultiplier;
  final double iconLegendaryPackMarginMultiplier;
  final double iconSupremePackMarginMultiplier;

  /// Match rewards (GDD 17.6).
  final int baseMatchReward;
  final int matchRewardPerGoal;

  /// Result multipliers on the par reward (base + goals): losses pay
  /// [matchRewardLossFactor] of par, wins [matchRewardWinFactor] — the
  /// performance-driven income spread (see EconomyConfig docs).
  final double matchRewardLossFactor;
  final double matchRewardWinFactor;

  /// Coins granted to a newly created club (GDD 3 starting state).
  final int startingCoins;

  /// Distinct players a club can own before buying more slots.
  final int baseSquadCapacity;

  /// Slots one purchase adds.
  final int squadSlotsPerPurchase;

  /// Price of the first block of slots, and the extra Coins every
  /// further block costs on top of the previous one.
  final int squadSlotBasePrice;
  final int squadSlotPriceStep;
}

const EconomyConfig defaultEconomyConfig = EconomyConfig();

/// The centralised economy calculator.
class EconomyEngine {
  const EconomyEngine({this.config = defaultEconomyConfig});

  final EconomyConfig config;

  /// Converts raw Market Value to Economic Value with a controlled
  /// non-linear formula (GDD 17.2):
  ///
  /// ev = economicValueAtReference * (value / reference)^growthExponent
  ///
  /// evaluated in log-space for stability with huge values, clamped to
  /// [EconomyConfig.minEconomicValue, maxEconomicValue]. Reference
  /// parameters are stable across dataset imports (GDD 17.5).
  int economicValueOf(int marketValueEur) {
    if (marketValueEur <= 0) return config.minEconomicValue;
    final logRatio =
        config.valueGrowthExponent *
        math.log(marketValueEur / config.valueReferenceEur);
    final ev = config.economicValueAtReference * math.exp(logRatio);
    return ev.round().clamp(config.minEconomicValue, config.maxEconomicValue);
  }

  /// Selling price for a base (unupgraded) player (GDD 17.3).
  int sellPriceOf(BasePlayer player) =>
      (economicValueOf(player.marketValueEur) * config.sellingPercentage)
          .round();

  /// Selling price for an upgraded owned copy — the same formula is used
  /// for every removal/compensation path (GDD 4.8, FR-008).
  ///
  /// Upgraded valuation: economic value increased by +10% of the economic
  /// value per upgrade level, then the normal selling percentage applies.
  int sellPriceOfUpgraded(BasePlayer player, int upgradeLevel) {
    final ev = economicValueOf(player.marketValueEur);
    final upgraded = ev * (1 + 0.10 * upgradeLevel);
    return (upgraded * config.sellingPercentage).round();
  }

  /// How many distinct players a club may own after buying
  /// [blocksBought] blocks of extra slots.
  int squadCapacity(int blocksBought) =>
      config.baseSquadCapacity + blocksBought * config.squadSlotsPerPurchase;

  /// Price of the NEXT block of slots when [blocksBought] were already
  /// bought: linear, so every purchase costs one step more than the last.
  int squadSlotBlockPrice(int blocksBought) =>
      config.squadSlotBasePrice + blocksBought * config.squadSlotPriceStep;

  /// Match reward in Coins (GDD 17.6): a goals-scored baseline (par),
  /// then the result multiplier — losses hold something back (80–90% of
  /// par), wins pay a proper bonus (120–135%), draws par. At a 1.6-goal
  /// average that is ~±20% between losing and winning performances.
  int matchReward({required int goalsFor, required bool won}) {
    final par = config.baseMatchReward + goalsFor * config.matchRewardPerGoal;
    return (par *
            (won
                ? config.matchRewardWinFactor
                : config.matchRewardLossFactor))
        .round();
  }
}

/// Formats an amount of Coins compactly (1.2M, 350k).
String formatCoins(int coins) {
  if (coins >= 1_000_000) {
    final v = coins / 1_000_000;
    return '${v >= 10 ? v.round() : v.toStringAsFixed(1)}M';
  }
  if (coins >= 10_000) return '${(coins / 1000).round()}k';
  return '$coins';
}
