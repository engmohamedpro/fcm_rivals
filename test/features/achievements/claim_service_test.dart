// The claim pipeline contracts (T-0108): the all-or-nothing claim +
// credit transaction, the UNIQUE-guarded idempotency, state-derived
// eligibility, the ledger convention, title recording, and the batch
// path. Built on T-0107's synthetic career (4 wins, 3 clean sheets,
// 3 packs opened...) with a REAL balance.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart' as db;
import 'package:fcm_rivals/features/achievements/achievement_claim_service.dart';
import 'package:fcm_rivals/features/achievements/achievement_claims_repository.dart';

import 'career_fixtures.dart';

void main() {
  late db.AppDatabase database;
  late AchievementClaimService service;
  late AchievementClaimsRepository repo;

  setUp(() async {
    database = await buildSyntheticCareer();
    service = AchievementClaimService(database);
    repo = AchievementClaimsRepository(database);
  });

  tearDown(() => database.close());

  Future<int> balance() async =>
      (await (database.select(database.clubs)
              ..where((c) => c.id.equals(1)))
          .getSingle())
          .coins;

  Future<int> ledgerCount(String reason, String detail) async {
    final rows = await (database.select(database.coinTransactions)
          ..where((t) => t.reason.equals(reason)))
        .get();
    return rows.where((t) => t.detail == detail).length;
  }

  test('happy path: granted, ledger row exact, balance moved', () async {
    // The fixture career has 4 wins — tier '4' of career_wins is
    // eligible; flat reward 20.
    final before = await balance();
    final result = await service.claimTier(
      clubId: 1,
      achievementId: 'career_wins',
      tierKey: '4',
    );
    expect(result, isA<ClaimGranted>());
    final granted = result as ClaimGranted;
    expect(granted.coins, 20);
    // career_wins IS a flagship: tier index 3 (threshold 4) confers
    // title1 — the happy path and the title test both prove it.
    expect(granted.titleGranted, 'career_wins-title1');

    expect(await balance(), before + 20);
    expect(await ledgerCount('achievement', 'career_wins:4'), 1,
        reason: "the convention: reason 'achievement', detail "
            "'<achievementId>:<tierKey>'");
    final claims = await repo.claimsForClub(1);
    expect(claims.single.achievementId, 'career_wins');
    expect(claims.single.tierKey, '4');
    expect(claims.single.rewardCoins, 20);
  });

  test('double claim: AlreadyClaimed, balance unchanged, still ONE '
      'ledger row', () async {
    final before = await balance();
    await service.claimTier(
      clubId: 1,
      achievementId: 'career_wins',
      tierKey: '4',
    );
    final afterFirst = await balance();

    // The double tap — same triple.
    final second = await service.claimTier(
      clubId: 1,
      achievementId: 'career_wins',
      tierKey: '4',
    );
    expect(second, isA<ClaimAlreadyClaimed>(),
        reason: 'an idempotent no-op, never an error');
    expect(await balance(), afterFirst);
    expect(await ledgerCount('achievement', 'career_wins:4'), 1,
        reason: 'no second credit ever landed');
    expect((await repo.claimsForClub(1)).length, 1);
    expect(afterFirst, before + 20);
  });

  test('not eligible: derived state decides, no rows, no coins', () async {
    final before = await balance();
    // Tier '64' of career_wins: the save derives 4 wins — 64 is
    // beyond it. A stale/tampered UI cannot claim it.
    final result = await service.claimTier(
      clubId: 1,
      achievementId: 'career_wins',
      tierKey: '64',
    );
    expect(result, isA<ClaimNotEligible>());
    final rejected = result as ClaimNotEligible;
    expect(rejected.progress, 4, reason: 'the save-derived number');
    expect(rejected.threshold, 64);
    expect(await balance(), before);
    expect((await repo.claimsForClub(1)), isEmpty);
    expect(await ledgerCount('achievement', 'career_wins:64'), 0);
  });

  test('title tier: the claim records the title it confers', () async {
    // cleanSheets = 3 in the fixture; rung 3 of
    // defence_clean_sheets confers... rungs 3/6 of FLAGSHIPS confer
    // titles: defence_clean_sheets IS a flagship. Tier '2' (threshold
    // 4? No — base 1 ratio 2: thresholds 1,2,4,8...). Tier index 3 has
    // threshold 4 — the fixture's 3 clean sheets do NOT reach it. Use
    // career_wins instead: 4 wins reaches threshold 4 at tier index 3
    // → titleId career_wins-title1.
    final result = await service.claimTier(
      clubId: 1,
      achievementId: 'career_wins',
      tierKey: '4',
    );
    expect(result, isA<ClaimGranted>());
    // (career_wins IS a flagship: tier index 3 → title1.)
    final claims = await repo.claimsForClub(1);
    expect(claims.single.titleGranted, 'career_wins-title1',
        reason: 'the claim row records the conferred title (granting '
            '≠ equipping — T-0112)');
  });

  test('claimAllTiers: the eligible-and-unclaimed set, each through '
      'the single-tier path', () async {
    final before = await balance();
    // career_wins with 4 wins: eligible unclaimed thresholds are the
    // ladder's 1, 2 and 4 (three rungs) — 8+ stay locked.
    final results = await service.claimAllTiers(
      clubId: 1,
      achievementId: 'career_wins',
    );
    expect(results.length, 3);
    expect(results.whereType<ClaimGranted>().length, 3);
    expect(await balance(), before + 3 * 20);
    expect((await repo.claimsForClub(1)).length, 3);
    for (final key in ['1', '2', '4']) {
      expect(await ledgerCount('achievement', 'career_wins:$key'), 1);
    }

    // Re-running the batch: everything is claimed — zero new results.
    final again = await service.claimAllTiers(
      clubId: 1,
      achievementId: 'career_wins',
    );
    expect(again, isEmpty);
    expect(await balance(), before + 60);
  });

  test('milestone claims pay the milestone budget, not the flat '
      'ladder rate', () async {
    // 3 packs opened → milestone... no pack milestone at 3; but the
    // career milestone 'milestone_first_win' (1 win, budget 300):
    final before = await balance();
    final result = await service.claimTier(
      clubId: 1,
      achievementId: 'milestone_first_win',
      tierKey: '1',
    );
    expect(result, isA<ClaimGranted>());
    expect((result as ClaimGranted).coins, 300);
    expect(await balance(), before + 300);
  });

  test('claimStateFor: the UI pre-flight mirrors the outcomes without '
      'writing', () async {
    // Not yet claimed, not eligible.
    var state = await service.claimStateFor(
      clubId: 1,
      achievementId: 'career_wins',
      tierKey: '64',
    );
    expect(state, isA<ClaimNotEligible>());

    // Eligible.
    state = await service.claimStateFor(
      clubId: 1,
      achievementId: 'career_wins',
      tierKey: '4',
    );
    expect(state, isA<ClaimGranted>());
    expect((await repo.claimsForClub(1)), isEmpty,
        reason: 'the pre-flight writes nothing');
    expect(await ledgerCount('achievement', 'career_wins:4'), 0);

    // Claim for real, then the pre-flight says already-claimed.
    await service.claimTier(
      clubId: 1,
      achievementId: 'career_wins',
      tierKey: '4',
    );
    state = await service.claimStateFor(
      clubId: 1,
      achievementId: 'career_wins',
      tierKey: '4',
    );
    expect(state, isA<ClaimAlreadyClaimed>());
  });
}
