/// FCM Rivals — collection store (GDD 5/8/17, FR-012..FR-016).
///
/// Orchestrates the engines over the Drift database: club creation with the
/// 22 starting packs (two per formation slot), pack opening, selling,
/// duplicate merging, and dataset updates with removed-player compensation.
/// Every coin movement runs in a database transaction and writes a ledger
/// row (FR-016, NFR-003).
///
/// Pure domain logic stays in the engines; this class only coordinates
/// persistence and transactions (SRS 21.1 / NFR-006).
library;

import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../core/domain/crest.dart';
import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;

import '../../core/database/app_database.dart';
import '../../core/database/coin_ops.dart';
import '../../core/domain/players.dart';
import '../ads/ad_engine.dart';
import '../ads/ad_store.dart';
import '../economy/economy_engine.dart';
import '../facilities/facilities.dart';
import '../match/stamina.dart'
    show StaminaConfig, recoverStamina;
import '../match/tactics.dart' show TeamTactics;
import '../packs/pack_engine.dart';
import '../packs/pack_rarity.dart';
import 'collection_results.dart';
import 'pack_catalog.dart';

export 'collection_results.dart';
import '../player_database/player_database.dart';
import '../squad/formations.dart';
import '../squad/squad_engine.dart';
import 'campus_store.dart';
import 'club_store.dart';
import 'squad_store.dart';
import '../upgrades/upgrade_engine.dart';

part 'collection_store_dataset.dart';
part 'collection_store_internals.dart';

part 'collection_store_match.dart';
class CollectionStore {
  CollectionStore({
    required this.db,
    this.economy = const EconomyEngine(),
    this.upgrades = const UpgradeEngine(),
    this.squad = const SquadEngine(),
    this.adStore,
    this.enforceSquadCapacity = true,
  })  : _club = ClubStore(db: db),
        _squadStore = SquadStore(db: db, squad: squad),
        _campus = CampusStore(db: db);

  final AppDatabase db;
  final EconomyEngine economy;
  final UpgradeEngine upgrades;
  final SquadEngine squad;

  /// Focused stores this facade composes (app-structure review Task 2):
  /// same database instance, same engines — single-purpose homes for
  /// club, squad and campus concerns.
  final ClubStore _club;
  final SquadStore _squadStore;
  final CampusStore _campus;

  /// Rewarded-ad store for the economy ad surfaces (GDD 19.3 'Other
  /// Proposed'): upgrade discount, selling bonus, daily reward
  /// multiplier. Optional — when absent, all ad boosts are simply
  /// inactive and the coin paths charge full price.
  final AdStore? adStore;

  /// Whether packs are refused once the club owns as many distinct
  /// players as it has slots (see [getSquadCapacity]). On in the app;
  /// the economy simulator turns it off because it measures the raw
  /// pack economy, not a player who also manages slots.
  final bool enforceSquadCapacity;

  /// Ledger reason of a slot purchase. The number of such rows IS the
  /// number of blocks bought — the append-only ledger doubles as the
  /// record, so no schema change is needed.
  static const String squadSlotsLedgerReason = 'squad_slots_purchase';

  /// Packs draw from the in-memory registry mirrored into SQLite; kept in
  /// sync by [applyDatasetUpdate] and lazily loaded on first use.
  final PlayerDatabase _registry = PlayerDatabase();
  bool _registryLoaded = false;

  /// Long-lived pack engine (perf pass 2026-11-12): its `_poolCache` is
  /// keyed by pool IDENTITY, so a fresh engine per call — what
  /// [openPack]/[buyPack]/`storeOffersFor` used to build — made every
  /// open, buy and shelf offer re-filter and re-sort the full 40k-player
  /// registry. One engine + one stored pool snapshot (below) keeps the
  /// cache hot: the first call per scope pays the build, the rest hit.
  PackEngine? _packEngine;

  /// The pool list handed to the engine — the SAME instance every call
  /// so the identity-keyed cache recognises it. Rebuilt only when the
  /// registry actually changes ([applyDatasetUpdate] bumps the epoch).
  List<BasePlayer> _packPool = const [];
  int _poolEpoch = 0;

  PackEngine _engineFor() {
    // Registry must be warm: `_ensureRegistry` sets _registryLoaded; the
    // pool snapshot is rebuilt whenever the epoch moves.
    assert(
      _registryLoaded,
      'call _ensureRegistry() before _engineFor()',
    );
    final engine = _packEngine;
    if (engine != null && _poolEpoch == _poolEpochBuilt) return engine;
    _packPool = _registry.all.toList(growable: false);
    _poolEpochBuilt = _poolEpoch;
    return _packEngine = PackEngine(economy: economy);
  }

  /// Bumped by dataset imports so the cached engine's pool snapshot (and
  /// its band caches) are rebuilt over the new registry contents.
  void _invalidatePackCache() => _poolEpoch++;
  int _poolEpochBuilt = -1;

  /// DEBUG-ONLY draw override (debug tool request 2026-11-12, removed
  /// before release): when set, [openPack] draws EXACTLY this player
  /// instead of rolling the two-stage odds — the packs debug picker
  /// (packs_screen.dart, `kDebugMode` gated) sets it so the chosen
  /// player is the one revealed, including every OPEN ANOTHER in a
  /// chain. Null (the release state — the field never exists outside
  /// debug builds' code paths) keeps the real odds. The override does
  /// NOT bypass the pack's own gating: the player must be in the pack's
  /// pool and the club must have room, exactly like a real draw, so
  /// the debug tool can never plant an impossible card.
  BasePlayer? debugDrawOverride;

  /// DEBUG-ONLY (removed before release, see [debugDrawOverride]):
  /// warms the registry so the debug picker's pool read is warm.
  Future<void> debugWarmRegistry() async {
    assert(kDebugMode, 'debug-only API');
    await _ensureRegistry();
  }

  /// DEBUG-ONLY (removed before release, see [debugDrawOverride]):
  /// the pack pool the debug picker searches — the same list instance
  /// the engine draws from.
  List<BasePlayer> debugPackPool() {
    assert(kDebugMode, 'debug-only API');
    if (_packPool.isEmpty && _registryLoaded) {
      _packPool = _registry.all.toList(growable: false);
    }
    return _packPool;
  }

  static const int startingPacksPerPosition = 2;

  /// Positions whose packs are the cheapest in the store — kept for the
  /// store's own context; the starting packs now follow the chosen
  /// formation instead (2 packs per slot position).
  static const int freeStartingPositionCount = 4;

  /// The [freeStartingPositionCount] positions with the cheapest store
  /// packs, derived from the current dataset's Bronze-tier position-pack
  /// prices (cheapest pools first, ties by pool size).
  Future<List<Position>> cheapestPackPositions() async {
    await _ensureRegistry();
    final engine = _engineFor();
    final pool = _packPool;
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
    CrestSpec? crest,
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
              // T-0097: the composed identity serializes into the new
              // column; null keeps today's bare crestIndex path.
              crest: crest == null ? const Value.absent() : Value(crest.encode()),
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

  // ---------------------------------------------------------------------------
  // Packs
  // ---------------------------------------------------------------------------

  /// Opens one owned pack: draws one player and persists it as an
  /// owned instance atomically with the pack's consumption (FR-010, NFR-003).
  Future<PackOpenResult> openPack({
    required int packId,
    required math.Random random,
  }) async {
    await _ensureRegistry();
    final pack = await (db.select(
      db.packs,
    )..where((p) => p.id.equals(packId))).getSingleOrNull();
    if (pack == null || pack.opened) {
      throw const CollectionException('Pack not available');
    }
    await _requireSquadRoom(pack.clubId);

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
    final engine = _engineFor();
    // DEBUG-ONLY draw override (debug tool request 2026-11-12, removed
    // before release): the packs debug picker chose this player — draw
    // him directly instead of rolling. The tier the reveal celebrates
    // is the player's OWN band (never a rolled one — the reveal card
    // colour and the odds display must agree with what is on screen).
    // The override respects the pack's scope: an ineligible pick (e.g.
    // a GK in a ST pack) falls through to the REAL roll, so the debug
    // tool cannot plant a card the pack could never contain.
    var draws = const <PackDraw>[];
    if (debugDrawOverride case final chosen?) {
      if (scope.matches(chosen)) {
        draws = [
          PackDraw(
            player: chosen,
            tier: chosen.isIcon
                ? kIconBandIndex
                : PackRarity.fromOverall(
                    chosen.baseStats.overall,
                    config: engine.oddsConfig,
                  ).index,
          ),
        ];
      }
    }
    if (draws.isEmpty) {
      draws = engine.open(scope, _packPool, random: random);
    }
    if (draws.isEmpty) {
      throw const CollectionException('No eligible players for this pack');
    }

    final now = DateTime.now();
    // T-0091: which draws are first-time players — the club's owned
    // playerIds BEFORE this open, read once so every draw judges
    // against the same pre-open state.
    final preOwnedIds = await _ownedPlayerIds(pack.clubId);
    final newFlags = computeNewFlags(
      [for (final d in draws) d.player.playerId],
      preOwnedIds,
    );
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
      newFlags: newFlags,
    );
  }

  /// The owned (status 'owned') playerIds of [clubId] — the pre-open
  /// state the T-0091 new-flags judge against.
  /// T-0091: the per-draw NEW decision, pure and side-effect free so
  /// the same-pack duplicate leg is directly unit-testable (review 1):
  /// a draw is first-time only when its playerId is NOT in the club's
  /// pre-open owned set AND was not drawn earlier in this same open.
  /// [drawnPlayerIds] is index-aligned with the returned flags.
  @visibleForTesting
  static List<bool> computeNewFlags(
    List<int> drawnPlayerIds,
    Set<int> preOwnedIds,
  ) {
    final seenThisPack = <int>{};
    return [
      for (final id in drawnPlayerIds)
        () {
          final firstTime =
              !preOwnedIds.contains(id) && !seenThisPack.contains(id);
          seenThisPack.add(id);
          return firstTime;
        }(),
    ];
  }

  Future<Set<int>> _ownedPlayerIds(int clubId) async {
    final rows = await (
      db.selectOnly(db.ownedPlayers)
            ..addColumns([db.ownedPlayers.playerId])
            ..where(
              db.ownedPlayers.clubId.equals(clubId) &
                  db.ownedPlayers.status.equals('owned'),
            )
        ).get();
    return {for (final r in rows) r.read(db.ownedPlayers.playerId)!};
  }

  /// Every player a pack of this scope could draw, best overall first —
  /// the contents list behind tapping a store cell (no stats shown there,
  /// just the rating ladder).
  Future<List<BasePlayer>> getPackPlayers({
    required PackCategory category,
    String? scopeValue,
    required PackTier tier,
  }) async {
    await _ensureRegistry();
    // Build/refresh the shared pool snapshot first (see _engineFor) —
    // reading _packPool without this would see the pre-seed empty list
    // when this is the first engine-adjacent call of the session.
    _engineFor();
    final scope = PackScope(
      category: category,
      position: category == PackCategory.position && scopeValue != null
          ? Position.fromCode(scopeValue)
          : null,
      tier: tier,
    );
    // Perf pass 2026-11-12: this feeds the pack-contents screen (rating
    // ladder over the full eligible pool). Filter the STOREED pool
    // snapshot (one list identity, no full-registry copies) and sort the
    // narrowed result — same output as before, no per-call 40k re-copy.
    final eligible =
        _packPool.where(scope.matches).toList(growable: false);
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
  Future<List<StorePackOffer>> getStoreOffers() async {
    await _ensureRegistry();
    // Perf pass 2026-11-12: inject the long-lived engine + stored pool so
    // the ~39 shelf offers share one hot band cache (see _engineFor).
    return storeOffersFor(
      _registry,
      economy,
      engine: _engineFor(),
      pool: _packPool,
    );
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
    // A pack that cannot be opened must not be sold either.
    await _requireSquadRoom(userClub.id);
    await _ensureRegistry();
    final scope = PackScope(
      category: category,
      nationality: nationality,
      position: position,
      tier: tier,
    );
    // A pack draws exactly one player — an empty eligible pool must be
    // rejected here, before any price is quoted.
    if (!_packPool.any(scope.matches)) {
      throw const CollectionException('Not enough eligible players');
    }
    final engine = _engineFor();
    final price = engine.packPriceFor(scope, _packPool);
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
      } on InsufficientFundsException {
        throw const CollectionException('Not enough coins');
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
  // Squad capacity
  // ---------------------------------------------------------------------------

  /// Blocks of extra slots the club has bought: one ledger row each.
  Future<int> _squadSlotBlocks(int clubId) async {
    final count = db.coinTransactions.id.count();
    final row =
        await (db.selectOnly(db.coinTransactions)
              ..addColumns([count])
              ..where(
                db.coinTransactions.clubId.equals(clubId) &
                    db.coinTransactions.reason.equals(squadSlotsLedgerReason),
              ))
            .getSingle();
    return row.read(count) ?? 0;
  }

  Future<SquadCapacity> _squadCapacityOf(int clubId) async {
    final blocks = await _squadSlotBlocks(clubId);
    // Distinct players: extra copies of one player count once.
    final owned = (await _ownedPlayerIds(clubId)).length;
    return SquadCapacity(
      owned: owned,
      capacity: economy.squadCapacity(blocks),
      blocksBought: blocks,
      nextBlockSlots: economy.config.squadSlotsPerPurchase,
      nextBlockPrice: economy.squadSlotBlockPrice(blocks),
    );
  }

  /// The club's squad capacity: distinct players owned vs. slots, and
  /// the price of the next block. Before a club exists it reads as an
  /// empty club with the base capacity.
  Future<SquadCapacity> getSquadCapacity() async {
    final club = await getClub();
    if (club == null) {
      return SquadCapacity(
        owned: 0,
        capacity: economy.squadCapacity(0),
        blocksBought: 0,
        nextBlockSlots: economy.config.squadSlotsPerPurchase,
        nextBlockPrice: economy.squadSlotBlockPrice(0),
      );
    }
    return _squadCapacityOf(club.id);
  }

  /// Refuses a pack buy / open when every slot is taken by a distinct
  /// player (a pack adds at most one new player, so the count can never
  /// pass the capacity).
  Future<void> _requireSquadRoom(int clubId) async {
    if (!enforceSquadCapacity) return;
    final cap = await _squadCapacityOf(clubId);
    if (cap.isFull) {
      throw CollectionException(
        'Your squad is full (${cap.owned}/${cap.capacity} players) — '
        'buy more slots on the Team tab.',
      );
    }
  }

  /// Buys the next block of squad slots with Coins: the price comes from
  /// the Economy Engine and rises with every block already bought. The
  /// debit and its ledger row (which is what counts the block) are one
  /// atomic step. Returns the new capacity.
  Future<SquadCapacity> buySquadSlots() async {
    final club = await getClub();
    if (club == null) {
      throw const CollectionException('No club');
    }
    await db.transaction(() async {
      // Re-read inside the transaction so the price always matches the
      // number of blocks really bought.
      final before = await _squadCapacityOf(club.id);
      try {
        await db.spendCoins(
          club.id,
          before.nextBlockPrice,
          reason: squadSlotsLedgerReason,
          detail:
              'Bought ${before.nextBlockSlots} squad slots '
              '(${before.capacity} -> '
              '${before.capacity + before.nextBlockSlots})',
        );
      } on InsufficientFundsException {
        throw const CollectionException('Not enough coins');
      }
    });
    return _squadCapacityOf(club.id);
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
          clubId: base.clubId,
          clubName: base.clubName,
          clubCrestUrl: base.clubCrestUrl,
          leagueName: base.leagueName,
          leagueLogoUrl: base.leagueLogoUrl,
          imageUrl: base.imageUrl,
          isIcon: base.isIcon,
          baseStats: BaseStats(
            overall: base.overall,
            attack: base.attack,
            support: base.support,
            defence: base.defence,
            goalkeeping: base.goalkeeping,
          ),
        ),
        upgradeLevel: owned.upgradeLevel,
        staminaPercent: owned.staminaPercent,
        injuryMatchesRemaining: owned.injuryMatchesRemaining ?? 0,
        injuryKind: owned.injuryKind,
      );
    }).get();
    rows.sort((a, b) => b.overall.compareTo(a.overall));
    return rows;
  }

  /// The dataset player behind an ENGINE player id — the live GOAL moment
  /// uses it to show the scorer's real portrait, rating and club logo.
  ///
  /// The engine's `MatchPlayer.playerId` is not the dataset id: the user's
  /// players carry their owned-card row id (>= 0, [OwnedPlayers.id]) and a
  /// league opponent's carry `-10000 - AiPlayers.id`, which points at the
  /// real dataset player through [AiPlayers.realPlayerId]. Synthetic
  /// friendly opponents (-1000 - slot) and fallback AI rows have no dataset
  /// player, so they return null; never throws for a missing row.
  Future<BasePlayer?> getBasePlayerForMatchPlayer(int matchPlayerId) async {
    int? datasetId;
    if (matchPlayerId >= 0) {
      final owned = await (db.select(
        db.ownedPlayers,
      )..where((o) => o.id.equals(matchPlayerId))).getSingleOrNull();
      datasetId = owned?.playerId;
    } else {
      final aiRowId = -10000 - matchPlayerId;
      if (aiRowId > 0) {
        final ai = await (db.select(
          db.aiPlayers,
        )..where((p) => p.id.equals(aiRowId))).getSingleOrNull();
        datasetId = ai?.realPlayerId;
      }
    }
    if (datasetId == null) return null;
    final row = await (db.select(
      db.players,
    )..where((p) => p.playerId.equals(datasetId!))).getSingleOrNull();
    return row == null ? null : _toBasePlayer(row);
  }

  /// Sells owned copies (FR-013): upgraded pricing applies per copy; the
  /// credit and status change share one transaction. Squad members are
  /// refused — the Team tab's full-card view sells those through
  /// [sellPlayerFromSquad] instead.
  Future<SaleResult> sellPlayers(List<int> ownedIds) async {
    if (ownedIds.isEmpty) {
      throw const CollectionException('Nothing to sell');
    }
    final club = await getClub();
    if (club == null) {
      throw const CollectionException('No club');
    }

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
    }

    return _sellCopies(club, ownedIds);
  }

  /// Squad-aware sell for the Team tab's full-card view (T-0090): an XI
  /// card's slot is cleared and auto re-picked INSIDE the sale's own
  /// transaction — the replacement, not the man being sold, takes the
  /// slot (the mergeDuplicates pattern; GDD 6.4 invariant: every XI
  /// slot stays filled). A bench/reserve card just sells (its slot is
  /// freed by the sale itself). The ad selling-bonus still applies.
  Future<SaleResult> sellPlayerFromSquad(int ownedId) async {
    final club = await getClub();
    if (club == null) {
      throw const CollectionException('No club');
    }

    final copy =
        await (db.select(db.ownedPlayers)
              ..where((o) => o.id.equals(ownedId) & o.status.equals('owned')))
            .getSingleOrNull();
    if (copy == null) {
      throw const CollectionException('Nothing to sell');
    }

    return db.transaction(() async {
      // Re-pick BEFORE the sale: the sold copy must not be re-picked
      // back into the XI he is about to leave.
      if (copy.squadSlot != null &&
          copy.squadSlot! < Formation.startingXiSize) {
        final cards = await getCollection();
        final formation = formationByCode(club.formationCode);
        final others = cards
            .where((c) => c.ownedId != ownedId)
            .toList(growable: false);
        final assignment = squad.autoPick(others, formation);
        // GDD 6.4, the squad_swap rule: the starting XI can never be
        // left with a hole. When no replacement can cover the freed
        // slot (an exactly-11 club, or an all-injured remainder) the
        // sale is REFUSED inside the transaction — nothing sold, coins
        // untouched, the ledger unwritten; the whole transaction rolls
        // back. autoPick fills slots in ascending order, so an
        // 11-strong map means every XI slot 0..10 is covered.
        if (assignment.length < Formation.startingXiSize) {
          throw const CollectionException(
            'Selling would leave the starting XI short',
          );
        }
        await saveSquad(assignment);
      }
      return _sellCopies(club, [ownedId]);
    });
  }

  /// The shared sale transaction (used by [sellPlayers] and
  /// [sellPlayerFromSquad]): prices every owned row, marks it 'sold',
  /// frees its slot and credits the club — the ledger and the coin
  /// balance move in the SAME transaction.
  Future<SaleResult> _sellCopies(Club club, List<int> ownedIds) async {
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
  /// duplicate is consumed and the target gains the levels — every level
  /// is +1% of the base stats via `upgradedValue` (owner decision
  /// 2026-11-09, unlimited). Merging is free — the Economy Engine prices
  /// upgrades when they are purchased with coins, not when merging owned
  /// duplicates.
  Future<MergeResult> mergeDuplicates({
    required int targetOwnedId,
    required int duplicateOwnedId,
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
    // Levels are unlimited (owner decision 2026-11-09): no cap check.
    final outcome = upgrades.merge(
      targetLevel: target.upgradeLevel,
      duplicateLevel: duplicate.upgradeLevel,
    );

    await db.transaction(() async {
      await (db.update(
        db.ownedPlayers,
      )..where((o) => o.id.equals(targetOwnedId))).write(
        OwnedPlayersCompanion(
          upgradeLevel: Value(outcome.newUpgradeLevel),
          // Legacy pre-2026-11-09 columns: zeroed on every write; the
          // gameplay math derives from upgradeLevel alone.
          upgradedAttack: const Value(0),
          upgradedSupport: const Value(0),
          upgradedDefence: const Value(0),
          upgradedGoalkeeping: const Value(0),
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
    );
  }

  // ---------------------------------------------------------------------------
  // Squad
  // ---------------------------------------------------------------------------

  /// Squad assignments currently persisted: slot → card. Iterates in
  /// slot order — the order Auto Pick writes (bench then reserves
  // ---------------------------------------------------------------------------
  // Campus facilities (GDD 3.5)
  // ---------------------------------------------------------------------------

  /// Current facility levels of the user's club (missing rows = 0).
  /// not come on keep their stamina untouched.

  /// Resolves a club row's crest spec (T-0097): the new `crest`
  /// column when it parses, else the legacy `crestIndex` mapping —
  /// every consumer resolves old-vs-new in this one place.
  static CrestSpec crestOf(Club club) =>
      CrestSpec.fromJsonString(club.crest) ?? CrestSpec.legacy(club.crestIndex);

  // --- Club / squad / campus: delegated to the focused stores ----------
  // (the bodies live in club_store.dart, squad_store.dart and
  // campus_store.dart; these members are the compatibility facade)

  Future<Club?> getClub() => _club.getClub();
  Stream<Club?> watchClub() => _club.watchClub();
  Future<void> grantTestCoins({int amount = 1_000_000}) =>
      _club.grantTestCoins(amount: amount);

  /// Ledger row for coin movements inside a caller-owned transaction
  /// (the CoinOps helpers cover the stand-alone cases).
  Future<void> coinLedger(
    int clubId,
    int amount, {
    required String reason,
    String? detail,
  }) =>
      _club.coinLedger(clubId, amount, reason: reason, detail: detail);

  Future<Map<int, PlayerCard>> getSquad() => _squadStore.getSquad();
  Future<void> saveSquad(Map<int, int> assignments) =>
      _squadStore.saveSquad(assignments);
  Future<Map<int, int>> autoPickSquad({
    bool excludeInjured = true,
    bool naturalOnly = false,
  }) => _squadStore.autoPickSquad(
    excludeInjured: excludeInjured,
    naturalOnly: naturalOnly,
  );
  Future<void> changeFormation(String formationCode) =>
      _squadStore.changeFormation(formationCode);
  Future<void> changeTactics({
    String? formationCode,
    TeamTactics? tactics,
    String? mentality,
  }) =>
      _squadStore.changeTactics(
        formationCode: formationCode,
        tactics: tactics,
        mentality: mentality,
      );

  Future<CampusLevels> getCampus() => _campus.getCampus();
  Future<int> upgradeFacility(
    Facility facility, {
    FacilitiesCosts costs = defaultFacilitiesCosts,
  }) =>
      _campus.upgradeFacility(facility, costs: costs);
}
