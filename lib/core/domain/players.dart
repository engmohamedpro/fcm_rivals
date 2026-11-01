/// FCM Rivals — core domain model.
///
/// Global base player data (immutable facts from the imported dataset) is kept
/// strictly separate from user-owned player instances (GDD 4.7 / SRS 25.1).
library;

import 'package:flutter/foundation.dart';

/// The 12 supported field positions (GDD 4.3).
enum Position {
  st('ST'),
  lw('LW'),
  rw('RW'),
  cam('CAM'),
  lm('LM'),
  rm('RM'),
  cm('CM'),
  cdm('CDM'),
  cb('CB'),
  rb('RB'),
  lb('LB'),
  gk('GK');

  const Position(this.code);
  final String code;

  static Position fromCode(String code) =>
      Position.values.firstWhere((p) => p.code == code.toUpperCase());

  /// Positions this player can reasonably play outside his primary slot.
  /// Used by Auto Pick and squad validation (compatibility, not equality).
  static const Set<Position> goalkeepers = {Position.gk};

  bool get isGoalkeeper => this == Position.gk;
}

/// The four visible primary attributes (GDD 7.1).
enum PlayerAttribute { attack, support, defence, goalkeeping }

/// Base stats derived from Market Value and Position via the non-linear
/// generation curve (GDD 4.5). Regenerated only when Market Value or Position
/// changes on a dataset update (GDD 4.6).
@immutable
class BaseStats {
  const BaseStats({
    required this.overall,
    required this.attack,
    required this.support,
    required this.defence,
    required this.goalkeeping,
  });

  final int overall;
  final int attack;
  final int support;
  final int defence;
  final int goalkeeping;

  @override
  bool operator ==(Object other) =>
      other is BaseStats &&
      other.overall == overall &&
      other.attack == attack &&
      other.support == support &&
      other.defence == defence &&
      other.goalkeeping == goalkeeping;

  @override
  int get hashCode =>
      Object.hash(overall, attack, support, defence, goalkeeping);

  @override
  String toString() =>
      'BaseStats(OVR $overall, ATT $attack, SUP $support, DEF $defence, GK $goalkeeping)';
}

/// A global player record from the imported database (GDD 4.2).
/// Identity is the permanent [playerId]; mutable facts (club, age, value,
/// position) may change between dataset versions without changing identity.
@immutable
class BasePlayer {
  const BasePlayer({
    required this.playerId,
    required this.name,
    required this.position,
    required this.age,
    required this.nationality,
    required this.club,
    required this.leagueCode,
    required this.marketValueEur,
    required this.baseStats,
  });

  /// Permanent unique identifier — the Transfermarkt player id.
  final int playerId;

  final String name;
  final Position position;
  final int age;
  final String nationality;
  final String club;

  /// Domestic league competition code of the club ('' for free agents).
  final String leagueCode;

  /// Current Market Value in euros, as imported.
  final int marketValueEur;

  final BaseStats baseStats;

  BasePlayer copyWith({
    String? name,
    Position? position,
    int? age,
    String? nationality,
    String? club,
    String? leagueCode,
    int? marketValueEur,
    BaseStats? baseStats,
  }) =>
      BasePlayer(
        playerId: playerId,
        name: name ?? this.name,
        position: position ?? this.position,
        age: age ?? this.age,
        nationality: nationality ?? this.nationality,
        club: club ?? this.club,
        leagueCode: leagueCode ?? this.leagueCode,
        marketValueEur: marketValueEur ?? this.marketValueEur,
        baseStats: baseStats ?? this.baseStats,
      );

  @override
  bool operator ==(Object other) =>
      other is BasePlayer && other.playerId == playerId;

  @override
  int get hashCode => playerId;

  @override
  String toString() => '#$playerId $name (${position.code})';
}

/// A user-owned copy of a [BasePlayer] (SRS 25.1).
/// Upgrades live here and must never leak into the global record (GDD 8.3).
@immutable
class OwnedPlayer {
  const OwnedPlayer({
    required this.ownedId,
    required this.playerId,
    required this.upgradeLevel,
    required this.upgradedAttributes,
    required this.acquiredAt,
    this.staminaPercent = 100,
  });

  /// Stable identifier of this owned instance.
  final int ownedId;

  /// Foreign key to the global [BasePlayer.playerId].
  final int playerId;

  /// Number of duplicate merges applied (GDD 8.1).
  final int upgradeLevel;

  /// Attribute points added by upgrades, per attribute (GDD 8.2).
  final Map<PlayerAttribute, int> upgradedAttributes;

  final DateTime acquiredAt;

  /// Current stamina 0..100 (GDD 11.1).
  final int staminaPercent;

  OwnedPlayer copyWith({
    int? upgradeLevel,
    Map<PlayerAttribute, int>? upgradedAttributes,
    int? staminaPercent,
  }) =>
      OwnedPlayer(
        ownedId: ownedId,
        playerId: playerId,
        upgradeLevel: upgradeLevel ?? this.upgradeLevel,
        upgradedAttributes: upgradedAttributes ?? this.upgradedAttributes,
        acquiredAt: acquiredAt,
        staminaPercent: staminaPercent ?? this.staminaPercent,
      );

  @override
  bool operator ==(Object other) =>
      other is OwnedPlayer && other.ownedId == ownedId;

  @override
  int get hashCode => ownedId;
}
