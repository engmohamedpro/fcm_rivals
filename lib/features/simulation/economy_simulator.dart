/// FCM Rivals — economy & progression simulation harness (GDD 30, 32, 33).
///
/// Simulates whole save files: club creation, squad assembly, multiple
/// seasons of fixtures (played through the real MatchSession pipeline
/// with stamina/rewards), pack openings, duplicate merges, selling and
/// rewarded-ad usage. Measures the GDD 30 list — coins earned/spent per
/// season, pack openings, collection growth, upgrade frequency, time to
/// obtain stronger players — plus the GDD 32 progression invariants
/// (promotion achievable, higher divisions harder, relegation possible,
/// no coin inflation) and the GDD 33 ad scenarios.
///
/// The simulator drives the REAL stores (Drift in-memory database), so
/// the numbers reflect the shipping code paths, not approximations.
/// Every random input is seeded (GDD development rule 7).
library;

import 'dart:math' as math;

import 'package:drift/native.dart';

import '../../core/database/app_database.dart';
import '../ads/ad_engine.dart';
import '../ads/ad_store.dart';
import '../collection/collection_store.dart';
import '../packs/pack_engine.dart';
import '../match/match_engine.dart';
import '../player_database/player_database.dart';
import '../season/season_engine.dart';
import '../season/season_store.dart';
import '../squad/formations.dart';
import '../squad/squad_engine.dart' show PlayerCard;
import '../upgrades/upgrade_engine.dart';
import 'economy_simulator_dataset.dart';

/// Per-season economy measurement (GDD 30 list).
class SeasonEconomyReport {
  SeasonEconomyReport({
    required this.seasonIndex,
    required this.division,
    required this.finalPosition,
    required this.outcome,
    required this.coinsEarned,
    required this.coinsSpent,
    required this.coinsEnd,
    required this.packOpenings,
    required this.merges,
    required this.collectionSize,
    required this.bestSquadOverall,
  });

  final int seasonIndex;
  final int division;
  final int finalPosition;
  final String outcome;

  /// Coins credited this season (matches, season reward, sales).
  final int coinsEarned;

  /// Coins debited this season (pack purchases if any, upgrades).
  final int coinsSpent;

  final int coinsEnd;

  final int packOpenings;
  final int merges;

  /// Distinct owned players at season end.
  final int collectionSize;

  /// Best achievable XI overall (auto-picked) at season end.
  final int bestSquadOverall;

  /// Net coin change this season (earned - spent).
  int get netCoins => coinsEarned - coinsSpent;
}

/// Whole-save progression report (GDD 30/32/33).
class EconomySimReport {
  EconomySimReport({
    required this.label,
    required this.seasons,
    required this.useAds,
    required this.startingCoins,
    required this.finalCoins,
    required this.maxDivisionReached,
    required this.promotions,
    required this.relegations,
    required this.adsWatched,
    required this.matchWins,
    required this.matchDraws,
    required this.matchLosses,
  });

  final String label;
  final List<SeasonEconomyReport> seasons;
  final bool useAds;

  final int startingCoins;
  final int finalCoins;
  final int maxDivisionReached;
  final int promotions;
  final int relegations;

  /// Successfully completed rewarded ads (GDD 33 scenarios).
  final int adsWatched;

  final int matchWins;
  final int matchDraws;
  final int matchLosses;

  /// GDD 32 'rewards do not cause Coin inflation': average net coins per
  /// season must stay bounded — the harness asserts a generous ceiling
  /// elsewhere; here we just report it.
  double get avgNetCoinsPerSeason => seasons.isEmpty
      ? 0
      : seasons.fold<int>(0, (a, s) => a + s.netCoins) / seasons.length;

  /// 'Time needed to obtain stronger players' (GDD 30): the first season
  /// index (0-based) whose best XI overall reaches [target], or null.
  int? seasonsToReachOverall(int target) {
    for (final s in seasons) {
      if (s.bestSquadOverall >= target) return s.seasonIndex;
    }
    return null;
  }
}

/// Drives a full save file through the real store stack.
class EconomySimulator {
  EconomySimulator({int seed = 20261101}) : _random = math.Random(seed);

  final math.Random _random;

  /// Level-cap check before attempting a merge (mirrors the store's
  /// validation so the simulation never trips on a capped pair).
  static const UpgradeEngine upgrades = UpgradeEngine();

  /// Runs one simulated save: [seasonCount] full seasons.
  ///
  /// [valueBand] picks the dataset's market values (GDD 30 low/medium/
  /// high scenarios); [useAds] enables the GDD 33 rewarded-ad behaviour
  /// (boosted recovery after non-wins, within daily limits).
  Future<EconomySimReport> run({
    required String label,
    required int seasonCount,
    SimValueBand valueBand = SimValueBand.medium,
    bool useAds = false,
    int datasetSize = 240,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    try {
      final dataset = SimDataset.generate(
        band: valueBand,
        size: datasetSize,
        random: math.Random(_random.nextInt(1 << 31)),
      );
      final collection = CollectionStore(db: db);
      await collection.applyDatasetUpdate(
        PlayerDataset.fromJson(dataset.toJson()),
      );
      await collection.createClub(
        clubName: 'Sim FC',
        managerName: 'Sim',
        crestIndex: 0,
      );

      // Opening packs & assembling the squad before season 1.
      var packOpenings = 0;
      for (final pack in await collection.getAvailablePacks()) {
        await collection.openPack(
          packId: pack.id,
          random: math.Random(_random.nextInt(1 << 31)),
        );
        packOpenings++;
      }
      await collection.autoPickSquad();

      final seasonStore = SeasonStore(
        db: db,
        random: math.Random(_random.nextInt(1 << 31)),
      );
      final adStore = AdStore(db: db);
      final startingCoins = (await collection.getClub())!.coins;

      final seasons = <SeasonEconomyReport>[];
      var promotions = 0, relegations = 0, adsWatched = 0;
      var wins = 0, draws = 0, losses = 0;

      var first = true;
      for (var s = 0; s < seasonCount; s++) {
        if (first) {
          await seasonStore.startSeason(division: 1);
          first = false;
        } else {
          await seasonStore.startNextSeason(collection);
        }

        final coinsStart = (await collection.getClub())!.coins;
        final earnedBefore = await _sumLedger(db, positive: true);
        final spentBefore = await _sumLedger(db, positive: false);
        var mergesThisSeason = 0;

        // Bootstrap: the 12 free starting packs (cheapest four positions)
        // cannot field a full XI, so the simulated manager signs players
        // before the first fixture — exactly like a real player must.
        await _buyAndOpenPacks(collection);
        await collection.autoPickSquad();
        while (!await _canFieldXI(collection)) {
          final before = (await collection.getClub())!.coins;
          packOpenings += await _buyAndOpenPacks(collection);
          await collection.autoPickSquad();
          if (!await _canFieldXI(collection) &&
              (await collection.getClub())!.coins >= before) {
            break; // out of money and still incomplete — nothing to buy
          }
        }

        // Play every user fixture through the real pipeline.
        while (true) {
          final next = await seasonStore.getNextFixture();
          if (next == null) break;
          final session = await seasonStore.startNextFixture(collection);
          session.simulateToEnd();

          final userHome = session.userSide == MatchSide.home;
          final userGoals = userHome
              ? session.engine.state.scoreHome
              : session.engine.state.scoreAway;
          final opponentGoals = userHome
              ? session.engine.state.scoreAway
              : session.engine.state.scoreHome;
          final userWon = userGoals > opponentGoals;

          if (useAds && !userWon) {
            // GDD 33: boosted recovery ad after a non-win (validated +
            // limited by the AdStore).
            try {
              await adStore.completeAd(
                kind: AdRewardKind.boostedRecovery,
                rewardKey: 'match:${next.fixtureId}',
                playbackCompleted: true,
                clubId: (await collection.getClub())!.id,
              );
              adsWatched++;
              await session.finish(adBoostedRecovery: true);
            } on AdException {
              await session.finish();
            }
          } else {
            await session.finish();
          }
          await seasonStore.commitFixtureResult(session, next);
          if (userWon) {
            wins++;
          } else if (userGoals == opponentGoals) {
            draws++;
          } else {
            losses++;
          }

          // Squad upkeep between fixtures: merge duplicates when found
          // and reinvest surplus coins in new packs (the GDD 30 spend
          // path: buying packs is the player's main coin sink). The XI
          // is re-picked afterwards so new signings actually play — a
          // manager who never refreshes the lineup once the collection
          // improved was understating the player's real progression.
          mergesThisSeason += await _mergeOneDuplicateIfAny(collection);
          packOpenings += await _buyAndOpenPacks(collection);
          await collection.autoPickSquad();
        }

        final completion = await seasonStore.completeSeason(collection);
        if (completion.outcome == SeasonOutcome.promoted.name) promotions++;
        if (completion.outcome == SeasonOutcome.relegated.name) relegations++;

        final earnedAfter = await _sumLedger(db, positive: true);
        final spentAfter = await _sumLedger(db, positive: false);
        final coinsEnd = (await collection.getClub())!.coins;
        final squad = await collection.getSquad();
        var bestOverall = 0;
        if (squad.isNotEmpty) {
          final cards = squad.values.toList()
            ..sort((a, b) => b.overall.compareTo(a.overall));
          bestOverall =
              cards.take(11).fold<int>(0, (a, c) => a + c.overall) ~/
              math.min(11, cards.length);
        }
        seasons.add(
          SeasonEconomyReport(
            seasonIndex: s,
            division: completion.division,
            finalPosition: completion.finalPosition,
            outcome: completion.outcome,
            // Season 1 ledger includes the starting grant — strip it so
            // the metric measures the season's own economy (GDD 30).
            coinsEarned:
                earnedAfter - earnedBefore - (s == 0 ? startingCoins : 0),
            coinsSpent: spentAfter - spentBefore,
            coinsEnd: coinsEnd,
            packOpenings: packOpenings,
            merges: mergesThisSeason,
            collectionSize: (await collection.getCollection()).length,
            bestSquadOverall: bestOverall,
          ),
        );
        // Coins balance check at the end of each season.
        final ledgerBalance =
            coinsStart +
            (earnedAfter - earnedBefore) -
            (spentAfter - spentBefore);
        if (coinsEnd != ledgerBalance) {
          final rows = await db.select(db.coinTransactions).get();
          throw StateError(
            'ledger must reconcile with the club balance '
            '(season $s: coins $coinsEnd vs ledger $ledgerBalance). '
            'Rows: ${rows.map((r) => '${r.amount}:${r.reason}').join(', ')}',
          );
        }
      }

      return EconomySimReport(
        label: label,
        seasons: seasons,
        useAds: useAds,
        startingCoins: startingCoins,
        finalCoins: (await collection.getClub())!.coins,
        maxDivisionReached: seasons.fold<int>(
          1,
          (a, s) => math.max(a, s.division),
        ),
        promotions: promotions,
        relegations: relegations,
        adsWatched: adsWatched,
        matchWins: wins,
        matchDraws: draws,
        matchLosses: losses,
      );
    } finally {
      await db.close();
    }
  }

  /// Whether the persisted squad fills all eleven starting-XI slots.
  Future<bool> _canFieldXI(CollectionStore collection) async {
    final squad = await collection.getSquad();
    var inXi = 0;
    for (final slot in squad.keys) {
      if (slot < Formation.startingXiSize) inXi++;
    }
    return inXi >= Formation.startingXiSize;
  }

  /// Sums the ledger in one direction; spent comes back as negative rows.
  Future<int> _sumLedger(AppDatabase db, {required bool positive}) async {
    final rows = await db.select(db.coinTransactions).get();
    var sum = 0;
    for (final r in rows) {
      if (positive && r.amount > 0) sum += r.amount;
      if (!positive && r.amount < 0) sum += r.amount;
    }
    return positive ? sum : -sum;
  }

  /// Buys and immediately opens global packs while the bank covers the
  /// price, keeping a small reserve — the natural player loop that turns
  /// match earnings into collection growth (GDD 30 spend measurement).
  /// The best affordable tier wins, mirroring a real player's instinct.
  Future<int> _buyAndOpenPacks(CollectionStore collection) async {
    var opened = 0;
    while (true) {
      final club = await collection.getClub();
      if (club == null) return opened;
      // Keep a reserve so match-day stamina/recovery spending is never
      // blocked; stop at two unaffordable attempts in a row.
      Pack? bought;
      for (final tier in [PackTier.legendary, PackTier.epic, PackTier.rare]) {
        try {
          bought = await collection.buyPack(
            category: PackCategory.global,
            tier: tier,
          );
          break;
        } on CollectionException {
          continue; // this tier is beyond the wallet — try the next down
        }
      }
      if (bought == null) return opened; // not enough coins — done for now
      if (club.coins - bought.price < 2_000) {
        // Bought the last affordable pack — open it, then stop.
        await collection.openPack(
          packId: bought.id,
          random: math.Random(_random.nextInt(1 << 31)),
        );
        return opened + 1;
      }
      await collection.openPack(
        packId: bought.id,
        random: math.Random(_random.nextInt(1 << 31)),
      );
      opened++;
    }
  }

  /// Merges one duplicate pair if the collection has one (upgrade
  /// frequency measurement, GDD 8/30). Returns the number of merges.
  Future<int> _mergeOneDuplicateIfAny(CollectionStore collection) async {
    final cards = await collection.getCollection();
    final byPlayer = <int, List<PlayerCard>>{};
    for (final c in cards) {
      byPlayer.putIfAbsent(c.base.playerId, () => []).add(c);
    }
    for (final copies in byPlayer.values) {
      if (copies.length < 2) continue;
      final target = copies[0];
      final duplicate = copies
          .skip(1)
          .firstWhere((c) => c.ownedId != target.ownedId);
      // Capped pairs stay unmerged — a maxed copy is kept, not consumed.
      if (!upgrades.canMerge(
        targetLevel: target.upgradeLevel,
        duplicateLevel: duplicate.upgradeLevel,
      )) {
        continue;
      }
      await collection.mergeDuplicates(
        targetOwnedId: target.ownedId,
        duplicateOwnedId: duplicate.ownedId,
        random: math.Random(_random.nextInt(1 << 31)),
      );
      return 1;
    }
    return 0;
  }
}
