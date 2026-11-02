/// FCM Rivals — rewarded-ad store (GDD 19, FR-040..FR-042).
///
/// Bridges the pure AdEngine with the database: records completed ads,
/// answers limit queries for the engine's validation, and applies the
/// ad-granted rewards — boosted post-match recovery, match replay, and
/// the GDD 19.3 'Other Proposed' surfaces: free user-selected pack,
/// upgrade cost discount, player selling bonus, daily reward multiplier
/// and season reward multiplier.
/// Ads are always optional (GDD 19.1); nothing here can be required for
/// Pep Talks or Live Match Actions (FR-043).
library;

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../packs/pack_engine.dart' show PackCategory;
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

  /// Remaining ads of one kind today (for UI limits display).
  Future<int> remainingToday(int clubId, AdRewardKind kind,
      {DateTime? now}) async {
    final usage = await _usageToday(clubId, now ?? DateTime.now());
    final used = usage.where((u) => u.rewardKind == kind.name).length;
    return (engine.config.dailyLimitPerKind - used)
        .clamp(0, engine.config.dailyLimitPerKind);
  }

  // ---------------------------------------------------------------------------
  // GDD 19.3 'Other Proposed' reward surfaces
  // ---------------------------------------------------------------------------

  /// Completes a free-pack ad and grants the pack immediately (GDD 19.3
  /// 'Free user-selected pack'): the user picked the scope beforehand,
  /// the pack lands in the club inventory unopened, priced at zero and
  /// marked with its ad source. One ad = one pack.
  Future<AdRewardResult> grantFreePack({
    required int clubId,
    required PackCategory category,
    String? scopeValue,
    required bool playbackCompleted,
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    // One free pack per calendar day per club, whatever the scope — the
    // daily key scopes the whole surface, not the scope choice.
    final dayKey = 'freepack:${timestamp.year}-${timestamp.month}-${timestamp.day}';
    final result = await completeAd(
      kind: AdRewardKind.freePack,
      rewardKey: dayKey,
      playbackCompleted: playbackCompleted,
      clubId: clubId,
      now: timestamp,
    );
    final packId = await db.into(db.packs).insert(PacksCompanion.insert(
          clubId: clubId,
          category: category.name,
          scopeValue: Value(scopeValue),
          price: const Value(0),
          source: const Value('ad_free'),
          createdAt: timestamp,
        ));
    return AdRewardResult(
        kind: result.kind,
        rewardKey: result.rewardKey,
        detail: 'Pack #$packId (${category.name})');
  }

  /// Whether an upgrade purchased now benefits from the ad discount, and
  /// the discounted price (GDD 19.3 'Upgrade cost discount'). The boost
  /// is consumed by [consumeUpgradeDiscount] once the purchase runs —
  /// validation and consumption are separate so the UI can display the
  /// discounted price before charging.
  Future<bool> upgradeDiscountActive(int clubId, {DateTime? now}) async {
    return await _kindUsedSince(
        clubId, AdRewardKind.upgradeDiscount, _startOfDailyWindow(now));
  }

  Future<void> consumeUpgradeDiscount(int clubId, {DateTime? now}) async {
    await _consumeOldestGrant(clubId, AdRewardKind.upgradeDiscount,
        DateTime(2000),
        now: now);
  }

  /// Whether a sale right now earns the ad selling bonus (GDD 19.3
  /// 'Player selling bonus'). Consumed by [consumeSellingBonus] with the
  /// sale it applied to.
  Future<bool> sellingBonusActive(int clubId, {DateTime? now}) async {
    return await _kindUsedSince(
        clubId, AdRewardKind.sellingBonus, _startOfDailyWindow(now));
  }

  Future<void> consumeSellingBonus(int clubId, {DateTime? now}) async {
    await _consumeOldestGrant(clubId, AdRewardKind.sellingBonus,
        DateTime(2000),
        now: now);
  }

  /// Whether match rewards today are multiplied (GDD 19.3 'Daily reward
  /// multiplier'): true while a daily-multiplier ad was watched today.
  Future<bool> dailyMultiplierActive(int clubId, {DateTime? now}) async {
    return await _kindUsedSince(
        clubId, AdRewardKind.dailyRewardMultiplier, _startOfDailyWindow(now));
  }

  /// Whether the next season completion pays the boosted reward (GDD
  /// 19.3 'Season reward multiplier'). One ad = one boosted completion;
  /// consumed by [consumeSeasonMultiplier] when the season pays out.
  Future<bool> seasonMultiplierActive(int clubId, {DateTime? now}) async {
    return await _kindUsedSince(
        clubId, AdRewardKind.seasonRewardMultiplier, DateTime(2000));
  }

  Future<void> consumeSeasonMultiplier(int clubId, {DateTime? now}) async {
    await _consumeOldestGrant(clubId, AdRewardKind.seasonRewardMultiplier,
        DateTime(2000),
        now: now);
  }

  DateTime _startOfDailyWindow(DateTime? now) {
    final t = now ?? DateTime.now();
    return DateTime(t.year, t.month, t.day);
  }

  /// Whether a boost of [kind] is active: at least one grant exists since
  /// [since] that has not been consumed. Grant rows carry the key
  /// `kind:grant:window`; consumption rows copy the exact grant key
  /// they consumed and prefix it `kind:consumed:window` — one-to-one,
  /// so a boost can never apply twice (GDD 19.4).
  Future<bool> _kindUsedSince(
      int clubId, AdRewardKind kind, DateTime since) async {
    final rows = await (db.select(db.adUsages)
          ..where((u) =>
              u.clubId.equals(clubId) &
              u.rewardKind.equals(kind.name) &
              u.completedAt.isBiggerOrEqualValue(since)))
        .get();
    final grants = rows
        .map((r) => r.rewardKey)
        .where((k) => k.startsWith('${kind.name}:grant:'))
        .toList();
    if (grants.isEmpty) return false;
    final consumed = rows
        .map((r) => r.rewardKey)
        .where((k) => k.startsWith('${kind.name}:consumed:'))
        .map((k) => k.replaceFirst(':consumed:', ':grant:'))
        .toSet();
    return grants.any((g) => !consumed.contains(g));
  }

  /// Consumes the OLDEST unconsumed grant of [kind] (one boost = one
  /// use). No-op when no grant is active.
  Future<void> _consumeOldestGrant(
      int clubId, AdRewardKind kind, DateTime since,
      {DateTime? now}) async {
    final rows = await (db.select(db.adUsages)
          ..where((u) =>
              u.clubId.equals(clubId) &
              u.rewardKind.equals(kind.name) &
              u.completedAt.isBiggerOrEqualValue(since))
          ..orderBy([(u) => OrderingTerm.asc(u.completedAt)]))
        .get();
    final consumed = rows
        .map((r) => r.rewardKey)
        .where((k) => k.startsWith('${kind.name}:consumed:'))
        .map((k) => k.replaceFirst(':consumed:', ':grant:'))
        .toSet();
    final grant = rows
        .map((r) => r.rewardKey)
        .firstWhere((k) => k.startsWith('${kind.name}:grant:') && !consumed.contains(k),
            orElse: () => '');
    if (grant.isEmpty) return;
    await db.into(db.adUsages).insert(AdUsagesCompanion.insert(
          clubId: clubId,
          rewardKind: kind.name,
          rewardKey: '${kind.name}:consumed:${grant.substring('${kind.name}:grant:'.length)}',
          completedAt: now ?? DateTime.now(),
        ));
  }

  /// Completes a boost-granting ad (upgrade discount, selling bonus,
  /// daily/season multiplier): these ads do not deliver an item, they
  /// switch a boost on. The grant key embeds a per-day/per-season tag so
  /// duplicate-callback prevention still applies within its window.
  Future<AdRewardResult> grantBoost({
    required int clubId,
    required AdRewardKind kind,
    required bool playbackCompleted,
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final String windowKey;
    switch (kind) {
      case AdRewardKind.seasonRewardMultiplier:
        // One per season: keyed by the latest season id.
        final season = await (db.select(db.seasons)
              ..orderBy([(s) => OrderingTerm.desc(db.seasons.id)]))
            .get();
        windowKey = 'season:${season.isEmpty ? 0 : season.first.id}';
      default:
        windowKey =
            'day:${timestamp.year}-${timestamp.month}-${timestamp.day}';
    }
    return completeAd(
      kind: kind,
      rewardKey: '${kind.name}:grant:$windowKey',
      playbackCompleted: playbackCompleted,
      clubId: clubId,
      now: timestamp,
    );
  }
}
