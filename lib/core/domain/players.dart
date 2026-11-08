/// FCM Rivals — core domain model.
///
/// Global base player data (immutable facts from the imported dataset) is kept
/// strictly separate from user-owned player instances (GDD 4.7 / SRS 25.1).
/// Pure Dart: no Flutter imports — the domain models run under plain
/// `dart run` (headless batch sims, the T-0060 probability probe).
library;

/// Local stand-in for Flutter's `@immutable` (analyzer-only annotation):
/// `@ImmutableMarker()` — const, zero runtime effect, keeps this file
/// pure Dart so it runs under plain `dart run`.
class ImmutableMarker {
  final List<String> fields;
  const ImmutableMarker([this.fields = const <String>[]]);
}

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
@ImmutableMarker()
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

  /// Attribute value by enum (GDD 7.1 primary attributes).
  int valueOf(PlayerAttribute attribute) {
    switch (attribute) {
      case PlayerAttribute.attack:
        return attack;
      case PlayerAttribute.support:
        return support;
      case PlayerAttribute.defence:
        return defence;
      case PlayerAttribute.goalkeeping:
        return goalkeeping;
    }
  }

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
/// Identity is the permanent [playerId]; mutable facts (value, position)
/// may change between dataset versions without changing identity.
/// The core data is deliberately minimal — name, nationality, position
/// and market value — no club, age or league affiliation.
@ImmutableMarker()
class BasePlayer {
  const BasePlayer({
    required this.playerId,
    required this.name,
    required this.position,
    required this.nationality,
    required this.marketValueEur,
    required this.baseStats,
  });

  /// Permanent unique identifier — the Transfermarkt player id.
  final int playerId;

  final String name;
  final Position position;
  final String nationality;

  /// Current Market Value in euros, as imported.
  final int marketValueEur;

  final BaseStats baseStats;

  BasePlayer copyWith({
    String? name,
    Position? position,
    String? nationality,
    int? marketValueEur,
    BaseStats? baseStats,
  }) => BasePlayer(
    playerId: playerId,
    name: name ?? this.name,
    position: position ?? this.position,
    nationality: nationality ?? this.nationality,
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
@ImmutableMarker()
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
  }) => OwnedPlayer(
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
