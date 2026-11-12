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

  /// Perf pass 2026-11-12 (L6): code → enum lookup map. `fromCode` runs
  /// once per row on the 40-51k-row dataset import and in other per-row
  /// paths (AI squads, warm-up rebuilds) — the old `firstWhere` scanned
  /// up to 12 entries and allocated a closure per call. The map is
  /// eagerly built (12 entries) and keyed by the upper-cased code.
  static final Map<String, Position> _byCode = {
    for (final p in Position.values) p.code: p,
  };

  static Position fromCode(String code) =>
      _byCode[code.toUpperCase()] ??
      (throw ArgumentError('Unknown position code: $code'));

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

/// Effective value of [baseValue] at upgrade level [upgradeLevel]
/// (owner decision 2026-11-09): each level adds +1% of the BASE value —
/// linear, not compounding — with no 99 cap (the game is infinite).
/// Examples: 90 at +1 → 91, at +2 → 92, at +11 → 100, at +20 → 108;
/// 60 at +3 → 62. Negative levels clamp to 0 (the base itself).
int upgradedValue(int baseValue, int upgradeLevel) {
  final level = upgradeLevel < 0 ? 0 : upgradeLevel;
  return baseValue + (baseValue * level / 100).round();
}

/// A global player record from the imported database (GDD 4.2).
/// Identity is the permanent [playerId]; mutable facts (value, position)
/// may change between dataset versions without changing identity.
/// The core data stays minimal — name, nationality, position and market
/// value — plus the presentation facts carried since dataset v3: the
/// Transfermarkt portrait URL and the player's real-world club and
/// domestic league (names + CDN links, '' when the source tracks none).
@ImmutableMarker()
class BasePlayer {
  const BasePlayer({
    required this.playerId,
    required this.name,
    required this.position,
    required this.nationality,
    required this.marketValueEur,
    required this.baseStats,
    this.clubId = 0,
    this.clubName = '',
    this.clubCrestUrl = '',
    this.leagueName = '',
    this.leagueLogoUrl = '',
    this.imageUrl = '',
    this.isIcon = false,
  });

  /// Permanent unique identifier — the Transfermarkt player id.
  final int playerId;

  final String name;
  final Position position;
  final String nationality;

  /// Current Market Value in euros, as imported.
  final int marketValueEur;

  final BaseStats baseStats;

  /// The player's real-world club on Transfermarkt (0 when untracked —
  /// free agents and players outside the scraped leagues).
  final int clubId;

  /// Club display name ('' when unknown) and crest link.
  final String clubName;
  final String clubCrestUrl;

  /// Domestic league display name ('' when the club carries no league
  /// in the source) and its logo link.
  final String leagueName;
  final String leagueLogoUrl;

  /// Transfermarkt portrait link ('' for the ~1,400 players whose only
  /// source image is the CDN placeholder — the app renders its own
  /// fallback for those).
  final String imageUrl;

  /// Icon players (owner request 2026-11-12): the legends of the game —
  /// the 73 rows of `tm-icons.json`. Icons are drawn exclusively from
  /// the store's three Icon packs (never from position packs), render
  /// with the holo `PlayerCardRarity.icon` treatment, and on the pitch
  /// they are chemistry WILDCARDS: an icon groups with every player in
  /// BOTH dimensions (nationality and club) — see `chemistry.dart`.
  final bool isIcon;

  BasePlayer copyWith({
    String? name,
    Position? position,
    String? nationality,
    int? marketValueEur,
    BaseStats? baseStats,
    int? clubId,
    String? clubName,
    String? clubCrestUrl,
    String? leagueName,
    String? leagueLogoUrl,
    String? imageUrl,
    bool? isIcon,
  }) => BasePlayer(
    playerId: playerId,
    name: name ?? this.name,
    position: position ?? this.position,
    nationality: nationality ?? this.nationality,
    marketValueEur: marketValueEur ?? this.marketValueEur,
    baseStats: baseStats ?? this.baseStats,
    clubId: clubId ?? this.clubId,
    clubName: clubName ?? this.clubName,
    clubCrestUrl: clubCrestUrl ?? this.clubCrestUrl,
    leagueName: leagueName ?? this.leagueName,
    leagueLogoUrl: leagueLogoUrl ?? this.leagueLogoUrl,
    imageUrl: imageUrl ?? this.imageUrl,
    isIcon: isIcon ?? this.isIcon,
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
