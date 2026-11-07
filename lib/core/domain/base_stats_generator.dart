/// FCM Rivals — Base Stats generation (GDD 4.5).
///
/// Market Value is converted into ratings through a logarithmic curve, never a
/// linear mapping. Since the OVR retune (T-0046, 2026-11-07) the curve is
/// TWO-SEGMENT: the shipped slope below the elite kink (anchored at the
/// €50M reference, so the economy anchor and every value below it keep
/// their exact old ratings) and a steeper elite slope above it, so the
/// world's best players reach the 94-99 band (€150M ≥ 96, €200M ≈ 99)
/// while the median and low bands stay exactly where they were.
/// Position-specific weightings then distribute the rating
/// across the four attributes so different positions produce different
/// distributions, mirroring real football:
///  * ST — attack is his identity, support ordinary, defence the least.
///  * LW/RW — attack still tops but clearly below a striker's, while their
///    support outruns a striker's; defence stays the least.
///  * CAM — the playmaker: support first, attack a close second, defence the
///    very lowest of all outfield roles.
///  * CM — box-to-box: support first, defence ahead of attack.
///  * CDM — the shield: defence towers (second only to CB), support second,
///    attack the least.
///  * LM/RM — wide midfielders: support first, attack second, defence modest.
///  * CB — the defensive ceiling of the whole game; support and attack trail.
///  * RB/LB — defend best but clearly below CBs, and support noticeably
///    better than CBs (overlapping full-backs).
///  * GK — goalkeeping towers over everything; attack stays 0.
///
/// A seeded probabilistic layer gives every player his own shape within his
/// position's profile: one shared quality offset (the player is a bit better
/// or worse than his value suggests) plus independent per-attribute style
/// noise (a striker with unusually good link-up play). Both are bounded, so
/// the position identity above can never invert.
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
    this.maxRating = 99,
    this.referenceValueEur = 50_000_000,
    this.valueAtReference = 84,
    this.ratingPerDoubling = 4,
    this.eliteKinkValueEur = 50_000_000,
    this.eliteRatingPerDoubling = 7.5,
    this.attributeSpread = 30,
    this.attributeAnchor = 0.25,
    this.qualityNoise = 2.0,
    this.attributeNoise = 2.5,
  });

  /// Floor for the lowest-value professionals.
  final int minRating;

  /// Ceiling for superstars (T-0046, 2026-11-07: the elite band reaches
  /// 94-99 — €200M translates to ~99; no code may cap OVR below 99).
  final int maxRating;

  /// Stable reference point so economy shifts stay measurable (GDD 17.5).
  final int referenceValueEur;

  /// Rating assigned at the reference market value.
  final int valueAtReference;

  /// Rating gained for each doubling of market value above/below reference
  /// on the STANDARD segment (at or below [eliteKinkValueEur]).
  final double ratingPerDoubling;

  /// Market value where the curve switches to the elite slope (T-0046).
  /// Anchored AT the reference value: the two log segments join exactly
  /// there, the €50M anchor stays exact, and every value below it keeps
  /// the shipped curve untouched (median/p90/floor bands unmoved).
  final int eliteKinkValueEur;

  /// Rating gained for each doubling ABOVE [eliteKinkValueEur] (T-0046).
  /// Shipped 7.5: €150M ≥ 96 and €200M ≈ 99 within the dataset band
  /// contract (top-5 in 96-99, 80+ population 2.0-3.5%).
  final double eliteRatingPerDoubling;

  /// How far an attribute may deviate from the overall rating because of
  /// its position weight: primary attributes land roughly
  /// `overall + attributeSpread * (weight - attributeAnchor)` — a striker's
  /// attack clearly outranks his defence, and vice versa for a centre-back.
  final double attributeSpread;

  /// The position weight that maps onto the overall rating itself.
  /// Weights above the anchor push the attribute up, below pull it down.
  final double attributeAnchor;

  /// Half-width of the per-player quality offset (rating points): the whole
  /// profile sits uniformly within ±[qualityNoise] of what the market value
  /// suggests — scouting uncertainty. Shared by all of a player's attributes.
  final double qualityNoise;

  /// Half-width of the independent per-attribute style noise (rating
  /// points): how far an individual may stray from his position's typical
  /// shape — a striker with unusually good support, a full-back who can
  /// cross. Bounded, so a position's identity ordering never flips.
  final double attributeNoise;
}

const BaseStatsConfig defaultBaseStatsConfig = BaseStatsConfig();

/// Per-position distribution of the base rating across the four attributes.
/// Weights are positive and sum to 1 per position. The deviation each weight
/// produces is `attributeSpread * (weight - attributeAnchor)`, so with the
/// default spread of 30 and anchor 0.25 the attribute ladders are:
///  * attack: ST +12.3 > LW/RW +9.9 > CAM +5.1 > LM/RM +3.0 > RB/LB −0.3 >
///    CM −0.9 > CB −2.7 > CDM −3.9
///  * support: CAM +6.9 ≈ CM +6.6 > LM/RM +5.1 > CDM +3.9 > RB/LB +2.7 >
///    LW/RW +1.5 > ST −0.9 > CB −1.5
///  * defence: CB +11.7 > CDM +7.5 > RB/LB +5.1 > CM +1.8 > LM/RM −0.6 >
///    ST = LW/RW −3.9 > CAM −4.5
const Map<Position, Map<PlayerAttribute, double>> positionWeights = {
  Position.st: {
    PlayerAttribute.attack: 0.66,
    PlayerAttribute.support: 0.22,
    PlayerAttribute.defence: 0.12,
    PlayerAttribute.goalkeeping: 0.0,
  },
  Position.lw: {
    PlayerAttribute.attack: 0.58,
    PlayerAttribute.support: 0.30,
    PlayerAttribute.defence: 0.12,
    PlayerAttribute.goalkeeping: 0.0,
  },
  Position.rw: {
    PlayerAttribute.attack: 0.58,
    PlayerAttribute.support: 0.30,
    PlayerAttribute.defence: 0.12,
    PlayerAttribute.goalkeeping: 0.0,
  },
  Position.cam: {
    PlayerAttribute.attack: 0.42,
    PlayerAttribute.support: 0.48,
    PlayerAttribute.defence: 0.10,
    PlayerAttribute.goalkeeping: 0.0,
  },
  Position.lm: {
    PlayerAttribute.attack: 0.35,
    PlayerAttribute.support: 0.42,
    PlayerAttribute.defence: 0.23,
    PlayerAttribute.goalkeeping: 0.0,
  },
  Position.rm: {
    PlayerAttribute.attack: 0.35,
    PlayerAttribute.support: 0.42,
    PlayerAttribute.defence: 0.23,
    PlayerAttribute.goalkeeping: 0.0,
  },
  Position.cm: {
    PlayerAttribute.attack: 0.22,
    PlayerAttribute.support: 0.47,
    PlayerAttribute.defence: 0.31,
    PlayerAttribute.goalkeeping: 0.0,
  },
  Position.cdm: {
    PlayerAttribute.attack: 0.12,
    PlayerAttribute.support: 0.38,
    PlayerAttribute.defence: 0.50,
    PlayerAttribute.goalkeeping: 0.0,
  },
  Position.cb: {
    PlayerAttribute.attack: 0.16,
    PlayerAttribute.support: 0.20,
    PlayerAttribute.defence: 0.64,
    PlayerAttribute.goalkeeping: 0.0,
  },
  Position.rb: {
    PlayerAttribute.attack: 0.24,
    PlayerAttribute.support: 0.34,
    PlayerAttribute.defence: 0.42,
    PlayerAttribute.goalkeeping: 0.0,
  },
  Position.lb: {
    PlayerAttribute.attack: 0.24,
    PlayerAttribute.support: 0.34,
    PlayerAttribute.defence: 0.42,
    PlayerAttribute.goalkeeping: 0.0,
  },
  Position.gk: {
    PlayerAttribute.attack: 0.0,
    PlayerAttribute.support: 0.08,
    PlayerAttribute.defence: 0.12,
    PlayerAttribute.goalkeeping: 0.80,
  },
};

/// Generates Base Stats for a player from Market Value and Position.
class BaseStatsGenerator {
  const BaseStatsGenerator({this.config = defaultBaseStatsConfig});

  final BaseStatsConfig config;

  /// Non-linear Market Value conversion (logarithmic scaling, T-0046
  /// two-segment form).
  ///
  /// Standard segment (value ≤ [BaseStatsConfig.eliteKinkValueEur]):
  /// rating = valueAtReference + ratingPerDoubling * log2(value / reference)
  ///
  /// Elite segment (value above the kink), anchored at the kink so the
  /// segments join exactly:
  /// rating = kinkRating + eliteRatingPerDoubling * log2(value / kink)
  ///
  /// Clamped to [minRating, maxRating]. Doubling the value still adds a
  /// constant amount per segment; the kink steepens the elite end so the
  /// world's best reach the 94-99 band while the mid/low bands keep
  /// their exact old positions.
  int baseRatingFor(int marketValueEur) {
    if (marketValueEur <= 0) return config.minRating;
    final double rating;
    if (marketValueEur <= config.eliteKinkValueEur) {
      rating =
          config.valueAtReference +
          config.ratingPerDoubling *
              _log2(marketValueEur / config.referenceValueEur);
    } else {
      final kinkRating =
          config.valueAtReference +
          config.ratingPerDoubling *
              _log2(config.eliteKinkValueEur / config.referenceValueEur);
      rating =
          kinkRating +
          config.eliteRatingPerDoubling *
              _log2(marketValueEur / config.eliteKinkValueEur);
    }
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
  ///
  /// With a [seed] the generation becomes probabilistic per player: one
  /// shared quality offset (±[BaseStatsConfig.qualityNoise]) and independent
  /// per-attribute style noise (±[BaseStatsConfig.attributeNoise]) are drawn
  /// from the seed, so two €50M strikers field different stat shapes while
  /// the SAME player + value always rebuilds the exact same stats (GDD 4.6
  /// regeneration stays stable when seeded with the player id). Without a
  /// seed the pure expected profile is returned.
  BaseStats generate(Position position, int marketValueEur, {int? seed}) {
    final base = baseRatingFor(marketValueEur);
    final weights = positionWeights[position]!;
    final spread = config.attributeSpread;
    final anchor = config.attributeAnchor;
    final rng = seed == null ? null : math.Random(seed);
    final quality = rng == null ? 0.0 : _triangle(rng) * config.qualityNoise;

    final attrs = <PlayerAttribute, int>{};
    for (final entry in weights.entries) {
      final w = entry.value;
      if (w == 0) {
        attrs[entry.key] = 0;
        continue;
      }
      final deviation = spread * (w - anchor);
      final style = rng == null ? 0.0 : _triangle(rng) * config.attributeNoise;
      final v = (base + deviation + quality + style).round().clamp(1, 99);
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

  /// Triangular noise in −1..1 (sum of two uniforms minus one): bell-shaped
  /// around 0 like real ability spread, but bounded — the extremes stay
  /// within ±[BaseStatsConfig.attributeNoise] per attribute, so the
  /// position identity orderings can never invert.
  static double _triangle(math.Random rng) =>
      (rng.nextDouble() + rng.nextDouble()) - 1.0;

  static double _log2(double x) => math.log(x) / math.ln2;
}
