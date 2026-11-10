// The progress derivation engine (T-0107): the whole career computed
// from the save — retroactive by construction (fixture first, derive
// after, zero writes), exact expected values, and the derivability
// census (what is NOT derivable is carried as documented zeros, never
// faked counters).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/features/achievements/achievement_progress.dart';

import 'career_fixtures.dart';

void main() {
  test('empty save: all zeros, no crash, null joinedAt', () async {
    final db = await buildEmptySave();
    addTearDown(db.close);

    final metrics = await deriveCareerMetrics(db, ExpectedCareer.clubId);
    expect(metrics.matchesManaged, 0);
    expect(metrics.wins, 0);
    expect(metrics.draws, 0);
    expect(metrics.losses, 0);
    expect(metrics.goalsFor, 0);
    expect(metrics.goalsAgainst, 0);
    expect(metrics.cleanSheets, 0);
    expect(metrics.longestWinStreak, 0);
    expect(metrics.longestUnbeatenStreak, 0);
    expect(metrics.longestCleanSheetStreak, 0);
    expect(metrics.mostGoalsInOneMatch, 0);
    expect(metrics.matchesScoredFirst, 0);
    expect(metrics.titlesByDivisionTotal, 0);
    expect(metrics.promotions, 0);
    expect(metrics.relegations, 0);
    expect(metrics.seasonsCompleted, 0);
    expect(metrics.packsOpened, 0);
    expect(metrics.cardsOwned, 0);
    expect(metrics.legendaryCardsOwned, 0);
    expect(metrics.epicCardsOwned, 0);
    expect(metrics.highestUpgradeLevel, 0);
    expect(metrics.upgradesCompleted, 0);
    expect(metrics.playerSalesCompleted, 0);
    expect(metrics.lifetimeCoinsEarned, 0);
    expect(metrics.coinsSpentOnPacks, 0);
    expect(metrics.coinsSpentOnUpgrades, 0);
    expect(metrics.facilityLevelTotal, 0);
    expect(metrics.recoveryCentreLevel, 0);
    expect(metrics.joinedAt, isNull);
    expect(metrics.legendaryPulls, 0);
    expect(metrics.tacticsInstructionsChanged, 0);
  });

  test('the synthetic career: every metric exactly', () async {
    final db = await buildSyntheticCareer();
    addTearDown(db.close);

    final m = await deriveCareerMetrics(db, ExpectedCareer.clubId);

    // Career.
    expect(m.matchesManaged, ExpectedCareer.matchesManaged,
        reason: '5 unique fixtures — the replayed one counts ONCE');
    expect(m.homeMatches, ExpectedCareer.homeMatches);
    expect(m.awayMatches, ExpectedCareer.awayMatches);
    expect(m.wins, ExpectedCareer.wins);
    expect(m.draws, ExpectedCareer.draws);
    expect(m.losses, ExpectedCareer.losses,
        reason: 'the replay REPLACED the loss, it did not append a win '
            'to the loss column');
    // Attack / defence.
    expect(m.goalsFor, ExpectedCareer.goalsFor);
    expect(m.goalsAgainst, ExpectedCareer.goalsAgainst);
    expect(m.cleanSheets, ExpectedCareer.cleanSheets);
    expect(m.mostGoalsInOneMatch, ExpectedCareer.mostGoalsInOneMatch);
    expect(m.matchesScoredFirst, ExpectedCareer.matchesScoredFirst);
    // Streaks.
    expect(m.longestWinStreak, ExpectedCareer.longestWinStreak);
    expect(m.longestUnbeatenStreak, ExpectedCareer.longestUnbeatenStreak,
        reason: 'the streak crosses the season boundary by design');
    expect(m.longestCleanSheetStreak, ExpectedCareer.longestCleanSheetStreak);
    // Silverware.
    expect(m.titlesByDivisionTotal, ExpectedCareer.titlesByDivisionTotal);
    expect(m.titlesByDivision, {2: 1, 1: 1},
        reason: 'a title in two different divisions');
    expect(m.promotions, ExpectedCareer.promotions);
    expect(m.relegations, ExpectedCareer.relegations);
    expect(m.seasonsCompleted, ExpectedCareer.seasonsCompleted);
    // Packs.
    expect(m.packsOpened, ExpectedCareer.packsOpened,
        reason: 'the unopened purchased pack does not count');
    expect(m.packsPurchased, ExpectedCareer.packsPurchased);
    expect(m.packsRewarded, ExpectedCareer.packsRewarded);
    expect(m.startingPacksOpened, ExpectedCareer.startingPacksOpened);
    // Squad.
    expect(m.cardsOwned, ExpectedCareer.cardsOwned,
        reason: 'the SOLD player is not owned');
    expect(m.legendaryCardsOwned, ExpectedCareer.legendaryCardsOwned,
        reason: '85 base and 85-upgraded-2 (87) are both legendary');
    expect(m.epicCardsOwned, ExpectedCareer.epicCardsOwned);
    expect(m.highestUpgradeLevel, ExpectedCareer.highestUpgradeLevel);
    expect(m.upgradesCompleted, ExpectedCareer.upgradesCompleted,
        reason: 'sum of owned levels = the merges that survived');
    expect(m.playerSalesCompleted, ExpectedCareer.playerSalesCompleted);
    // Economy.
    expect(m.lifetimeCoinsEarned, ExpectedCareer.lifetimeCoinsEarned,
        reason: 'positive rows only: grant + match + season + sale');
    expect(m.coinsSpentOnPacks, ExpectedCareer.coinsSpentOnPacks);
    expect(m.coinsSpentOnUpgrades, ExpectedCareer.coinsSpentOnUpgrades);
    // Campus.
    expect(m.facilityLevelTotal, ExpectedCareer.facilityLevelTotal);
    expect(m.recoveryCentreLevel, ExpectedCareer.recoveryCentreLevel);
    // Identity.
    expect(m.joinedAt, DateTime.fromMillisecondsSinceEpoch(1_700_000_050_000));
  });

  test('RETROACTIVITY: the fixture was built BEFORE the derivation ran '
      'and the save is unchanged after', () async {
    final db = await buildSyntheticCareer();
    addTearDown(db.close);

    // The row counts BEFORE.
    Future<int> count(String table) async =>
        (await db.customSelect('SELECT COUNT(*) AS n FROM $table')
                .get())
            .first
            .read<int>('n');
    final before = {
      'players': await count('players'),
      'clubs': await count('clubs'),
      'seasons': await count('seasons'),
      'match_results': await count('match_results'),
      'packs': await count('packs'),
      'owned_players': await count('owned_players'),
      'coin_transactions': await count('coin_transactions'),
      'facility_levels': await count('facility_levels'),
      'achievement_claims': await count('achievement_claims'),
    };

    await deriveCareerMetrics(db, ExpectedCareer.clubId);

    // ZERO writes: every count identical, no claim rows appeared, no
    // ledger rows appeared.
    for (final entry in before.entries) {
      expect(await count(entry.key), entry.value,
          reason: '${entry.key} row count changed — the derivation '
              'must be pure reads');
    }
  });

  test('progressFor: the catalog metric map is total — every id '
      'resolves (or is a documented zero)', () async {
    final db = await buildSyntheticCareer();
    addTearDown(db.close);
    final m = await deriveCareerMetrics(db, ExpectedCareer.clubId);

    // Every metric id the catalog uses resolves to a value (the engine
    // knows all of them — 0 is a real value for the not-derivable
    // ones, null would be a gap).
    final known = <String>{
      'matchesManaged', 'homeMatches', 'awayMatches', 'wins', 'draws',
      'losses', 'goalsFor', 'goalsAgainst', 'cleanSheets',
      'longestWinStreak', 'longestUnbeatenStreak',
      'longestCleanSheetStreak', 'mostGoalsInOneMatch',
      'matchesScoredFirst', 'titlesByDivisionTotal', 'promotions',
      'relegations', 'seasonsCompleted', 'packsOpened',
      'packsPurchased', 'packsRewarded', 'startingPacksOpened',
      'cardsOwned', 'legendaryCardsOwned', 'epicCardsOwned',
      'highestUpgradeLevel', 'upgradesCompleted', 'legendaryPulls',
      'playerSalesCompleted', 'lifetimeCoinsEarned',
      'coinsSpentOnPacks', 'coinsSpentOnUpgrades', 'facilityLevelTotal',
      'recoveryCentreLevel', 'tacticsInstructionsChanged',
    };
    for (final id in known) {
      expect(m.progressFor(id), isNotNull, reason: 'metric $id unresolved');
    }
    expect(m.progressFor('nonexistent'), isNull);
    // The synthetic career has real values on the derivable ones.
    expect(m.progressFor('wins'), ExpectedCareer.wins);
    expect(m.progressFor('packsOpened'), ExpectedCareer.packsOpened);
    // The documented non-derivables carry 0 — never a fake counter.
    expect(m.progressFor('tacticsInstructionsChanged'), 0);
    expect(m.progressFor('legendaryPulls'), 0);
  });
}
