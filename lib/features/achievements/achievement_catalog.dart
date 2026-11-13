/// FCM Rivals — the typed achievement catalog (T-0105, GDD 26).
///
/// The achievements feature's single source of truth: a typed,
/// config-driven catalog of categories, metrics, definitions, reward
/// ladders and titles — pure Dart data, no DB, no UI, no providers
/// (T-0106..T-0113 build on top of exactly these types).
///
/// ECONOMY SAFETY — THE ONE RULE THIS FILE EXISTS TO ENFORCE:
/// every ENDLESS ladder uses GEOMETRIC effort thresholds (tier n
/// requires `base * ratio^n`, `ratio >= 2`) while its per-tier coin
/// reward stays FLAT. Consequence: total coins claimable from one
/// ladder after effort E is `flat * log2(E / base)` — coins-per-effort
/// strictly decreases, so the lifetime achievement income is
/// effectively bounded even though the ladder never ends. Endless
/// PRESTIGE (badge metals + titles) is unlimited; endless COINS is
/// logarithmic. The bound is BY CONSTRUCTION (constructor asserts +
/// [AchievementEconomyConfig.totalCatalogCoinCeiling] derives, never
/// hand-writes), so a future linear-growth ladder fails the catalog
/// tests instead of silently re-breaking the economy — the exact
/// regression T-0082 taught this codebase to design against.
///
/// All balance numbers here are PRE-BALANCE PLACEHOLDERS in the
/// `EconomyConfig` tradition (GDD rule 14): gathered in one config so
/// the simulation-driven sweep (T-0109) can re-pin them without
/// touching structure.
library;

import 'achievement_economy_config.dart';

/// One achievement category — the hub screen's sections (T-0110).
class AchievementCategory {
  const AchievementCategory({
    required this.id,
    required this.iconName,
    required this.l10nPrefix,
  });

  /// Stable identifier, e.g. `career`.
  final String id;

  /// Icon resource name (the UI maps it to an IconData).
  final String iconName;

  /// L10n key prefix; the UI reads `<prefix>Title` and
  /// `<prefix>Subtitle`.
  final String l10nPrefix;
}

/// How a definition's reward ladder is shaped.
enum AchievementKind {
  /// Countable metric, geometric thresholds, flat coins — the safe
  /// endless shape (see the library doc).
  endlessLadder,

  /// A unique feat claimed once for a fixed budget.
  milestone,
}

/// Badge metal for a tier — prestige, not coins.
enum BadgeMetal {
  bronze,
  silver,
  gold,
  platinum,
  legend;

  /// Rank for UI comparisons (higher = rarer).
  int get rank => switch (this) {
    bronze => 0,
    silver => 1,
    gold => 2,
    platinum => 3,
    legend => 4,
  };
}

/// The reward ladder SPEC of one definition. Finite ladders list
/// tiers directly; endless ladders generate them on demand up to a
/// UI-only cap (`maxGeneratedTiers`) — the cap is honest about being
/// a UI cap, not a game cap: crossing it generates more tiers, it
/// never stops the climb.
class AchievementLadder {
  const AchievementLadder({
    required this.baseThreshold,
    required this.thresholdRatio,
    this.tierCount,
    this.endless = false,
    this.maxGeneratedTiers = 24,
  }) : assert(
         thresholdRatio >= 2,
         'geometric ladders only: ratio >= 2 keeps coins-per-effort '
         'logarithmic (T-0105 economy contract)',
       ),
       assert(
         tierCount == null || tierCount >= 1,
         'a finite ladder has at least one tier',
       ),
       assert(
         endless ? tierCount == null : tierCount != null,
         'a ladder is either endless (tiers on demand) or finite '
         '(tierCount set)',
       ),
       assert(
         baseThreshold >= 1,
         'the first tier sits at a real effort',
       );

  /// Effort of tier 1 (e.g. 1 win, 10 goals).
  final int baseThreshold;

  /// Effort multiplier per tier — at least 2 by construction.
  final double thresholdRatio;

  /// Number of tiers in a FINITE ladder; null for endless ones.
  final int? tierCount;

  /// Whether tiers generate on demand forever (UI-capped only).
  final bool endless;

  /// UI-only cap: the highest tier index a list builder will
  /// materialise. Crossing it in play generates more — this cap
  /// protects widget builds, never the climb itself.
  final int maxGeneratedTiers;

  /// Effort required for tier [index] (1-based: index 1 is the
  /// first tier). Geometric: base * ratio^(index-1), rounded to the
  /// nearest integer (never below the previous tier + 1 — the
  /// monotonicity the catalog tests lock).
  int thresholdOf(int index) {
    assert(index >= 1);
    if (index == 1) return baseThreshold;
    final raw = baseThreshold * _pow(thresholdRatio, index - 1);
    return raw <= thresholdOf(index - 1)
        ? thresholdOf(index - 1) + 1
        : raw;
  }
}

/// An achievement tier: the rung at `threshold` effort, its flat coin
/// reward, its badge metal, and the title it confers (if any).
class AchievementTier {
  const AchievementTier({
    required this.index,
    required this.threshold,
    required this.coinReward,
    required this.badgeMetal,
    this.titleId,
  });

  /// 1-based rung number (tier 1 is the first).
  final int index;

  /// Effort that unlocks this rung.
  final int threshold;

  /// FLAT coin reward — the safety property: never grows with index
  /// on endless ladders (locked by tests).
  final int coinReward;

  /// Badge metal conferred at this rung.
  final BadgeMetal badgeMetal;

  /// Title conferred (ownership, not equipping — equipping is
  /// T-0112's surface).
  final String? titleId;
}

/// Integer-safe geometric power for the threshold math.
int _pow(double base, int exponent) {
  var result = 1.0;
  for (var i = 0; i < exponent; i++) {
    result *= base;
  }
  return result.round();
}

/// One achievement definition: what it measures, its category, its
/// ladder or one-time budget, and its l10n keys.
class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.category,
    required this.metricId,
    required this.titleKey,
    required this.descriptionKey,
    required this.hint,
    required this.kind,
    required this.ladder,
    this.milestoneReward,
    this.confersTitles = false,
  }) : assert(
         kind != AchievementKind.milestone || milestoneReward != null,
         'a milestone needs its fixed budget',
       ),
       assert(
         kind != AchievementKind.endlessLadder || milestoneReward == null,
         'endless ladders pay flat per-tier coins, not a milestone '
         'budget',
       );

  /// Unique, stable identifier, e.g. `career_wins`.
  final String id;

  /// Owning category id.
  final String category;

  /// The metric this definition climbs (see T-0107's derivation).
  final String metricId;

  /// L10n key for the display name.
  final String titleKey;

  /// L10n key for the description.
  final String descriptionKey;

  /// One-line hint of what it measures (developer-facing doc).
  final String hint;

  /// Ladder vs milestone.
  final AchievementKind kind;

  /// The reward ladder (endless AND finite ladders carry one).
  final AchievementLadder ladder;

  /// Fixed budget for milestones; null on ladders.
  final int? milestoneReward;

  /// Whether this ladder's rungs confer TITLES (prestige): only the
  /// flagship definition of each category climbs into titles — the
  /// registry lives in the catalog data, and the title-integrity
  /// test refuses a conferred id the registry does not know.
  final bool confersTitles;

  /// The tiers this definition exposes, generated from [ladder]:
  /// finite ladders materialise `tierCount` rungs; endless ones
  /// materialise up to `maxGeneratedTiers` (UI cap) — the game
  /// itself keeps climbing beyond it.
  ///
  /// Badge metals climb proportionally with the climb: the last fifth
  /// of an endless ladder's UI horizon is legend-tier, the one before
  /// it platinum — prestige tracks progress, not coins.
  List<AchievementTier> tiers(AchievementEconomyConfig economy) {
    final count = ladder.endless
        ? ladder.maxGeneratedTiers
        : ladder.tierCount!;
    final flat = economy.flatCoinRewardFor(this);
    final metals = BadgeMetal.values;
    return List.generate(count, (i) {
      final index = i + 1;
      // Proportional slot: index 1 of N lands at the first metal, N
      // lands at the last. Scaled to (metals.length - 1) so a 1-tier
      // milestone sits on bronze and the ladder's top rung is legend.
      final slot = count == 1
          ? 0
          : (index - 1) * (metals.length - 1) ~/ (count - 1);
      return AchievementTier(
        index: index,
        threshold: ladder.thresholdOf(index),
        coinReward: flat,
        badgeMetal: metals[slot.clamp(0, metals.length - 1)],
        titleId: _titleFor(index),
      );
    });
  }

  /// Title ladder: rungs 3 and 6 of a title-conferring endless
  /// ladder grant the registry's two titles per flagship.
  String? _titleFor(int index) {
    if (!ladder.endless || !confersTitles) return null;
    // Rungs 3 and 6 grant title1/title2 (the registry's two per
    // flagship). Beyond tier 6 the climb continues for badge metals —
    // titles are prestige, deliberately capped where the registry
    // ends; a third title is one registry entry + one arb key pair.
    return switch (index) { 3 => '$id-title1', 6 => '$id-title2', _ => null };
  }
}

/// A title: the prestige string the profile can equip (T-0112).
class TitleDefinition {
  const TitleDefinition({required this.id, required this.l10nKey});

  /// Unique identifier, e.g. `career_wins-title1`.
  final String id;

  /// L10n key for the display text.
  final String l10nKey;
}

/// Division championship titles: one per division, generated on
/// demand for divisions beyond the seeded five.
class DivisionTitleDefinition {
  const DivisionTitleDefinition({required this.division});

  /// The division this championship titles (division 1 = start).
  final int division;

  /// Stable id: `division_champion_$division`.
  String get id => 'division_champion_$division';

  /// L10n key with the division placeholder.
  String get l10nKey => 'achievementDivisionChampion';

  /// The seeded divisions (1..5); six and beyond generate on demand
  /// through [AchievementCatalog.divisionChampionTitle].
  static const List<int> seededDivisions = [1, 2, 3, 4, 5];
}
