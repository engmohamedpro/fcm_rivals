/// FCM Rivals — the achievements providers (T-0110).
///
/// The screen's whole state layer over T-0105..T-0108: career metrics
/// derived once per refresh, the claims table watched live (drift's
/// watch → the UI re-renders the moment a claim lands — the
/// AlreadyClaimed contract renders silently from THIS stream), the
/// equipped title exposed empty-safe for the header, and the claim
/// action wired to T-0108's atomic pipeline. Thin widgets consume;
/// zero business logic in the screen (the standing architecture
/// rule).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart' show databaseProvider;
import '../../core/database/app_database.dart' as db;
import 'achievement_claim_service.dart';
import 'achievement_claims_repository.dart';
import 'achievement_progress.dart';

/// The derived career snapshot (T-0107) for the user's club.
///
/// FutureProvider (not Stream): the derivation is six grouped reads
/// over the save; the screen refreshes it after each claim through
/// [achievementsRefreshProvider] — the metrics only move when coins,
/// matches or squad rows move, and the claims stream (below) is what
/// the UI reacts to instantly.
final careerMetricsProvider = FutureProvider<CareerMetrics>((
  ref,
) async {
  final database = await ref.watch(databaseProvider.future);
  final club = await _userClub(database);
  if (club == null) return CareerMetrics.empty;
  return deriveCareerMetrics(database, club.id);
});

/// The claims table, LIVE (T-0106): every tier row the club ever
/// claimed, keyed `<achievementId>:<tierKey>` for the screen's
/// O(1) claimed-state lookup. drift's watch fans through the provider
/// graph the moment a claim transaction commits — the claim-all
/// affordance's flip-to-claimed is this stream, not a local flag.
final claimsProvider = StreamProvider<Set<String>>((ref) async* {
  final database = await ref.watch(databaseProvider.future);
  final club = await _userClub(database);
  if (club == null) {
    yield <String>{};
    return;
  }
  final repository = AchievementClaimsRepository(database);
  // Seed once (the stream opens before any claim exists), then relay
  // the table's live snapshots.
  yield await _claimKeys(repository, club.id);
  await for (final _ in database
      .select(database.achievementClaims)
      .watch()) {
    yield await _claimKeys(repository, club.id);
  }
});

/// The equipped title id (T-0106's column, T-0112's surface) —
/// empty-safe: null when nothing is equipped (fresh save, or the
/// settings row itself absent).
final equippedTitleProvider = FutureProvider<String?>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  return AchievementClaimsRepository(database).getEquippedTitle();
});

/// The claim action (T-0108's atomic pipeline) as a call the screen
/// makes and then invalidates the derived snapshot on success — the
/// coin reward moves `lifetimeCoinsEarned` (an achievement metric),
/// so the progress numbers must re-derive after a claim.
final claimTierProvider = FutureProvider.family<ClaimResult, ClaimArgs>((
  ref,
  args,
) async {
  final database = await ref.watch(databaseProvider.future);
  final club = await _userClub(database);
  if (club == null) {
    return const ClaimNotEligible(progress: 0, threshold: 0);
  }
  final service = AchievementClaimService(database);
  return service.claimTier(
    clubId: club.id,
    achievementId: args.achievementId,
    tierKey: args.tierKey,
  );
});

/// Invalidate-and-rederive trigger: bumping this re-runs the metric
/// derivation after claims. The screen calls [refreshAchievements].
final achievementsRefreshProvider =
    StateProvider<int>((ref) => 0);

/// One claim request's arguments.
class ClaimArgs {
  const ClaimArgs(this.achievementId, this.tierKey);

  final String achievementId;
  final String tierKey;

  @override
  bool operator ==(Object other) =>
      other is ClaimArgs &&
      other.achievementId == achievementId &&
      other.tierKey == tierKey;

  @override
  int get hashCode => Object.hash(achievementId, tierKey);
}

/// Re-derives the career snapshot (post-claim: coins earned moved).
void refreshAchievements(WidgetRef ref) {
  ref.read(achievementsRefreshProvider.notifier).state++;
  ref.invalidate(careerMetricsProvider);
}

Future<db.Club?> _userClub(db.AppDatabase database) async {
  final rows = await (database.select(database.clubs)
        ..where((c) => c.isUser))
      .get();
  return rows.isEmpty ? null : rows.first;
}

Future<Set<String>> _claimKeys(
  AchievementClaimsRepository repository,
  int clubId,
) async {
  final claims = await repository.claimsForClub(clubId);
  return {
    for (final c in claims) '${c.achievementId}:${c.tierKey}',
  };
}
