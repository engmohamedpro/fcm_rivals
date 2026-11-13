/// FCM Rivals — the achievement claim pipeline (T-0108).
///
/// Claiming a tier is ONE database transaction: the UNIQUE-guarded
/// claim row insert plus the `creditCoins` ledger row, all-or-nothing.
/// A double tap claims once. Back-navigation re-entry claims zero. A
/// process kill mid-claim leaves either both rows or neither — the
/// reward can never be double-spent into the economy. The DB, not the
/// UI flow, is the idempotency owner (the same treatment pack opening
/// carries).
///
/// Eligibility is STATE-DERIVED, not request-declared: the service
/// re-derives the current progress (T-0107) inside the decision — a
/// stale or tampered UI cannot claim what the game state does not
/// support, and no client parameter can mint eligibility.
///
/// Replays are transparent to claims (T-0099 interaction): a replayed
/// fixture re-derives the SAME metric values (the derivation counts a
/// fixture once), so a claimed tier never becomes un-claimed and an
/// unclaimed threshold never appears to vanish. Claims are terminal —
/// nothing about them is ever refunded or re-rolled.
///
/// Ledger convention (T-0109's sweep attributes on it):
/// `reason: LedgerReasons.achievement` with
/// `detail: '<achievementId>:<tierKey>'`.
library;

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart' as db;
import '../../core/database/coin_ops.dart' show CoinOps;
import 'achievement_catalog.dart';
import 'achievement_catalog_data.dart' show AchievementCatalog;
import 'achievement_claims_repository.dart';
import 'achievement_progress.dart'
    show LedgerReasons, deriveCareerMetrics;

/// The claim's outcome — sealed, no exceptions across the API
/// boundary for the two expected cases.
sealed class ClaimResult {
  const ClaimResult();
}

/// The claim landed: coins are credited and the claim row persists.
class ClaimGranted extends ClaimResult {
  const ClaimGranted({required this.coins, this.titleGranted});

  /// The amount actually credited.
  final int coins;

  /// The title this claim recorded, if the tier confers one (equipping
  /// stays manual — T-0112; granting ≠ equipping).
  final String? titleGranted;
}

/// The exact (club, achievement, tierKey) was already claimed: an
/// idempotent no-op, NOT an error — the UI renders claimed from the
/// claims table, so this is the normal second visit.
class ClaimAlreadyClaimed extends ClaimResult {
  const ClaimAlreadyClaimed();
}

/// The derived game state does not meet the tier's threshold: no
/// rows, no coins, nothing.
class ClaimNotEligible extends ClaimResult {
  const ClaimNotEligible({required this.progress, required this.threshold});

  /// What the save currently derives — for the UI's "X of Y" display.
  final int progress;
  final int threshold;
}

/// One club's claim pipeline: claim a tier, ask what a claim for it
/// would return (the UI's pre-flight), and batch-claim through the
/// same single-tier path.
class AchievementClaimService {
  AchievementClaimService(this.database);

  final db.AppDatabase database;

  /// Claims ONE tier of [achievementId] at [tierKey] (the tier's
  /// THRESHOLD as a canonical string — the stable identity across
  /// catalog re-ordering).
  Future<ClaimResult> claimTier({
    required int clubId,
    required String achievementId,
    required String tierKey,
  }) async {
    final definition = AchievementCatalog.byId(achievementId);
    if (definition == null) {
      // An unknown achievement id is a catalog drift, not a user
      // action — surfaced as not-eligible with zeroed numbers rather
      // than an exception across the boundary.
      return const ClaimNotEligible(progress: 0, threshold: 0);
    }

    // Eligibility from DERIVED state, not request parameters.
    final metrics = await deriveCareerMetrics(database, clubId);
    final progress = metrics.progressFor(definition.metricId);
    if (progress == null) {
      return const ClaimNotEligible(progress: 0, threshold: 0);
    }
    final threshold = int.tryParse(tierKey);
    if (threshold == null || progress < threshold) {
      return ClaimNotEligible(progress: progress, threshold: threshold ?? 0);
    }

    // The tier itself (badge metal, titleId, reward) at this rung.
    final tier = _tierOf(definition, tierKey);
    if (tier == null) {
      return ClaimNotEligible(progress: progress, threshold: threshold);
    }
    final reward = definition.kind == AchievementKind.milestone
        ? (definition.milestoneReward ?? 0)
        : tier.coinReward;

    // ONE transaction: claim row + credit. The UNIQUE violation on
    // the insert is the idempotency token — if it cannot land, no
    // credit happens; if it lands, the credit is justified.
    try {
      final grantedTitle = tier.titleId;
      await database.transaction(() async {
        await database
            .into(database.achievementClaims)
            .insert(
              db.AchievementClaimsCompanion.insert(
                clubId: clubId,
                achievementId: achievementId,
                tierKey: tierKey,
                rewardCoins: reward,
                titleGranted: grantedTitle == null
                    ? const Value.absent()
                    : Value(grantedTitle),
                claimedAt: DateTime.now(),
              ),
            );
        return database.creditCoins(
          clubId,
          reward,
          reason: LedgerReasons.achievement,
          detail: '$achievementId:$tierKey',
        );
      });
      return ClaimGranted(coins: reward, titleGranted: grantedTitle);
    } on Exception {
      // The UNIQUE(club, achievement, tierKey) refusal surfaces as an
      // exception whose message carries 'UNIQUE constraint failed' —
      // caught BROADLY (never string-matched: the message is not a
      // stable cross-version API), then verified by the row's actual
      // presence so a genuine failure is not masked as a success.
      final already = await AchievementClaimsRepository(database).hasClaim(
        clubId: clubId,
        achievementId: achievementId,
        tierKey: tierKey,
      );
      if (already) {
        return const ClaimAlreadyClaimed();
      }
      // Anything else is an unknown failure — rethrown honestly with
      // the original stack; the caller's surface decides how to show
      // it. The transaction already rolled back: neither row landed.
      rethrow;
    }
  }

  /// What a claim for this tier would return right now — the UI's
  /// pre-flight check (claimed already vs eligible vs locked), one
  /// derivation, no writes.
  Future<ClaimResult> claimStateFor({
    required int clubId,
    required String achievementId,
    required String tierKey,
  }) async {
    final definition = AchievementCatalog.byId(achievementId);
    if (definition == null) {
      return const ClaimNotEligible(progress: 0, threshold: 0);
    }
    if (await AchievementClaimsRepository(database).hasClaim(
      clubId: clubId,
      achievementId: achievementId,
      tierKey: tierKey,
    )) {
      return const ClaimAlreadyClaimed();
    }
    final metrics = await deriveCareerMetrics(database, clubId);
    final progress = metrics.progressFor(definition.metricId) ?? 0;
    final threshold = int.tryParse(tierKey) ?? 0;
    if (progress < threshold) {
      return ClaimNotEligible(progress: progress, threshold: threshold);
    }
    final tier = _tierOf(definition, tierKey);
    final reward = definition.kind == AchievementKind.milestone
        ? (definition.milestoneReward ?? 0)
        : (tier?.coinReward ?? 0);
    return ClaimGranted(
      coins: reward,
      titleGranted: tier?.titleId,
    );
  }

  /// Batch claim ("claim all"): every ELIGIBLE unclaimed tier of
  /// [achievementId], each through the same single-tier path — a loop
  /// of transactions, NEVER one mega-transaction, so a partial batch
  /// success persists and the UI re-renders from the claims table.
  Future<List<ClaimResult>> claimAllTiers({
    required int clubId,
    required String achievementId,
  }) async {
    final definition = AchievementCatalog.byId(achievementId);
    if (definition == null) return const [];

    final metrics = await deriveCareerMetrics(database, clubId);
    final progress = metrics.progressFor(definition.metricId) ?? 0;
    final repo = AchievementClaimsRepository(database);

    final results = <ClaimResult>[];
    for (final tier in definition.tiers(AchievementCatalog.economy)) {
      final key = tier.threshold.toString();
      if (progress < tier.threshold) continue; // not yet eligible
      if (await repo.hasClaim(
        clubId: clubId,
        achievementId: achievementId,
        tierKey: key,
      )) {
        continue; // claimed: not part of this batch's results
      }
      results.add(await claimTier(
        clubId: clubId,
        achievementId: achievementId,
        tierKey: key,
      ));
    }
    return results;
  }

  /// The catalog's tier at [tierKey] (the threshold string), or null
  /// when the key names no rung of this definition's ladder.
  AchievementTier? _tierOf(AchievementDefinition definition, String tierKey) {
    for (final tier in definition.tiers(AchievementCatalog.economy)) {
      if (tier.threshold.toString() == tierKey) return tier;
    }
    return null;
  }
}
