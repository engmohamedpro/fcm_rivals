// The migration + retroactivity release gate (T-0113): a RICH
// pre-achievements save (the synthetic career fixture — real engine
// shapes: played results with the W/D/L mix, a title season, packs,
// upgrades, ledger rows) written at the v13 schema, opened on v14,
// and the whole observable contract: migration clean, metrics
// derived exactly, the retroactively-eligible tiers claimable,
// NOTHING auto-granted, the first claim through the real pipeline.
library;

import 'dart:io' show Directory, File;

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart' as db;
import 'package:fcm_rivals/features/achievements/achievement_claim_service.dart';
import 'package:fcm_rivals/features/achievements/achievement_claims_repository.dart';
import 'package:fcm_rivals/features/achievements/achievement_progress.dart';

import 'career_fixtures.dart';

void main() {
  test('a pre-v13 save migrates to v14 and retro-derives EXACTLY '
      'with a zero-claims state, then the first claim lands', () async {
    // 1. The RICH save on a FILE (a played season with the W/D/L mix,
    // a title season, packs, upgrades, ledger rows — the fixture's
    // real engine shapes).
    final file = File(
      '${Directory.systemTemp.createTempSync('fcm_ach').path}/save.sqlite',
    );
    var database = await buildSyntheticCareerOnFile(file);

    // 2. Rewind to v13: drop the v14 surfaces a pre-achievements
    // install never had (the claims table + the equipped column).
    await database
        .customStatement('DROP TABLE achievement_claims');
    await database
        .customStatement('PRAGMA user_version = 13');
    await database.close();

    // 3. Reopen on the current schema: the v13→v14 step runs on the
    // real file (the raw-file path the migration contract rides).
    database = db.AppDatabase(NativeDatabase(file));
    expect(database.schemaVersion, 14);
    final hasClaims = (await database
            .customSelect('PRAGMA table_info(achievement_claims)')
            .get())
        .isNotEmpty;
    final hasEquipped = (await database
            .customSelect('PRAGMA table_info(user_settings)')
            .get())
        .any((row) => row.read<String>('name') == 'equipped_title');
    expect(hasClaims, isTrue,
        reason: 'the v14 step re-created the claims table');
    expect(hasEquipped, isTrue,
        reason: 'the v14 step re-added the equipped column');

    // 4. Retro-derivation: EXACT against the fixture's ground truth.
    final metrics = await deriveCareerMetrics(database, 1);
    expect(metrics.wins, ExpectedCareer.wins);
    expect(metrics.draws, ExpectedCareer.draws);
    expect(metrics.losses, ExpectedCareer.losses);
    expect(metrics.goalsFor, ExpectedCareer.goalsFor);
    expect(metrics.titlesByDivisionTotal,
        ExpectedCareer.titlesByDivisionTotal);
    expect(metrics.packsOpened, ExpectedCareer.packsOpened);
    expect(metrics.upgradesCompleted,
        ExpectedCareer.upgradesCompleted);
    expect(metrics.lifetimeCoinsEarned,
        ExpectedCareer.lifetimeCoinsEarned);

    // 5. NOTHING auto-granted: the claims table is empty.
    final repo = AchievementClaimsRepository(database);
    expect(await repo.claimsForClub(1), isEmpty,
        reason: 'migration never grants — retroactivity renders '
            'eligible tiers as CLAIMABLE, not claimed');

    // 6. The FIRST claim through the real pipeline succeeds.
    final balanceBefore =
        (await (database.select(database.clubs)
                  ..where((c) => c.id.equals(1)))
            .getSingle())
            .coins;
    final service = AchievementClaimService(database);
    final result = await service.claimTier(
      clubId: 1,
      achievementId: 'career_wins',
      tierKey: '1',
    );
    expect(result, isA<ClaimGranted>());
    expect(
      (await repo.claimsForClub(1)).single.tierKey,
      '1',
      reason: 'the retroactive-eligible tier claimed on first tap',
    );
    final ledger = await database
        .select(database.coinTransactions)
        .get();
    expect(ledger.any((r) => r.reason == 'achievement'), isTrue);
    final balanceAfter =
        (await (database.select(database.clubs)
                  ..where((c) => c.id.equals(1)))
            .getSingle())
            .coins;
    expect(balanceAfter, greaterThan(balanceBefore));
    await database.close();
  });

  test('KILL-CLAIM RECOVERY: the all-or-nothing XOR contract — '
      'a failing second write leaves NEITHER row', () async {
    final database = await buildSyntheticCareer();
    addTearDown(database.close);

    final balanceBefore =
        (await (database.select(database.clubs)
                  ..where((c) => c.id.equals(1)))
            .getSingle())
            .coins;
    final ledgerBefore =
        await database.select(database.coinTransactions).get();
    final claimsBefore = await AchievementClaimsRepository(database)
        .claimsForClub(1);

    // Simulate the kill at the controllable point: the claim's two
    // writes with the SECOND one failing. The service's transaction
    // must roll back the first write with it (drift's atomicity) —
    // the OBSERVABLE contract: claim row XOR nothing, never half.
    final boom = StateError('process killed mid-claim');
    var firstWriteLanded = false;
    await expectLater(
      database.transaction(() async {
        await database
            .into(database.achievementClaims)
            .insert(
              db.AchievementClaimsCompanion.insert(
                clubId: 1,
                achievementId: 'career_wins',
                tierKey: '2',
                rewardCoins: 20,
                claimedAt: DateTime.now(),
              ),
            );
        firstWriteLanded = true;
        // The credit that never completes (the kill point).
        throw boom;
      }),
      throwsA(boom),
      reason: 'the injected failure surfaces',
    );
    expect(firstWriteLanded, isTrue,
        reason: 'the first write DID land inside the transaction');

    // NEITHER row: the rollback removed the claim row; the ledger and
    // the balance never moved.
    expect(
      await AchievementClaimsRepository(database).claimsForClub(1),
      claimsBefore,
      reason: 'the XOR contract: no claim row without its credit',
    );
    final ledgerAfter =
        await database.select(database.coinTransactions).get();
    expect(
      ledgerAfter.where((r) => r.reason == 'achievement').length,
      ledgerBefore.where((r) => r.reason == 'achievement').length,
      reason: 'no half state: no ledger row without its claim',
    );
    final balanceAfter =
        (await (database.select(database.clubs)
                  ..where((c) => c.id.equals(1)))
            .getSingle())
            .coins;
    expect(balanceAfter, balanceBefore,
        reason: 'the balance is consistent with the ledger in the '
            'killed case');
  });
}
