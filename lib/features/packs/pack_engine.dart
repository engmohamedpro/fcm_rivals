/// FCM Rivals — Pack Engine (GDD 5, FR-009..FR-011).
///
/// Every pack contains three players — one low, one medium and one high
/// Market Value tier draw. Higher-value players have proportionally lower
/// odds (never impossible). Categories filter the eligible pool: Global,
/// League, Nationality, Club and Position packs.
library;

import 'dart:math' as math;

import '../../core/domain/players.dart';
import '../economy/economy_engine.dart';

/// The five pack categories (GDD 5.2).
enum PackCategory {
  global('Global Pack'),
  league('League Pack'),
  nationality('Nationality Pack'),
  club('Club Pack'),
  position('Position Pack');

  const PackCategory(this.label);
  final String label;
}

/// Filter describing which players a pack draws from.
class PackScope {
  const PackScope({
    required this.category,
    this.leagueCode,
    this.nationality,
    this.club,
    this.position,
  });

  final PackCategory category;
  final String? leagueCode;
  final String? nationality;
  final String? club;
  final Position? position;

  bool matches(BasePlayer p) {
    switch (category) {
      case PackCategory.global:
        return true;
      case PackCategory.league:
        return leagueCode != null && p.leagueCode == leagueCode;
      case PackCategory.nationality:
        return nationality != null && p.nationality == nationality;
      case PackCategory.club:
        return club != null && p.club == club;
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
    required this.random,
    this.economy = const EconomyEngine(),
  }) : assert(
          tierBoundaries.length == 2 &&
              0 < tierBoundaries[0] &&
              tierBoundaries[0] < tierBoundaries[1] &&
              tierBoundaries[1] < 1,
          'tier boundaries must be increasing fractions in (0, 1)',
        );

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

  /// Opens a pack: three players, one per tier, low→mid→high reveal order
  /// (GDD 5.3). Empty pool returns an empty draw list.
  List<PackDraw> open(PackScope scope, List<BasePlayer> pool, {double? oddsSmoothing}) {
    final eligible = pool.where(scope.matches).toList()..sort(_byValue);
    if (eligible.length < 3) {
      return List.from(eligible.map((p) => PackDraw(player: p, tier: 0)));
    }
    final tiers = tiersOf(eligible);
    final smoothing =
        oddsSmoothing ?? economy.config.packOddsSmoothing;
    final draws = <PackDraw>[];
    for (var tierIndex = 0; tierIndex < 3; tierIndex++) {
      final tier = _fallbackTier(tiers, tierIndex);
      final player = _drawFromTier(tier, smoothing);
      if (player != null) draws.add(PackDraw(player: player, tier: tierIndex));
    }
    return draws;
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
    final result = <int, Map<int, double>>{};
    for (var t = 0; t < 3; t++) {
      final tier = _fallbackTier(tiers, t);
      if (tier.isEmpty) {
        result[t] = const {};
        continue;
      }
      final weights = tier
          .map((p) => 1.0 /
              math.pow(economy.economicValueOf(p.marketValueEur).toDouble(), smoothing))
          .toList();
      final total = weights.fold<double>(0, (a, b) => a + b);
      final probs = <int, double>{};
      for (var i = 0; i < tier.length; i++) {
        probs[tier[i].playerId] = total > 0 ? weights[i] / total : 0;
      }
      result[t] = probs;
    }
    return result;
  }

  /// Expected economic value of one pack's contents under the actual draw
  /// odds (GDD 5.5): the sum over the three tiers of the odds-weighted
  /// expected economic value of that tier's draw.
  int expectedPackValue(PackScope scope, List<BasePlayer> pool) {
    final eligible = pool.where(scope.matches).toList();
    if (eligible.isEmpty) return 0;
    final tiers = tiersOf(eligible);
    final smoothing = economy.config.packOddsSmoothing;
    var total = 0.0;
    for (var t = 0; t < 3; t++) {
      final tier = _fallbackTier(tiers, t);
      if (tier.length <= 1) {
        // Single (or empty) tier: value is deterministic.
        if (tier.isNotEmpty) {
          total += economy.economicValueOf(tier.single.marketValueEur);
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
      total += tierEv;
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
