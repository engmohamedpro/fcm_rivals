/// FCM Rivals — rewarded advertisement engine (GDD 19, FR-040..FR-043).
///
/// Pure validation logic for rewarded ads: ads are optional (GDD 19.1),
/// rewards are granted only after successful completion, duplicate
/// callbacks are rejected, daily and per-transaction limits are enforced,
/// and no ad ever gates Pep Talks or Live Match Actions (FR-043).
///
/// The actual ad playback is a platform concern; this engine decides
/// whether a completed ad may grant its reward, and what that reward is.
library;

/// Tunable ad limits — pre-balance placeholders (GDD rule 14).
class AdConfig {
  const AdConfig({
    this.dailyLimitPerKind = 3,
    this.dailyTotalLimit = 8,
    this.boostedRecoveryBonus = 0.15,
    this.boostedRecoveryCap = 100,
    this.matchReplayWindowHours = 24,
    this.upgradeDiscountFraction = 0.20,
    this.sellingBonusFraction = 0.20,
    this.dailyRewardMultiplier = 1.5,
    this.seasonRewardMultiplier = 1.25,
    this.freePackValueTargetEur = 20_000_000,
  });

  /// Maximum completed ads of one reward kind per day (GDD 19.3/19.4).
  final int dailyLimitPerKind;

  /// Maximum completed ads across all kinds per day.
  final int dailyTotalLimit;

  /// Post-match pep talk boosted recovery: +15% to natural recovery for
  /// eligible players (GDD 19.3 proposed value).
  final double boostedRecoveryBonus;

  /// Stamina never exceeds this percentage.
  final int boostedRecoveryCap;

  /// How long after full time a match replay stays available.
  final int matchReplayWindowHours;

  /// Upgrade cost discount fraction (GDD 19.3 'Upgrade cost discount').
  final double upgradeDiscountFraction;

  /// Selling bonus fraction (GDD 19.3 'Player selling bonus').
  final double sellingBonusFraction;

  /// Match reward multiplier while active (GDD 19.3 'Daily reward
  /// multiplier' — lasts the day it was watched).
  final double dailyRewardMultiplier;

  /// Season reward multiplier (GDD 19.3 'Season reward multiplier').
  final double seasonRewardMultiplier;

  /// The free ad pack draws at roughly this market-value target so its
  /// contents stay comparable to a normal purchasable pack.
  final int freePackValueTargetEur;
}

const AdConfig defaultAdConfig = AdConfig();

/// Reward kinds offered in Version 1 (GDD 19.3): the two mandatory
/// surfaces plus the 'Other Proposed' list.
enum AdRewardKind {
  boostedRecovery('Boosted recovery'),
  matchReplay('Match replay'),
  freePack('Free pack'),
  upgradeDiscount('Upgrade discount'),
  sellingBonus('Selling bonus'),
  dailyRewardMultiplier('Daily reward multiplier'),
  seasonRewardMultiplier('Season reward multiplier');

  const AdRewardKind(this.displayName);
  final String displayName;
}

/// Result of validating one completed ad.
class AdValidation {
  const AdValidation({
    required this.allowed,
    this.reason,
    this.rewardKind,
    this.rewardKey,
  });

  final bool allowed;
  final String? reason;

  /// Null when validation failed before resolving the reward.
  final AdRewardKind? rewardKind;
  final String? rewardKey;
}

/// One completed ad, as presented to the engine for validation.
class CompletedAd {
  const CompletedAd({
    required this.kind,
    required this.rewardKey,
    required this.clubId,
    required this.completedAt,
  });

  final AdRewardKind kind;

  /// Unique transaction key, e.g. 'match:fixtureId' for a replay.
  final String rewardKey;
  final int clubId;
  final DateTime completedAt;
}

/// A previously recorded ad usage (from the AdUsage table).
class AdUsageRecord {
  const AdUsageRecord({
    required this.rewardKind,
    required this.rewardKey,
    required this.completedAt,
  });

  final String rewardKind;
  final String rewardKey;
  final DateTime completedAt;
}

/// Pure validation for rewarded-ad rewards (GDD 19.4).
class AdEngine {
  const AdEngine({this.config = defaultAdConfig});

  final AdConfig config;

  /// Whether a match replay ad is offered at all: only after a draw or
  /// defeat, at most one replay per match, within the replay window
  /// (GDD 19.3 Match Replay).
  AdValidation validateMatchReplayOffer({
    required bool won,
    required DateTime fullTimeAt,
    required DateTime now,
  }) {
    if (won) {
      return const AdValidation(
          allowed: false, reason: 'No replay after a win');
    }
    if (now.difference(fullTimeAt).inMinutes <
        0) {
      return const AdValidation(allowed: false, reason: 'Match not finished');
    }
    if (now.difference(fullTimeAt).inHours > config.matchReplayWindowHours) {
      return const AdValidation(
          allowed: false, reason: 'Replay window has closed');
    }
    return const AdValidation(allowed: true);
  }

  /// Central validation for one completed ad (GDD 19.4, FR-041/FR-042):
  /// completion must be confirmed, the key must not have been rewarded
  /// before (duplicate callback prevention), the per-kind daily limit and
  /// the global daily limit must hold.
  AdValidation validateReward({
    required CompletedAd ad,
    required List<AdUsageRecord> usageToday,
    required bool playbackCompleted,
  }) {
    if (!playbackCompleted) {
      return const AdValidation(
          allowed: false, reason: 'Ad did not complete');
    }
    if (usageToday.any((u) =>
        u.rewardKey == ad.rewardKey &&
        u.rewardKind == ad.kind.name)) {
      return const AdValidation(
          allowed: false, reason: 'Reward already granted');
    }
    final sameKind =
        usageToday.where((u) => u.rewardKind == ad.kind.name).length;
    if (sameKind >= config.dailyLimitPerKind) {
      return AdValidation(
          allowed: false,
          reason: 'Daily limit reached for ${ad.kind.displayName}');
    }
    if (usageToday.length >= config.dailyTotalLimit) {
      return const AdValidation(
          allowed: false, reason: 'Daily ad limit reached');
    }
    return AdValidation(
      allowed: true,
      rewardKind: ad.kind,
      rewardKey: ad.rewardKey,
    );
  }

  /// Applies the boosted post-match recovery (GDD 19.3: +15% to natural
  /// recovery for eligible players). Stacks on nothing else: callers pass
  /// the natural-recovery result only, so no ad bonus can double up with
  /// a normal pep talk on the same transaction (GDD 19.4 last rule —
  /// enforced by the store picking either path, and here by the flat cap).
  ///
  /// The result is a whole stamina point: the raw sum can land on a
  /// half-point (70.0 + 14.5 = 84.5) and stamina is displayed as whole
  /// points, so the value is rounded before capping — the ad then
  /// delivers exactly the 100 the UI promises instead of stopping one
  /// half-point short (99.5 capped to 99.5 → displayed 100 but never
  /// banked; rebalance Ch.8).
  double boostedRecovery({
    required double staminaAfterNaturalRecovery,
    required double naturalRecovery,
  }) {
    if (naturalRecovery <= 0) return staminaAfterNaturalRecovery;
    final boosted =
        staminaAfterNaturalRecovery + naturalRecovery * config.boostedRecoveryBonus;
    return boosted.round().clamp(0, config.boostedRecoveryCap).toDouble();
  }

  /// Discounted upgrade price (GDD 19.3 'Upgrade cost discount'): the
  /// flat fraction off, floored at 50 coins so an upgrade never becomes
  /// free (or at the full price when that is already lower). Exactly one
  /// discount applies per purchase — the store consumes the boost when
  /// it is used.
  int discountedUpgradeCost(int fullCost) {
    final discounted = (fullCost * (1 - config.upgradeDiscountFraction)).round();
    if (fullCost <= 50) return fullCost;
    return discounted.clamp(50, fullCost);
  }

  /// Selling bonus (GDD 19.3 'Player selling bonus'): the fraction added
  /// on top of the normal selling price, per copy sold while the boost is
  /// active. The store consumes the boost with the sale it applies to.
  int sellingBonus(int normalPrice) {
    return (normalPrice * (1 + config.sellingBonusFraction)).round();
  }

  /// Match reward while the daily multiplier is active (GDD 19.3 'Daily
  /// reward multiplier'). The multiplier applies to the whole reward —
  /// base, goals and win bonus alike — and lasts the day.
  int boostedMatchReward(int normalReward) =>
      (normalReward * config.dailyRewardMultiplier).round();

  /// Season reward while the season multiplier is active (GDD 19.3
  /// 'Season reward multiplier'). Applies once, at season completion.
  int boostedSeasonReward(int normalReward) =>
      (normalReward * config.seasonRewardMultiplier).round();
}
