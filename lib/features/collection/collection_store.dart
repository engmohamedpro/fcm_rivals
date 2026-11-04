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
import '../../core/database/coin_ops.dart';
import '../../core/domain/players.dart';
import '../ads/ad_engine.dart';
import '../ads/ad_store.dart';
import '../economy/economy_engine.dart';
import '../facilities/facilities.dart';
import '../match/stamina.dart'
    show StaminaConfig, PepTalk, recoverStamina, applyPepTalkBonus;
import '../packs/pack_engine.dart';
import '../player_database/player_database.dart';
import '../squad/formations.dart';
import '../squad/squad_engine.dart';
import '../upgrades/upgrade_engine.dart';
import '../../core/ui/fcm_style.dart' show CardRarity;

/// Thrown when an operation would leave persistent state inconsistent.
class CollectionException implements Exception {
  const CollectionException(this.message);
  final String message;

  @override
  String toString() => 'CollectionException: $message';
}

/// The players drawn from one opened pack, in reveal order.
class PackOpenResult {
  const PackOpenResult({
    required this.players,
    this.tiers = const [],
    this.ownedIds = const [],
  });

  /// Drawn players (one per pack).
  final List<BasePlayer> players;

  /// Market Value tier each player was drawn from (0 low, 1 mid, 2 high),
  /// index-aligned with [players]. Drives reveal effects (GDD 5.6).
  final List<int> tiers;

  /// Owned-player row ids of the drawn players, index-aligned with
  /// [players] — the handle for sell- straight-from-the-reveal.
  final List<int> ownedIds;
}

/// One buyable pack in the store (GDD 5.5): category, scope, store tier
/// and the Economy-Engine-derived coin price.
class StorePackOffer {
  const StorePackOffer({
    required this.category,
    required this.title,
    required this.scopeValue,
    required this.tier,
    required this.price,
    required this.eligibleCount,
  });

  final PackCategory category;

  /// Store tier: bronze / silver / gold odds variety (GDD 5.5).
  final PackTier tier;

  /// Display title, e.g. 'ST Position Pack'.
  final String title;

  /// Scope filter value (position code), null for the global pack.
  final String? scopeValue;

  /// Coin price from `PackEngine.packPriceFor`.
  final int price;

  /// Number of eligible players in the pool.
  final int eligibleCount;
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

  int get totalCompensation => compensations.fold(0, (a, c) => a + c.coins);
}

/// Result of buying one upgrade level with coins (GDD 8.4).
class UpgradePurchaseResult {
  const UpgradePurchaseResult({
    required this.ownedId,
    required this.playerName,
    required this.upgradeLevel,
    required this.coins,
    required this.fullCost,
    required this.discountApplied,
  });

  final int ownedId;
  final String playerName;
  final int upgradeLevel;

  /// Coins actually charged (the discounted price when an ad discount
  /// applied).
  final int coins;

  /// Undiscounted Economy Engine price.
  final int fullCost;

  /// Whether the GDD 19.3 ad discount was applied (and consumed).
  final bool discountApplied;
}

class CollectionStore {
  CollectionStore({
    required this.db,
    this.economy = const EconomyEngine(),
    this.upgrades = const UpgradeEngine(),
    this.squad = const SquadEngine(),
    this.adStore,
  });

  final AppDatabase db;
  final EconomyEngine economy;
  final UpgradeEngine upgrades;
  final SquadEngine squad;

  /// Rewarded-ad store for the economy ad surfaces (GDD 19.3 'Other
  /// Proposed'): upgrade discount, selling bonus, daily reward
  /// multiplier. Optional — when absent, all ad boosts are simply
  /// inactive and the coin paths charge full price.
  final AdStore? adStore;

  /// Facility enum name → instance, for reading FacilityLevels rows.
  static final Map<String, Facility> _facilityByCode = {
    for (final f in Facility.values) f.name: f,
  };

  /// Packs draw from the in-memory registry mirrored into SQLite; kept in
  /// sync by [applyDatasetUpdate] and lazily loaded on first use.
  final PlayerDatabase _registry = PlayerDatabase();
  bool _registryLoaded = false;

  static const int startingPacksPerPosition = 2;

  /// Positions whose packs are the cheapest in the store — kept for the
  /// store's own context; the starting packs now follow the chosen
  /// formation instead (2 packs per slot position).
  static const int freeStartingPositionCount = 4;

  /// The [freeStartingPositionCount] positions with the cheapest store
  /// packs, derived from the current dataset's Bronze-tier position-pack
  /// prices (cheapest pools first, ties by pool size).
  Future<List<Position>> cheapestPackPositions() async {
    final registry = await _ensureRegistry();
    final pool = registry.all.toList(growable: false);
    final engine = PackEngine(random: math.Random(0), economy: economy);
    final priced =
        [
          for (final position in Position.values)
            (
              position: position,
              price: engine.packPriceFor(
                PackScope(
                  category: PackCategory.position,
                  position: position,
                  tier: PackTier.rare,
                ),
                pool,
              ),
              poolSize: pool.where((p) => p.position == position).length,
            ),
        ]..sort((a, b) {
          final byPrice = a.price.compareTo(b.price);
          if (byPrice != 0) return byPrice;
          return a.poolSize.compareTo(b.poolSize);
        });
    return [
      for (final entry in priced.take(freeStartingPositionCount))
        entry.position,
    ];
  }

  // ---------------------------------------------------------------------------
  // Club lifecycle
  // ---------------------------------------------------------------------------

  /// Creates the user club (FR-001) with starting coins, the chosen
  /// starter formation and its free packs (GDD 5.8): TWO position packs
  /// per formation slot — 22 packs for an 11-slot shape, so opening the
  /// free inventory fields the exact XI the user picked plus a full
  /// bench's worth of cover. Returns the club id.
  Future<int> createClub({
    required String clubName,
    required String managerName,
    required int crestIndex,
    String formationCode = '4-3-3',
  }) async {
    if (clubName.trim().isEmpty) {
      throw const CollectionException('Club name is required');
    }
    if (managerName.trim().isEmpty) {
      throw const CollectionException('Manager name is required');
    }
    final existing = await (db.select(
      db.clubs,
    )..where((c) => c.isUser.equals(true))).getSingleOrNull();
    if (existing != null) {
      throw const CollectionException('A club already exists on this device');
    }
    final formation = formationByCode(formationCode);

    final now = DateTime.now();
    return db.transaction(() async {
      final clubId = await db
          .into(db.clubs)
          .insert(
            ClubsCompanion.insert(
              name: clubName.trim(),
              managerName: managerName.trim(),
              crestIndex: Value(crestIndex),
              formationCode: Value(formation.code),
              coins: economy.config.startingCoins,
              createdAt: now,
            ),
          );
      await db.coinLedger(
        clubId,
        economy.config.startingCoins,
        reason: 'starting_grant',
        detail: 'Club creation grant',
      );
      // Free starting packs (GDD 5.8), the 22-pack system: two packs of
      // EVERY position the chosen formation asks for — one wave to fill
      // the XI, one for the bench. Duplicated slot positions (e.g. two
      // CB slots in a back four) each contribute their two packs, so a
      // 4-3-3 hands out 4 CB packs while a 3-5-2 hands out 6 CB/CM-heavy
      // packs: the inventory mirrors the shape the user committed to.
      for (final slot in formation.slots) {
        for (var i = 0; i < startingPacksPerPosition; i++) {
          await db
              .into(db.packs)
              .insert(
                PacksCompanion.insert(
                  clubId: clubId,
                  category: 'position',
                  scopeValue: Value(slot.position.code),
                  tier: const Value('rare'),
                  source: const Value('starting'),
                  createdAt: now,
                ),
              );
        }
      }
      return clubId;
    });
  }

  /// The user club, or null before onboarding completes. Uses
  /// getSingleOrNull — watchSingle would throw on the empty table on a
  /// fresh install, crashing club creation.
  Future<Club?> getClub() => (db.select(
    db.clubs,
  )..where((c) => c.isUser.equals(true))).getSingleOrNull();

  /// TEMPORARY DEV HELPER — remove together with the app-bar "+"
  /// button (main.dart) once testing is done. Credits the user club
  /// with [amount] test coins through the same atomic transaction and
  /// ledger row as every other coin movement (FR-016).
  ///
  /// Debug and test builds only: asserts are enabled there, so the
  /// helper runs; release builds compile asserts out and this returns
  /// without touching the balance or the ledger. The app-bar button is
  /// guarded by kDebugMode too, so neither half of the dev shortcut can
  /// ship.
  Future<void> grantTestCoins({int amount = 1_000_000}) async {
    var devBuild = false;
    assert(() {
      devBuild = true;
      return true;
    }());
    if (!devBuild) return;
    final club = await getClub();
    if (club == null) {
      throw const CollectionException('No club yet — cannot grant coins');
    }
    await db.creditCoins(
      club.id,
      amount,
      reason: 'test_grant',
      detail: 'Dev test grant from app-bar + button',
    );
  }

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
        version:
            (await db.select(db.datasetVersions).getSingleOrNull())?.version ??
            0,
        asOf: '',
        rows: [
          for (final r in rows)
            PlayerDatasetRow(
              playerId: r.playerId,
              name: r.name,
              position: Position.fromCode(r.position),
              nationality: r.nationality,
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
  /// primes the in-memory registry. The caller owns parsing — the app
  /// bootstrap decodes on a background isolate (see providers.dart).
  Future<void> importBundledDataset(PlayerDataset dataset) async {
    final current = await db.select(db.datasetVersions).getSingleOrNull();
    if (current != null && current.version >= dataset.version) return;
    await applyDatasetUpdate(dataset);
  }

  /// Applies a dataset update transactionally (FR-004..FR-008, NFR-003):
  /// registry update rules, upsert of player rows, removed-player
  /// compensation at the exact upgraded selling formula, squad slot cleanup.
  Future<DatasetUpdateReport> applyDatasetUpdate(PlayerDataset dataset) async {
    await _ensureRegistry();
    final importResult = _registry.importDataset(dataset);

    final club = await (db.select(
      db.clubs,
    )..where((c) => c.isUser.equals(true))).getSingleOrNull();
    final compensations = <RemovalCompensation>[];

    await db.transaction(() async {
      // Upsert current rows (regenerated stats included per GDD 4.6) in
      // ONE batched statement instead of ~20,876 awaited round trips:
      // the batch is atomic with the rest of this transaction, so
      // dataset updates and removed-player compensation still commit
      // or roll back together (FR-004..FR-008, NFR-003).
      await db.batch((batch) {
        batch.insertAll(
          db.players,
          [
            for (final player in [
              ...importResult.added,
              ...importResult.updated,
              ...importResult.regenerated,
            ])
              PlayersCompanion.insert(
                playerId: Value(player.playerId),
                name: player.name,
                position: player.position.code,
                nationality: player.nationality,
                marketValueEur: player.marketValueEur,
                overall: player.baseStats.overall,
                attack: player.baseStats.attack,
                support: player.baseStats.support,
                defence: player.baseStats.defence,
                goalkeeping: player.baseStats.goalkeeping,
              ),
          ],
          mode: InsertMode.insertOrReplace,
        );
      });

      // Removed players: compensate owners, drop copies and squad slots
      // (GDD 4.8) — inside the same transaction as the data update.
      if (club != null) {
        for (final removed in importResult.removed) {
          final owned =
              await (db.select(db.ownedPlayers)..where(
                    (o) =>
                        o.playerId.equals(removed.playerId) &
                        o.status.equals('owned'),
                  ))
                  .get();
          for (final copy in owned) {
            final coins = economy.sellPriceOfUpgraded(
              removed,
              copy.upgradeLevel,
            );
            compensations.add(
              RemovalCompensation(
                playerName: removed.name,
                upgradeLevel: copy.upgradeLevel,
                coins: coins,
              ),
            );
            await (db.delete(
              db.ownedPlayers,
            )..where((o) => o.id.equals(copy.id))).go();
          }
        }
        if (compensations.isNotEmpty) {
          final total = compensations.fold<int>(0, (a, c) => a + c.coins);
          // Relative update — a concurrent coin movement (a pack
          // purchase, a match reward) can no longer be overwritten by
          // this credit (see coin_ops.dart). The legacy coinLedger
          // re-selects the row itself, so its balanceAfter is correct.
          await db.customUpdate(
            'UPDATE clubs SET coins = coins + ? WHERE id = ?',
            variables: [
              Variable.withInt(total),
              Variable.withInt(club.id),
            ],
            updates: {db.clubs},
            updateKind: UpdateKind.update,
          );
          await db.coinLedger(
            club.id,
            total,
            reason: 'removal_compensation',
            detail: '${compensations.length} players removed by dataset update',
          );
        }
      }

      await db
          .into(db.datasetVersions)
          .insertOnConflictUpdate(
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
      importResult: importResult,
      compensations: compensations,
    );
  }

  // ---------------------------------------------------------------------------
  // Packs
  // ---------------------------------------------------------------------------

  /// Opens one owned pack: draws one player and persists it as an
  /// owned instance atomically with the pack's consumption (FR-010, NFR-003).
  Future<PackOpenResult> openPack({
    required int packId,
    required math.Random random,
  }) async {
    final registry = await _ensureRegistry();
    final pack = await (db.select(
      db.packs,
    )..where((p) => p.id.equals(packId))).getSingleOrNull();
    if (pack == null || pack.opened) {
      throw const CollectionException('Pack not available');
    }

    final category = PackCategory.values.firstWhere(
      (c) => c.name == pack.category,
      orElse: () => PackCategory.global,
    );
    final scope = PackScope(
      category: category,
      position: pack.scopeValue != null && category == PackCategory.position
          ? Position.fromCode(pack.scopeValue!)
          : null,
      tier: PackTier.fromName(pack.tier),
    );
    final pool = registry.all.toList(growable: false);
    final engine = PackEngine(random: random, economy: economy);
    final draws = engine.open(scope, pool);
    if (draws.isEmpty) {
      throw const CollectionException('No eligible players for this pack');
    }

    final now = DateTime.now();
    final ownedIds = <int>[];
    await db.transaction(() async {
      for (final draw in draws) {
        final ownedId = await db
            .into(db.ownedPlayers)
            .insert(
              OwnedPlayersCompanion.insert(
                clubId: pack.clubId,
                playerId: draw.player.playerId,
                acquisitionSource: Value('pack'),
                acquiredAt: now,
              ),
            );
        ownedIds.add(ownedId);
      }
      await (db.update(db.packs)..where((p) => p.id.equals(packId))).write(
        PacksCompanion(opened: const Value(true), openedAt: Value(now)),
      );
    });
    return PackOpenResult(
      players: [for (final d in draws) d.player],
      tiers: [for (final d in draws) d.tier],
      ownedIds: ownedIds,
    );
  }

  /// Every player a pack of this scope could draw, best overall first —
  /// the contents list behind tapping a store cell (no stats shown there,
  /// just the rating ladder).
  Future<List<BasePlayer>> getPackPlayers({
    required PackCategory category,
    String? scopeValue,
    required PackTier tier,
  }) async {
    final registry = await _ensureRegistry();
    final scope = PackScope(
      category: category,
      position: category == PackCategory.position && scopeValue != null
          ? Position.fromCode(scopeValue)
          : null,
      tier: tier,
    );
    final eligible = registry.all.where(scope.matches).toList(growable: false);
    eligible.sort((a, b) {
      final byOverall = b.baseStats.overall.compareTo(a.baseStats.overall);
      if (byOverall != 0) return byOverall;
      return a.playerId.compareTo(b.playerId);
    });
    return eligible;
  }

  /// All unopened packs of the club.
  Future<List<Pack>> getAvailablePacks() async {
    final club = await getClub();
    if (club == null) return const [];
    return (db.select(
      db.packs,
    )..where((p) => p.clubId.equals(club.id) & p.opened.equals(false))).get();
  }

  /// The store's buyable packs (GDD 5.5): one section per position, each
  /// tier with its own odds of better players and its own price from the
  /// Economy Engine's expected-contents formula (better odds cost more).
  /// Prices are stable per dataset.
  ///
  /// A tier only goes on the shelf when the position's pool actually
  /// contains players of that pack's rarity — no legendary players in
  /// the pool, no legendary pack (the dataset's LM and RM pools hold no
  /// 82+ players, so those sections show Rare and Epic only).
  Future<List<StorePackOffer>> getStoreOffers() async {
    final registry = await _ensureRegistry();
    final pool = registry.all.toList(growable: false);

    CardRarity rarityOf(PackTier tier) => switch (tier) {
      PackTier.rare => CardRarity.rare,
      PackTier.epic => CardRarity.epic,
      PackTier.legendary => CardRarity.legendary,
    };

    StorePackOffer? offerFor(
      PackCategory category,
      String? scopeValue,
      PackTier tier,
      String baseTitle,
    ) {
      final scope = PackScope(
        category: category,
        position: category == PackCategory.position && scopeValue != null
            ? Position.fromCode(scopeValue)
            : null,
        tier: tier,
      );
      final eligible = pool.where(scope.matches).toList(growable: false);
      if (!eligible.any(
        (p) => CardRarity.fromOverall(p.baseStats.overall) == rarityOf(tier),
      )) {
        return null;
      }
      return StorePackOffer(
        category: category,
        title: '${tier.label} $baseTitle',
        scopeValue: scopeValue,
        tier: tier,
        price: PackEngine(
          random: math.Random(0),
          economy: economy,
        ).packPriceFor(scope, eligible),
        eligibleCount: eligible.length,
      );
    }

    final offers = <StorePackOffer>[];
    for (final position in Position.values) {
      for (final tier in PackTier.values) {
        final offer = offerFor(
          PackCategory.position,
          position.code,
          tier,
          '${position.code} Position Pack',
        );
        if (offer != null) offers.add(offer);
      }
    }
    return offers;
  }

  /// Buys one pack with Coins (GDD 5.5: prices come from the Economy
  /// Engine's expected-contents formula — driven by the pack's [tier] —
  /// and are charged atomically with a ledger row). The bought pack lands
  /// in the club's inventory like any other and is opened via [openPack].
  Future<Pack> buyPack({
    required PackCategory category,
    PackTier tier = PackTier.rare,
    String? nationality,
    Position? position,
  }) async {
    final userClub = await getClub();
    if (userClub == null) {
      throw const CollectionException('No club');
    }
    final registry = await _ensureRegistry();
    final scope = PackScope(
      category: category,
      nationality: nationality,
      position: position,
      tier: tier,
    );
    final pool = registry.all
        .where((p) => scope.matches(p))
        .toList(growable: false);
    // A pack draws exactly one player.
    if (pool.isEmpty) {
      throw const CollectionException('Not enough eligible players');
    }
    final engine = PackEngine(random: math.Random(0), economy: economy);
    final price = engine.packPriceFor(scope, pool);
    if (price <= 0) {
      throw const CollectionException('Pack price must be positive');
    }
    // Friendly early failure (the WHERE-clause guard in spendCoins is
    // what actually enforces it under races).
    if (userClub.coins < price) {
      throw const CollectionException('Not enough coins');
    }
    final now = DateTime.now();
    final id = await db.transaction(() async {
      // Debit first, relative and conditional: if a concurrent movement
      // spent the balance below the price between the pre-check and
      // here, this throws and the transaction (including the pack row)
      // rolls back — no pack without coins, no coins without ledger.
      try {
        await db.spendCoins(
          userClub.id,
          price,
          reason: 'pack_purchase',
          detail: 'Bought ${tier.label} ${category.name} pack',
        );
      } on Exception catch (e) {
        throw CollectionException(e.toString().replaceFirst('Exception: ', ''));
      }
      return await db
          .into(db.packs)
          .insert(
            PacksCompanion.insert(
              clubId: userClub.id,
              category: category.name,
              scopeValue: Value(position?.code ?? nationality),
              tier: Value(tier.name),
              price: Value(price),
              source: const Value('purchase'),
              createdAt: now,
            ),
          );
    });
    return (await (db.select(
      db.packs,
    )..where((p) => p.id.equals(id))).getSingle());
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
        db.players,
        db.players.playerId.equalsExp(db.ownedPlayers.playerId),
      ),
    ]);
    query.where(
      db.ownedPlayers.clubId.equals(club.id) &
          db.ownedPlayers.status.equals('owned'),
    );
    final rows = await query.map((row) {
      final owned = row.readTable(db.ownedPlayers);
      final base = row.readTable(db.players);
      return PlayerCard(
        ownedId: owned.id,
        base: BasePlayer(
          playerId: base.playerId,
          name: base.name,
          position: Position.fromCode(base.position),
          nationality: base.nationality,
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
    // GDD 19.3 'Player selling bonus': one ad boosts this sale by +20%.
    final ads = adStore;
    var bonusActive = false;
    if (ads != null && await ads.sellingBonusActive(club.id)) {
      bonusActive = true;
    }
    await db.transaction(() async {
      for (final id in ownedIds) {
        final copy =
            await (db.select(db.ownedPlayers)
                  ..where((o) => o.id.equals(id) & o.status.equals('owned')))
                .getSingleOrNull();
        if (copy == null) continue;
        if (copy.squadSlot != null) {
          throw CollectionException(
            'Player is in the squad (slot ${copy.squadSlot})',
          );
        }
        final base = await (db.select(
          db.players,
        )..where((p) => p.playerId.equals(copy.playerId))).getSingle();
        var price = economy.sellPriceOfUpgraded(
          _toBasePlayer(base),
          copy.upgradeLevel,
        );
        if (bonusActive) {
          price = const AdEngine().sellingBonus(price);
        }
        credit += price;
        sold.add(id);
        await (db.update(db.ownedPlayers)..where((o) => o.id.equals(id))).write(
          const OwnedPlayersCompanion(
            status: Value('sold'),
            squadSlot: Value(null),
          ),
        );
      }
      if (sold.isNotEmpty) {
        // Relative credit — a concurrent coin movement can no longer be
        // overwritten by this sale (see coin_ops.dart).
        await db.customUpdate(
          'UPDATE clubs SET coins = coins + ? WHERE id = ?',
          variables: [Variable.withInt(credit), Variable.withInt(club.id)],
          updates: {db.clubs},
          updateKind: UpdateKind.update,
        );
        await db.coinLedger(
          club.id,
          credit,
          reason: 'player_sale',
          detail:
              '${sold.length} players sold${bonusActive ? ' (ad selling bonus)' : ''}',
        );
        if (bonusActive) {
          await ads!.consumeSellingBonus(club.id);
        }
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

    final target =
        await (db.select(db.ownedPlayers)..where(
              (o) => o.id.equals(targetOwnedId) & o.status.equals('owned'),
            ))
            .getSingleOrNull();
    final duplicate =
        await (db.select(db.ownedPlayers)..where(
              (o) => o.id.equals(duplicateOwnedId) & o.status.equals('owned'),
            ))
            .getSingleOrNull();
    if (target == null || duplicate == null) {
      throw const CollectionException('Both copies must be owned');
    }
    if (target.playerId != duplicate.playerId) {
      throw const CollectionException('Merging requires the same player');
    }
    if (!upgrades.canMerge(
      targetLevel: target.upgradeLevel,
      duplicateLevel: duplicate.upgradeLevel,
    )) {
      throw const CollectionException('Maximum upgrade level reached');
    }

    final base = await (db.select(
      db.players,
    )..where((p) => p.playerId.equals(target.playerId))).getSingle();
    final outcome = upgrades.merge(
      position: Position.fromCode(base.position),
      targetLevel: target.upgradeLevel,
      duplicateLevel: duplicate.upgradeLevel,
      random: random,
    );

    await db.transaction(() async {
      await (db.update(
        db.ownedPlayers,
      )..where((o) => o.id.equals(targetOwnedId))).write(
        OwnedPlayersCompanion(
          upgradeLevel: Value(outcome.newUpgradeLevel),
          upgradedAttack: Value(
            target.upgradedAttack +
                (outcome.attributeGain[PlayerAttribute.attack] ?? 0),
          ),
          upgradedSupport: Value(
            target.upgradedSupport +
                (outcome.attributeGain[PlayerAttribute.support] ?? 0),
          ),
          upgradedDefence: Value(
            target.upgradedDefence +
                (outcome.attributeGain[PlayerAttribute.defence] ?? 0),
          ),
          upgradedGoalkeeping: Value(
            target.upgradedGoalkeeping +
                (outcome.attributeGain[PlayerAttribute.goalkeeping] ?? 0),
          ),
        ),
      );
      // Consume the duplicate; keep the row as history.
      await (db.update(
        db.ownedPlayers,
      )..where((o) => o.id.equals(duplicateOwnedId))).write(
        const OwnedPlayersCompanion(
          status: Value('merged'),
          squadSlot: Value(null),
        ),
      );
      // The duplicate may have been a starter (merged INTO from the
      // bench): its slot is now empty — re-run Auto Pick so every XI
      // slot stays filled (GDD 6.4 invariant, next fixture depends on it).
      if (duplicate.squadSlot != null &&
          duplicate.squadSlot! < Formation.startingXiSize) {
        final cards = await getCollection();
        final formation = formationByCode(club.formationCode);
        await saveSquad(squad.autoPick(cards, formation));
      }
    });

    return MergeResult(
      targetOwnedId: targetOwnedId,
      duplicateOwnedId: duplicateOwnedId,
      newUpgradeLevel: outcome.newUpgradeLevel,
      attributeGain: outcome.attributeGain,
    );
  }

  /// Buys one upgrade level with Coins (GDD 8.4: cost = Economy Engine
  /// formula on Market Value and current Upgrade Level). When an ad
  /// discount is active (GDD 19.3 'Upgrade cost discount') the discounted
  /// price is charged and the boost consumed. The attribute points land
  /// through the same UpgradeEngine allocation as merges.
  Future<UpgradePurchaseResult> buyUpgrade({
    required int ownedId,
    required math.Random random,
  }) async {
    final club = await getClub();
    if (club == null) {
      throw const CollectionException('No club');
    }
    final copy =
        await (db.select(db.ownedPlayers)
              ..where((o) => o.id.equals(ownedId) & o.status.equals('owned')))
            .getSingleOrNull();
    if (copy == null) {
      throw const CollectionException('Player not owned');
    }
    if (copy.upgradeLevel >= UpgradeEngine.maxUpgradeLevel) {
      throw const CollectionException('Maximum upgrade level reached');
    }
    final base = await (db.select(
      db.players,
    )..where((p) => p.playerId.equals(copy.playerId))).getSingle();
    final fullCost = economy.upgradeCostOf(
      _toBasePlayer(base),
      copy.upgradeLevel,
    );

    var price = fullCost;
    var discounted = false;
    final ads = adStore;
    if (ads != null && await ads.upgradeDiscountActive(club.id)) {
      price = const AdEngine().discountedUpgradeCost(fullCost);
      discounted = true;
    }
    if (club.coins < price) {
      throw CollectionException('Not enough coins (need $price)');
    }

    final outcome = upgrades.merge(
      position: Position.fromCode(base.position),
      targetLevel: copy.upgradeLevel,
      duplicateLevel: 0,
      random: random,
    );

    await db.transaction(() async {
      // Relative, conditional debit: if a concurrent movement dropped
      // the balance below the price after the pre-check, this throws
      // and the whole upgrade rolls back (see coin_ops.dart).
      try {
        await db.spendCoins(
          club.id,
          price,
          reason: 'upgrade_purchase',
          detail:
              'Bought upgrade to +${outcome.newUpgradeLevel} for ${base.name}',
        );
      } on Exception catch (e) {
        throw CollectionException(e.toString().replaceFirst('Exception: ', ''));
      }
      await (db.update(
        db.ownedPlayers,
      )..where((o) => o.id.equals(ownedId))).write(
        OwnedPlayersCompanion(
          upgradeLevel: Value(outcome.newUpgradeLevel),
          upgradedAttack: Value(
            copy.upgradedAttack +
                (outcome.attributeGain[PlayerAttribute.attack] ?? 0),
          ),
          upgradedSupport: Value(
            copy.upgradedSupport +
                (outcome.attributeGain[PlayerAttribute.support] ?? 0),
          ),
          upgradedDefence: Value(
            copy.upgradedDefence +
                (outcome.attributeGain[PlayerAttribute.defence] ?? 0),
          ),
          upgradedGoalkeeping: Value(
            copy.upgradedGoalkeeping +
                (outcome.attributeGain[PlayerAttribute.goalkeeping] ?? 0),
          ),
        ),
      );
      if (discounted) {
        await ads!.consumeUpgradeDiscount(club.id);
      }
    });

    return UpgradePurchaseResult(
      ownedId: ownedId,
      playerName: base.name,
      upgradeLevel: outcome.newUpgradeLevel,
      coins: price,
      discountApplied: discounted,
      fullCost: fullCost,
    );
  }

  // ---------------------------------------------------------------------------
  // Squad
  // ---------------------------------------------------------------------------

  /// Squad assignments currently persisted: slot → card. Iterates in
  /// slot order — the order Auto Pick writes (bench then reserves
  /// best-first) — so consumers that walk the entries see the ranked
  /// squad instead of an arbitrary database row order.
  Future<Map<int, PlayerCard>> getSquad() async {
    final club = await getClub();
    if (club == null) return const {};
    final cards = await getCollection();
    final byId = {for (final c in cards) c.ownedId: c};
    final rows =
        await (db.select(db.ownedPlayers)
              ..where((o) => o.clubId.equals(club.id))
              ..orderBy([(o) => OrderingTerm.asc(o.squadSlot)]))
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
    final owned = await (db.select(
      db.ownedPlayers,
    )..where((o) => o.clubId.equals(club.id) & o.status.equals('owned'))).get();
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
    await (db.update(db.clubs)..where((c) => c.id.equals(club.id))).write(
      ClubsCompanion(formationCode: Value(formation.code)),
    );
    await autoPickSquad();
  }

  /// Updates the club's tactical setup for future matches (GDD 10.2/10.3).
  Future<void> changeTactics({
    String? formationCode,
    String? playingStyle,
    String? mentality,
  }) async {
    final club = await getClub();
    if (club == null) {
      throw const CollectionException('No club');
    }
    await (db.update(db.clubs)..where((c) => c.id.equals(club.id))).write(
      ClubsCompanion(
        formationCode: formationCode != null
            ? Value(formationByCode(formationCode).code)
            : const Value.absent(),
        playingStyle: playingStyle != null
            ? Value(playingStyle)
            : const Value.absent(),
        mentality: mentality != null ? Value(mentality) : const Value.absent(),
      ),
    );
    if (formationCode != null) {
      await autoPickSquad();
    }
  }

  // ---------------------------------------------------------------------------
  // Campus facilities (GDD 3.5)
  // ---------------------------------------------------------------------------

  /// Current facility levels of the user's club (missing rows = 0).
  Future<CampusLevels> getCampus() async {
    final club = await getClub();
    if (club == null) return CampusLevels.empty;
    final rows = await (db.select(
      db.facilityLevels,
    )..where((f) => f.clubId.equals(club.id))).get();
    return CampusLevels({
      for (final row in rows)
        if (_facilityByCode[row.facility] != null)
          _facilityByCode[row.facility]!: row.level,
    });
  }

  /// Builds the next level of [facility]: charges the escalating coin
  /// price, writes the level row and the ledger entry in one
  /// transaction. Returns the new level.
  Future<int> upgradeFacility(
    Facility facility, {
    FacilitiesCosts costs = defaultFacilitiesCosts,
  }) async {
    final club = await getClub();
    if (club == null) {
      throw const CollectionException('No club');
    }
    final levels = await getCampus();
    final level = levels.levelOf(facility);
    if (level >= costs.maxLevel) {
      throw CollectionException(
        '${facility.title} is already at its maximum level',
      );
    }
    final price = costs.upgradeCost(level);
    if (club.coins < price) {
      throw CollectionException('Not enough coins (need $price)');
    }
    final nextLevel = level + 1;
    final now = DateTime.now();
    await db.transaction(() async {
      // Relative, conditional debit — same race-free guard as every
      // other coin movement (see coin_ops.dart).
      try {
        await db.spendCoins(
          club.id,
          price,
          reason: 'facility_upgrade',
          detail: '${facility.subtitle} level $nextLevel',
        );
      } on Exception catch (e) {
        throw CollectionException(e.toString().replaceFirst('Exception: ', ''));
      }
      final existing =
          await (db.select(db.facilityLevels)..where(
                (f) =>
                    f.clubId.equals(club.id) & f.facility.equals(facility.name),
              ))
              .getSingleOrNull();
      if (existing == null) {
        await db
            .into(db.facilityLevels)
            .insert(
              FacilityLevelsCompanion.insert(
                clubId: club.id,
                facility: facility.name,
                level: Value(nextLevel),
                upgradedAt: Value(now),
              ),
            );
      } else {
        await (db.update(
          db.facilityLevels,
        )..where((f) => f.id.equals(existing.id))).write(
          FacilityLevelsCompanion(
            level: Value(nextLevel),
            upgradedAt: Value(now),
          ),
        );
      }
    });
    return nextLevel;
  }

  /// Applies a finished match (GDD 11 recovery + 17.6 rewards, FR-016):
  /// stamina recovery with the optional pep talk bonus, the reward credit
  /// and its ledger row — all in one transaction. Bench players who did
  /// not come on keep their stamina untouched.
  Future<void> applyMatchResult({
    required int clubId,
    required int rewardCoins,
    required List<({int ownedId, double stamina, int minutesPlayed})> players,
    PepTalk? pepTalk,
    int restDays = 3,
    bool adBoostedRecovery = false,
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final staminaConfig = const StaminaConfig();
    final adEngine = const AdEngine();
    // Campus recovery centre (GDD 3.5/11.5): its bonus is added to the
    // natural recovery of every player who featured — one decimal of
    // design space the manager invests in across seasons.
    final campus = await getCampus();
    final campusRecoveryBonus = campus.recoveryBonusPercent;
    // GDD 19.3 'Daily reward multiplier': rewards earned today are boosted
    // while a daily-multiplier ad was watched (no consumption — it lasts
    // the whole day it was granted).
    final ads = adStore;
    var reward = rewardCoins;
    if (ads != null && rewardCoins > 0) {
      final club = await (db.select(
        db.clubs,
      )..where((c) => c.id.equals(clubId))).getSingleOrNull();
      if (club != null &&
          await ads.dailyMultiplierActive(club.id, now: timestamp)) {
        reward = adEngine.boostedMatchReward(rewardCoins);
      }
    }
    await db.transaction(() async {
      for (final p in players) {
        final row = await (db.select(
          db.ownedPlayers,
        )..where((o) => o.id.equals(p.ownedId))).getSingleOrNull();
        if (row == null) continue;
        var next = row.staminaPercent.toDouble();
        if (p.minutesPlayed > 0) {
          final afterNatural = recoverStamina(
            config: staminaConfig,
            currentStamina: p.stamina,
            minutesPlayed: p.minutesPlayed,
            restDays: restDays,
            campusRecoveryBonus: campusRecoveryBonus,
          );
          if (adBoostedRecovery) {
            // Ad-supported boosted recovery (GDD 19.3): +15% natural
            // recovery for eligible players. Mutually exclusive with a
            // pep talk on the same transaction (GDD 19.4).
            next = adEngine.boostedRecovery(
              staminaAfterNaturalRecovery: afterNatural,
              naturalRecovery: afterNatural - p.stamina,
            );
          } else if (pepTalk != null) {
            next = applyPepTalkBonus(
              pepTalk: pepTalk,
              currentStamina: p.stamina,
              naturalRecovery: afterNatural - p.stamina,
              staminaAfterNaturalRecovery: afterNatural,
              minutesPlayed: p.minutesPlayed,
            );
          } else {
            next = afterNatural;
          }
        } else {
          // Players who missed the match still REST: the same natural
          // recovery minus the workload, applied to their current
          // condition. They used to be frozen at their old stamina
          // forever — benched and reserve players never healed between
          // fixtures, which made the squad's condition one-way ratchet.
          next = recoverStamina(
            config: staminaConfig,
            currentStamina: next,
            minutesPlayed: 0,
            restDays: restDays,
            campusRecoveryBonus: campusRecoveryBonus,
          );
        }
        await (db.update(
          db.ownedPlayers,
        )..where((o) => o.id.equals(p.ownedId))).write(
          OwnedPlayersCompanion(
            staminaPercent: Value(next.round().clamp(0, 100)),
          ),
        );
      }
      if (reward > 0) {
        // Relative credit — a concurrent coin movement (the user buying
        // a pack while the match resolves) can no longer be overwritten
        // by this reward (see coin_ops.dart).
        await db.customUpdate(
          'UPDATE clubs SET coins = coins + ? WHERE id = ?',
          variables: [Variable.withInt(reward), Variable.withInt(clubId)],
          updates: {db.clubs},
          updateKind: UpdateKind.update,
        );
        await db.coinLedger(
          clubId,
          reward,
          reason: 'match_reward',
          detail:
              'Match reward for ${players.length} squad players'
              '${reward != rewardCoins ? ' (ad daily multiplier)' : ''}',
        );
      }
    });
  }

  /// Adapts a persisted player row to the domain model.
  BasePlayer _toBasePlayer(Player row) => BasePlayer(
    playerId: row.playerId,
    name: row.name,
    position: Position.fromCode(row.position),
    nationality: row.nationality,
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
  ///
  /// Kept for call sites that update the balance inside their own larger
  /// transaction (e.g. applyMatchResult's stamina writes share it); new
  /// coin movements should prefer [CoinOps.spendCoins]/[CoinOps.creditCoins]
  /// which are relative and race-free.
  Future<void> coinLedger(
    int clubId,
    int amount, {
    required String reason,
    String? detail,
  }) async {
    final club = await (select(
      clubs,
    )..where((c) => c.id.equals(clubId))).getSingle();
    await into(coinTransactions).insert(
      CoinTransactionsCompanion.insert(
        clubId: clubId,
        amount: amount,
        balanceAfter: club.coins,
        reason: reason,
        detail: Value(detail),
        createdAt: DateTime.now(),
      ),
    );
  }
}
