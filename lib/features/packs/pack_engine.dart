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

/// Store pack varieties: each tier biases the Market Value tier roll
/// toward better players — a Gold pack heavily favours the high tier, a
/// Bronze pack almost never leaves the low tier — and is priced by its
/// own expected contents, so better odds cost proportionally more Coins.
enum PackTier {
  bronze('Bronze', [1.0, 0.12, 0.0]),
  silver('Silver', [0.35, 1.0, 0.18]),
  gold('Gold', [0.05, 0.45, 1.0]);

  const PackTier(this.label, this.weights);

  /// Display label used in pack titles and badges.
  final String label;

  /// Relative chance of the low / mid / high Market Value tier, aligned
  /// with [PackEngine.tierWeights] ordering.
  final List<double> weights;

  /// Parses a persisted tier name; unknown values fall back to bronze.
  static PackTier fromName(String? name) => values
      .firstWhere((t) => t.name == name, orElse: () => PackTier.bronze);
}

/// Store-tier accent colours, aligned with the rarity palette in the UI
/// style (bronze → warm bronze, silver → cool silver, gold → champion
/// gold). Cells, badges and foils draw from these so a pack's tier reads
/// at a glance.
extension PackTierColor on PackTier {
  Color get accent => switch (this) {
        PackTier.bronze => const Color(0xFFC89A5B),
        PackTier.silver => const Color(0xFFD9D9E2),
        PackTier.gold => const Color(0xFFF2D488),
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
}

/// One drawn player with the tier he came from.
class PackDraw {
  const PackDraw({required this.player, required this.tier});

  final BasePlayer player;

  /// 0 = low, 1 = medium, 2 = high Market Value tier.
  final int tier;
}

/// Draws packs from an eligible pool with value-weighted odds.
class PackEngine {
  PackEngine({
    this.tierBoundaries = const [0.15, 0.55],
    this.tierWeights = const [1.0, 1.0, 1.0],
    required this.random,
    this.economy = const EconomyEngine(),
  })  : assert(
          tierBoundaries.length == 2 &&
              0 < tierBoundaries[0] &&
              tierBoundaries[0] < tierBoundaries[1] &&
              tierBoundaries[1] < 1,
          'tier boundaries must be increasing fractions in (0, 1)',
        ),
        assert(
          tierWeights.length == 3 && tierWeights.every((w) => w >= 0) &&
              tierWeights.any((w) => w > 0),
          'tier weights need three non-negative values, at least one > 0',
        );

  /// Relative chance that the pack's single player comes from the low, mid
  /// or high tier. Equal by default.
  final List<double> tierWeights;

  /// Fractions of the pool's Market Value range separating low/mid/high
  /// tiers, measured on the log-value scale (GDD 5.3 configurable tiers).
  final List<double> tierBoundaries;

  /// Shared RNG — callers inject a seeded generator for deterministic tests.
  final math.Random random;

  final EconomyEngine economy;

  /// Splits [pool] into low/mid/high tiers on the log-value scale.
  List<List<BasePlayer>> tiersOf(List<BasePlayer> pool) {
    if (pool.isEmpty) return [[], [], []];
    final values = pool.map((p) => p.marketValueEur).toList();
    final minV = values.reduce(math.min).toDouble();
    final maxV = values.reduce(math.max).toDouble();
    if (minV <= 0 || maxV <= minV) {
      // Degenerate pool: everything is one tier.
      return [pool, <BasePlayer>[], <BasePlayer>[]];
    }
    final logMin = math.log(minV);
    final logMax = math.log(maxV);
    final low = <BasePlayer>[], mid = <BasePlayer>[], high = <BasePlayer>[];
    for (final p in pool) {
      final t = (math.log(p.marketValueEur.toDouble()) - logMin) /
          (logMax - logMin);
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

  /// Weighted draw of a single player from [tier].
  ///
  /// Weight = 1 / economicValue^smoothing, so higher value ⇒ lower odds
  /// (GDD 5.4) while remaining strictly positive — elite players are rare,
  /// never impossible.
  BasePlayer? _drawFromTier(List<BasePlayer> tier, double smoothing) {
    if (tier.isEmpty) return null;
    if (tier.length == 1) return tier.single;
    final weights = tier
        .map((p) => 1.0 /
            math.pow(economy.economicValueOf(p.marketValueEur).toDouble(), smoothing))
        .toList();
    final total = weights.fold<double>(0, (a, b) => a + b);
    var roll = random.nextDouble() * total;
    for (var i = 0; i < tier.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return tier[i];
    }
    return tier.last;
  }

  /// Falls back to the nearest non-empty tier when a tier is exhausted.
  List<BasePlayer> _fallbackTier(List<List<BasePlayer>> tiers, int index) {
    if (tiers[index].isNotEmpty) return tiers[index];
    for (final delta in const [1, -1, 2, -2]) {
      final i = index + delta;
      if (i >= 0 && i < tiers.length && tiers[i].isNotEmpty) return tiers[i];
    }
    return const [];
  }

  /// Opens a pack: exactly one player. A tier (low/mid/high) is rolled —
  /// with the scope's store tier weights when it has one — then one
  /// player is drawn from it with value-weighted odds. Empty pool returns
  /// an empty draw list.
  List<PackDraw> open(PackScope scope, List<BasePlayer> pool, {double? oddsSmoothing}) {
    final eligible = pool.where(scope.matches).toList()..sort(_byValue);
    if (eligible.isEmpty) return const [];
    final tiers = tiersOf(eligible);
    final smoothing =
        oddsSmoothing ?? economy.config.packOddsSmoothing;
    final tierIndex = _rollTier(scope.rollWeights(this));
    final player = _drawFromTier(_fallbackTier(tiers, tierIndex), smoothing);
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
    final eligible = pool.where(scope.matches).toList();
    final tiers = tiersOf(eligible);
    final smoothing = oddsSmoothing ?? economy.config.packOddsSmoothing;
    final rollWeights = scope.rollWeights(this);
    final rollTotal = rollWeights.fold<double>(0, (a, b) => a + b);
    final result = <int, Map<int, double>>{};
    for (var t = 0; t < 3; t++) {
      final tier = _fallbackTier(tiers, t);
      if (tier.isEmpty || rollTotal <= 0 || rollWeights[t] <= 0) {
        result[t] = const {};
        continue;
      }
      final weights = tier
          .map((p) => 1.0 /
              math.pow(economy.economicValueOf(p.marketValueEur).toDouble(), smoothing))
          .toList();
      final total = weights.fold<double>(0, (a, b) => a + b);
      // Per-player probability = P(tier roll) × P(player | tier).
      final tierShare = rollWeights[t] / rollTotal;
      final probs = <int, double>{};
      for (var i = 0; i < tier.length; i++) {
        probs[tier[i].playerId] =
            total > 0 ? tierShare * weights[i] / total : 0;
      }
      result[t] = probs;
    }
    return result;
  }

  /// Expected economic value of one pack's single player under the actual
  /// draw odds (GDD 5.5): the tier-weighted average of each tier's
  /// odds-weighted expected economic value. The scope's store tier weights
  /// drive the roll, so a Gold pack's expectation — and therefore its
  /// price — sits well above a Bronze pack's over the same pool.
  int expectedPackValue(PackScope scope, List<BasePlayer> pool) {
    final eligible = pool.where(scope.matches).toList();
    if (eligible.isEmpty) return 0;
    final tiers = tiersOf(eligible);
    final smoothing = economy.config.packOddsSmoothing;
    final rollWeights = scope.rollWeights(this);
    final weightTotal = rollWeights.fold<double>(0, (a, b) => a + b);
    var total = 0.0;
    for (var t = 0; t < 3; t++) {
      final tierShare = rollWeights[t] / weightTotal;
      if (tierShare == 0) continue;
      final tier = _fallbackTier(tiers, t);
      if (tier.length <= 1) {
        // Single (or empty) tier: value is deterministic.
        if (tier.isNotEmpty) {
          total += tierShare *
              economy.economicValueOf(tier.single.marketValueEur);
        }
        continue;
      }
      final weights = tier
          .map((p) => 1.0 /
              math.pow(economy.economicValueOf(p.marketValueEur).toDouble(), smoothing))
          .toList();
      final wSum = weights.fold<double>(0, (a, b) => a + b);
      if (wSum <= 0) continue;
      var tierEv = 0.0;
      for (var i = 0; i < tier.length; i++) {
        tierEv +=
            economy.economicValueOf(tier[i].marketValueEur) * (weights[i] / wSum);
      }
      total += tierShare * tierEv;
    }
    return total.round();
  }

  /// Pack price (GDD 5.5): expected contents value plus the configured
  /// margin, driven by the Economy Engine's parameters.
  int packPriceFor(PackScope scope, List<BasePlayer> pool) =>
      (expectedPackValue(scope, pool) * economy.config.packMarginMultiplier)
          .round();

  static int _byValue(BasePlayer a, BasePlayer b) =>
      a.marketValueEur.compareTo(b.marketValueEur);
}
