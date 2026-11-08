/// FCM Rivals — Pack Engine (GDD 5, FR-009..FR-011).
///
/// The owner's two-stage draw (T-0059): stage 1 rolls a rarity from the
/// pack tier's configured table ([PackOddsConfig] — RARE pack 75/20/5/0,
/// EPIC 40/50/10/0, LEGENDARY 0/55/43/2); stage 2 selects one player
/// inside the rolled rarity's pool weighted by `(poolMinMv / mv)^exponent`
/// ([weightFor]) — cheap players likelier, the band's stars reachable but
/// rare. Rarity is derived from OVR, never stored: rare < 70, epic 70-79,
/// legendary 80-89, premium 90+. Premium is exclusive to Legendary packs
/// (the rare and epic tables carry 0.0). Scopes filter the eligible pool:
/// Global, Nationality and Position packs. Prices re-derive automatically
/// from the two-stage EV — no pricing code of its own.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart' show Color;

import '../../core/domain/players.dart';
import '../economy/economy_engine.dart';
import 'pack_rarity.dart';

/// The pack categories (GDD 5.2). League and Club packs are gone — the
/// player core data no longer carries club or league affiliation.
enum PackCategory {
  global('Global Pack'),
  nationality('Nationality Pack'),
  position('Position Pack');

  const PackCategory(this.label);
  final String label;
}

/// Store pack rarities, named after the player-card rarities they bias
/// toward. The tier no longer carries odds of its own (the T-0047
/// low/mid/high MV weights are gone): its name selects one row of
/// [PackOddsConfig]'s four-band matrix, and its price re-derives from the
/// two-stage expected contents — better odds cost proportionally more
/// Coins.
enum PackTier {
  rare('Rare'),
  epic('Epic'),
  legendary('Legendary');

  const PackTier(this.label);
  final String label;

  /// Parses a persisted tier name. Rows written before the rarity
  /// renaming stored the medal metals ('bronze'/'silver'/'gold'); they
  /// map onto the same tiers. Unknown values fall back to rare.
  static PackTier fromName(String? name) => switch (name) {
    'epic' || 'silver' => PackTier.epic,
    'legendary' || 'gold' => PackTier.legendary,
    _ => PackTier.rare, // 'rare', legacy 'bronze', anything else
  };
}

/// Pack-rarity accent colours — the same jewel palette as the player-card
/// rarities ([CardRarity.accent]): rare → royal amethyst, epic → royal
/// sapphire, legendary → radiant champion gold. Cells, badges and foils
/// draw from these so a pack's rarity reads at a glance and matches the
/// cards it draws.
extension PackTierColor on PackTier {
  Color get accent => switch (this) {
    PackTier.rare => const Color(0xFF8B5CF6),
    PackTier.epic => const Color(0xFF3B82F6),
    PackTier.legendary => const Color(0xFFF7C948),
  };

  /// Rarity stars stamped on the foil: rare 3, epic 4, legendary 5 —
  /// the shelf and the reveal agree on the count.
  int get stars => switch (this) {
    PackTier.rare => 3,
    PackTier.epic => 4,
    PackTier.legendary => 5,
  };
}

/// Filter describing which players a pack draws from.
class PackScope {
  const PackScope({
    required this.category,
    this.nationality,
    this.position,
    this.tier,
  });

  final PackCategory category;
  final String? nationality;
  final Position? position;

  /// Store tier of the pack (GDD 5.5 variety); null keeps the engine's
  /// constructor-configured tier (backwards compatibility).
  final PackTier? tier;

  /// The tier whose [PackOddsConfig] table this scope rolls: its own, or
  /// the engine's configured default.
  PackTier rollTier(PackEngine engine) => tier ?? engine.tier;

  bool matches(BasePlayer p) {
    switch (category) {
      case PackCategory.global:
        return true;
      case PackCategory.nationality:
        return nationality != null && p.nationality == nationality;
      case PackCategory.position:
        return position != null && p.position == position;
    }
  }

  /// Scopes are value objects: two scopes describing the same filter hit
  /// the same per-pool draw-cache entry.
  @override
  bool operator ==(Object other) =>
      other is PackScope &&
      other.category == category &&
      other.nationality == nationality &&
      other.position == position &&
      other.tier == tier;

  @override
  int get hashCode => Object.hash(category, nationality, position, tier);
}

/// One drawn player with the rarity band he was drawn under.
class PackDraw {
  const PackDraw({required this.player, required this.tier});

  final BasePlayer player;

  /// The ROLLED rarity's [PackRarity] index: 0 rare (< 70), 1 epic
  /// (70-79), 2 legendary (80-89), 3 premium (90+). A fallback draw from
  /// a neighbouring non-empty pool still reports the rolled band's index
  /// — the same band the odds display and EV booked the pull under.
  final int tier;
}

/// Cached per-pool draw structure for ONE rarity band: the value-sorted
/// eligible players of that band with their stage-2 weights
/// ([weightFor], `(poolMinMv / mv)^exponent`), weight total and cumulative
/// distribution. Built once per (pool, scope, exponent), then reused by
/// [PackEngine.open], [PackEngine.oddsFor] and
/// [PackEngine.expectedPackValue] — the store shelf, odds sheet and a
/// streak of opens over the same pool no longer re-filter, re-sort and
/// re-weight thousands of players per call.
class _PoolDrawInfo {
  _PoolDrawInfo({
    required this.players,
    required this.weights,
    required this.total,
    required this.cumulative,
  });

  /// The band's eligible players, cheapest first.
  final List<BasePlayer> players;

  /// Per-player stage-2 weight, same order as [players].
  final List<double> weights;

  /// Sum of [weights].
  final double total;

  /// `cumulative[i]` is the summed weight up to and including index `i`.
  /// Used by the binary-search draw.
  final List<double> cumulative;
}

/// Cache key: the pool instance (identity), the scope (value equality)
/// and the stage-2 exponent that produced the structures. The engine
/// instance owns the cache, so constructor configuration (odds tables,
/// exponent, economy) is fixed per key.
class _CacheKey {
  const _CacheKey(this.pool, this.scope, this.exponent);

  final List<BasePlayer> pool;
  final PackScope scope;
  final double exponent;

  @override
  bool operator ==(Object other) =>
      other is _CacheKey &&
      identical(other.pool, pool) &&
      other.scope == scope &&
      other.exponent == exponent;

  @override
  int get hashCode => Object.hash(identityHashCode(pool), scope, exponent);
}

/// Draws packs from an eligible pool with the owner's two-stage rarity
/// engine: rarity first (config table), then a value-weighted player
/// inside the rolled band's pool.
class PackEngine {
  /// Owner regrade rule (T-0047): OVR 80 is the golden legendary cut
  /// (`CardRarity.fromOverall`). Kept beside the odds config so the pack
  /// band and the card colour can never drift apart silently — the audit
  /// test binds [PackOddsConfig.legendaryMinOverall] to it.
  static const int legendaryOverall = 80;

  PackEngine({
    this.tier = PackTier.rare,
    required this.random,
    this.economy = const EconomyEngine(),
    this.oddsConfig = defaultPackOddsConfig,
  }) {
    // Release-safe validation of the odds tables (asserts are stripped in
    // release builds) — a bad table fails fast, never draws.
    oddsConfig.validate();
  }

  /// The engine's default store tier for scopes that carry none.
  final PackTier tier;

  /// Shared RNG — callers inject a seeded generator for deterministic tests.
  final math.Random random;

  final EconomyEngine economy;

  /// The four-band odds configuration (T-0058): per-tier rarity tables,
  /// the OVR cut points and the stage-2 weighting exponent.
  final PackOddsConfig oddsConfig;

  /// Cached per-pool draw structures, keyed by pool identity + scope +
  /// exponent. Pools in this game are loaded once and handed around as
  /// the same instance, so identity is the right key; the cached weights
  /// depend only on immutable player values, so they never go stale. The
  /// map is cleared once it exceeds [_maxCachedEntries] distinct
  /// (pool, scope, exponent) combinations, keeping memory bounded — the
  /// store shelf's few dozen scopes rebuild in microseconds anyway.
  static const _maxCachedEntries = 32;

  final Map<_CacheKey, List<_PoolDrawInfo?>> _poolCache = {};

  /// Returns the four rarity-band draw infos for [scope] over [pool]
  /// (index = [PackRarity] index; null = empty band), building and
  /// caching them on first use.
  List<_PoolDrawInfo?> _poolsFor(PackScope scope, List<BasePlayer> pool) {
    final exponent = oddsConfig.marketValueExponent;
    if (_poolCache.length >= _maxCachedEntries) _poolCache.clear();
    return _poolCache.putIfAbsent(
      _CacheKey(pool, scope, exponent),
      () => _buildPools(scope, pool, exponent),
    );
  }

  /// Computes the uncached draw infos: filter by scope, partition by the
  /// OVR bands, sort each band by value, then weight each player.
  List<_PoolDrawInfo?> _buildPools(
    PackScope scope,
    List<BasePlayer> pool,
    double exponent,
  ) {
    final eligible = pool.where(scope.matches).toList()..sort(_byValue);
    final bands = <List<BasePlayer>>[
      for (final _ in PackRarity.values) <BasePlayer>[],
    ];
    for (final p in eligible) {
      bands[PackRarity.fromOverall(
        p.baseStats.overall,
        config: oddsConfig,
      ).index].add(p);
    }
    return [
      for (final band in bands) band.isEmpty ? null : _weightBand(band, exponent),
    ];
  }

  /// Weights one non-empty band: `(poolMinMv / mv)^exponent` per player
  /// ([weightFor]), cumulative sums for the binary-search draw.
  ///
  /// Guard (requirement 4): [weightFor] already clamps mv ≤ 0 and a
  /// non-positive pool floor, so every weight is finite and > 0 — but the
  /// normalization sum is still guarded: should it ever degrade to 0 or
  /// non-finite (pathological exponent, absurd magnitudes), the band
  /// falls back to UNIFORM weights instead of producing NaN rolls or a
  /// zero-weight total.
  _PoolDrawInfo _weightBand(List<BasePlayer> band, double exponent) {
    final poolMinMv = band.first.marketValueEur; // cheapest first
    final weights = [
      for (final p in band)
        weightFor(
          marketValueEur: p.marketValueEur,
          poolMinMarketValueEur: poolMinMv,
          exponent: exponent,
        ),
    ];
    var sum = 0.0;
    final cumulative = <double>[];
    for (final w in weights) {
      sum += w;
      cumulative.add(sum);
    }
    if (!(sum > 0 && sum.isFinite)) {
      // Degenerate normalization: draw uniformly among the band's
      // players rather than crash or bias every roll to index 0.
      final uniform = List<double>.filled(band.length, 1.0);
      var u = 0.0;
      final uCum = <double>[];
      for (final w in uniform) {
        u += w;
        uCum.add(u);
      }
      return _PoolDrawInfo(
        players: band,
        weights: uniform,
        total: u,
        cumulative: uCum,
      );
    }
    return _PoolDrawInfo(
      players: band,
      weights: weights,
      total: sum,
      cumulative: cumulative,
    );
  }

  /// Index of the nearest non-empty band when [index] is exhausted, or
  /// -1 when every band is empty. Empty bands are REAL (RM has no
  /// legendary rows, GK no premium rows): the fallback keeps every roll
  /// answerable and books the draw under the rolled band's probability
  /// share — the documented safe-empty answer, never a pool mix.
  int _fallbackIndex(List<_PoolDrawInfo?> pools, int index) {
    if (pools[index] != null) return index;
    for (final delta in const [1, -1, 2, -2, 3, -3]) {
      final i = index + delta;
      if (i >= 0 && i < pools.length && pools[i] != null) return i;
    }
    return -1;
  }

  /// Weighted draw of a single player from [info], using the cached
  /// cumulative distribution and a binary search.
  ///
  /// The search returns the smallest index whose cumulative weight is at
  /// least the roll — exactly the player the original linear
  /// `roll -= weights[i]; if (roll <= 0) return players[i]` scan selected,
  /// including at ties, but in O(log n) instead of O(n). Single-player
  /// bands return their player without consuming RNG, matching the
  /// original scan (the existing single-player contract).
  BasePlayer? _drawFromPool(_PoolDrawInfo info) {
    if (info.players.isEmpty) return null;
    if (info.players.length == 1) return info.players.single;
    final roll = random.nextDouble() * info.total;
    final cum = info.cumulative;
    var lo = 0, hi = cum.length - 1;
    while (lo < hi) {
      final mid = lo + (hi - lo) ~/ 2;
      if (cum[mid] < roll) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return info.players[lo];
  }

  /// Opens a pack: exactly one player, through the owner's exact
  /// two-stage sequence (T-0059). Stage 1 rolls a rarity from the scope's
  /// configured table; stage 2 draws one player from that rarity's pool
  /// with `(poolMinMv / mv)^exponent` weights. Never selects the player
  /// first; never mixes the rarity roll and the MV weighting into one
  /// distribution; never leaves the rolled rarity's pool except through
  /// the documented empty-band fallback. Empty pool returns an empty
  /// draw list. The reported tier is the ROLLED rarity's index, matching
  /// the odds display, which also books fallback draws under the rolled
  /// band's probability share.
  List<PackDraw> open(PackScope scope, List<BasePlayer> pool) {
    final pools = _poolsFor(scope, pool);
    if (pools.every((b) => b == null)) return const [];
    final rarityIndex = _rollRarity(oddsConfig.oddsFor(scope.rollTier(this)));
    final drawIndex = _fallbackIndex(pools, rarityIndex);
    if (drawIndex < 0) return const [];
    final player = _drawFromPool(pools[drawIndex]!);
    if (player == null) return const [];
    return [PackDraw(player: player, tier: rarityIndex)];
  }

  /// Stage 1: rolls which rarity band the pack's single player comes
  /// from, using the tier's configured table ([PackRarity] enum order).
  int _rollRarity(PackRarityOdds odds) {
    final total = odds.rare + odds.epic + odds.legendary + odds.premium;
    var roll = random.nextDouble() * total;
    if ((roll -= odds.rare) <= 0) return PackRarity.rare.index;
    if ((roll -= odds.epic) <= 0) return PackRarity.epic.index;
    if ((roll -= odds.legendary) <= 0) return PackRarity.legendary.index;
    return PackRarity.premium.index;
  }

  /// The per-rarity probability of drawing each eligible player, for the
  /// user-facing odds display (GDD 5.4). Returns one entry per
  /// [PackRarity] index with the summed probability per player in that
  /// band: `P(rarity roll) × P(player | rarity)`. A band whose table
  /// weight is 0 renders empty (never rolled); a rolled band with an
  /// empty pool books its nearest non-empty neighbour's players under
  /// the rolled band's share — exactly what [open] draws.
  Map<int, Map<int, double>> oddsFor(PackScope scope, List<BasePlayer> pool) {
    final pools = _poolsFor(scope, pool);
    final odds = oddsConfig.oddsFor(scope.rollTier(this));
    final total = odds.rare + odds.epic + odds.legendary + odds.premium;
    final shares = [odds.rare, odds.epic, odds.legendary, odds.premium];
    final result = <int, Map<int, double>>{};
    for (var r = 0; r < PackRarity.values.length; r++) {
      final poolIndex = _fallbackIndex(pools, r);
      if (poolIndex < 0 || total <= 0 || shares[r] <= 0) {
        result[r] = const {};
        continue;
      }
      final info = pools[poolIndex]!;
      // Per-player probability = P(rarity roll) × P(player | rarity).
      final share = shares[r] / total;
      final probs = <int, double>{};
      for (var i = 0; i < info.players.length; i++) {
        probs[info.players[i].playerId] =
            info.total > 0 ? share * info.weights[i] / info.total : 0;
      }
      result[r] = probs;
    }
    return result;
  }

  /// Expected economic value of one pack's single player under the
  /// actual two-stage odds (GDD 5.5): the rarity-table-weighted average
  /// of each band's odds-weighted expected economic value. The scope's
  /// store tier drives the table, so a Legendary pack's expectation —
  /// and therefore its price — sits well above a Rare pack's over the
  /// same pool, and a table retune re-prices the shelf automatically.
  int expectedPackValue(PackScope scope, List<BasePlayer> pool) {
    final pools = _poolsFor(scope, pool);
    final odds = oddsConfig.oddsFor(scope.rollTier(this));
    final total = odds.rare + odds.epic + odds.legendary + odds.premium;
    final shares = [odds.rare, odds.epic, odds.legendary, odds.premium];
    var value = 0.0;
    for (var r = 0; r < PackRarity.values.length; r++) {
      final share = total > 0 ? shares[r] / total : 0.0;
      if (share == 0) continue;
      final poolIndex = _fallbackIndex(pools, r);
      if (poolIndex < 0) continue;
      final info = pools[poolIndex]!;
      if (info.players.length <= 1) {
        // Single (or fallback-booked single) band: value is
        // deterministic.
        if (info.players.isNotEmpty) {
          value +=
              share *
              economy.economicValueOf(info.players.single.marketValueEur);
        }
        continue;
      }
      var bandEv = 0.0;
      for (var i = 0; i < info.players.length; i++) {
        bandEv +=
            economy.economicValueOf(info.players[i].marketValueEur) *
            (info.weights[i] / info.total);
      }
      value += share * bandEv;
    }
    return value.round();
  }

  /// Pack price (GDD 5.5): expected contents value plus the configured
  /// margin, driven by the Economy Engine's parameters. Legendary packs
  /// pay their own premium margin (rebalance Ch.8): at the flat margin
  /// they were the cheapest power-per-coin purchase in the store, so the
  /// elite tier now costs proportionally more than Rare/Epic.
  ///
  /// Store prices are normalized to whole thousands (26,344 → 26,000):
  /// the value the player sees on a plate is the exact value the ledger
  /// charges — no hidden rounding between the shelf and the wallet —
  /// and the compact readout maps to it 1:1 (26k). Rounding goes DOWN
  /// so the charged price can never exceed the margin-implied one.
  int packPriceFor(PackScope scope, List<BasePlayer> pool) {
    final margin = scope.rollTier(this) == PackTier.legendary
        ? economy.config.legendaryPackMarginMultiplier
        : economy.config.packMarginMultiplier;
    final raw = expectedPackValue(scope, pool) * margin;
    return (raw / 1000).floor() * 1000;
  }

  static int _byValue(BasePlayer a, BasePlayer b) =>
      a.marketValueEur.compareTo(b.marketValueEur);
}
