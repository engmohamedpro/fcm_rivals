/// FCM Rivals — Pack Engine (GDD 5, FR-009..FR-011).
///
/// Every pack contains exactly one player, drawn from a randomly rolled low,
/// medium or high Market Value tier. Higher-value players have
/// proportionally lower odds (never impossible). Categories filter the
/// eligible pool: Global, Nationality and Position packs.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart' show Color;

import '../../core/domain/players.dart';
import '../economy/economy_engine.dart';

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
/// toward: each tier weights the Market Value tier roll toward better
/// players — a Legendary pack heavily favours the high tier, a Rare pack
/// almost never leaves the low tier — and is priced by its own expected
/// contents, so better odds cost proportionally more Coins.
enum PackTier {
  rare('Rare', [1.0, 0.12, 0.0]),
  epic('Epic', [0.35, 1.0, 0.18]),
  legendary('Legendary', [0.05, 0.45, 1.0]);

  const PackTier(this.label, this.weights);
  final String label;

  /// Relative chance of the low / mid / high Market Value tier, aligned
  /// with [PackEngine.tierWeights] ordering.
  final List<double> weights;

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
  /// constructor-configured tier roll (backwards compatibility).
  final PackTier? tier;

  /// Weights this scope draws with: its own tier's, or the engine's.
  List<double> rollWeights(PackEngine engine) =>
      tier?.weights ?? engine.tierWeights;

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

/// One drawn player with the tier he came from.
class PackDraw {
  const PackDraw({required this.player, required this.tier});

  final BasePlayer player;

  /// 0 = low, 1 = medium, 2 = high Market Value tier.
  final int tier;
}

/// Cached per-pool draw structures: for one (pool, scope, smoothing)
/// combination, the value-sorted eligible players split into tiers with
/// their draw weights, weight totals and cumulative distributions. Built
/// once, then reused by [PackEngine.open], [PackEngine.oddsFor] and
/// [PackEngine.expectedPackValue] — the store shelf, odds sheet and a
/// streak of opens over the same pool no longer re-filter, re-sort,
/// re-tier and re-weight thousands of players per call.
class _PoolDrawInfo {
  _PoolDrawInfo({
    required this.tiers,
    required this.weights,
    required this.totals,
    required this.cumulative,
  });

  /// The three value tiers over the eligible pool (value-sorted within
  /// each tier).
  final List<List<BasePlayer>> tiers;

  /// Per-tier value weights (1 / economicValue^smoothing), same order as
  /// the tier lists.
  final List<List<double>> weights;

  /// Per-tier weight sums.
  final List<double> totals;

  /// Per-tier cumulative weight sums; `cumulative[t][i]` is the summed
  /// weight of tier `t`'s players up to and including index `i`. Used by
  /// the binary-search draw below.
  final List<List<double>> cumulative;
}

/// Cache key: the pool instance (identity), the scope (value equality)
/// and the odds smoothing that produced a [_PoolDrawInfo]. The engine
/// instance owns the cache, so constructor configuration (tier
/// boundaries, tier weights, economy) is fixed per key.
class _CacheKey {
  const _CacheKey(this.pool, this.scope, this.smoothing);

  final List<BasePlayer> pool;
  final PackScope scope;
  final double smoothing;

  @override
  bool operator ==(Object other) =>
      other is _CacheKey &&
      identical(other.pool, pool) &&
      other.scope == scope &&
      other.smoothing == smoothing;

  @override
  int get hashCode => Object.hash(identityHashCode(pool), scope, smoothing);
}

/// Draws packs from an eligible pool with value-weighted odds.
class PackEngine {
  /// Default absolute tier floors (review 2026-11-04
  /// economy_pack-tier-bands-and-elite-ceiling): low < €3M, mid €3–20M,
  /// high ≥ €20M — a star is a star in every pool, so a Legendary pack
  /// can actually contain one (the relative log-scale bands let a
  /// €0.4–2.6M nationality pool label €2.5M players 'high tier').
  static const List<double> defaultAbsoluteTierFloorEur = [
    3_000_000,
    20_000_000,
  ];

  PackEngine({
    this.tierBoundaries = const [0.15, 0.55],
    this.tierWeights = const [1.0, 1.0, 1.0],
    required this.random,
    this.economy = const EconomyEngine(),
    this.absoluteTierFloorEur = defaultAbsoluteTierFloorEur,
  }) : assert(
         tierBoundaries.length == 2 &&
             0 < tierBoundaries[0] &&
             tierBoundaries[0] < tierBoundaries[1] &&
             tierBoundaries[1] < 1,
         'tier boundaries must be increasing fractions in (0, 1)',
       ),
       assert(
         tierWeights.length == 3 &&
             tierWeights.every((w) => w >= 0) &&
             tierWeights.any((w) => w > 0),
         'tier weights need three non-negative values, at least one > 0',
       ),
       assert(
         absoluteTierFloorEur == null ||
             (absoluteTierFloorEur.length == 2 &&
                 0 < absoluteTierFloorEur[0] &&
                 absoluteTierFloorEur[0] < absoluteTierFloorEur[1]),
         'absolute tier floors must be increasing positive EUR values',
       );

  /// Relative chance that the pack's single player comes from the low, mid
  /// or high tier. Equal by default.
  final List<double> tierWeights;

  /// Fractions of the pool's Market Value range separating low/mid/high
  /// tiers, measured on the log-value scale (GDD 5.3 configurable tiers).
  final List<double> tierBoundaries;

  /// Absolute market-value tier floors in EUR (`[low/mid boundary,
  /// mid/high boundary]`). When set, they OVERRIDE [tierBoundaries] for
  /// pools spanning them: the high tier starts at a fixed star price
  /// (default €20M) instead of 55% down every pool's own log-value range
  /// — a €0.4–2.6M nationality pool can no longer label a €2.5M player
  /// 'high tier'. Pools entirely below the first floor collapse into the
  /// low tier; pools entirely above the second floor put everything in
  /// the high tier (the engine's fallback keeps every draw reachable).
  final List<double>? absoluteTierFloorEur;

  /// Shared RNG — callers inject a seeded generator for deterministic tests.
  final math.Random random;

  final EconomyEngine economy;

  /// Cached per-pool draw structures, keyed by pool identity + scope +
  /// smoothing. Pools in this game are loaded once and handed around as
  /// the same instance, so identity is the right key; the cached weights
  /// depend only on immutable player values, so they never go stale. The
  /// map is cleared once it exceeds [_maxCachedEntries] distinct
  /// (pool, scope, smoothing) combinations, keeping memory bounded — the
  /// store shelf's few dozen scopes rebuild in microseconds anyway.
  static const _maxCachedEntries = 32;

  final Map<_CacheKey, _PoolDrawInfo> _poolCache = {};

  /// Returns the draw info for [scope] over [pool] at [smoothing],
  /// building and caching it on first use.
  _PoolDrawInfo _drawInfoFor(
    PackScope scope,
    List<BasePlayer> pool,
    double smoothing,
  ) {
    if (_poolCache.length >= _maxCachedEntries) _poolCache.clear();
    return _poolCache.putIfAbsent(
      _CacheKey(pool, scope, smoothing),
      () => _buildDrawInfo(scope, pool, smoothing),
    );
  }

  /// Computes the uncached draw info: filter by scope, sort by value,
  /// split into tiers, then weight each tier's players.
  _PoolDrawInfo _buildDrawInfo(
    PackScope scope,
    List<BasePlayer> pool,
    double smoothing,
  ) {
    final eligible = pool.where(scope.matches).toList()..sort(_byValue);
    final tiers = _splitIntoTiers(eligible);
    final weights = <List<double>>[];
    final totals = <double>[];
    final cumulative = <List<double>>[];
    for (final tier in tiers) {
      final w = tier
          .map(
            (p) =>
                1.0 /
                math.pow(
                  economy.economicValueOf(p.marketValueEur).toDouble(),
                  smoothing,
                ),
          )
          .toList();
      weights.add(w);
      var sum = 0.0;
      final cum = <double>[];
      for (final value in w) {
        sum += value;
        cum.add(sum);
      }
      totals.add(sum);
      cumulative.add(cum);
    }
    return _PoolDrawInfo(
      tiers: tiers,
      weights: weights,
      totals: totals,
      cumulative: cumulative,
    );
  }

  /// Splits a value-sorted eligible pool into low/mid/high tiers. When
  /// [absoluteTierFloorEur] is set, the bands are absolute market values
  /// (default low < €3M, mid €3–20M, high ≥ €20M) — the same star is a
  /// star in every pool; otherwise the legacy log-scale relative bands
  /// apply.
  List<List<BasePlayer>> _splitIntoTiers(List<BasePlayer> sorted) {
    if (sorted.isEmpty) return const [[], [], []];
    final low = <BasePlayer>[], mid = <BasePlayer>[], high = <BasePlayer>[];
    final floors = absoluteTierFloorEur;
    if (floors != null) {
      for (final p in sorted) {
        final v = p.marketValueEur.toDouble();
        if (v < floors[0]) {
          low.add(p);
        } else if (v < floors[1]) {
          mid.add(p);
        } else {
          high.add(p);
        }
      }
      return [low, mid, high];
    }
    final values = sorted.map((p) => p.marketValueEur).toList();
    final minV = values.reduce(math.min).toDouble();
    final maxV = values.reduce(math.max).toDouble();
    if (minV <= 0 || maxV <= minV) {
      // Degenerate pool: everything is one tier.
      return [sorted, <BasePlayer>[], <BasePlayer>[]];
    }
    final logMin = math.log(minV);
    final logMax = math.log(maxV);
    for (final p in sorted) {
      final t =
          (math.log(p.marketValueEur.toDouble()) - logMin) / (logMax - logMin);
      if (t < tierBoundaries[0]) {
        low.add(p);
      } else if (t < tierBoundaries[1]) {
        mid.add(p);
      } else {
        high.add(p);
      }
    }
    return [low, mid, high];
  }

  /// Splits [pool] into low/mid/high tiers on the log-value scale.
  ///
  /// Public for tests and the odds display; the engine internally uses
  /// the cached per-(pool, scope) structures instead.
  List<List<BasePlayer>> tiersOf(List<BasePlayer> pool) {
    if (pool.isEmpty) return [[], [], []];
    return _splitIntoTiers(pool.toList()..sort(_byValue));
  }

  /// Index of the nearest non-empty tier when [index] is exhausted, or
  /// -1 when every tier is empty.
  int _fallbackIndex(List<List<BasePlayer>> tiers, int index) {
    if (tiers[index].isNotEmpty) return index;
    for (final delta in const [1, -1, 2, -2]) {
      final i = index + delta;
      if (i >= 0 && i < tiers.length && tiers[i].isNotEmpty) return i;
    }
    return -1;
  }

  /// Weighted draw of a single player from tier `tierIndex` of [info],
  /// using the cached cumulative distribution and a binary search.
  ///
  /// The search returns the smallest index whose cumulative weight is at
  /// least the roll — exactly the player the original linear
  /// `roll -= weights[i]; if (roll <= 0) return tier[i]` scan selected,
  /// including at ties, but in O(log n) instead of O(n). Single-player
  /// tiers return their player without consuming RNG, matching the
  /// original scan.
  BasePlayer? _drawFromTier(_PoolDrawInfo info, int tierIndex) {
    final tier = info.tiers[tierIndex];
    if (tier.isEmpty) return null;
    if (tier.length == 1) return tier.single;
    final cum = info.cumulative[tierIndex];
    final roll = random.nextDouble() * info.totals[tierIndex];
    var lo = 0, hi = cum.length - 1;
    while (lo < hi) {
      final mid = lo + (hi - lo) ~/ 2;
      if (cum[mid] < roll) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return tier[lo];
  }

  /// Opens a pack: exactly one player. A tier (low/mid/high) is rolled —
  /// with the scope's store tier weights when it has one — then one
  /// player is drawn from it with value-weighted odds. Empty pool returns
  /// an empty draw list. The reported tier is the ROLLED tier, matching
  /// the odds display, which also books fallback-tier players under the
  /// rolled tier's probability share.
  List<PackDraw> open(
    PackScope scope,
    List<BasePlayer> pool, {
    double? oddsSmoothing,
  }) {
    final smoothing = oddsSmoothing ?? economy.config.packOddsSmoothing;
    final info = _drawInfoFor(scope, pool, smoothing);
    if (info.tiers.every((tier) => tier.isEmpty)) return const [];
    final tierIndex = _rollTier(scope.rollWeights(this));
    final drawIndex = _fallbackIndex(info.tiers, tierIndex);
    if (drawIndex < 0) return const [];
    final player = _drawFromTier(info, drawIndex);
    if (player == null) return const [];
    return [PackDraw(player: player, tier: tierIndex)];
  }

  /// Rolls which tier the pack's single player comes from.
  int _rollTier(List<double> weights) {
    final total = weights.fold<double>(0, (a, b) => a + b);
    var roll = random.nextDouble() * total;
    for (var i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return i;
    }
    return weights.length - 1;
  }

  /// The per-tier probability of drawing each eligible player, for the
  /// user-facing odds display (GDD 5.4). Returns one entry per tier with the
  /// sum of probabilities per player in that tier.
  Map<int, Map<int, double>> oddsFor(
    PackScope scope,
    List<BasePlayer> pool, {
    double? oddsSmoothing,
  }) {
    final smoothing = oddsSmoothing ?? economy.config.packOddsSmoothing;
    final info = _drawInfoFor(scope, pool, smoothing);
    final rollWeights = scope.rollWeights(this);
    final rollTotal = rollWeights.fold<double>(0, (a, b) => a + b);
    final result = <int, Map<int, double>>{};
    for (var t = 0; t < 3; t++) {
      final tierIndex = _fallbackIndex(info.tiers, t);
      if (tierIndex < 0 || rollTotal <= 0 || rollWeights[t] <= 0) {
        result[t] = const {};
        continue;
      }
      final tier = info.tiers[tierIndex];
      final total = info.totals[tierIndex];
      // Per-player probability = P(tier roll) × P(player | tier).
      final tierShare = rollWeights[t] / rollTotal;
      final probs = <int, double>{};
      for (var i = 0; i < tier.length; i++) {
        probs[tier[i].playerId] = total > 0
            ? tierShare * info.weights[tierIndex][i] / total
            : 0;
      }
      result[t] = probs;
    }
    return result;
  }

  /// Expected economic value of one pack's single player under the actual
  /// draw odds (GDD 5.5): the tier-weighted average of each tier's
  /// odds-weighted expected economic value. The scope's store tier weights
  /// drive the roll, so a Legendary pack's expectation — and therefore its
  /// price — sits well above a Rare pack's over the same pool.
  int expectedPackValue(PackScope scope, List<BasePlayer> pool) {
    final info = _drawInfoFor(scope, pool, economy.config.packOddsSmoothing);
    final rollWeights = scope.rollWeights(this);
    final weightTotal = rollWeights.fold<double>(0, (a, b) => a + b);
    var total = 0.0;
    for (var t = 0; t < 3; t++) {
      final tierShare = rollWeights[t] / weightTotal;
      if (tierShare == 0) continue;
      final tierIndex = _fallbackIndex(info.tiers, t);
      if (tierIndex < 0) continue;
      final tier = info.tiers[tierIndex];
      if (tier.length <= 1) {
        // Single (or empty) tier: value is deterministic.
        if (tier.isNotEmpty) {
          total +=
              tierShare * economy.economicValueOf(tier.single.marketValueEur);
        }
        continue;
      }
      final wSum = info.totals[tierIndex];
      if (wSum <= 0) continue;
      var tierEv = 0.0;
      for (var i = 0; i < tier.length; i++) {
        tierEv +=
            economy.economicValueOf(tier[i].marketValueEur) *
            (info.weights[tierIndex][i] / wSum);
      }
      total += tierShare * tierEv;
    }
    return total.round();
  }

  /// Pack price (GDD 5.5): expected contents value plus the configured
  /// margin, driven by the Economy Engine's parameters. Legendary packs
  /// pay their own premium margin (rebalance Ch.8): at the flat margin
  /// they were the cheapest power-per-coin purchase in the store, so the
  /// elite tier now costs proportionally more than Rare/Epic.
  int packPriceFor(PackScope scope, List<BasePlayer> pool) {
    final margin = scope.tier == PackTier.legendary
        ? economy.config.legendaryPackMarginMultiplier
        : economy.config.packMarginMultiplier;
    return (expectedPackValue(scope, pool) * margin).round();
  }

  static int _byValue(BasePlayer a, BasePlayer b) =>
      a.marketValueEur.compareTo(b.marketValueEur);
}
