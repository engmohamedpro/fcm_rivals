/// FCM Rivals — match event records and engine inputs (GDD 12, GDD 26).
///
/// Extracted from `match_engine.dart` (app-structure review, task
/// `2026-11-05_app-structure_split-match-engine`): the pure data layer
/// the engine, the report and the session layer all consume.
/// Behaviour-identical move; `match_engine.dart` re-exports this file.
library;

import '../../core/domain/players.dart';
import 'injury.dart';
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
  injury,
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
    this.nationality = '',
    this.stamina = 100,
  });

  final int playerId;
  final String name;

  /// Natural position (used for stat weighting and ratings).
  final Position position;

  /// Pre-upgrade effective attributes (upgrades already applied by the
  /// caller); the engine applies them at full value (GDD 12.2 — fatigue
  /// decoupled: stamina never scales performance).
  final int attack;
  final int support;
  final int defence;
  final int goalkeeping;

  /// Nationality as imported from the dataset ('' for engine-level
  /// fixtures and synthetic squads). Players sharing a nationality on
  /// the pitch earn a chemistry bonus — see `chemistry.dart`.
  final String nationality;

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
          nationality: nationality,
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
    this.medicalCentreLevel = 0,
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

  /// This club's Medical Centre level 0..[InjuryConfig.maxMedicalCentreLevel]
  /// (GDD 11.7): reduces every player's injury risk. Engine-level tests
  /// stay at 0; the real level rides in via the session layer (T-0055).
  final int medicalCentreLevel;
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
    // Fatigue-decoupling re-anchor (T-0052, 2026-11-07): attributes apply
    // at FULL VALUE, so the attack-minus-defence edge entering this
    // logistic is ~16% wider than the stamina-scaled edge the old curve
    // was calibrated on (the removed per-player scaling compressed every
    // edge by the ~0.84 match-average stamina factor). Mid and steepness
    // are rescaled by that factor so the chance-response curve sees the
    // same effective edges as before — no behaviour change at even
    // strength, and the blowout/mismatch tails keep their calibrated
    // shape with the coupling gone.
    this.chanceSigmoidMid = 4.76,
    this.chanceSigmoidSteepness = 0.0714,
    this.shotFromChance = 0.82,
    this.speculativeShotChance = 0.14,
    this.blockChance = 0.28,
    // Underdog set-piece income (T-0114, 2026-11-10 — the T-0082
    // unblocking mechanism): an EDGE-INDEPENDENT chance stream for
    // the side out of possession, coupled to TERRITORY (the support
    // pocket share), never to attack-minus-defence — a corner is a
    // corner at OVR 70 or 105, which is exactly the stability the
    // chance layer's strength response lacks at big upgrade gaps
    // (measured: the underdog at +50% is pinned at the chanceP clamp
    // floor on ~30% of pockets, scoring 0.33 goals/match). OFF by
    // default (0.0): no draw, bit-identical output, every band and
    // the seeded snapshot untouched. T-0116 turns it on at the
    // probe-validated value with the two-direction ceiling locked.
    this.setPieceIncome = 0.0,
    // Fatigue-decoupling re-anchor (T-0052, 2026-11-07): attributes now
    // apply at FULL VALUE, so the shooter term in onTargetP sits at its
    // full-value level — the old base was calibrated against the removed
    // implicit stamina discount (avg shooter efficiency ≈ 0.85) and the
    // decoupling lifted the SoT share ~+3 points and goals ~+0.23/match.
    // 0.17 -> 0.14 restores the measured SoT/goals profile with the
    // shooter differentiation (onTargetScale) untouched.
    this.onTargetBase = 0.14,
    this.onTargetScale = 0.25,
    // Re-anchor twin of onTargetBase: with the shooter-vs-keeper edge at
    // full value the xG/shot level sat ~+0.006 above the calibrated
    // profile; 0.20 -> 0.19 re-centres it (differentiation via
    // goalDiffScale untouched). Measured against both conversion floors
    // and the xG/shot ceiling: 0.186 crossed the tier-70 conversion
    // floor (0.1145 < 0.115) and 0.19 keeps it; the residual tier-79
    // xG/shot overshoot is recorded in the T-0052 Developer Notes.
    this.goalBase = 0.19,
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
    this.injuryConfig = defaultInjuryConfig,
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

  /// The underdog set-piece income rate (T-0114) — see the
  /// constructor comment. 0.0 = the layer is fully inert (the random
  /// stream draw is SKIPPED, not drawn-and-ignored, so seeded output
  /// is bit-identical).
  final double setPieceIncome;

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

  /// Injury risk model (GDD 11.7, T-0053/T-0054): per-minute rolls run
  /// in [MatchEngine.advanceMinute] for every on-pitch player of both
  /// sides. Constants are pre-balance placeholders (GDD rule 14); the
  /// calibration gate is the `injuries` group in
  /// test/features/match/engine_calibration_test.dart.
  final InjuryConfig injuryConfig;
}

const MatchEngineConfig defaultMatchEngineConfig = MatchEngineConfig();
