/// FCM Rivals — local persistence schema (SRS 25).
///
/// v1: global player dataset cache + dataset versions, user club, owned
/// player instances (upgrade state per SRS 25.1), packs and the coin
/// transaction ledger (FR-016).
/// v2: division/season tables — seasons, league teams, fixtures and match
/// results (SRS 25; AI clubs reuse [Clubs] with isUser = false, their
/// squads reuse [OwnedPlayers] with status 'ai').
/// v12: injury columns (GDD 11.7, T-0053) — `injuryMatchesRemaining`
/// (matches still missed; 0/null = fit) + `injuryKind` (nullable, the
/// InjuryKind name) on both [OwnedPlayers] and [AiPlayers]. Behaviours
/// (writing/decrementing/gating) land with T-0055.
library;

import 'package:drift/drift.dart';

import '../domain/base_stats_generator.dart';
import '../domain/players.dart' show Position;

part 'app_database.g.dart';

/// Imported global players (SRS 25: PlayerDatabase).
///
/// Identity is the permanent [playerId] (Transfermarkt id, GDD 4.4). Base
/// stats columns are written at import time by the Player Database Engine
/// and follow its update rules (GDD 4.6). Core data is minimal: name,
/// nationality, position and market value — no club, age or league.
class Players extends Table {
  IntColumn get playerId => integer()();
  TextColumn get name => text()();
  TextColumn get position => text()();
  TextColumn get nationality => text()();
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

  /// Composed crest identity (T-0097): JSON CrestSpec — shape +
  /// primary/secondary palette indices + icon. Null on every
  /// pre-v13 row and on legacy callers: the resolver falls back to
  /// [crestIndex] rendering, so old saves look exactly as before.
  TextColumn get crest => text().nullable()();
  TextColumn get formationCode => text().withDefault(const Constant('4-3-3'))();

  /// Custom tactics (GDD 10.2): JSON payload of TeamTactics. Legacy saves
  /// stored one of ten playing-style names here; the v10→v11 migration
  /// swaps the column and every legacy value loads as default tactics
  /// (the mapping to instruction combinations is documented in GDD 10.2
  /// and filled by phases 1-3).
  TextColumn get tactics => text().withDefault(const Constant('{}'))();
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

  /// LEGACY pre-2026-11-09 columns: random upgrade attribute points from
  /// the old "+1 OVR + random points" rule. Unused for gameplay since the
  /// owner's +N% decision (stats derive from upgradeLevel via
  /// `upgradedValue`); new merges write 0. Kept for save compatibility —
  /// no migration drops them.
  IntColumn get upgradedAttack => integer().withDefault(const Constant(0))();
  IntColumn get upgradedSupport => integer().withDefault(const Constant(0))();
  IntColumn get upgradedDefence => integer().withDefault(const Constant(0))();
  IntColumn get upgradedGoalkeeping =>
      integer().withDefault(const Constant(0))();

  IntColumn get staminaPercent => integer().withDefault(const Constant(100))();
  IntColumn get squadSlot => integer().nullable()();

  /// Injury state (GDD 11.7, schema v12): matches still missed — 0 or
  /// null = fit. [injuryKind] is the InjuryKind name and is non-null
  /// exactly while the player is currently injured. Written and
  /// decremented by the post-match pipeline (T-0055).
  IntColumn get injuryMatchesRemaining =>
      integer().nullable().withDefault(const Constant(0))();
  TextColumn get injuryKind => text().nullable()();

  /// owned | sold | merged (sold/merged rows kept for history).
  TextColumn get status => text().withDefault(const Constant('owned'))();
  TextColumn get acquisitionSource =>
      text().withDefault(const Constant('pack'))();
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
  TextColumn get tier => text().withDefault(const Constant('rare'))();
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
  BoolColumn get carriedOver => boolean().withDefault(const Constant(false))();
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

  /// The real dataset player behind this squad entry, or null for
  /// synthetic fallback players (tiny test pools). AI squads are built
  /// from the imported player database, and a promoted/relegated club
  /// keeps its squad — the identity survives across seasons.
  IntColumn get realPlayerId => integer().nullable()();

  /// Injury state, same contract as [OwnedPlayers.injuryMatchesRemaining]
  /// (GDD 11.7, schema v12): AI players sit out matches through the same
  /// gating (T-0055).
  IntColumn get injuryMatchesRemaining =>
      integer().nullable().withDefault(const Constant(0))();
  TextColumn get injuryKind => text().nullable()();
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

/// Club campus facilities (GDD 3.5): one row per built facility of the
/// user's club. The level drives the facility's team-wide effect and the
/// escalating coin cost of the next upgrade. AI clubs own no facilities.
class FacilityLevels extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get clubId => integer()();

  /// Facility identifier — see [lib/features/facilities/facilities.dart].
  TextColumn get facility => text()();
  IntColumn get level => integer().withDefault(const Constant(0))();
  DateTimeColumn get upgradedAt => dateTime().nullable()();
}

/// App-level user preferences (single row, id = 1): the chosen match
/// playback speed and other cross-session UI settings. Written by the
/// live match screen the moment the user changes a value, read at the
/// next kick-off — the choice sticks FOREVER, not just for one match.
class UserSettings extends Table {
  IntColumn get id => integer()();

  /// Live match playback speed multiplier: 1, 2, 3 or 4 (GDD 26.2).
  IntColumn get matchSpeed => integer().withDefault(const Constant(1))();

  /// UI language tag: 'en', 'ar' or null (follow the system locale).
  TextColumn get locale => text().nullable()();
}

@DriftDatabase(
  tables: [
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
    FacilityLevels,
    UserSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 13;

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
      if (from < 5) {
        // Core player data slimmed to name/nationality/position/value:
        // age, club and leagueCode dropped. TableMigration rebuilds the
        // table, preserving every remaining row and column.
        // drift 2.31 (the version resolvable on the shipped toolchain)
        // marks TableMigration experimental; the API is stable here.
        // ignore: experimental_member_use
        await m.alterTable(TableMigration(players));
      }
      if (from < 6) {
        // Packs gained the store tier (bronze/silver/gold variety).
        await m.addColumn(packs, packs.tier);
        // Base stats move to the position-weighted distribution: every
        // existing player row is regenerated from its market value and
        // position so the collection reflects the new curve (GDD 4.6).
        final generator = const BaseStatsGenerator();
        final rows = await select(players).get();
        for (final row in rows) {
          final stats = generator.generate(
            Position.fromCode(row.position),
            row.marketValueEur,
            seed: row.playerId,
          );
          await (update(
            players,
          )..where((p) => p.playerId.equals(row.playerId))).write(
            PlayersCompanion(
              attack: Value(stats.attack),
              support: Value(stats.support),
              defence: Value(stats.defence),
              goalkeeping: Value(stats.goalkeeping),
            ),
          );
        }
      }
      if (from < 7) {
        // Club campus facilities (GDD 3.5): the upgrade tab's state.
        await m.createTable(facilityLevels);
      }
      if (from < 8) {
        // App-level preferences (match playback speed, GDD 26.2).
        await m.createTable(userSettings);
      }
      if (from < 9) {
        // AI squads drawn from the real player database: each squad
        // entry carries the dataset player it represents. Existing
        // rows predate real-player generation and stay null.
        await m.addColumn(aiPlayers, aiPlayers.realPlayerId);
      }
      if (from < 10) {
        // UI language preference (EN/AR; null follows the system).
        await m.addColumn(userSettings, userSettings.locale);
      }
      if (from < 11) {
        // Custom Tactics replace the ten preset playing styles (GDD
        // 10.2): the text name column becomes a JSON tactics payload.
        // Every legacy value — all ten old style names — maps to the
        // default (identity) setup; the legacy-style → combination
        // mapping is documentation only, delivered with phases 1-3.
        // ignore: experimental_member_use
        await m.addColumn(clubs, clubs.tactics);
        // ignore: experimental_member_use
        await m.alterTable(TableMigration(clubs));
      }
      if (from < 12) {
        // Injury columns (GDD 11.7, T-0053): pure additions — every
        // existing row keeps its values byte-for-byte and reads as fit
        // (0 / null). Behaviours land with T-0055.
        await m.addColumn(ownedPlayers, ownedPlayers.injuryMatchesRemaining);
        await m.addColumn(ownedPlayers, ownedPlayers.injuryKind);
        await m.addColumn(aiPlayers, aiPlayers.injuryMatchesRemaining);
        await m.addColumn(aiPlayers, aiPlayers.injuryKind);
      }
      if (from < 13) {
        // Composed crest identities (T-0097): the nullable TEXT column
        // carries a JSON CrestSpec; pure addition — every existing row
        // stays null and renders through the legacy crestIndex path.
        // The v11 TableMigration rebuilds clubs at the CURRENT shape,
        // so a v10/11 database reopening here may already carry the
        // column — add it only when missing (SQLite has no ADD COLUMN
        // IF NOT EXISTS; introspect PRAGMA table_info instead).
        final hasCrest =
            (await customSelect('PRAGMA table_info(clubs)').get())
                .any((row) => row.read<String>('name') == 'crest');
        if (!hasCrest) {
          await m.addColumn(clubs, clubs.crest);
        }
      }
    },
  );
}
