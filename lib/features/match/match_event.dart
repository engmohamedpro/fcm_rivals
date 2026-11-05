/// FCM Rivals — match event records and engine inputs (GDD 12, GDD 26).
///
/// Extracted from `match_engine.dart` (app-structure review, task
/// `2026-11-05_app-structure_split-match-engine`): the pure data layer
/// the engine, the report and the session layer all consume.
/// Behaviour-identical move; `match_engine.dart` re-exports this file.
library;

import '../../core/domain/players.dart';
import 'stamina.dart';
import 'tactics.dart';


/// Which side an event belongs to.
enum MatchSide { home, away }

enum MatchEventType {
  kickoff,
  halfTime,
  fullTime,
  possession,
  passMove,
  dispossessed,
  offside,
  foul,
  penaltyAwarded,
  corner,
  shot,
  goal,
  card,
  substitution,
  tacticalChange,
  liveAction,
}

/// Outcome of a shot event (GDD 12.3 step 9).
enum ShotOutcome { goal, saved, offTarget, blocked }

/// Chance quality tiers feeding shot selection and xG.
enum ChanceQuality { normal, bigChance, header, freeKick, penalty }

/// One recorded match event (GDD 26.3). Statistics, commentary and player
/// ratings all derive from these records — never from side calculations.
class MatchEvent {
  const MatchEvent({
    required this.eventId,
    required this.minute,
    required this.second,
    required this.type,
    required this.side,
    required this.teamId,
    this.primaryPlayerId,
    this.secondaryPlayerId,
    this.shotOutcome,
    this.quality,
    this.xg,
    this.metadata = const {},
  });

  final int eventId;
  final int minute;
  final int second;
  final MatchEventType type;
  final MatchSide side;
  final int teamId;

  /// Shooter / tackler / fouler / substituted-off player, by context.
  final int? primaryPlayerId;

  /// Assister / dispossessed player / substituted-in player, by context.
  final int? secondaryPlayerId;

  final ShotOutcome? shotOutcome;
  final ChanceQuality? quality;

  /// Expected goals of a shot (GDD 13.2 xG).
  final double? xg;

  /// Free-form context: passes, crosses, card color, reasons...
  final Map<String, dynamic> metadata;

  bool get isShot => type == MatchEventType.shot;
  bool get isGoal => type == MatchEventType.goal;
}

/// A player as seen by the engine: plain data so the engine stays portable
/// (GDD 29). Constructed from `PlayerCard` by the wiring layer.
class MatchPlayer {
  MatchPlayer({
    required this.playerId,
    required this.name,
    required this.position,
    required this.attack,
    required this.support,
    required this.defence,
    required this.goalkeeping,
    this.stamina = 100,
  });

  final int playerId;
  final String name;

  /// Natural position (used for stat weighting and ratings).
  final Position position;

  /// Pre-upgrade effective attributes (upgrades already applied by the
  /// caller); the engine scales them by stamina (GDD 12.2).
  final int attack;
  final int support;
  final int defence;
  final int goalkeeping;

  /// Current stamina 0..100 (GDD 11.1). Mutated by the engine.
  double stamina;

  /// Minutes on the pitch this match.
  int minutesPlayed = 0;

  int yellowCards = 0;
  bool sentOff = false;

  MatchPlayer clone() =>
      MatchPlayer(
          playerId: playerId,
          name: name,
          position: position,
          attack: attack,
          support: support,
          defence: defence,
          goalkeeping: goalkeeping,
          stamina: stamina,
        )
        ..minutesPlayed = minutesPlayed
        ..yellowCards = yellowCards
        ..sentOff = sentOff;
}

/// One team's setup (GDD 26.1): identity, tactics, XI and bench.
class MatchTeamInput {
  MatchTeamInput({
    required this.teamId,
    required this.teamName,
    required this.formationCode,
    required this.tactics,
    required this.mentality,
    required List<MatchPlayer> starters,
    required this.bench,
    this.aiControlled = false,
  }) : assert(starters.length == 11, 'starting XI must have 11 players'),
       starters = List.of(starters);

  final int teamId;
  final String teamName;
  final String formationCode;
  final TeamTactics tactics;
  final Mentality mentality;

  /// Starting XI in formation-slot order (slot 0 = goalkeeper).
  final List<MatchPlayer> starters;

  /// Bench players available for substitution (max 5 used, FR-023).
  final List<MatchPlayer> bench;

  /// Whether the engine's AI may adapt this team's tactics (GDD 12.6).
  final bool aiControlled;
}

/// Tunable engine parameters — calibrated against real football
/// distributions (§31 simulation): ~2.6 goals/match at even strength,
/// a favourite's edge that SATURATES instead of exploding, ~22 fouls
/// and ~4 yellows a match, shots 9–14 per team (GDD rule 14 keeps all
/// of them configurable in this one place).
class MatchEngineConfig {
  const MatchEngineConfig({
    this.homeAdvantage = 1.07,
    this.staminaConfig = defaultStaminaConfig,
    this.segmentWeights = const [0.18, 0.55, 0.27],
    this.buildUpBase = 0.28,
    this.buildUpScale = 0.62,
    this.chanceBase = 0.01,
    this.chanceScale = 0.37,
    this.chanceMax = 0.43,
    this.chanceSigmoidMid = 4.0,
    this.chanceSigmoidSteepness = 0.085,
    this.shotFromChance = 0.82,
    this.speculativeShotChance = 0.14,
    this.blockChance = 0.28,
    this.onTargetBase = 0.17,
    this.onTargetScale = 0.25,
    this.goalBase = 0.20,
    this.goalScale = 0.126,
    this.goalDiffScale = 0.22,
    this.foulOnTurnover = 0.50,
    this.inBoxFoulChance = 0.013,
    this.penaltyOnTarget = 0.93,
    this.penaltyGoalBase = 0.82,
    this.penaltyGoalEdgeScale = 0.10,
    this.yellowCardChance = 0.17,
    this.straightRedChance = 0.001,
    this.offsideChance = 0.07,
    this.cornerFromBlock = 0.62,
    this.cornerFromCross = 0.35,
    this.cornerFromSave = 0.30,
    this.headerFromCorner = 0.28,
    this.assistChance = 0.70,
    this.aiMinMinutesBetweenChanges = 10,
    this.aiMaxChanges = 2,
    this.liveActionDuration = 10,
    this.maxSubstitutions = 5,
  });

  /// Home advantage percentage boost (GDD 12.2 step 4; final value to be
  /// established through simulation — placeholder).
  final double homeAdvantage;

  final StaminaConfig staminaConfig;

  /// P(0/1/2 attack segments per minute).
  final List<double> segmentWeights;

  final double buildUpBase;
  final double buildUpScale;
  final double chanceBase;
  final double chanceScale;
  final double chanceMax;
  final double shotFromChance;

  /// P(a possession that didn't create a clear chance still ends in a
  /// low-quality shot) — the volume layer that puts real-world 11-13
  /// shots per team under the tactical chance layer.
  final double speculativeShotChance;
  final double blockChance;
  final double onTargetBase;
  final double onTargetScale;
  final double goalBase;
  final double goalScale;

  /// Sigmoid centre: the attack-minus-defence point where chance
  /// creation sits at its neutral rate. In engine points (~60+), so a
  /// +12 edge is roughly 'clear favourite', +20 'title winner vs
  /// relegation fodder'.
  final double chanceSigmoidMid;

  /// Sigmoid steepness per engine point of attack-minus-defence. Small
  /// (0.075): a full 20-point edge saturates near ~80% of the cap, it
  /// never reaches certainty.
  final double chanceSigmoidSteepness;

  /// Goal-rate sensitivity per point of shooter-minus-keeper edge —
  /// bounded linear, so a superstar facing a weak keeper converts maybe
  /// ten points higher, never 'scores every time'.
  final double goalDiffScale;

  final double foulOnTurnover;
  final double inBoxFoulChance;
  final double penaltyOnTarget;
  final double penaltyGoalBase;
  final double penaltyGoalEdgeScale;
  final double yellowCardChance;
  final double straightRedChance;
  final double offsideChance;
  final double cornerFromBlock;
  final double cornerFromCross;

  /// P(a saved shot ends in a corner for the attacking side) — the
  /// keeper parries it behind the goal line. Real football derives
  /// roughly a third of its corners from saves.
  final double cornerFromSave;
  final double headerFromCorner;
  final double assistChance;

  final int aiMinMinutesBetweenChanges;
  final int aiMaxChanges;
  final int liveActionDuration;
  final int maxSubstitutions;
}

const MatchEngineConfig defaultMatchEngineConfig = MatchEngineConfig();
