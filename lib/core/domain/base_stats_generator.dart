/// FCM Rivals — Base Stats generation (GDD 4.5).
///
/// Market Value is converted into ratings through a logarithmic curve, never a
/// linear mapping. Position-specific weightings then distribute the rating
/// across the four attributes so different positions produce different
/// distributions (ST high attack, CDM high defence/support, GK high
/// goalkeeping, ...).
library;

import 'dart:math' as math;

import 'players.dart';

/// Tunable curve parameters. Values are pre-balance placeholders that follow
/// the GDD rule: "Do not hardcode final balancing values before simulation"
/// (development rule 14) — they live here in one place, configurable and
/// ready for simulation-driven tuning.
class BaseStatsConfig {
  const BaseStatsConfig({
    this.minRating = 30,
    this.maxRating = 94,
    this.referenceValueEur = 50_000_000,
    this.valueAtReference = 84,
    this.ratingPerDoubling = 4,
    this.attributeSpread = 30,
    this.attributeAnchor = 0.25,
  });

  /// Floor for the lowest-value professionals.
  final int minRating;

  /// Ceiling for superstars (€200M translates just under this).
  final int maxRating;

  /// Stable reference point so economy shifts stay measurable (GDD 17.5).
  final int referenceValueEur;

  /// Rating assigned at the reference market value.
  final int valueAtReference;

  /// Rating gained for each doubling of market value above/below reference.
  final double ratingPerDoubling;

  /// How far an attribute may deviate from the overall rating because of
  /// its position weight: primary attributes land roughly
  /// `overall + attributeSpread * (weight - attributeAnchor)` — a striker's
  /// attack clearly outranks his defence, and vice versa for a centre-back.
  final double attributeSpread;

  /// The position weight that maps onto the overall rating itself.
  /// Weights above the anchor push the attribute up, below pull it down.
  final double attributeAnchor;
}

const BaseStatsConfig defaultBaseStatsConfig = BaseStatsConfig();

/// Per-position distribution of the base rating across the four attributes.
/// Weights are positive and sum to 1 per position.
const Map<Position, Map<PlayerAttribute, double>> positionWeights = {
  Position.st: {
    PlayerAttribute.attack: 0.62,
    PlayerAttribute.support: 0.20,
    PlayerAttribute.defence: 0.18,
    PlayerAttribute.goalkeeping: 0.0,
  },
  Position.lw: {
    PlayerAttribute.attack: 0.56,
    PlayerAttribute.support: 0.24,
    PlayerAttribute.defence: 0.20,
    PlayerAttribute.goalkeeping: 0.0,
  },
  Position.rw: {
    PlayerAttribute.attack: 0.56,
    PlayerAttribute.support: 0.24,
    PlayerAttribute.defence: 0.20,
    PlayerAttribute.goalkeeping: 0.0,
  },
  Position.cam: {
    PlayerAttribute.attack: 0.46,
    PlayerAttribute.support: 0.34,
    PlayerAttribute.defence: 0.20,
    PlayerAttribute.goalkeeping: 0.0,
  },
  Position.lm: {
    PlayerAttribute.attack: 0.42,
    PlayerAttribute.support: 0.30,
    PlayerAttribute.defence: 0.28,
    PlayerAttribute.goalkeeping: 0.0,
  },
  Position.rm: {
    PlayerAttribute.attack: 0.42,
    PlayerAttribute.support: 0.30,
    PlayerAttribute.defence: 0.28,
    PlayerAttribute.goalkeeping: 0.0,
  },
  Position.cm: {
    PlayerAttribute.attack: 0.26,
    PlayerAttribute.support: 0.40,
    PlayerAttribute.defence: 0.34,
    PlayerAttribute.goalkeeping: 0.0,
  },
  Position.cdm: {
    PlayerAttribute.attack: 0.12,
    PlayerAttribute.support: 0.36,
    PlayerAttribute.defence: 0.52,
    PlayerAttribute.goalkeeping: 0.0,
  },
  Position.cb: {
    PlayerAttribute.attack: 0.10,
    PlayerAttribute.support: 0.22,
    PlayerAttribute.defence: 0.68,
    PlayerAttribute.goalkeeping: 0.0,
  },
  Position.rb: {
    PlayerAttribute.attack: 0.22,
    PlayerAttribute.support: 0.32,
    PlayerAttribute.defence: 0.46,
    PlayerAttribute.goalkeeping: 0.0,
  },
  Position.lb: {
    PlayerAttribute.attack: 0.22,
    PlayerAttribute.support: 0.32,
    PlayerAttribute.defence: 0.46,
    PlayerAttribute.goalkeeping: 0.0,
  },
  Position.gk: {
    PlayerAttribute.attack: 0.0,
    PlayerAttribute.support: 0.10,
    PlayerAttribute.defence: 0.12,
    PlayerAttribute.goalkeeping: 0.78,
  },
};

/// Generates Base Stats for a player from Market Value and Position.
class BaseStatsGenerator {
  const BaseStatsGenerator({this.config = defaultBaseStatsConfig});

  final BaseStatsConfig config;

  /// Non-linear Market Value conversion (logarithmic scaling).
  ///
  /// rating = valueAtReference + ratingPerDoubling * log2(value / reference)
  /// clamped to [minRating, maxRating]. Doubling the value always adds the
  /// same amount of rating; the curve flattens toward the top so a €200M
  /// superstar is not ten times a €20M international.
  int baseRatingFor(int marketValueEur) {
    if (marketValueEur <= 0) return config.minRating;
    final doublings =
        _log2(marketValueEur / config.referenceValueEur);
    final rating =
        config.valueAtReference + config.ratingPerDoubling * doublings;
    final clamped = rating.clamp(config.minRating, config.maxRating);
    return clamped.round();
  }

  /// Position-weighted attribute distribution around [baseRatingFor].
  ///
  /// The market value fixes the overall rating; the position then decides
  /// where that quality lives: each attribute sits at
  /// `overall + spread * (weight - anchor)`, so a striker converts his
  /// rating mostly into attack, a centre-back into defence and a keeper
  /// into goalkeeping. Zero-weight attributes (an outfield player's
  /// goalkeeping) stay at 0.
  BaseStats generate(Position position, int marketValueEur) {
    final base = baseRatingFor(marketValueEur);
    final weights = positionWeights[position]!;
    final spread = config.attributeSpread;
    final anchor = config.attributeAnchor;

    final attrs = <PlayerAttribute, int>{};
    for (final entry in weights.entries) {
      final w = entry.value;
      if (w == 0) {
        attrs[entry.key] = 0;
        continue;
      }
      final deviation = spread * (w - anchor);
      final v = (base + deviation).round().clamp(1, 99);
      attrs[entry.key] = v;
    }
    return BaseStats(
      overall: base,
      attack: attrs[PlayerAttribute.attack]!,
      support: attrs[PlayerAttribute.support]!,
      defence: attrs[PlayerAttribute.defence]!,
      goalkeeping: attrs[PlayerAttribute.goalkeeping]!,
    );
  }

  static double _log2(double x) => math.log(x) / math.ln2;
}
