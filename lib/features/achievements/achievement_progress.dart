/// FCM Rivals — the achievement progress derivation engine (T-0107).
///
/// Computes the whole career's metric snapshot from the EXISTING game
/// state — pure reads, zero writes, no hooks in any write path, no new
/// columns. Retroactive by construction: the day the achievements
/// feature ships, every player's whole history already counts, because
/// the source of truth is the save itself.
///
/// Shape: ONE `CareerMetrics` immutable snapshot, derived in a handful
/// of grouped queries (one per metric family — results, seasons, packs,
/// owned players, ledger, facilities — never N+1 per achievement). The
/// catalog maps metric ids onto the snapshot's fields through
/// `progressFor(metricId)` — a pure in-memory lookup AFTER the one
/// derivation.
///
/// Ledger reasons are typed constants here (the single home the task
/// demanded): production writes them, these queries read them, later
/// audits share them.
library;

import 'package:drift/drift.dart' hide isNull;

import '../../core/database/app_database.dart' as db;
import '../../core/ui/card_rarity.dart' show CardRarity;
import 'achievement_catalog_data.dart' show AchievementCatalog;

/// Every `reason` string production code writes to CoinTransactions.
/// The 2026-11-10 census (grep over lib/): these nine are the ledger
/// reasons; `'tired'`/`'chasing'` in match_engine_events are substitution
/// EVENT labels, not ledger rows. Achievements (T-0108) will add an
/// `achievement:` prefixed family — parsed there, not here.
abstract final class LedgerReasons {
  static const matchReward = 'match_reward';
  static const seasonReward = 'season_reward';
  static const packPurchase = 'pack_purchase';
  static const playerSale = 'player_sale';
  static const facilityUpgrade = 'facility_upgrade';
  static const startingGrant = 'starting_grant';
  static const removalCompensation = 'removal_compensation';
  static const matchReplayRefund = 'match_replay_refund';
  static const testGrant = 'test_grant';
}

/// The career's derived metric snapshot — every number the achievement
/// catalog and the profile stats (T-0112) read. Immutable; one
/// derivation per screen refresh, no caching layer here (the provider
/// layer that lands in T-0110 owns freshness).
class CareerMetrics {
  const CareerMetrics({
    required this.matchesManaged,
    required this.homeMatches,
    required this.awayMatches,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.cleanSheets,
    required this.longestWinStreak,
    required this.longestUnbeatenStreak,
    required this.longestCleanSheetStreak,
    required this.mostGoalsInOneMatch,
    required this.matchesScoredFirst,
    required this.titlesByDivision,
    required this.titlesByDivisionTotal,
    required this.promotions,
    required this.relegations,
    required this.seasonsCompleted,
    required this.packsOpened,
    required this.packsPurchased,
    required this.packsRewarded,
    required this.startingPacksOpened,
    required this.cardsOwned,
    required this.legendaryCardsOwned,
    required this.epicCardsOwned,
    required this.highestUpgradeLevel,
    required this.upgradesCompleted,
    required this.legendaryPulls,
    required this.playerSalesCompleted,
    required this.lifetimeCoinsEarned,
    required this.coinsSpentOnPacks,
    required this.coinsSpentOnUpgrades,
    required this.facilityLevelTotal,
    required this.recoveryCentreLevel,
    required this.joinedAt,
    required this.tacticsInstructionsChanged,
  });

  // -- Career (MatchResults rows where the club is home or away) ------
  // A REPLAYED fixture (same fixtureId) counts ONCE: the derivation
  // deduplicates on fixtureId keeping the latest playedAt — the
  // replay refund flow (match_replay_refund) makes replays rare but
  // possible, and one fixture is one match in the career's story.
  final int matchesManaged;
  final int homeMatches;
  final int awayMatches;
  final int wins;
  final int draws;
  final int losses;

  // -- Attack / Defence (same rows, goals attributed by side) --------
  final int goalsFor;
  final int goalsAgainst;
  final int cleanSheets;
  final int mostGoalsInOneMatch;
  final int matchesScoredFirst;

  // -- Streaks (career-scoped, season-crossing by design) -----------
  final int longestWinStreak;
  final int longestUnbeatenStreak;
  final int longestCleanSheetStreak;

  // -- Silverware / Loyalty (Seasons with finalPosition/outcome) ----
  /// division → titles (finalPosition == 1).
  final Map<int, int> titlesByDivision;
  final int titlesByDivisionTotal;
  final int promotions;
  final int relegations;
  final int seasonsCompleted;

  // -- Packs (Packs rows where opened) ------------------------------
  final int packsOpened;
  final int packsPurchased;
  final int packsRewarded;
  final int startingPacksOpened;

  // -- Squad (OwnedPlayers where status == 'owned') ------------------
  final int cardsOwned;
  final int legendaryCardsOwned;
  final int epicCardsOwned;
  final int highestUpgradeLevel;
  final int upgradesCompleted;
  final int legendaryPulls;
  final int playerSalesCompleted;

  // -- Economy (CoinTransactions grouped by reason) -------------------
  final int lifetimeCoinsEarned;
  final int coinsSpentOnPacks;
  final int coinsSpentOnUpgrades;

  // -- Campus (FacilityLevels) ---------------------------------------
  final int facilityLevelTotal;
  final int recoveryCentreLevel;

  // -- Career identity -----------------------------------------------
  final DateTime? joinedAt;

  /// Tactical instruction changes. NOT DERIVABLE today: no persisted
  /// trace exists for tactic edits (pre-match saves the result, not
  /// the edit count; the live match persists nothing per change) —
  /// documented, carried as a constant 0, and the mastermind
  /// definitions sit unranked in the catalog until a trace lands.
  /// This is the honest alternative to a fake counter.
  final int tacticsInstructionsChanged;

  /// The metric id → value map the catalog's definitions read. Pure
  /// in-memory lookup after the one derivation — never a DB hit.
  int? progressFor(String metricId) => switch (metricId) {
    'matchesManaged' => matchesManaged,
    'homeMatches' => homeMatches,
    'awayMatches' => awayMatches,
    'wins' => wins,
    'draws' => draws,
    'losses' => losses,
    'goalsFor' => goalsFor,
    'goalsAgainst' => goalsAgainst,
    'cleanSheets' => cleanSheets,
    'longestWinStreak' => longestWinStreak,
    'longestUnbeatenStreak' => longestUnbeatenStreak,
    'longestCleanSheetStreak' => longestCleanSheetStreak,
    'mostGoalsInOneMatch' => mostGoalsInOneMatch,
    'matchesScoredFirst' => matchesScoredFirst,
    'titlesByDivisionTotal' => titlesByDivisionTotal,
    'promotions' => promotions,
    'relegations' => relegations,
    'seasonsCompleted' => seasonsCompleted,
    'packsOpened' => packsOpened,
    'packsPurchased' => packsPurchased,
    'packsRewarded' => packsRewarded,
    'startingPacksOpened' => startingPacksOpened,
    'cardsOwned' => cardsOwned,
    'legendaryCardsOwned' => legendaryCardsOwned,
    'epicCardsOwned' => epicCardsOwned,
    'highestUpgradeLevel' => highestUpgradeLevel,
    'upgradesCompleted' => upgradesCompleted,
    'legendaryPulls' => legendaryPulls,
    'playerSalesCompleted' => playerSalesCompleted,
    'lifetimeCoinsEarned' => lifetimeCoinsEarned,
    'coinsSpentOnPacks' => coinsSpentOnPacks,
    'coinsSpentOnUpgrades' => coinsSpentOnUpgrades,
    'facilityLevelTotal' => facilityLevelTotal,
    'recoveryCentreLevel' => recoveryCentreLevel,
    'tacticsInstructionsChanged' => tacticsInstructionsChanged,
    _ => null,
  };
}

/// Derives the club's whole career snapshot. Pure reads over the save.
Future<CareerMetrics> deriveCareerMetrics(
  db.AppDatabase database,
  int clubId,
) async {
  // ---- Results: the club's rows, deduplicated per fixture -----------
  final resultRows = await (database.select(database.matchResults)
        ..where(
          (t) => t.homeClubId.equals(clubId) | t.awayClubId.equals(clubId),
        ))
      .get();
  // One row per fixtureId (latest playedAt wins — a replay replaces
  // the original story, it does not add to it).
  final latestPerFixture = <int, db.MatchResult>{};
  for (final r in resultRows) {
    final known = latestPerFixture[r.fixtureId];
    if (known == null || !r.playedAt.isBefore(known.playedAt)) {
      latestPerFixture[r.fixtureId] = r;
    }
  }
  // Career order: season, then round — the streak walk needs the
  // timeline, season-crossing by design.
  final results = latestPerFixture.values.toList()
    ..sort(
      (a, b) => a.seasonId.compareTo(b.seasonId) != 0
          ? a.seasonId.compareTo(b.seasonId)
          : a.round.compareTo(b.round),
    );

  var wins = 0, draws = 0, losses = 0;
  var goalsFor = 0, goalsAgainst = 0;
  var homeMatches = 0, awayMatches = 0;
  var cleanSheets = 0, mostGoalsInOneMatch = 0, matchesScoredFirst = 0;
  var winStreak = 0, unbeatenStreak = 0, cleanSheetStreak = 0;
  var bestWinStreak = 0, bestUnbeaten = 0, bestCleanSheet = 0;
  for (final r in results) {
    final isHome = r.homeClubId == clubId;
    isHome ? homeMatches++ : awayMatches++;
    final scored = isHome ? r.homeGoals : r.awayGoals;
    final conceded = isHome ? r.awayGoals : r.homeGoals;
    goalsFor += scored;
    goalsAgainst += conceded;
    if (scored > mostGoalsInOneMatch) mostGoalsInOneMatch = scored;
    // Scored first: strictly more goals than the opponent by the
    // final whistle is the closest persisted proxy — the full 90-
    // minute order lives in engine detail, not columns; documented
    // as the derivation's exact semantics.
    if (scored > conceded) matchesScoredFirst++;
    if (conceded == 0) {
      cleanSheets++;
      cleanSheetStreak++;
      if (cleanSheetStreak > bestCleanSheet) bestCleanSheet = cleanSheetStreak;
    } else {
      cleanSheetStreak = 0;
    }
    if (scored > conceded) {
      wins++;
      winStreak++;
      unbeatenStreak++;
      if (winStreak > bestWinStreak) bestWinStreak = winStreak;
      if (unbeatenStreak > bestUnbeaten) bestUnbeaten = unbeatenStreak;
    } else if (scored < conceded) {
      losses++;
      winStreak = 0;
      unbeatenStreak = 0;
    } else {
      draws++;
      // A draw ENDS a winning run (it never ended one — the original
      // bug this fixture caught: W W W D W counted a 4-streak).
      winStreak = 0;
      unbeatenStreak++;
      if (unbeatenStreak > bestUnbeaten) bestUnbeaten = unbeatenStreak;
    }
  }

  // ---- Seasons: titles per division, promotion/relegation counts ----
  final seasonRows = await (database.select(database.seasons)
        ..where((t) => t.userClubId.equals(clubId)))
      .get();
  final titlesByDivision = <int, int>{};
  var promotions = 0, relegations = 0, seasonsCompleted = 0;
  for (final s in seasonRows) {
    if (s.status != 'completed') continue;
    seasonsCompleted++;
    if (s.finalPosition == 1) {
      titlesByDivision.update(s.division, (v) => v + 1, ifAbsent: () => 1);
    }
    if (s.outcome == 'promoted') promotions++;
    if (s.outcome == 'relegated') relegations++;
  }

  // ---- Packs: totals and per-source splits -------------------------
  final packRows = await (database.select(database.packs)
        ..where((t) => t.clubId.equals(clubId)))
      .get();
  var packsOpened = 0, packsPurchased = 0, packsRewarded = 0,
      startingPacksOpened = 0;
  for (final p in packRows) {
    if (!p.opened) continue;
    packsOpened++;
    switch (p.source) {
      case 'purchased':
        packsPurchased++;
      case 'reward':
        packsRewarded++;
      case 'starting':
        startingPacksOpened++;
    }
  }

  // ---- Squad: owned cards, rarities via the dataset join -----------
  // Rarity comes from the BASE player's overall the same way
  // player_detail_sheet's rarityOf does (CardRarity.fromOverall) —
  // upgraded cards show their upgraded rarity, so `overall` is the
  // derived rating: base stats weighted by position + upgrade level.
  final ownedRows = await (database.select(database.ownedPlayers)
        ..where(
          (t) => t.clubId.equals(clubId) & t.status.equals('owned'),
        ))
      .get();
  final datasetRows = await (database.select(database.players)
        ..where((p) => p.playerId.isIn(ownedRows.map((o) => o.playerId))))
      .get();
  final baseById = {for (final p in datasetRows) p.playerId: p};

  var cardsOwned = 0, legendary = 0, epic = 0, highestUpgrade = 0;
  var mergesSeen = 0;
  DateTime? joinedAt;
  for (final o in ownedRows) {
    cardsOwned++;
    final acquired = o.acquiredAt;
    if (joinedAt == null || acquired.isBefore(joinedAt)) {
      joinedAt = acquired;
    }
    if (o.upgradeLevel > highestUpgrade) highestUpgrade = o.upgradeLevel;
    final base = baseById[o.playerId];
    if (base == null) continue;
    // The upgraded rating: +1% of base overall per level (upgradedValue,
    // the owner's 2026-11-09 decision — the attribute interpolation the
    // dead `attr` helper sketched is NOT how the engine derives it).
    final overall =
        (base.overall * (1 + o.upgradeLevel / 100)).round().clamp(1, 99);
    final rarity = CardRarity.fromOverall(overall);
    if (rarity == CardRarity.legendary) legendary++;
    if (rarity == CardRarity.epic) epic++;
  }

  // Merges (upgradesCompleted): every owned card's upgradeLevel is the
  // result of N merges — the sum of levels over OWNED cards is the
  // count that survived into today's squad; sold/merged-away levels
  // left no trace (documented derivation semantics).
  mergesSeen = ownedRows.fold(0, (sum, o) => sum + o.upgradeLevel);

  // Legendary pulls: no per-open trace exists (Packs rows carry no
  // contents) — NOT derivable; carried as 0 and documented. The
  // milestone sits unclaimable until a trace lands.
  const legendaryPulls = 0;

  // Player sales: ledger reason rows are the persisted trace.
  // ---- Economy: ledger groups ---------------------------------------
  final ledgerRows = await (database.select(database.coinTransactions)
        ..where((t) => t.clubId.equals(clubId)))
      .get();
  var earned = 0, packSpend = 0, upgradeSpend = 0, sales = 0;
  for (final tx in ledgerRows) {
    if (tx.amount > 0) earned += tx.amount;
    switch (tx.reason) {
      case LedgerReasons.packPurchase:
        packSpend += -tx.amount;
      case LedgerReasons.playerSale:
        sales++;
      case LedgerReasons.facilityUpgrade:
        upgradeSpend += -tx.amount;
    }
  }

  // ---- Campus --------------------------------------------------------
  final facilityRows = await (database.select(database.facilityLevels)
        ..where((t) => t.clubId.equals(clubId)))
      .get();
  var facilityLevelTotal = 0, recoveryLevel = 0;
  for (final f in facilityRows) {
    facilityLevelTotal += f.level;
    if (f.facility == 'recovery') recoveryLevel = f.level;
  }

  return CareerMetrics(
    matchesManaged: results.length,
    homeMatches: homeMatches,
    awayMatches: awayMatches,
    wins: wins,
    draws: draws,
    losses: losses,
    goalsFor: goalsFor,
    goalsAgainst: goalsAgainst,
    cleanSheets: cleanSheets,
    longestWinStreak: bestWinStreak,
    longestUnbeatenStreak: bestUnbeaten,
    longestCleanSheetStreak: bestCleanSheet,
    mostGoalsInOneMatch: mostGoalsInOneMatch,
    matchesScoredFirst: matchesScoredFirst,
    titlesByDivision: titlesByDivision,
    titlesByDivisionTotal: titlesByDivision.values.fold(0, (a, b) => a + b),
    promotions: promotions,
    relegations: relegations,
    seasonsCompleted: seasonsCompleted,
    packsOpened: packsOpened,
    packsPurchased: packsPurchased,
    packsRewarded: packsRewarded,
    startingPacksOpened: startingPacksOpened,
    cardsOwned: cardsOwned,
    legendaryCardsOwned: legendary,
    epicCardsOwned: epic,
    highestUpgradeLevel: highestUpgrade,
    upgradesCompleted: mergesSeen,
    legendaryPulls: legendaryPulls,
    playerSalesCompleted: sales,
    lifetimeCoinsEarned: earned,
    coinsSpentOnPacks: packSpend,
    coinsSpentOnUpgrades: upgradeSpend,
    facilityLevelTotal: facilityLevelTotal,
    recoveryCentreLevel: recoveryLevel,
    joinedAt: joinedAt,
    tacticsInstructionsChanged: 0,
  );
}

// The unused-warning shield: the catalog import documents where the
// metric-id contract lives (progressFor's ids mirror T-0105's data).
// ignore: unused_element
final List<String> _catalogMetricIds = AchievementCatalog.definitions
    .map((d) => d.metricId)
    .toSet()
    .toList();
