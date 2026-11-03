/// FCM Rivals — club campus facilities (GDD 3.5).
///
/// A long-term coin sink with a small, always-on team payoff. Six
/// buildings, each with ten levels; every level costs more than the last
/// (geometric growth) so the campus stays a project the manager chips
/// away at across seasons, never a one-shopping-spree power spike.
///
/// Design intents:
///
///  * SLIGHT boosts — the match engine's totals move by a few percent
///    at realistic mid-levels (a level-5 academy is +4 attack on a
///    70-rated side: half a point per line). Facilities complement
///    squad quality; they never replace buying or upgrading players.
///  * TWO pace facilities for the stamina game (GDD 11): the recovery
///    centre speeds natural post-match recovery and the medical centre
///    ... is the injury-risk reducer, kept as a real hook even though
///    injuries themselves are forecast-only today — the level persists
///    and the UI shows the effect, so the system is live the day
///    injuries ship.
///  * Effects are visible (GDD 15's rule): the screen states exactly
///    what each level does in percentage points.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Everything the campus can build (GDD 3.5).
enum Facility {
  attack('Attack Academy', 'attack academy', Icons.sports_soccer_rounded,
      FacilityEffect.attribute(
          attribute: FacilityAttribute.attack, perLevelPercent: 0.9)),
  support('Playmaker Hub', 'playmaker hub', Icons.hub_rounded,
      FacilityEffect.attribute(
          attribute: FacilityAttribute.support, perLevelPercent: 0.9)),
  defence('Defence Forge', 'defence forge', Icons.shield_rounded,
      FacilityEffect.attribute(
          attribute: FacilityAttribute.defence, perLevelPercent: 0.9)),
  goalkeeping('Keeper School', 'keeper school',
      Icons.sports_handball_rounded, FacilityEffect.attribute(
          attribute: FacilityAttribute.goalkeeping, perLevelPercent: 1.1)),
  recovery('Recovery Centre', 'recovery centre', Icons.spa_rounded,
      FacilityEffect.recovery(2.5)),
  medical('Medical Centre', 'medical centre',
      Icons.medical_services_rounded, FacilityEffect.medical(0.6)),
  ;

  const Facility(this.title, this.subtitle, this.icon, this.effect);

  /// Display name.
  final String title;

  /// Short descriptor used in ledger detail lines.
  final String subtitle;

  final IconData icon;

  /// What one more level buys.
  final FacilityEffect effect;
}

/// Which attribute a training facility boosts.
enum FacilityAttribute { attack, support, defence, goalkeeping }

/// The concrete effect of a facility level. Attribute facilities add
/// `perLevelPercent` of each player's BASE attribute per level (applied
/// in the match input, so stamina scaling still rides on top); the
/// recovery centre adds to natural post-match recovery; the medical
/// centre reduces injury risk.
class FacilityEffect {
  const FacilityEffect.attribute({
    required FacilityAttribute attribute,
    required double perLevelPercent,
  })  : _attribute = attribute,
        _attributePerLevelPercent = perLevelPercent,
        recoveryPerLevelPercent = 0,
        injuryRiskPerLevel = 0;

  const FacilityEffect.recovery(double perLevelPercent)
      : _attribute = null,
        _attributePerLevelPercent = 0,
        recoveryPerLevelPercent = perLevelPercent,
        injuryRiskPerLevel = 0;

  const FacilityEffect.medical(double perLevelRisk)
      : _attribute = null,
        _attributePerLevelPercent = 0,
        recoveryPerLevelPercent = 0,
        injuryRiskPerLevel = perLevelRisk;

  final FacilityAttribute? _attribute;
  final double _attributePerLevelPercent;
  final double recoveryPerLevelPercent;
  final double injuryRiskPerLevel;

  /// Fraction of a base attribute added at [level] (0 for non-training
  /// facilities), e.g. level 4 of the 0.9%/level academy = 0.036.
  double attributeFractionAt(int level) =>
      _attribute == null ? 0 : _attributePerLevelPercent / 100 * level;

  /// Percentage points of natural recovery added at [level].
  double recoveryPercentAt(int level) => recoveryPerLevelPercent * level;

  /// Injury-risk percentage points removed at [level].
  double injuryRiskAt(int level) => injuryRiskPerLevel * level;

  /// One-line human description of the effect at [level] (GDD 15: the
  /// effect must be visible).
  String describeAt(int level) {
    if (_attribute != null) {
      final attr = switch (_attribute) {
        FacilityAttribute.attack => 'Attack',
        FacilityAttribute.support => 'Support',
        FacilityAttribute.defence => 'Defence',
        FacilityAttribute.goalkeeping => 'Goalkeeping',
      };
      final pts = attributeFractionAt(level) * 100;
      return '+${pts.toStringAsFixed(pts.truncateToDouble() == pts ? 0 : 1)}% '
          '$attr for every player';
    }
    if (recoveryPerLevelPercent > 0) {
      return '+${recoveryPercentAt(level).toStringAsFixed(1)}% natural '
          'recovery after matches';
    }
    return '−${injuryRiskAt(level).toStringAsFixed(1)}% injury risk';
  }

  /// Whether this facility's effect is live in the match input today.
  bool get isMatchLive => _attribute != null;
}

/// Cost curve (GDD 17.5-style escalation): level 1 costs [baseCost] and
/// every following level multiplies by [growth] — so late levels feel
/// like the big-money project they are, while the first two or three
/// upgrades stay affordable early in a club's life.
class FacilitiesCosts {
  const FacilitiesCosts({
    this.baseCost = 4_000,
    this.growth = 1.55,
    this.maxLevel = 10,
  });

  final int baseCost;
  final double growth;
  final int maxLevel;

  /// Coin price to go from [currentLevel] to currentLevel + 1.
  int upgradeCost(int currentLevel) {
    if (currentLevel >= maxLevel) return 0;
    final cost = baseCost * math.pow(growth, currentLevel);
    return (cost / 100).round() * 100;
  }

  /// Total coins sunk into a facility at [level] — the screen shows it
  /// so the escalating curve is legible.
  int investedAt(int level) {
    var total = 0;
    for (var l = 0; l < level; l++) {
      total += upgradeCost(l);
    }
    return total;
  }

}

/// Default campus economy: level 1 at 4k coins (a couple of match
/// rewards), level 10 at ~150k — a full season-plus project per
/// building, ~2M for the whole campus.
const FacilitiesCosts defaultFacilitiesCosts = FacilitiesCosts();

/// Immutable campus snapshot: level per facility, straight from the
/// FacilityLevels rows (missing row = level 0).
class CampusLevels {
  const CampusLevels(this._byFacility);

  final Map<Facility, int> _byFacility;

  static const CampusLevels empty = CampusLevels({});

  int levelOf(Facility f) => _byFacility[f] ?? 0;

  /// Fraction of BASE attribute added per player at current levels
  /// (match-input hook): only training facilities contribute.
  ({
    double attack,
    double support,
    double defence,
    double goalkeeping,
  }) get attributeFractions {
    double attack = 0, support = 0, defence = 0, goalkeeping = 0;
    for (final f in Facility.values) {
      final e = f.effect;
      final frac = e.attributeFractionAt(levelOf(f));
      switch (e._attribute) {
        case FacilityAttribute.attack:
          attack += frac;
        case FacilityAttribute.support:
          support += frac;
        case FacilityAttribute.defence:
          defence += frac;
        case FacilityAttribute.goalkeeping:
          goalkeeping += frac;
        case null:
          break;
      }
    }
    return (
      attack: attack,
      support: support,
      defence: defence,
      goalkeeping: goalkeeping,
    );
  }

  /// Percentage points added to natural post-match recovery (GDD 11.5).
  double get recoveryBonusPercent {
    var bonus = 0.0;
    for (final f in Facility.values) {
      bonus += f.effect.recoveryPercentAt(levelOf(f));
    }
    return bonus;
  }

  /// Injury-risk percentage points removed (forecast/GDD 14 hook).
  double get injuryRiskReductionPercent {
    var reduction = 0.0;
    for (final f in Facility.values) {
      reduction += f.effect.injuryRiskAt(levelOf(f));
    }
    return reduction;
  }
}
