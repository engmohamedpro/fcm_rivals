/// FCM Rivals — collection store (GDD 5/8/17, FR-012..FR-016).
///
/// Orchestrates the engines over the Drift database: club creation with the
/// 36 starting packs, pack opening, selling, duplicate merging, and dataset
/// updates with removed-player compensation. Every coin movement runs in a
/// database transaction and writes a ledger row (FR-016, NFR-003).
///
/// Pure domain logic stays in the engines; this class only coordinates
/// persistence and transactions (SRS 21.1 / NFR-006).
library;

import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/domain/players.dart';
import '../economy/economy_engine.dart';
import '../packs/pack_engine.dart';
import '../player_database/player_database.dart';
import '../squad/formations.dart';
import '../squad/squad_engine.dart';
import '../upgrades/upgrade_engine.dart';

/// Thrown when an operation would leave persistent state inconsistent.
class CollectionException implements Exception {
  const CollectionException(this.message);
  final String message;

  @override
  String toString() => 'CollectionException: $message';
}

/// The players drawn from one opened pack, in reveal order.
class PackOpenResult {
  const PackOpenResult({required this.players});

  /// Drawn players, low → mid → high tier (GDD 5.3).
  final List<BasePlayer> players;
}

/// Players sold back to the system with the total credit.
class SaleResult {
  const SaleResult({required this.soldOwnedIds, required this.credit});

  final List<int> soldOwnedIds;
  final int credit;
}

/// One merged duplicate outcome.
class MergeResult {
  const MergeResult({
    required this.targetOwnedId,
    required this.duplicateOwnedId,
    required this.newUpgradeLevel,
    required this.attributeGain,
  });

  final int targetOwnedId;
  final int duplicateOwnedId;
  final int newUpgradeLevel;
  final Map<PlayerAttribute, int> attributeGain;
}

/// Removed-player compensation entry (GDD 4.8 step 6: notify with name).
class RemovalCompensation {
  const RemovalCompensation({
    required this.playerName,
    required this.upgradeLevel,
    required this.coins,
  });

  final String playerName;
  final int upgradeLevel;
  final int coins;
}

/// Result of applying a dataset update to the persisted world.
class DatasetUpdateReport {
  const DatasetUpdateReport({
    required this.importResult,
    required this.compensations,
  });

  final ImportResult importResult;
  final List<RemovalCompensation> compensations;

  int get totalCompensation =>
      compensations.fold(0, (a, c) => a + c.coins);
}

class CollectionStore {
  CollectionStore({
    required this.db,
    this.economy = const EconomyEngine(),
    this.upgrades = const UpgradeEngine(),
    this.squad = const SquadEngine(),
  });

  final AppDatabase db;
  final EconomyEngine economy;
  final UpgradeEngine upgrades;
  final SquadEngine squad;

  /// Packs draw from the in-memory registry mirrored into SQLite; kept in
  /// sync by [applyDatasetUpdate] and lazily loaded on first use.
  final PlayerDatabase _registry = PlayerDatabase();
  bool _registryLoaded = false;

  static const int startingPacksPerPosition = 3;

  // ---------------------------------------------------------------------------
  // Club lifecycle
  // ---------------------------------------------------------------------------

  /// Creates the user club (FR-001) with starting coins and the 36 starting
  /// position packs (GDD 5.8). Returns the club id.
  Future<int> createClub({
    required String clubName,
    required String managerName,
    required int crestIndex,
  }) async {
    if (clubName.trim().isEmpty) {
      throw const CollectionException('Club name is required');
    }
    if (managerName.trim().isEmpty) {
      throw const CollectionException('Manager name is required');
    }
    final existing = await db.select(db.clubs).getSingleOrNull();
    if (existing != null) {
      throw const CollectionException('A club already exists on this device');
    }

    final now = DateTime.now();
    return db.transaction(() async {
      final clubId = await db.into(db.clubs).insert(ClubsCompanion.insert(
            name: clubName.trim(),
            managerName: managerName.trim(),
            crestIndex: Value(crestIndex),
            coins: economy.config.startingCoins,
            createdAt: now,
          ));
      await db.coinLedger(clubId, economy.config.startingCoins,
          reason: 'starting_grant', detail: 'Club creation grant');
      // 36 starting packs: three per supported position (GDD 5.8).
      for (final position in Position.values) {
        for (var i = 0; i < startingPacksPerPosition; i++) {
          await db.into(db.packs).insert(PacksCompanion.insert(
                clubId: clubId,
                category: 'position',
                scopeValue: Value(position.code),
                source: const Value('starting'),
                createdAt: now,
              ));
        }
      }
      return clubId;
    });
  }

  /// The user club, or null before onboarding completes. Uses
  /// getSingleOrNull — watchSingle would throw on the empty table on a
  /// fresh install, crashing club creation.
  Future<Club?> getClub() => db.select(db.clubs).getSingleOrNull();

  // ---------------------------------------------------------------------------
  // Dataset
  // ---------------------------------------------------------------------------

  /// Ensures the in-memory registry mirrors the persisted dataset (used by
  /// pack drawing before any update was applied in this session).
  Future<PlayerDatabase> _ensureRegistry() async {
    if (_registryLoaded) return _registry;
    final rows = await db.select(db.players).get();
    if (rows.isNotEmpty) {
      final dataset = PlayerDataset(
        version: (await db.select(db.datasetVersions).getSingleOrNull())
                ?.version ??
            0,
        asOf: '',
        rows: [
          for (final r in rows)
            PlayerDatasetRow(
              playerId: r.playerId,
              name: r.name,
              position: Position.fromCode(r.position),
              age: r.age,
              nationality: r.nationality,
              club: r.club,
              leagueCode: r.leagueCode,
              marketValueEur: r.marketValueEur,
            ),
        ],
      );
      _registry.importDataset(dataset);
    }
    _registryLoaded = true;
    return _registry;
  }

  /// Imports the bundled dataset into SQLite (idempotent per version) and
  /// primes the in-memory registry. Called at app start.
  Future<void> importBundledDataset(String jsonText) async {
    final dataset = PlayerDataset.fromJson(jsonText);
    final current =
        await db.select(db.datasetVersions).getSingleOrNull();
    if (current != null && current.version >= dataset.version) return;
    await applyDatasetUpdate(dataset);
  }

  /// Applies a dataset update transactionally (FR-004..FR-008, NFR-003):
  /// registry update rules, upsert of player rows, removed-player
  /// compensation at the exact upgraded selling formula, squad slot cleanup.
  Future<DatasetUpdateReport> applyDatasetUpdate(PlayerDataset dataset) async {
    await _ensureRegistry();
    final importResult = _registry.importDataset(dataset);

    final club = await db.select(db.clubs).getSingleOrNull();
    final compensations = <RemovalCompensation>[];

    await db.transaction(() async {
      // Upsert current rows (regenerated stats included per GDD 4.6).
      for (final player in [
        ...importResult.added,
        ...importResult.updated,
        ...importResult.regenerated,
      ]) {
        await db.into(db.players).insertOnConflictUpdate(
              PlayersCompanion.insert(
                playerId: Value(player.playerId),
                name: player.name,
                position: player.position.code,
                age: player.age,
                nationality: player.nationality,
                club: player.club,
                leagueCode: Value(player.leagueCode),
                marketValueEur: player.marketValueEur,
                overall: player.baseStats.overall,
                attack: player.baseStats.attack,
                support: player.baseStats.support,
                defence: player.baseStats.defence,
                goalkeeping: player.baseStats.goalkeeping,
              ),
            );
      }

      // Removed players: compensate owners, drop copies and squad slots
      // (GDD 4.8) — inside the same transaction as the data update.
      if (club != null) {
        for (final removed in importResult.removed) {
          final owned = await (db.select(db.ownedPlayers)
                ..where((o) =>
                    o.playerId.equals(removed.playerId) &
                    o.status.equals('owned')))
              .get();
          for (final copy in owned) {
            final coins = economy.sellPriceOfUpgraded(
                removed, copy.upgradeLevel);
            compensations.add(RemovalCompensation(
              playerName: removed.name,
              upgradeLevel: copy.upgradeLevel,
              coins: coins,
            ));
            await (db.delete(db.ownedPlayers)
                  ..where((o) => o.id.equals(copy.id)))
                .go();
          }
        }
        if (compensations.isNotEmpty) {
          final total =
              compensations.fold<int>(0, (a, c) => a + c.coins);
          await (db.update(db.clubs)
                ..where((c) => c.id.equals(club.id)))
              .write(ClubsCompanion(
                  coins: Value(club.coins + total)));
          await db.coinLedger(club.id, total,
              reason: 'removal_compensation',
              detail:
                  '${compensations.length} players removed by dataset update');
        }
      }

      await db.into(db.datasetVersions).insertOnConflictUpdate(
            DatasetVersionsCompanion.insert(
              version: Value(dataset.version),
              asOf: dataset.asOf,
              digest: Value(dataset.digest),
              importedAt: DateTime.now(),
              playerCount: dataset.count,
            ),
          );
    });

    _registryLoaded = true;
    return DatasetUpdateReport(
        importResult: importResult, compensations: compensations);
  }

  // ---------------------------------------------------------------------------
  // Packs
  // ---------------------------------------------------------------------------

  /// Opens one owned pack: draws three players and persists each as an
  /// owned instance atomically with the pack's consumption (FR-010, NFR-003).
  Future<PackOpenResult> openPack({
    required int packId,
    required math.Random random,
  }) async {
    final registry = await _ensureRegistry();
    final pack = await (db.select(db.packs)
          ..where((p) => p.id.equals(packId)))
        .getSingleOrNull();
    if (pack == null || pack.opened) {
      throw const CollectionException('Pack not available');
    }

    final category = PackCategory.values
        .firstWhere((c) => c.name == pack.category, orElse: () => PackCategory.global);
    final scope = PackScope(
      category: category,
      position: pack.scopeValue != null && category == PackCategory.position
          ? Position.fromCode(pack.scopeValue!)
          : null,
    );
    final pool = registry.all.toList(growable: false);
    final engine = PackEngine(random: random, economy: economy);
    final draws = engine.open(scope, pool);
    if (draws.isEmpty) {
      throw const CollectionException('No eligible players for this pack');
    }

    final now = DateTime.now();
    await db.transaction(() async {
      for (final draw in draws) {
        await db.into(db.ownedPlayers).insert(OwnedPlayersCompanion.insert(
              clubId: pack.clubId,
              playerId: draw.player.playerId,
              acquisitionSource: Value('pack'),
              acquiredAt: now,
            ));
      }
      await (db.update(db.packs)
            ..where((p) => p.id.equals(packId)))
          .write(PacksCompanion(opened: const Value(true), openedAt: Value(now)));
    });
    return PackOpenResult(
        players: [for (final d in draws) d.player]);
  }

  /// All unopened packs of the club.
  Future<List<Pack>> getAvailablePacks() async {
    final club = await getClub();
    if (club == null) return const [];
    return (db.select(db.packs)
          ..where((p) => p.clubId.equals(club.id) & p.opened.equals(false)))
        .get();
  }

  // ---------------------------------------------------------------------------
  // Collection
  // ---------------------------------------------------------------------------

  /// Owned (active) cards joined with base data, ordered by rating.
  Future<List<PlayerCard>> getCollection() async {
    final club = await getClub();
    if (club == null) return const [];
    final query = db.select(db.ownedPlayers).join([
      innerJoin(
          db.players, db.players.playerId.equalsExp(db.ownedPlayers.playerId)),
    ]);
    query.where(db.ownedPlayers.clubId.equals(club.id) &
        db.ownedPlayers.status.equals('owned'));
    final rows = await query.map((row) {
      final owned = row.readTable(db.ownedPlayers);
      final base = row.readTable(db.players);
      return PlayerCard(
        ownedId: owned.id,
        base: BasePlayer(
          playerId: base.playerId,
          name: base.name,
          position: Position.fromCode(base.position),
          age: base.age,
          nationality: base.nationality,
          club: base.club,
          leagueCode: base.leagueCode,
          marketValueEur: base.marketValueEur,
          baseStats: BaseStats(
            overall: base.overall,
            attack: base.attack,
            support: base.support,
            defence: base.defence,
            goalkeeping: base.goalkeeping,
          ),
        ),
        upgradeLevel: owned.upgradeLevel,
        upgradedAttack: owned.upgradedAttack,
        upgradedSupport: owned.upgradedSupport,
        upgradedDefence: owned.upgradedDefence,
        upgradedGoalkeeping: owned.upgradedGoalkeeping,
        staminaPercent: owned.staminaPercent,
      );
    }).get();
    rows.sort((a, b) => b.overall.compareTo(a.overall));
    return rows;
  }

  /// Sells owned copies (FR-013): upgraded pricing applies per copy; the
  /// credit and status change share one transaction.
  Future<SaleResult> sellPlayers(List<int> ownedIds) async {
    if (ownedIds.isEmpty) {
      throw const CollectionException('Nothing to sell');
    }
    final club = await getClub();
    if (club == null) {
      throw const CollectionException('No club');
    }

    var credit = 0;
    final sold = <int>[];
    await db.transaction(() async {
      for (final id in ownedIds) {
        final copy = await (db.select(db.ownedPlayers)
              ..where((o) => o.id.equals(id) & o.status.equals('owned')))
            .getSingleOrNull();
        if (copy == null) continue;
        if (copy.squadSlot != null) {
          throw CollectionException(
              'Player is in the squad (slot ${copy.squadSlot})');
        }
        final base = await (db.select(db.players)
              ..where((p) => p.playerId.equals(copy.playerId)))
            .getSingle();
        credit += economy.sellPriceOfUpgraded(
            _toBasePlayer(base), copy.upgradeLevel);
        sold.add(id);
        await (db.update(db.ownedPlayers)..where((o) => o.id.equals(id)))
            .write(const OwnedPlayersCompanion(
                status: Value('sold'), squadSlot: Value(null)));
      }
      if (sold.isNotEmpty) {
        await (db.update(db.clubs)..where((c) => c.id.equals(club.id)))
            .write(ClubsCompanion(coins: Value(club.coins + credit)));
        await db.coinLedger(club.id, credit,
            reason: 'player_sale',
            detail: '${sold.length} players sold');
      }
    });
    return SaleResult(soldOwnedIds: sold, credit: credit);
  }

  /// Merges two owned copies of the same player (FR-014, GDD 8.1): the
  /// duplicate is consumed, the target gains the levels and attribute
  /// points. Merging is free — the Economy Engine prices upgrades when they
  /// are purchased with coins, not when merging owned duplicates.
  Future<MergeResult> mergeDuplicates({
    required int targetOwnedId,
    required int duplicateOwnedId,
    required math.Random random,
  }) async {
    if (targetOwnedId == duplicateOwnedId) {
      throw const CollectionException('Cannot merge a player into itself');
    }
    final club = await getClub();
    if (club == null) {
      throw const CollectionException('No club');
    }

    final target = await (db.select(db.ownedPlayers)
          ..where((o) =>
              o.id.equals(targetOwnedId) & o.status.equals('owned')))
        .getSingleOrNull();
    final duplicate = await (db.select(db.ownedPlayers)
          ..where((o) =>
              o.id.equals(duplicateOwnedId) & o.status.equals('owned')))
        .getSingleOrNull();
    if (target == null || duplicate == null) {
      throw const CollectionException('Both copies must be owned');
    }
    if (target.playerId != duplicate.playerId) {
      throw const CollectionException('Merging requires the same player');
    }
    if (!upgrades.canMerge(
        targetLevel: target.upgradeLevel,
        duplicateLevel: duplicate.upgradeLevel)) {
      throw const CollectionException('Maximum upgrade level reached');
    }

    final base = await (db.select(db.players)
          ..where((p) => p.playerId.equals(target.playerId)))
        .getSingle();
    final outcome = upgrades.merge(
      position: Position.fromCode(base.position),
      targetLevel: target.upgradeLevel,
      duplicateLevel: duplicate.upgradeLevel,
      random: random,
    );

    await db.transaction(() async {
      await (db.update(db.ownedPlayers)
            ..where((o) => o.id.equals(targetOwnedId)))
          .write(OwnedPlayersCompanion(
        upgradeLevel: Value(outcome.newUpgradeLevel),
        upgradedAttack:
            Value(target.upgradedAttack + (outcome.attributeGain[PlayerAttribute.attack] ?? 0)),
        upgradedSupport:
            Value(target.upgradedSupport + (outcome.attributeGain[PlayerAttribute.support] ?? 0)),
        upgradedDefence:
            Value(target.upgradedDefence + (outcome.attributeGain[PlayerAttribute.defence] ?? 0)),
        upgradedGoalkeeping: Value(target.upgradedGoalkeeping +
            (outcome.attributeGain[PlayerAttribute.goalkeeping] ?? 0)),
      ));
      // Consume the duplicate; keep the row as history.
      await (db.update(db.ownedPlayers)
            ..where((o) => o.id.equals(duplicateOwnedId)))
          .write(const OwnedPlayersCompanion(
              status: Value('merged'), squadSlot: Value(null)));
    });

    return MergeResult(
      targetOwnedId: targetOwnedId,
      duplicateOwnedId: duplicateOwnedId,
      newUpgradeLevel: outcome.newUpgradeLevel,
      attributeGain: outcome.attributeGain,
    );
  }

  // ---------------------------------------------------------------------------
  // Squad
  // ---------------------------------------------------------------------------

  /// Squad assignments currently persisted: slot → card.
  Future<Map<int, PlayerCard>> getSquad() async {
    final club = await getClub();
    if (club == null) return const {};
    final cards = await getCollection();
    final byId = {for (final c in cards) c.ownedId: c};
    final rows = await (db.select(db.ownedPlayers)
          ..where((o) => o.clubId.equals(club.id)))
        .get();
    final squad = <int, PlayerCard>{};
    for (final row in rows) {
      if (row.squadSlot != null && byId.containsKey(row.id)) {
        squad[row.squadSlot!] = byId[row.id]!;
      }
    }
    return squad;
  }

  /// Persists a full squad assignment (FR-017/FR-020 storage side). Slots
  /// not present in [assignments] are cleared. Runs in one transaction.
  Future<void> saveSquad(Map<int, int> assignments) async {
    final club = await getClub();
    if (club == null) {
      throw const CollectionException('No club');
    }
    final owned = await (db.select(db.ownedPlayers)
          ..where((o) =>
              o.clubId.equals(club.id) & o.status.equals('owned')))
        .get();
    final byOwned = {for (final o in owned) o.id: o};
    for (final id in assignments.values) {
      if (!byOwned.containsKey(id)) {
        throw CollectionException('Owned player $id not found');
      }
    }
    // one player per slot and one slot per player
    if (assignments.values.toSet().length != assignments.length) {
      throw const CollectionException('A player cannot take two slots');
    }

    await db.transaction(() async {
      for (final o in owned) {
        final slot = assignments.entries
            .where((e) => e.value == o.id)
            .map((e) => e.key)
            .firstOrNull;
        if (o.squadSlot != slot) {
          await (db.update(db.ownedPlayers)..where((x) => x.id.equals(o.id)))
              .write(OwnedPlayersCompanion(squadSlot: Value(slot)));
        }
      }
    });
  }

  /// Auto Pick over the current collection and formation, then persist
  /// (FR-019). Returns the applied assignment.
  Future<Map<int, int>> autoPickSquad() async {
    final club = await getClub();
    if (club == null) {
      throw const CollectionException('No club');
    }
    final cards = await getCollection();
    final formation = formationByCode(club.formationCode);
    final assignment = squad.autoPick(cards, formation);
    await saveSquad(assignment);
    return assignment;
  }

  /// Updates the club formation (FR-018) and re-runs Auto Pick so every XI
  /// slot stays filled (GDD 6.4: changing formation updates positions).
  Future<void> changeFormation(String formationCode) async {
    final club = await getClub();
    if (club == null) {
      throw const CollectionException('No club');
    }
    final formation = formationByCode(formationCode);
    await (db.update(db.clubs)..where((c) => c.id.equals(club.id)))
        .write(ClubsCompanion(formationCode: Value(formation.code)));
    await autoPickSquad();
  }

  /// Adapts a persisted player row to the domain model.
  BasePlayer _toBasePlayer(Player row) => BasePlayer(
        playerId: row.playerId,
        name: row.name,
        position: Position.fromCode(row.position),
        age: row.age,
        nationality: row.nationality,
        club: row.club,
        leagueCode: row.leagueCode,
        marketValueEur: row.marketValueEur,
        baseStats: BaseStats(
          overall: row.overall,
          attack: row.attack,
          support: row.support,
          defence: row.defence,
          goalkeeping: row.goalkeeping,
        ),
      );
}

extension on AppDatabase {
  /// Appends one ledger row for [amount] credited to [clubId]. Must be
  /// called AFTER the balance update inside the same transaction so
  /// balanceAfter reflects the post-transaction state (FR-016).
  Future<void> coinLedger(int clubId, int amount,
      {required String reason, String? detail}) async {
    final club = await (select(clubs)..where((c) => c.id.equals(clubId)))
        .getSingle();
    await into(coinTransactions).insert(CoinTransactionsCompanion.insert(
      clubId: clubId,
      amount: amount,
      balanceAfter: club.coins,
      reason: reason,
      detail: Value(detail),
      createdAt: DateTime.now(),
    ));
  }
}
