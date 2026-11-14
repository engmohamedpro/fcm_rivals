/// FCM Rivals — AI opponent data models (GDD 9.4).
///
/// The plain data classes describing AI clubs, their squads and the
/// real-player pool candidates, moved verbatim out of
/// `season_engine.dart` (T-0043); the engine imports and re-exports
/// them, so existing `season_engine.dart` imports keep working. Pure
/// Dart, no UI dependencies (GDD rule 4).
library;

import '../../core/domain/players.dart' show Position;
import '../match/tactics.dart';

import '../../core/domain/crest.dart' show CrestSpec;

/// A real player from the imported dataset, offered to the AI-club
/// generator as a squad candidate (GDD 9.4: AI squads are built from the
/// same player database the user collects — real names, real positions,
/// real attributes). Built by the SeasonStore from the persisted Players
/// rows; the engine stays pure Dart.
class AiPoolPlayer {
  const AiPoolPlayer({
    required this.playerId,
    required this.name,
    required this.position,
    required this.overall,
    required this.attack,
    required this.support,
    required this.defence,
    required this.goalkeeping,
  });

  final int playerId;
  final String name;
  final Position position;

  /// Base-stats overall rating (drives division banding).
  final int overall;
  final int attack;
  final int support;
  final int defence;
  final int goalkeeping;
}

/// A generated AI club definition (GDD 9.4): identity, tactics and squad
/// for one division, before persistence.
class AiClubDefinition {
  const AiClubDefinition({
    required this.name,
    required this.managerName,
    required this.crest,
    required this.formationCode,
    required this.tactics,
    required this.mentality,
    required this.players,
    required this.targetAverageOverall,
  });

  final String name;
  final String managerName;

  /// The club's full random crest (T-0099): shape + two palette colours
  /// + icon, drawn from the same seeded engine random so the league is
  /// reproducible crest-for-crest. [crestIndex] lives on as the spec's
  /// primary palette index for legacy consumers.
  final CrestSpec crest;
  final String formationCode;
  final TeamTactics tactics;
  final Mentality mentality;

  /// 18 players: starting XI in formation slot order plus 7 bench players
  /// (a smaller squad than the user's 23 — AI clubs don't open packs).
  /// With a real-player pool available these are REAL dataset players
  /// ([AiPlayerDefinition.realPlayerId] set); tiny test pools fall back
  /// to synthetic generation through the same attribute curve.
  final List<AiPlayerDefinition> players;

  final int targetAverageOverall;
}

/// One AI squad player (GDD 9.4): a real dataset player when
/// [realPlayerId] is set, otherwise a synthetic player generated through
/// the same BaseStatsGenerator curve as real players — inverted from the
/// target overall — so AI teams always have attribute parity with user
/// squads.
class AiPlayerDefinition {
  const AiPlayerDefinition({
    required this.name,
    required this.position,
    required this.attack,
    required this.support,
    required this.defence,
    required this.goalkeeping,
    this.realPlayerId,
    this.upgradeLevel = 0,
  });

  final String name;
  final Position position;
  final int attack;
  final int support;
  final int defence;
  final int goalkeeping;

  /// The real dataset player this squad entry represents, or null for the
  /// synthetic fallback. Persisted on AiPlayers so promoted/relegated
  /// clubs keep their identity across seasons.
  final int? realPlayerId;

  /// The club-wide uniform upgrade level applied when the squad's base
  /// average overall sits below the division target (GDD 9.6, owner
  /// decision 2026-11-09): the four attributes above are ALREADY the
  /// lifted effective values via `upgradedValue`. Debug/diagnostic only —
  /// not persisted, not shown in UI.
  final int upgradeLevel;
}

/// One persisted AI squad player with live condition, as needed for
/// between-match rotation decisions (the store maps database rows to
/// this; the engine picks the lineup).
class AiSquadPlayer {
  const AiSquadPlayer({
    required this.realPlayerId,
    required this.name,
    required this.position,
    required this.attack,
    required this.support,
    required this.defence,
    required this.goalkeeping,
    this.nationality = '',
    this.clubId = 0,
    this.clubName = '',
    this.isIcon = false,
  });

  final int? realPlayerId;
  final String name;
  final Position position;
  final int attack;
  final int support;
  final int defence;
  final int goalkeeping;

  /// Nationality of the dataset player ('' for the synthetic fallback) —
  /// feeds the engine's on-pitch chemistry (owner spec 2026-11-09).
  final String nationality;

  /// Real-world club of the dataset player (0 / '' for the synthetic
  /// fallback) — feeds the club half of the chemistry (owner request
  /// 2026-11-11).
  final int clubId;
  final String clubName;

  /// Icon players (owner request 2026-11-12): chemistry wildcards in
  /// both dimensions — see `chemistry.dart`. AI clubs never SIGN icons
  /// (the pool excludes them), but the flag rides for completeness.
  final bool isIcon;

}
