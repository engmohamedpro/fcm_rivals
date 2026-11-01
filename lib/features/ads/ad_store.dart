/// FCM Rivals — rewarded-ad store (GDD 19, FR-040..FR-042).
///
/// Bridges the pure AdEngine with the database: records completed ads,
/// answers limit queries for the engine's validation, and applies the
/// ad-granted rewards — boosted post-match recovery and match replay.
/// Ads are always optional (GDD 19.1); nothing here can be required for
/// Pep Talks or Live Match Actions (FR-043).
library;

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import 'ad_engine.dart';

/// Ad-specific errors.
class AdException implements Exception {
  const AdException(this.message);
  final String message;
  @override
  String toString() => 'AdException: $message';
}

/// Outcome of one completed rewarded ad.
class AdRewardResult {
  const AdRewardResult({
    required this.kind,
    required this.rewardKey,
    this.detail,
  });

  final AdRewardKind kind;
  final String rewardKey;
  final String? detail;
}

class AdStore {
  AdStore({
    required this.db,
    this.engine = const AdEngine(),
  });

  final AppDatabase db;
  final AdEngine engine;

  /// Records one successfully completed ad and applies its reward
  /// (GDD 19.4: grant only after completion, reject duplicate callbacks,
  /// enforce daily limits). [playbackCompleted] comes from the ad SDK.
  Future<AdRewardResult> completeAd({
    required AdRewardKind kind,
    required String rewardKey,
    required bool playbackCompleted,
    required int clubId,
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final usage = await _usageToday(clubId, timestamp);
    final validation = engine.validateReward(
      ad: CompletedAd(
          kind: kind, rewardKey: rewardKey, clubId: clubId, completedAt: timestamp),
      usageToday: usage,
      playbackCompleted: playbackCompleted,
    );
    if (!validation.allowed) {
      throw AdException(validation.reason ?? 'Reward not allowed');
    }
    await db.transaction(() async {
      await db.into(db.adUsages).insert(AdUsagesCompanion.insert(
            clubId: clubId,
            rewardKind: kind.name,
            rewardKey: rewardKey,
            completedAt: timestamp,
          ));
    });
    return AdRewardResult(kind: kind, rewardKey: rewardKey);
  }

  /// Whether a match replay is currently offered for the last user
  /// fixture result (GDD 19.3: only after draw/defeat, one per match,
  /// inside the replay window, and not already used).
  Future<bool> replayOfferedFor({
    required int fixtureId,
    required int userClubId,
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final result = await (db.select(db.matchResults)
          ..where((r) => r.fixtureId.equals(fixtureId)))
        .getSingleOrNull();
    if (result == null) return false;
    final userHome = result.homeClubId == userClubId;
    final userGoals = userHome ? result.homeGoals : result.awayGoals;
    final opponentGoals = userHome ? result.awayGoals : result.homeGoals;
    final won = userGoals > opponentGoals;
    final offer = engine.validateMatchReplayOffer(
      won: won,
      fullTimeAt: result.playedAt,
      now: timestamp,
    );
    if (!offer.allowed) return false;
    // One replay per match (duplicate prevention).
    final used = await (db.select(db.adUsages)
          ..where((u) =>
              u.rewardKind.equals(AdRewardKind.matchReplay.name) &
              u.rewardKey.equals('match:$fixtureId')))
        .get();
    return used.isEmpty;
  }

  /// Usage rows of one club since local midnight.
  Future<List<AdUsageRecord>> _usageToday(int clubId, DateTime now) async {
    final startOfDay = DateTime(now.year, now.month, now.day);
    final rows = await (db.select(db.adUsages)
          ..where((u) =>
              u.clubId.equals(clubId) &
              u.completedAt.isBiggerOrEqualValue(startOfDay)))
        .get();
    return [
      for (final r in rows)
        AdUsageRecord(
            rewardKind: r.rewardKind, rewardKey: r.rewardKey, completedAt: r.completedAt)
    ];
  }

  /// Remaining boosted-recovery ads today (for UI limits display).
  Future<int> boostedRecoveryRemaining(int clubId, {DateTime? now}) async {
    final usage = await _usageToday(clubId, now ?? DateTime.now());
    final used = usage
        .where((u) => u.rewardKind == AdRewardKind.boostedRecovery.name)
        .length;
    return (engine.config.dailyLimitPerKind - used).clamp(0, engine.config.dailyLimitPerKind);
  }
}
