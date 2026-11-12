/// FCM Rivals — pack rarity model (owner spec 2026-11-08, T-0058).
///
/// The pack layer's own four-band rarity PARTITION and its odds
/// configuration. Rarity is derived FROM OVR — never manually assigned —
/// in four bands: RARE < 70, EPIC 70–79, LEGENDARY 80–89, PREMIUM 90+.
///
/// Measured on the real dataset (analysis 2026-11-08,
/// `assets/data/players_v1.json`, 20,876 rows, shipped T-0046 curve —
/// boundaries OVR 70 = €4.42M, 80 = €25M, 90 = €87.06M): curve-based
/// pools RARE 18,295 (87.64%) / EPIC 2,088 (10.00%) / LEGENDARY 464
/// (2.22%) / PREMIUM 29 (0.139%). The MV boundaries are DERIVED from the
/// curve (`BaseStatsConfig.valueForRating`) and are recorded here as
/// documentation only — they are never hardcoded into logic; a curve
/// retune moves them (and the measured pools) with it.
///
/// The PREMIUM band is a probability partition only — it is NOT a fourth
/// `CardRarity` (T-0049 rejected that and test-locked
/// `CardRarity.values.length == 3`); premium RENDERING stays
/// `CardClass` (crimson red, T-0049). The band and the red card are
/// bound by test to the same threshold
/// (`CardClass.premiumOverallThreshold`).
///
/// Pure Dart, no Flutter imports, no RNG state — the `injury.dart`
/// pattern: the draw engine (T-0059) consumes this configuration; this
/// task delivers configuration only, no behavior change.
library;

import 'dart:math' as math;

import 'pack_engine.dart' show PackTier;

/// The four-band pack rarity partition (owner spec 2026-11-08).
///
/// Derived from OVR only — a player's band is a pure function of his
/// overall, never a stored attribute. Display-name l10n keys (T-0059/T-0060
/// add the ARB strings when the odds become user-facing; no user-facing
/// strings live in this layer):
/// - [PackRarity.rare] → `packRarityRare`
/// - [PackRarity.epic] → `packRarityEpic`
/// - [PackRarity.legendary] → `packRarityLegendary`
/// - [PackRarity.premium] → `packRarityPremium`
enum PackRarity {
  rare,
  epic,
  legendary,
  premium;

  /// Partitions an OVR into its band using [config]'s thresholds
  /// (defaults: rare < 70 ≤ epic < 80 ≤ legendary < 90 ≤ premium).
  static PackRarity fromOverall(
    int overall, {
    PackOddsConfig config = defaultPackOddsConfig,
  }) {
    if (overall >= config.premiumMinOverall) return PackRarity.premium;
    if (overall >= config.legendaryMinOverall) return PackRarity.legendary;
    if (overall >= config.epicMinOverall) return PackRarity.epic;
    return PackRarity.rare;
  }
}

/// Per-pack rarity probability table — one row of the owner's matrix,
/// in fixed [PackRarity] enum order consumption-friendly named fields.
typedef PackRarityOdds = ({
  double rare,
  double epic,
  double legendary,
  double premium,
});

/// Every pack-odds knob in one class — the `InjuryConfig` pattern: no
/// magic numbers anywhere else. T-0059's two-stage draw and T-0060's
/// calibration gate both consume this configuration.
class PackOddsConfig {
  const PackOddsConfig({
    this.epicMinOverall = 70,
    this.legendaryMinOverall = 80,
    this.premiumMinOverall = 90,
    this.rarePack = (
      rare: 0.75,
      epic: 0.20,
      legendary: 0.05,
      premium: 0.0,
    ),
    this.epicPack = (
      rare: 0.40,
      epic: 0.50,
      legendary: 0.10,
      premium: 0.0,
    ),
    this.legendaryPack = (
      rare: 0.00,
      epic: 0.55,
      legendary: 0.43,
      premium: 0.02,
    ),
    this.iconEpicPack = (
      rare: 0.30,
      epic: 0.70,
      legendary: 0.0,
      premium: 0.0,
    ),
    this.iconLegendaryPack = (
      rare: 0.00,
      epic: 0.55,
      legendary: 0.45,
      premium: 0.0,
    ),
    this.iconSupremePack = (
      rare: 0.00,
      epic: 0.55,
      legendary: 0.43,
      premium: 0.02,
    ),
    this.iconEpicChance = 0.005,
    this.iconLegendaryChance = 0.010,
    this.iconSupremeChance = 0.015,
    this.marketValueExponent = 1.5,
    this.pityGuaranteedRarityPulls,
  }) : assert(epicMinOverall < legendaryMinOverall),
       assert(legendaryMinOverall < premiumMinOverall);

  /// OVR cut points of the four bands (owner defaults 70/80/90; rare has
  /// no lower cut). [premiumMinOverall] must stay bound to
  /// `CardClass.premiumOverallThreshold` (test-locked) so the probability
  /// band and the red premium card can never drift apart, and
  /// [legendaryMinOverall] to the gold rule (`PackEngine.legendaryOverall`).
  final int epicMinOverall;
  final int legendaryMinOverall;
  final int premiumMinOverall;

  /// The owner's per-pack rarity matrix (2026-11-08):
  /// RARE pack 75/20/5/0, EPIC pack 40/50/10/0, LEGENDARY pack
  /// 0/55/43/2 — order RARE/EPIC/LEGENDARY/PREMIUM. Premium is exclusive
  /// to Legendary packs: the rare and epic tables carry 0.0 and a test
  /// locks that exclusivity.
  final PackRarityOdds rarePack;
  final PackRarityOdds epicPack;
  final PackRarityOdds legendaryPack;

  /// The three icon-pack tables (owner request 2026-11-12, "very very
  /// very tiny chance"): the band shares of the ICON TIER's regular
  /// draws. The icon chance itself lives beside them
  /// ([iconEpicChance] etc.): stage 1 first rolls the tiny icon chance,
  /// and only when it misses does the rolled band of THIS table decide
  /// the regular player — so each table still sums to 1 on its own and
  /// the effective per-band probabilities the player sees rescale by
  /// (1 − iconChance).
  ///
  /// - ICON EPIC pack: 30/70/0/0 — epic-weighted regulars, no gold.
  /// - ICON LEGENDARY pack: 0/55/45/0 — the legendary pack's shape with
  ///   premium folded into the icon chance.
  /// - ICON SUPREME pack: 0/55/43/2 — premium regulars reachable, same
  ///   shape as the classic legendary pack.
  final PackRarityOdds iconEpicPack;
  final PackRarityOdds iconLegendaryPack;
  final PackRarityOdds iconSupremePack;

  /// The tiny icon chance of each icon tier (owner request 2026-11-12):
  /// the probability a pack's single player is an ICON (a legend from
  /// tm-icons.json) instead of a regular of the rolled band. 0.5% /
  /// 1.0% / 1.5% — deliberately minuscule: icons are the chase.
  final double iconEpicChance;
  final double iconLegendaryChance;
  final double iconSupremeChance;

  /// The draw stage's value-weighting exponent: stage-2 candidate weight
  /// is `(poolMinMv / mv)^exponent` ([weightFor]) — higher values flatten
  /// the in-band distribution toward the pool floor (owner default 1.5).
  final double marketValueExponent;

  /// RESERVED (GDD rule 14 pre-balance): pull count after which a
  /// guaranteed-rarity (pity) rule fires. Nullable placeholder — UNUSED
  /// in this task (no behavior), a test locks that it stays null until
  /// T-0059/T-0060 wire the draw and its economy.
  final int? pityGuaranteedRarityPulls;

  /// The table for [tier], in [PackRarity] enum order.
  PackRarityOdds oddsFor(PackTier tier) => switch (tier) {
    PackTier.rare => rarePack,
    PackTier.epic => epicPack,
    PackTier.legendary => legendaryPack,
    PackTier.iconEpic => iconEpicPack,
    PackTier.iconLegendary => iconLegendaryPack,
    PackTier.iconSupreme => iconSupremePack,
  };

  /// The tiny icon chance of [tier]; 0 for every regular tier.
  double iconChanceOf(PackTier tier) => switch (tier) {
    PackTier.iconEpic => iconEpicChance,
    PackTier.iconLegendary => iconLegendaryChance,
    PackTier.iconSupreme => iconSupremeChance,
    _ => 0.0,
  };

  /// Validation of one table. The const constructor cannot call methods
  /// in its initializer list (const asserts only take constant
  /// expressions), so the tables are checked here — [validate] covers
  /// debug AND release builds, and the tests lock every shipped table.
  static bool _validTable(PackRarityOdds t) =>
      _validWeight(t.rare) &&
      _validWeight(t.epic) &&
      _validWeight(t.legendary) &&
      _validWeight(t.premium) &&
      (t.rare + t.epic + t.legendary + t.premium - 1.0).abs() <= 1e-9;

  static bool _validWeight(double w) => w >= 0.0 && w <= 1.0;

  /// Runtime validation for release builds and tests (asserts are
  /// stripped in release): throws [ArgumentError] on any invalid table.
  void validate() {
    for (final tier in PackTier.values) {
      final t = oddsFor(tier);
      if (!_validTable(t)) {
        throw ArgumentError.value(
          t,
          '${tier.name}Pack',
          'each weight must be in [0, 1] and the four must sum to 1 '
              '(±1e-9); got ${t.rare}/${t.epic}/${t.legendary}/${t.premium}',
        );
      }
    }
    for (final tier in PackTier.values) {
      final chance = iconChanceOf(tier);
      if (!(chance >= 0.0 && chance <= 0.05)) {
        throw ArgumentError.value(
          chance,
          '${tier.name} icon chance',
          'the icon chance must stay tiny (≤ 0.05) — owner spec '
              '"very very very tiny chance"',
        );
      }
    }
  }
}

const PackOddsConfig defaultPackOddsConfig = PackOddsConfig();

/// Stage-2 value weight for one candidate (owner formula):
/// `(poolMinMv / mv)^exponent` — cheaper players inside a band weigh
/// more, so an in-band pull still spans the band instead of collapsing
/// onto its stars.
///
/// Guards (documented behavior, tested):
/// - `marketValueEur ≤ 0` clamps to 1 before dividing (a zero/negative
///   MV cannot zero out or invert the weight);
/// - `poolMinMarketValueEur ≤ 0` clamps to 1 (the floor must stay
///   positive or every weight becomes 0/undefined);
/// - the result is always finite and ≥ 0 — with clamped positive inputs
///   and a finite [exponent], `pow` cannot produce NaN/Infinity, and the
///   ratio is positive by construction. A candidate BELOW the pool floor
///   legitimately weighs more than 1 (relative weighting, not a
///   probability).
double weightFor({
  required int marketValueEur,
  required int poolMinMarketValueEur,
  required double exponent,
}) {
  final mv = marketValueEur < 1 ? 1 : marketValueEur;
  final floor = poolMinMarketValueEur < 1 ? 1 : poolMinMarketValueEur;
  return math.pow(floor / mv, exponent).toDouble();
}
