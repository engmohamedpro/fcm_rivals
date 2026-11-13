/// FCM Rivals — the achievements economy config (T-0105, GDD 26/27).
///
/// WHY THIS FILE EXISTS, in plain words for future maintainers:
/// the achievement faucet must never out-grow the match-economy
/// faucet, no matter how far the endless ladders climb. The safety is
/// structural, not a promise:
///
/// 1. Every ENDLESS ladder's thresholds grow GEOMETRICALLY (tier n
///    needs base * ratio^n effort, ratio >= 2) while its per-tier
///    coin reward stays FLAT. Total coins claimable after effort E is
///    `flat * log2(E / base)` — O(log effort). Coins-per-match trends
///    to zero: climbing from tier 10 to tier 11 takes as much extra
///    effort as the whole career so far, and pays exactly the same
///    flat reward. A player cannot farm achievements for a living.
/// 2. One-time milestones carry fixed budgets.
/// 3. [totalCatalogCoinCeiling] DERIVES the whole catalog's ceiling
///    from those two shapes (sum of milestones + `flat * log2(cap /
///    base)` per endless ladder, using each ladder's UI generation
///    cap as the honest horizon). It is a getter, never a stored
///    number, so the ceiling and the catalog can never drift apart.
///
/// Prestige is the endless axis: badge metals and titles multiply
/// with tiers — the top of the ladder is worn, not banked.
///
/// Every number here is a PRE-BALANCE PLACEHOLDER in the
/// `EconomyConfig` tradition (GDD rule 14): one typed place for the
/// simulation-driven sweep (T-0109) to re-pin.
library;

import 'achievement_catalog.dart';

/// Tunable achievement-economy parameters (GDD 27 companion to
/// `EconomyConfig`).
class AchievementEconomyConfig {
  const AchievementEconomyConfig({
    // PRE-BALANCE PLACEHOLDERS (T-0109 re-pins): a flat ladder tier
    // pays ~1.3% of a par match reward — achievements are a bonus
    // drip, never a wage. compare EconomyConfig.baseMatchReward
    // = 1_500.
    this.flatEndlessCoinReward = 20,
    this.milestoneCareerFirstWin = 300,
    this.milestoneCareerFirstTitle = 1_000,
    this.milestoneSquadFirstLegendary = 500,
    this.milestoneSquadFirstEpic = 150,
    this.milestonePacksFirstLegendaryPull = 400,
    this.milestoneEconomyFirstMillion = 2_000,
    this.milestoneLoyaltyFirstSeason = 250,
    this.milestoneMastermindFirstTactic = 100,
    this.milestoneCampusFirstFacilityMax = 600,
  });

  /// FLAT per-tier coin reward of EVERY endless ladder — THE safety
  /// number: it never scales with tier, so ladder income is
  /// logarithmic by construction (see the library doc).
  final int flatEndlessCoinReward;

  // One-time milestone budgets (unique feats, fixed faucets).
  final int milestoneCareerFirstWin;
  final int milestoneCareerFirstTitle;
  final int milestoneSquadFirstLegendary;
  final int milestoneSquadFirstEpic;
  final int milestonePacksFirstLegendaryPull;
  final int milestoneEconomyFirstMillion;
  final int milestoneLoyaltyFirstSeason;
  final int milestoneMastermindFirstTactic;
  final int milestoneCampusFirstFacilityMax;

  /// The flat coin reward for one tier of [definition]'s ladder.
  /// Milestones never route through here (they carry their own
  /// budgets) — the ladder path is flat-only.
  int flatCoinRewardFor(AchievementDefinition definition) =>
      definition.kind == AchievementKind.endlessLadder
          ? flatEndlessCoinReward
          : 0;

  /// The TOTAL coin ceiling of the whole catalog: milestones summed
  /// + each endless ladder's `flat * log2(cap / base)` horizon,
  /// DERIVED from the catalog — never stored, never drifted. This is
  /// the number T-0109's economy sweep compares against the
  /// match-economy faucet.
  int totalCatalogCoinCeiling(Iterable<AchievementDefinition> catalog) {
    var total = 0;
    for (final d in catalog) {
      if (d.kind == AchievementKind.milestone) {
        total += d.milestoneReward ?? 0;
        continue;
      }
      // The endless horizon: the highest tier the UI materialises.
      // Past it the climb continues for prestige, coins asymptote.
      final tiers = d.tiers(this);
      final topThreshold = tiers.isEmpty ? d.ladder.baseThreshold : tiers.last.threshold;
      final reachableTiers = d.ladder.baseThreshold <= topThreshold
          ? (tiers.isEmpty ? 0 : tiers.length)
          : 0;
      total += flatEndlessCoinReward * reachableTiers;
    }
    return total;
  }
}
