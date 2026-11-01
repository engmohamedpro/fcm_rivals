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
}

const AdConfig defaultAdConfig = AdConfig();

/// Reward kinds offered in Version 1 (GDD 19.3).
enum AdRewardKind {
  boostedRecovery('Boosted recovery'),
  matchReplay('Match replay');

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
  double boostedRecovery({
    required double staminaAfterNaturalRecovery,
    required double naturalRecovery,
  }) {
    if (naturalRecovery <= 0) return staminaAfterNaturalRecovery;
    final boosted =
        staminaAfterNaturalRecovery + naturalRecovery * config.boostedRecoveryBonus;
    return boosted.clamp(0, config.boostedRecoveryCap.toDouble());
  }
}
