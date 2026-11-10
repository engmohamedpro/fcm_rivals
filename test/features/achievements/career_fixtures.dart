// Reusable career fixtures for the achievements tests (T-0107) and
// the profile career stats (T-0112): one synthetic club career across
// two seasons — home/away wins, draws, losses, a REPLAYED fixture
// (counted once), goals by side, streaks crossing the season
// boundary, a title in two different divisions, packs split by
// source, owned/sold player statuses, ledger rows per reason,
// facilities. Pure drift row inserts — the exact save the derivation
// must read back.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart' as db;

/// The synthetic career's EXPECTED metric values — the single source
/// of truth the engine tests and (later) the profile stats assert
/// against. Every number here is chosen to be non-trivial: no two
/// metrics accidentally equal, streaks that cross the season
/// boundary, a replay that must not double-count.
class ExpectedCareer {
  static const clubId = 1;
  static const otherClubId = 2;

  // Matches: 2 home wins, 1 away win, 1 draw, 1 loss, 1 replayed
  // (replaces an original loss) = 6 total, 5 unique fixtures.
  static const matchesManaged = 5;
  static const homeMatches = 3;
  static const awayMatches = 2;
  static const wins = 4;
  static const draws = 1;
  static const losses = 0;
  // Goals: 2+3 home wins, 2 away win, 1 draw, 1 replay win = 9 for;
  // conceded 0+1+0+1+0 = 2.
  static const goalsFor = 9;
  static const goalsAgainst = 2;
  // Clean sheets: the 2-0 home win, the 2-0 away win and the 1-0
  // replay win = 3.
  static const cleanSheets = 3;
  static const mostGoalsInOneMatch = 3;
  // Scored-first proxy (scored > conceded): the 3 wins only — the
  // draw is not. == wins here by construction.
  static const matchesScoredFirst = 4;
  // Timeline: W W W D W (the replay REPLACES the original loss).
  // Longest win streak = 3 (the draw breaks it); unbeaten = 5 (the
  // whole timeline); clean-sheet pattern ✓ ✗ ✓ ✗ ✓ → streak = 1.
  static const longestWinStreak = 3;
  static const longestUnbeatenStreak = 5;
  static const longestCleanSheetStreak = 1;

  // Seasons: two completed — division 2 title (finalPosition 1,
  // promoted) and division 1 title (finalPosition 1, stayed).
  static const titlesByDivisionTotal = 2;
  static const promotions = 1;
  static const relegations = 0;
  static const seasonsCompleted = 2;

  // Packs: 3 opened — 1 starting, 1 purchased, 1 reward (+1 unopened).
  static const packsOpened = 3;
  static const packsPurchased = 1;
  static const packsRewarded = 1;
  static const startingPacksOpened = 1;

  // Squad: 4 owned — base 85 (legendary), upgraded 85+2% (legendary),
  // base 74 (epic), base 60 (rare); highest upgrade level 2; merges =
  // 0+2+0+0 = 2. One SOLD player (status 'sold', not owned — not
  // counted in cardsOwned).
  static const cardsOwned = 4;
  static const legendaryCardsOwned = 2;
  static const epicCardsOwned = 1;
  static const highestUpgradeLevel = 2;
  static const upgradesCompleted = 2;
  static const playerSalesCompleted = 1;

  // Ledger (positive rows only count as earned): 25k grant, 1500
  // match reward, 800 season reward, 300 sale = 27,600 earned.
  // Spends: 500 pack, 900 facility.
  static const lifetimeCoinsEarned = 27_600;
  static const coinsSpentOnPacks = 500;
  static const coinsSpentOnUpgrades = 900;

  // Facilities: attack 2, recovery 1 → total 3, recovery 1.
  static const facilityLevelTotal = 3;
  static const recoveryCentreLevel = 1;

  // Not derivable today (documented in the engine).
  static const legendaryPulls = 0;
  static const tacticsInstructionsChanged = 0;
}

/// Builds the synthetic career in a FRESH in-memory database and
/// returns it. The dataset players the owned cards reference must be
/// imported first (rarity derives from the base overall) — the four
/// base players are inserted directly into the players table.
Future<db.AppDatabase> buildSyntheticCareer() async {
  final database = db.AppDatabase(NativeDatabase.memory());

  // Base players for the owned cards: overall 85 / 85 / 74 / 60.
  Future<void> addPlayer(int playerId, String position, int overall) async {
    await database
        .into(database.players)
        .insert(
          db.PlayersCompanion.insert(
            playerId: Value(playerId),
            name: 'Player $playerId',
            position: position,
            nationality: 'Egypt',
            marketValueEur: 5_000_000,
            overall: overall,
            attack: overall - 2,
            support: overall,
            defence: overall - 4,
            goalkeeping: position == 'GK' ? overall : 10,
          ),
        );
  }

  await addPlayer(101, 'ST', 85);
  await addPlayer(102, 'CB', 85);
  await addPlayer(103, 'CM', 74);
  await addPlayer(104, 'RB', 60);

  // The club.
  await database
      .into(database.clubs)
      .insert(
        db.ClubsCompanion.insert(
          name: 'Pyramid United',
          managerName: 'Mohamed',
          coins: 27_600,
          createdAt: DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
        ),
      );

  // Two seasons: division 2 (completed, champions, promoted) and
  // division 1 (completed, champions, stayed).
  Future<int> addSeason(
    int division,
    int ordinal,
    int finalPosition,
    String outcome,
  ) async =>
      database
          .into(database.seasons)
          .insert(
            db.SeasonsCompanion.insert(
              division: division,
              ordinal: ordinal,
              userClubId: ExpectedCareer.clubId,
              status: const Value('completed'),
              startedAt: DateTime.fromMillisecondsSinceEpoch(
                1_700_000_000_000 + ordinal * 86_400_000,
              ),
              finalPosition: Value(finalPosition),
              outcome: Value(outcome),
            ),
          );

  final season1 = await addSeason(2, 1, 1, 'promoted');
  final season2 = await addSeason(1, 2, 1, 'stayed');

  // Match results — homeGoals/awayGoals belong to the REAL home and
  // away teams; the club's side flips with clubIsHome. Fixtures:
  //   s1 r1: home W 2-0            (fixtureId 11)
  //   s1 r2: home W 3-1            (fixtureId 12)
  //   s1 r3: away W 2-0 (0-2 real) (fixtureId 13)
  //   s2 r1: home D 1-1            (fixtureId 21)
  //   s2 r2: away L 0-2 REPLAYED as away W 1-0
  //          (fixtureId 22 — two rows, the later playedAt wins).
  Future<void> addResult(
    int fixtureId,
    int seasonId,
    int round,
    int homeGoals,
    int awayGoals, {
    int playedAtMs = 1_700_000_100_000,
    bool clubIsHome = true,
  }) async {
    final home = clubIsHome ? ExpectedCareer.clubId : ExpectedCareer.otherClubId;
    final away = clubIsHome ? ExpectedCareer.otherClubId : ExpectedCareer.clubId;
    await database
        .into(database.matchResults)
        .insert(
          db.MatchResultsCompanion.insert(
            fixtureId: fixtureId,
            seasonId: seasonId,
            round: round,
            homeClubId: home,
            awayClubId: away,
            homeGoals: homeGoals,
            awayGoals: awayGoals,
            seed: 1,
            engineVersion: 1,
            playedAt: DateTime.fromMillisecondsSinceEpoch(playedAtMs),
          ),
        );
  }

  await addResult(11, season1, 1, 2, 0);
  await addResult(12, season1, 2, 3, 1);
  await addResult(13, season1, 3, 0, 2, clubIsHome: false);
  await addResult(21, season2, 1, 1, 1);
  // The replayed fixture: original loss (away 0-2), then the replay
  // win (away 1-0) — homeGoals/awayGoals are the REAL home/away
  // teams' goals, the club's side comes from clubIsHome.
  await addResult(22, season2, 2, 2, 0, clubIsHome: false,
      playedAtMs: 1_700_000_200_000);
  await addResult(22, season2, 2, 0, 1, clubIsHome: false,
      playedAtMs: 1_700_000_300_000);

  // Packs: one per source, opened; one unopened.
  Future<void> addPack(String source, bool opened) async {
    await database
        .into(database.packs)
        .insert(
          db.PacksCompanion.insert(
            clubId: ExpectedCareer.clubId,
            category: 'standard',
            source: Value(source),
            opened: Value(opened),
            createdAt: DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
          ),
        );
  }

  await addPack('starting', true);
  await addPack('purchased', true);
  await addPack('reward', true);
  await addPack('purchased', false);

  // Owned players: 85 base, 85 base upgraded to level 2 (still
  // legendary: 85*1.02 = 86.7 → 87), 74 base (epic), 60 base (rare).
  // One sold (status 'sold').
  Future<void> addOwned(
    int playerId,
    int upgradeLevel,
    String status,
  ) async {
    await database
        .into(database.ownedPlayers)
        .insert(
          db.OwnedPlayersCompanion.insert(
            clubId: ExpectedCareer.clubId,
            playerId: playerId,
            upgradeLevel: Value(upgradeLevel),
            status: Value(status),
            acquiredAt: DateTime.fromMillisecondsSinceEpoch(
              1_700_000_050_000,
            ),
          ),
        );
  }

  await addOwned(101, 0, 'owned');
  await addOwned(102, 2, 'owned');
  await addOwned(103, 0, 'owned');
  await addOwned(104, 0, 'owned');
  await addOwned(104, 0, 'sold');

  // Ledger rows: every reason family the engine groups.
  Future<void> addLedger(
    int amount,
    String reason,
  ) async {
    var balance = 25_000;
    await database
        .into(database.coinTransactions)
        .insert(
          db.CoinTransactionsCompanion.insert(
            clubId: ExpectedCareer.clubId,
            amount: amount,
            balanceAfter: balance + amount,
            reason: reason,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              1_700_000_150_000,
            ),
          ),
        );
    balance += amount;
  }

  await addLedger(25_000, 'starting_grant');
  await addLedger(1_500, 'match_reward');
  await addLedger(800, 'season_reward');
  await addLedger(300, 'player_sale');
  await addLedger(-500, 'pack_purchase');
  await addLedger(-900, 'facility_upgrade');

  // Facilities: attack 2, recovery 1.
  Future<void> addFacility(String facility, int level) async {
    await database
        .into(database.facilityLevels)
        .insert(
          db.FacilityLevelsCompanion.insert(
            clubId: ExpectedCareer.clubId,
            facility: facility,
            level: Value(level),
            upgradedAt: Value(DateTime.fromMillisecondsSinceEpoch(
              1_700_000_400_000,
            )),
          ),
        );
  }

  await addFacility('attack', 2);
  await addFacility('recovery', 1);

  return database;
}

/// An EMPTY database (club only, nothing else) — the zero-save case.
Future<db.AppDatabase> buildEmptySave() async {
  final database = db.AppDatabase(NativeDatabase.memory());
  await database
      .into(database.clubs)
      .insert(
        db.ClubsCompanion.insert(
          name: 'Empty FC',
          managerName: 'Nobody',
          coins: 0,
          createdAt: DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
        ),
      );
  return database;
}
