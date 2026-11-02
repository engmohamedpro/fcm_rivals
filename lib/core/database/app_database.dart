/// FCM Rivals — local persistence schema (SRS 25).
///
/// v1: global player dataset cache + dataset versions, user club, owned
/// player instances (upgrade state per SRS 25.1), packs and the coin
/// transaction ledger (FR-016).
/// v2: division/season tables — seasons, league teams, fixtures and match
/// results (SRS 25; AI clubs reuse [Clubs] with isUser = false, their
/// squads reuse [OwnedPlayers] with status 'ai').
library;

import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Imported global players (SRS 25: PlayerDatabase).
///
/// Identity is the permanent [playerId] (Transfermarkt id, GDD 4.4). Base
/// stats columns are written at import time by the Player Database Engine
/// and follow its update rules (GDD 4.6).
class Players extends Table {
  IntColumn get playerId => integer()();
  TextColumn get name => text()();
  TextColumn get position => text()();
  IntColumn get age => integer()();
  TextColumn get nationality => text()();
  TextColumn get club => text()();
  TextColumn get leagueCode => text().withDefault(const Constant(''))();
  IntColumn get marketValueEur => integer()();
  IntColumn get overall => integer()();
  IntColumn get attack => integer()();
  IntColumn get support => integer()();
  IntColumn get defence => integer()();
  IntColumn get goalkeeping => integer()();

  @override
  Set<Column> get primaryKey => {playerId};
}

/// Dataset version tracking (SRS 25: PlayerDatabaseVersions).
class DatasetVersions extends Table {
  IntColumn get version => integer()();
  TextColumn get asOf => text()();
  TextColumn get digest => text().withDefault(const Constant(''))();
  DateTimeColumn get importedAt => dateTime()();
  IntColumn get playerCount => integer()();

  @override
  Set<Column> get primaryKey => {version};
}

/// User club (SRS 25: Clubs). AI clubs arrive with the season iteration and
/// reuse this table via [isUser] = false.
class Clubs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get managerName => text()();
  IntColumn get crestIndex => integer().withDefault(const Constant(0))();
  TextColumn get formationCode => text().withDefault(const Constant('4-3-3'))();
  TextColumn get playingStyle => text().withDefault(const Constant('balanced'))();
  TextColumn get mentality => text().withDefault(const Constant('balanced'))();
  IntColumn get coins => integer()();
  BoolColumn get isUser => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
}

/// User-owned player instances (SRS 25: OwnedPlayers + 25.1 data
/// separation). Upgrade state lives here only — never on [Players].
///
/// Squad assignment is denormalized into [squadSlot]: 0–10 starting XI
/// (formation slot order), 11–17 bench, 18–22 reserves; null = out of squad.
class OwnedPlayers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clubId => integer()();
  IntColumn get playerId => integer()();

  /// Duplicate-merge level (GDD 8.1).
  IntColumn get upgradeLevel => integer().withDefault(const Constant(0))();

  /// Attribute points added by upgrades (GDD 8.2).
  IntColumn get upgradedAttack => integer().withDefault(const Constant(0))();
  IntColumn get upgradedSupport => integer().withDefault(const Constant(0))();
  IntColumn get upgradedDefence => integer().withDefault(const Constant(0))();
  IntColumn get upgradedGoalkeeping => integer().withDefault(const Constant(0))();

  IntColumn get staminaPercent => integer().withDefault(const Constant(100))();
  IntColumn get squadSlot => integer().nullable()();

  /// owned | sold | merged (sold/merged rows kept for history).
  TextColumn get status => text().withDefault(const Constant('owned'))();
  TextColumn get acquisitionSource => text().withDefault(const Constant('pack'))();
  DateTimeColumn get acquiredAt => dateTime()();
}

/// Pack instances available to the club (SRS 25: Packs): the 36 starting
/// packs plus future purchased/reward packs. Odds are computed by the Pack
/// Engine from the eligible pool — not persisted (no PackOdds table yet).
class Packs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clubId => integer()();
  TextColumn get category => text()();
  TextColumn get scopeValue => text().nullable()();
  IntColumn get price => integer().withDefault(const Constant(0))();
  TextColumn get source => text().withDefault(const Constant('starting'))();
  BoolColumn get opened => boolean().withDefault(const Constant(false))();
  DateTimeColumn get openedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Coin transaction ledger (FR-016: atomic and recorded). Every coin
/// movement writes exactly one row with the post-transaction balance.
class CoinTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clubId => integer()();
  IntColumn get amount => integer()();
  IntColumn get balanceAfter => integer()();
  TextColumn get reason => text()();
  TextColumn get detail => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// One league season (GDD 9.2): a division of 20 clubs, 38 rounds.
/// Division 1 is the starting division; higher numbers are harder
/// (GDD 9.1). The season ordinal is global across divisions.
class Seasons extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get division => integer()();
  IntColumn get ordinal => integer()();
  IntColumn get userClubId => integer()();

  /// active | completed.
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get finalPosition => integer().nullable()();

  /// promoted | stayed | relegated (user outcome, GDD 9.3).
  TextColumn get outcome => text().nullable()();
}

/// Season participation (SRS 25: LeagueTeams): which club played which
/// season, with the final position kept for history (FR-038).
class LeagueTeams extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get seasonId => integer()();
  IntColumn get clubId => integer()();
  BoolColumn get isUser => boolean().withDefault(const Constant(false))();
  IntColumn get finalPosition => integer().nullable()();

  /// GDD 9.5: the club was carried over into this season from the
  /// previous one (promoted/relegated AI club with a retained squad).
  BoolColumn get carriedOver =>
      boolean().withDefault(const Constant(false))();
}

/// Match schedule (SRS 25: Fixtures): double round-robin, 38 rounds
/// (FR-036). Played state derives from [MatchResults].
class Fixtures extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get seasonId => integer()();
  IntColumn get round => integer()();
  IntColumn get homeClubId => integer()();
  IntColumn get awayClubId => integer()();
}

/// Final results (SRS 25: MatchResults; FR-038 history). The seed and
/// engine version are stored for deterministic replay (GDD 12.5); user
/// matches also persist the full event JSON in [detail].
class MatchResults extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get fixtureId => integer()();
  IntColumn get seasonId => integer()();
  IntColumn get round => integer()();
  IntColumn get homeClubId => integer()();
  IntColumn get awayClubId => integer()();
  IntColumn get homeGoals => integer()();
  IntColumn get awayGoals => integer()();
  IntColumn get seed => integer()();
  IntColumn get engineVersion => integer()();
  TextColumn get detail => text().nullable()();
  DateTimeColumn get playedAt => dateTime()();
}

/// Synthetic squads of AI clubs (GDD 9.4). Kept separate from
/// [OwnedPlayers]: AI players are generated, not drawn from the global
/// dataset, and they are retired with their club at season end (GDD 9.5)
/// while historical results stay (FR-038). Rows 0–10 are the starting XI
/// in formation slot order, 11+ the bench.
class AiPlayers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clubId => integer()();
  TextColumn get playerName => text()();
  TextColumn get position => text()();
  IntColumn get attack => integer()();
  IntColumn get support => integer()();
  IntColumn get defence => integer()();
  IntColumn get goalkeeping => integer()();
  IntColumn get staminaPercent => integer().withDefault(const Constant(100))();
}

/// Rewarded-ad usage ledger (SRS 25: AdUsage; GDD 19.4, FR-040..FR-042).
/// One row per successfully completed ad: rewards are granted only on
/// completion, duplicates are prevented by checking the reward key, and
/// daily limits count rows of the same reward kind.
class AdUsages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clubId => integer()();

  /// Reward kind: 'boostedRecovery' | 'matchReplay' | 'freePack' | ... —
  /// the ad-granted reward identifier.
  TextColumn get rewardKind => text()();

  /// Unique key of the rewarded transaction (e.g. 'match:fixtureId');
  /// one reward per key prevents duplicate callbacks.
  TextColumn get rewardKey => text()();
  DateTimeColumn get completedAt => dateTime()();
}

@DriftDatabase(tables: [
  Players,
  DatasetVersions,
  Clubs,
  OwnedPlayers,
  Packs,
  CoinTransactions,
  Seasons,
  LeagueTeams,
  Fixtures,
  MatchResults,
  AiPlayers,
  AdUsages,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(seasons);
            await m.createTable(leagueTeams);
            await m.createTable(fixtures);
            await m.createTable(matchResults);
            await m.createTable(aiPlayers);
          }
          if (from < 3) {
            await m.createTable(adUsages);
          }
          if (from < 4) {
            await m.addColumn(leagueTeams, leagueTeams.carriedOver);
          }
        },
      );
}
