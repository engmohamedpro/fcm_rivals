/// FCM Rivals — local persistence schema (SRS 25).
///
/// Tables for this iteration: global player dataset cache + dataset versions,
/// user club, owned player instances (upgrade state per SRS 25.1), packs and
/// the coin transaction ledger (FR-016). Division/season/match tables come
/// with their feature iteration — the schema is versioned for migrations.
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

@DriftDatabase(tables: [Players, DatasetVersions, Clubs, OwnedPlayers, Packs, CoinTransactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
