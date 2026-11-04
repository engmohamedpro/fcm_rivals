/// FCM Rivals — Match Engine (GDD 12, GDD 26, FR-024..FR-029).
///
/// Simulates football through a structured event pipeline (GDD 12.3):
/// possession → build-up → progression → defensive pressure → chance
/// creation → shot selection → accuracy → goalkeeper reaction → outcome.
/// Goals emerge from these events only.
///
/// v2 — calibrated against real football distributions (see
/// test/features/match/engine_calibration_test.dart): ~2.7 goals/match
/// at even strength with the real share of 0-0s and 1-0s, 11-13 shots
/// per team at a 33-39% on-target share, 8-11 corners, 3.5-5.5 offsides,
/// 3-4 yellows with rare reds, big chances converting near 30%, and a
/// goal-timing curve that opens up late (19-25% of goals in the final
/// fifteen minutes) through a bounded defensive-fatigue term. The
/// strength response SATURATES: chance creation follows a logistic
/// curve in attack-minus-defence (a 17-point class gap is a ~80%
/// favourite, not a 9-1) and shot conversion moves only a few points
/// per edge, so blowouts stay as rare as they are in real leagues. A
/// speculative-shot layer puts real-world shot volume under the
/// tactical chance layer.
///
/// Pure Dart, widget-independent (GDD development rule 4) and shaped for a
/// future authoritative server port (GDD 29): inputs are plain values, the
/// PRNG is a seeded single stream (GDD 12.5) and user commands are applied
/// chronologically without recalculating completed events (GDD 26.4).
library;

import 'dart:math' as math;

import '../../core/domain/players.dart';
import '../squad/formations.dart';
import '../squad/squad_engine.dart';
import 'stamina.dart';
import 'tactics.dart';

/// Engine identity for deterministic replay records (GDD 12.5).
const int matchEngineVersion = 2;

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
    required this.style,
    required this.mentality,
    required List<MatchPlayer> starters,
    required this.bench,
    this.aiControlled = false,
  }) : assert(starters.length == 11, 'starting XI must have 11 players'),
       starters = List.of(starters);

  final int teamId;
  final String teamName;
  final String formationCode;
  final PlayingStyle style;
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

/// Match commands (GDD 26.4): timestamped user (or AI) actions, applied in
/// chronological order. [atMinute] is the match minute at which the change
/// takes effect; commands queued mid-match take effect from the next
/// simulated minute onward and never recalculate past events (FR-029).
abstract class MatchCommand {
  const MatchCommand({required this.atMinute, required this.side});

  final int atMinute;
  final MatchSide side;
}

class ChangeFormationCommand extends MatchCommand {
  const ChangeFormationCommand({
    required super.atMinute,
    required super.side,
    required this.formationCode,
  });

  final String formationCode;
}

class ChangeStyleCommand extends MatchCommand {
  const ChangeStyleCommand({
    required super.atMinute,
    required super.side,
    required this.style,
  });

  final PlayingStyle style;
}

class ChangeMentalityCommand extends MatchCommand {
  const ChangeMentalityCommand({
    required super.atMinute,
    required super.side,
    required this.mentality,
  });

  final Mentality mentality;
}

class SubstitutionCommand extends MatchCommand {
  const SubstitutionCommand({
    required super.atMinute,
    required super.side,
    required this.outPlayerId,
    required this.inPlayerId,
  });

  final int outPlayerId;
  final int inPlayerId;
}

class LiveActionCommand extends MatchCommand {
  const LiveActionCommand({
    required super.atMinute,
    required super.side,
    required this.action,
  });

  final LiveMatchAction action;
}

/// A pre-match or half-time pep talk (GDD 15): team-wide multipliers that
/// never expire — a pre-match talk runs from kick-off, a half-time talk
/// from the second half. Replaces any earlier talk (no stacking), and
/// like every command it affects future events only.
class PepTalkCommand extends MatchCommand {
  const PepTalkCommand({
    required super.atMinute,
    required super.side,
    required this.talk,
  });

  final MatchPepTalk talk;
}

/// Effective team totals (GDD 12.2): stamina-scaled individual attributes
/// aggregated with slot role weights, then modified by mentality, playing
/// style and home advantage — in that exact order.
class TeamTotals {
  const TeamTotals({
    required this.attack,
    required this.support,
    required this.defence,
    required this.goalkeeping,
  });

  final double attack;
  final double support;
  final double defence;
  final double goalkeeping;
}

/// Neutral squad-quality totals for the pre-match forecast (GDD 13): the
/// role-weighted mean of EVERY player's raw attributes keyed by natural
/// position — the whole squad list (starting XI + bench + reserves) counts
/// alike, with no formation slots, no stamina scaling, no tactics, no
/// mentality and no home edge. A like-for-like measure of what each squad
/// is worth on paper.
TeamTotals squadQualityTotals(List<MatchPlayer> squad) {
  double attackSum = 0, supportSum = 0, defenceSum = 0;
  var attackW = 0.0, supportW = 0.0, defenceW = 0.0;
  double gkSum = 0;
  var gkCount = 0;
  for (final p in squad) {
    final pos = p.position;
    final aw = _MatchEngineRole.attack[pos]!;
    final sw = _MatchEngineRole.support[pos]!;
    final dw = _MatchEngineRole.defence[pos]!;
    attackSum += p.attack * aw;
    attackW += aw;
    supportSum += p.support * sw;
    supportW += sw;
    defenceSum += p.defence * dw;
    defenceW += dw;
    if (pos == Position.gk) {
      gkSum += p.goalkeeping;
      gkCount++;
    }
  }
  return TeamTotals(
    attack: attackW > 0 ? attackSum / attackW : 0,
    support: supportW > 0 ? supportSum / supportW : 0,
    defence: defenceW > 0 ? defenceSum / defenceW : 0,
    // No goalkeeper in the list at all: the engine's fallback for a
    // missing keeper applies (GDD 12.3 step 8).
    goalkeeping: gkCount > 0 ? gkSum / gkCount : 40,
  );
}

/// Public match snapshot for UI and persistence (GDD 26.1).
class MatchState {
  const MatchState({
    required this.minute,
    required this.scoreHome,
    required this.scoreAway,
    required this.isFinished,
    required this.isHalfTime,
    required this.substitutionsHome,
    required this.substitutionsAway,
  });

  final int minute;
  final int scoreHome;
  final int scoreAway;
  final bool isFinished;
  final bool isHalfTime;
  final int substitutionsHome;
  final int substitutionsAway;
}

/// The deterministic match simulator.
class MatchEngine {
  MatchEngine({
    required MatchTeamInput home,
    required MatchTeamInput away,
    required int seed,
    this.config = defaultMatchEngineConfig,
  }) : _home = _TeamRuntime.from(home),
       _away = _TeamRuntime.from(away),
       _random = MatchRandom(seed) {
    // Stoppage deterministically drawn once at setup (GDD 12.5: one seed,
    // one stream — stoppage is part of that stream).
    _firstHalfStoppage = 1 + _random.nextInt(3);
    _secondHalfStoppage = 1 + _random.nextInt(4);
    _halfTimeMinute = 45 + _firstHalfStoppage;
    _fullTimeMinute = 90 + _secondHalfStoppage + _firstHalfStoppage;
  }

  final MatchEngineConfig config;
  final MatchRandom _random;
  final _TeamRuntime _home;
  final _TeamRuntime _away;

  late final int _firstHalfStoppage;
  late final int _secondHalfStoppage;
  late final int _halfTimeMinute;
  late final int _fullTimeMinute;

  int _minute = 0;
  int _eventId = 0;
  bool _finished = false;
  bool _halfTimeReached = false;
  int _scoreHome = 0;
  int _scoreAway = 0;
  final List<MatchEvent> _events = [];
  final List<MatchCommand> _pending = [];
  final List<MatchCommand> _applied = [];
  final Set<int> _involvedThisMinute = {};

  /// All events so far (GDD 26.4: the single source for commentary,
  /// statistics and ratings).
  List<MatchEvent> get events => List.unmodifiable(_events);

  /// Commands actually applied, in order — the replay record (GDD 12.5).
  List<MatchCommand> get appliedCommands => List.unmodifiable(_applied);

  MatchState get state => MatchState(
    minute: _minute,
    scoreHome: _scoreHome,
    scoreAway: _scoreAway,
    isFinished: _finished,
    isHalfTime: _halfTimeReached && _minute == _halfTimeMinute,
    substitutionsHome: _home.substitutionsUsed,
    substitutionsAway: _away.substitutionsUsed,
  );

  bool get isFinished => _finished;
  int get seed => _random.initialSeed;

  /// Effective team totals for one side at this instant.
  TeamTotals totalsOf(MatchSide side) => _runtimeOf(side).computeTotals(
    isHome: side == MatchSide.home,
    homeAdvantage: config.homeAdvantage,
    actionModifiers: _activeActionModifiersOf(side),
  );

  /// Every player of one side with final (live) state — for post-match
  /// stamina persistence, ratings and recovery.
  List<MatchPlayer> playersOf(MatchSide side) {
    final rt = _runtimeOf(side);
    return [
      for (final p in rt.onPitch.whereType<MatchPlayer>()) p,
      ...rt.bench,
      ...rt.offPitch,
    ];
  }

  /// Players currently on the pitch for [side], formation-slot order —
  /// for the live substitution UI. Empty slots (sent off) are skipped.
  List<MatchPlayer> onPitchOf(MatchSide side) {
    final rt = _runtimeOf(side);
    return [for (final p in rt.onPitch.whereType<MatchPlayer>()) p];
  }

  /// Bench players for [side] still available to come on.
  List<MatchPlayer> benchOf(MatchSide side) => [..._runtimeOf(side).bench];

  /// Substitutions used so far by [side] (of config.maxSubstitutions).
  int substitutionsUsedOf(MatchSide side) => _runtimeOf(side).substitutionsUsed;

  /// Current formation code of [side] — the live tactics UI marks the
  /// active choice.
  String formationOf(MatchSide side) => _runtimeOf(side).formation.code;

  /// Current playing style of [side] (GDD 10.2).
  PlayingStyle styleOf(MatchSide side) => _runtimeOf(side).style;

  /// Current mentality of [side] (GDD 10.3).
  Mentality mentalityOf(MatchSide side) => _runtimeOf(side).mentality;

  /// Queues a command; it is applied at the next minute boundary with
  /// atMinute <= that minute (GDD 10.4: changes affect future events
  /// immediately, never past ones).
  void queueCommand(MatchCommand command) {
    if (_finished) {
      throw StateError('The match is finished');
    }
    _pending.add(command);
  }

  /// Simulates one match minute and returns the events it produced.
  List<MatchEvent> advanceMinute() {
    if (_finished) {
      throw StateError('The match is finished');
    }
    final minute = _minute + 1;
    final produced = <MatchEvent>[];
    // Commands first: their events belong to the minute that applies them.
    produced.addAll(_applyDueCommands(minute));
    _minute = minute;
    _involvedThisMinute.clear();

    if (minute == 1) {
      produced.add(
        _emit(minute: 0, type: MatchEventType.kickoff, side: MatchSide.home),
      );
    } else if (minute == _halfTimeMinute + 1) {
      produced.add(
        _emit(
          minute: minute,
          type: MatchEventType.kickoff,
          side: MatchSide.away,
          metadata: {'secondHalf': true},
        ),
      );
    }

    // Attack segments this minute (GDD 12.3 steps 1-9).
    final segments = _drawSegmentCount();
    for (var s = 0; s < segments; s++) {
      produced.addAll(_simulateSegment(minute));
    }

    // Stamina drain for everyone on the pitch (GDD 11.3: bench doesn't
    // consume; GDD 11.4: dynamic workload).
    _drainStamina();

    // AI adaptation (GDD 12.6) — reasoning recorded as events.
    produced.addAll(_maybeAdaptAi(MatchSide.home, minute));
    produced.addAll(_maybeAdaptAi(MatchSide.away, minute));

    if (minute == _halfTimeMinute) {
      _halfTimeReached = true;
      produced.add(
        _emit(
          minute: minute,
          type: MatchEventType.halfTime,
          side: MatchSide.home,
        ),
      );
    }
    if (minute >= _fullTimeMinute) {
      _finished = true;
      produced.add(
        _emit(
          minute: minute,
          type: MatchEventType.fullTime,
          side: MatchSide.home,
        ),
      );
    }
    return produced;
  }

  /// Runs the match to full time (live UI drives advanceMinute instead).
  List<MatchEvent> simulateToEnd() {
    final all = <MatchEvent>[];
    while (!_finished) {
      all.addAll(advanceMinute());
    }
    return all;
  }

  // -------------------------------------------------------------------------
  // Segment pipeline
  // -------------------------------------------------------------------------

  int _drawSegmentCount() {
    final roll = _random.nextDouble();
    final w = config.segmentWeights;
    if (roll < w[0]) return 0;
    if (roll < w[0] + w[1]) return 1;
    return 2;
  }

  List<MatchEvent> _simulateSegment(int minute) {
    final produced = <MatchEvent>[];

    // 1. Possession (GDD 12.3 step 1): support-based, biased by style.
    //    A POWER competition, not a ratio: weaker support loses the ball
    //    disproportionately more, but the exponent (1.4) bounds it — a
    //    20-support-point gap swings possession ~61/39, never 90/10,
    //    mirroring how real mismatches dominate without absurdity. The
    //    softer exponent (was 1.6) keeps a dominated minnow touching the
    //    ball often enough to register real shot volume of its own.
    final homeTotals = totalsOf(MatchSide.home);
    final awayTotals = totalsOf(MatchSide.away);
    final homePoss = math.pow(
      homeTotals.support * _home.style.modifiers.possession,
      1.4,
    );
    final awayPoss = math.pow(
      awayTotals.support * _away.style.modifiers.possession,
      1.4,
    );
    final attackerSide = _random.chance(homePoss / (homePoss + awayPoss))
        ? MatchSide.home
        : MatchSide.away;
    final att = _runtimeOf(attackerSide);
    final def = _runtimeOf(
      attackerSide == MatchSide.home ? MatchSide.away : MatchSide.home,
    );
    final attTotals = attackerSide == MatchSide.home ? homeTotals : awayTotals;
    final defTotals = attackerSide == MatchSide.home ? awayTotals : homeTotals;

    // Possession event carries pass volume for the statistics module.
    // The pocket's fate is decided by the build-up draw below; on a
    // turnover only the ball-playing before the loss counts, at the
    // team's support-driven accuracy — so failed pockets contribute
    // fewer attempts than kept ones (GDD 13.2 stat realism: real teams
    // complete 75-85%).
    final passesAttempted = 3 + _random.nextInt(8);
    final possessionAccuracy =
        ((attTotals.support / 100) * att.style.modifiers.passAccuracy)
            .clamp(0.40, 0.92);
    var passesCompleted = (passesAttempted * possessionAccuracy).round();

    // 2-3. Build-up: passing and progression vs defensive pressure.
    final supportRatio =
        attTotals.support / (attTotals.support + defTotals.defence * 0.85);
    final passSuccess =
        (config.buildUpBase + config.buildUpScale * supportRatio).clamp(
          0.15,
          0.88,
        );
    if (!_random.chance(passSuccess)) {
      // Turnover: the pocket died — only a fraction of the passes got
      // away before the loss (a real dispossessed move is 1-3 passes,
      // not a full 3-10-pass pocket). Deterministic from the pocket's
      // own volume: no extra random draw, so the engine's random stream
      // (and every calibrated distribution) is unchanged.
      final lostAttempted = (passesAttempted ~/ 3).clamp(1, 3);
      passesCompleted = (lostAttempted * possessionAccuracy).round();
      produced.add(
        _emit(
          minute: minute,
          type: MatchEventType.possession,
          side: attackerSide,
          metadata: {
            'passesAttempted': lostAttempted,
            'passesCompleted': passesCompleted,
          },
        ),
      );
      produced.addAll(_turnover(minute, attackerSide, att, def));
      return produced;
    }

    produced.add(
      _emit(
        minute: minute,
        type: MatchEventType.possession,
        side: attackerSide,
        metadata: {
          'passesAttempted': passesAttempted,
          'passesCompleted': passesCompleted,
        },
      ),
    );

    // Offside during progression.
    if (_random.chance(config.offsideChance)) {
      final striker = _pickAttacker(att)!;
      produced.add(
        _emit(
          minute: minute,
          type: MatchEventType.offside,
          side: attackerSide,
          primaryPlayerId: striker.playerId,
        ),
      );
      _involvedThisMinute.add(striker.playerId);
      return produced;
    }

    // 4-5. Chance creation (score/time context: urgency, GDD 12.4).
    //    SATURATING strength response: the attack-minus-defence edge
    //    drives a logistic curve, not a ratio. Real football's
    //    favourite still only creates chances at ~1.6x the rate of the
    //    underdog's own, because defenders congest space and convert
    //    superiority into half-chances, not penalties. The mid/steepness
    //    pair sets where the curve bends: ±10 engine points ≈ the
    //    crossing region, +20 is near-saturation.
    final attackEdge = attTotals.attack - defTotals.defence;
    final urgency = _urgencyBoost(attackerSide, minute);
    final edgeFactor =
        1 /
        (1 +
            math.exp(
              -config.chanceSigmoidSteepness *
                  (attackEdge - config.chanceSigmoidMid),
            ));
    final chanceP =
        (config.chanceBase +
                config.chanceScale *
                    edgeFactor *
                    att.style.modifiers.chance *
                    urgency *
                    _defensiveFatigue(attackerSide, minute))
            .clamp(0.05, config.chanceMax);
    if (!_random.chance(chanceP)) {
      // Retained possession: completed passes, maybe a cross or dribble.
      // A share of these pockets end in a LOW-QUALITY shot — a snatched
      // long-range effort, a cross shanked goalwards — which is how real
      // matches reach 11-13 shots per team while clear chances stay
      // rare. Quality stays 'normal' so conversion treats them as
      // half-chances.
      if (_random.chance(config.speculativeShotChance)) {
        produced.addAll(
          _shoot(minute, attackerSide, att, def, ChanceQuality.normal),
        );
        return produced;
      }
      final passAccuracy =
          (attTotals.support / 100) * att.style.modifiers.passAccuracy;
      final completed = (passesAttempted * passAccuracy.clamp(0.40, 0.92))
          .round();
      final md = <String, dynamic>{
        'passesAttempted': passesAttempted,
        'passesCompleted': completed,
      };
      if (_random.chance(0.22)) md['cross'] = true;
      if (_random.chance(0.18)) md['dribble'] = true;
      final creator = _pickAttacker(att);
      produced.add(
        _emit(
          minute: minute,
          type: MatchEventType.passMove,
          side: attackerSide,
          primaryPlayerId: creator?.playerId,
          metadata: md,
        ),
      );
      if (creator != null) _involvedThisMinute.add(creator.playerId);

      // Deep crosses can win corners (GDD 13.2 corners).
      if (md['cross'] == true && _random.chance(config.cornerFromCross)) {
        produced.addAll(
          _corner(minute, attackerSide, att, headerChance: false),
        );
      }
      return produced;
    }

    // 6-8. Shot selection, accuracy, goalkeeper reaction.
    produced.addAll(_attackChance(minute, attackerSide, att, def, defTotals));
    return produced;
  }

  /// Losing teams push harder late (GDD 12.4: match score + time).
  /// The urgency multiplier rises per goal chased from minute 55 and
  /// caps at 1.18 — a two-goal deficit from the hour mark is a real
  /// push, not a token one.
  double _urgencyBoost(MatchSide side, int minute) {
    final diff = side == MatchSide.home
        ? _scoreHome - _scoreAway
        : _scoreAway - _scoreHome;
    if (diff < 0 && minute > 55) return 1 + (0.06 * -diff).clamp(0, 0.18);
    return 1.0;
  }

  /// Tired defences concede more (GDD 12.4): a bounded fatigue term on
  /// chance creation from the DEFENDING side's average on-pitch
  /// stamina. The defensive effectiveness form
  /// `0.92 + 0.08 × avgStamina/100` is what the defence is worth as it
  /// tires; the quadratic time weight ramps the concession through the
  /// second half — a fresh defence in the opening quarter concedes
  /// ~+1%, a drained one (avg 74) in the final quarter ~+18% — which
  /// is what moves real football's goal share into the last fifteen
  /// minutes without inflating the total (a tired ATTACK tires just as
  /// fast in its own minutes).
  double _defensiveFatigue(MatchSide attackerSide, int minute) {
    final def = _runtimeOf(
      attackerSide == MatchSide.home ? MatchSide.away : MatchSide.home,
    );
    var sum = 0.0;
    var n = 0;
    for (final p in def.onPitch) {
      if (p == null) continue;
      sum += p.stamina;
      n++;
    }
    final avg = n > 0 ? sum / n : 100;
    final t = minute / _fullTimeMinute;
    // Cold-start ramp over the opening quarter: teams feel their way
    // into a match before it opens up (real football's 1-15 minute
    // goal share is the LOWEST of the six buckets).
    final coldStart = minute < 15 ? 0.70 + 0.30 * (minute / 15) : 1.0;
    return coldStart * (1 + 2.0 * (1 - avg / 100) * t * t);
  }

  List<MatchEvent> _turnover(
    int minute,
    MatchSide attackerSide,
    _TeamRuntime att,
    _TeamRuntime def,
  ) {
    final produced = <MatchEvent>[];
    final loser = _pickAttacker(att)!;
    _involvedThisMinute.add(loser.playerId);

    if (_random.chance(config.foulOnTurnover)) {
      // Foul by the defending side (GDD 13.1 free kicks / penalties).
      final fouler = _pickDefender(def)!;
      _involvedThisMinute.add(fouler.playerId);
      // A foul lands in the box ~1.3% of the time (Europe's top
      // divisions award 0.25-0.30 penalties/match from ~20 fouls) —
      // the old 7% produced ~5x the real award rate.
      final inBox = _random.chance(config.inBoxFoulChance);
      final finalThird = !inBox && _random.chance(0.30);
      produced.add(
        _emit(
          minute: minute,
          type: MatchEventType.foul,
          side: _opposite(attackerSide),
          primaryPlayerId: fouler.playerId,
          secondaryPlayerId: loser.playerId,
          metadata: {
            'fouledTeam': attackerSide == MatchSide.home
                ? _home.teamId
                : _away.teamId,
            'inBox': inBox,
            'finalThird': finalThird,
          },
        ),
      );
      // Cards (GDD 13.1).
      if (_random.chance(config.yellowCardChance)) {
        produced.addAll(
          _issueCard(
            minute,
            _opposite(attackerSide),
            def,
            fouler,
            straightRed: false,
          ),
        );
      } else if (_random.chance(config.straightRedChance)) {
        produced.addAll(
          _issueCard(
            minute,
            _opposite(attackerSide),
            def,
            fouler,
            straightRed: true,
          ),
        );
      }
      if (inBox) {
        produced.add(
          _emit(
            minute: minute,
            type: MatchEventType.penaltyAwarded,
            side: attackerSide,
            primaryPlayerId: loser.playerId,
            secondaryPlayerId: fouler.playerId,
          ),
        );
        produced.addAll(
          _shoot(
            minute,
            attackerSide,
            att,
            def,
            ChanceQuality.penalty,
            // The designated taker: a striker's job, not the CAM the
            // creator weights would hand it to (a CAM was ~2.5x more
            // likely to take a penalty than an ST).
            shooterOverride: _pickShooter(att),
          ),
        );
        return produced;
      }
      if (finalThird && _random.chance(0.12)) {
        produced.addAll(
          _shoot(
            minute,
            attackerSide,
            att,
            def,
            ChanceQuality.freeKick,
            shooterOverride: _pickAttacker(att)!,
          ),
        );
      }
      return produced;
    }

    // Clean turnover: tackle or interception (GDD 13.2).
    final winner = _pickDefender(def)!;
    _involvedThisMinute.add(winner.playerId);
    produced.add(
      _emit(
        minute: minute,
        type: MatchEventType.dispossessed,
        side: _opposite(attackerSide),
        primaryPlayerId: winner.playerId,
        secondaryPlayerId: loser.playerId,
        metadata: _random.chance(0.45)
            ? {'interception': true}
            : {'tackle': true},
      ),
    );
    return produced;
  }

  List<MatchEvent> _issueCard(
    int minute,
    MatchSide side,
    _TeamRuntime team,
    MatchPlayer fouler, {
    required bool straightRed,
  }) {
    final produced = <MatchEvent>[];
    fouler.yellowCards++;
    final secondYellow = fouler.yellowCards >= 2;
    final isRed = straightRed || secondYellow;
    produced.add(
      _emit(
        minute: minute,
        type: MatchEventType.card,
        side: side,
        primaryPlayerId: fouler.playerId,
        metadata: {
          'card': isRed ? 'red' : 'yellow',
          'secondYellow': secondYellow && !straightRed,
        },
      ),
    );
    if (isRed) _sendOff(team, fouler);
    return produced;
  }

  void _sendOff(_TeamRuntime team, MatchPlayer player) {
    player.sentOff = true;
    team.onPitch[team.onPitch.indexOf(player)] = null;
    team.offPitch.add(player);
  }

  List<MatchEvent> _corner(
    int minute,
    MatchSide attackerSide,
    _TeamRuntime att, {
    required bool headerChance,
  }) {
    final produced = <MatchEvent>[];
    final taker = _pickAttacker(att)!;
    _involvedThisMinute.add(taker.playerId);
    // The defending keeper fights for the cross (GDD 14): a share of
    // corners end in a claim rather than a header — his visible
    // involvement, so keepers register in low-scoring matches too.
    // Deterministic minute rotation (~1 in 3): no extra random draw, so
    // the engine's random stream (and every calibrated distribution)
    // is unchanged.
    final defendingGk = _oppositeRuntime(attackerSide).onPitch
        .whereType<MatchPlayer>()
        .firstOrNull;
    final claimed = !headerChance && minute % 3 == 0;
    if (claimed && defendingGk != null && !defendingGk.sentOff) {
      _involvedThisMinute.add(defendingGk.playerId);
    }
    produced.add(
      _emit(
        minute: minute,
        type: MatchEventType.corner,
        side: attackerSide,
        primaryPlayerId: taker.playerId,
        metadata: claimed ? const {'gkClaim': true} : const {},
      ),
    );
    // The header draw is ALWAYS taken (even on a claim, where its result
    // is discarded) so the random stream stays byte-identical to the
    // pre-claim engine and every calibrated distribution holds.
    final headerDraw = _random.chance(config.headerFromCorner);
    if (!claimed && (headerChance || headerDraw)) {
      produced.addAll(
        _shoot(
          minute,
          attackerSide,
          att,
          _oppositeRuntime(attackerSide),
          ChanceQuality.header,
        ),
      );
    }
    return produced;
  }

  /// Chance creation → shot → outcome (GDD 12.3 steps 6-9).
  List<MatchEvent> _attackChance(
    int minute,
    MatchSide attackerSide,
    _TeamRuntime att,
    _TeamRuntime def,
    TeamTotals defTotals,
  ) {
    var quality = ChanceQuality.normal;
    if (_random.chance(0.28)) quality = ChanceQuality.bigChance;
    return _shoot(minute, attackerSide, att, def, quality);
  }

  List<MatchEvent> _shoot(
    int minute,
    MatchSide attackerSide,
    _TeamRuntime att,
    _TeamRuntime def,
    ChanceQuality quality, {
    MatchPlayer? shooterOverride,
  }) {
    final produced = <MatchEvent>[];
    final shooter = shooterOverride ?? _pickShooter(att);
    if (shooter == null) return produced;
    _involvedThisMinute.add(shooter.playerId);

    MatchPlayer? assister;
    if (quality != ChanceQuality.penalty && quality != ChanceQuality.freeKick) {
      if (_random.chance(config.assistChance)) {
        assister = _pickAssister(att, exclude: shooter);
      }
    }

    final shooterEff = shooter.attack * (shooter.stamina / 100);
    final gk = def.onPitch.whereType<MatchPlayer>().firstOrNull;
    final gkEff = (gk?.goalkeeping ?? 40) * ((gk?.stamina ?? 100) / 100);

    // Shot accuracy (GDD 12.3 step 7).
    final qualityOnTargetBonus = switch (quality) {
      ChanceQuality.bigChance => 0.36,
      ChanceQuality.header => -0.12,
      ChanceQuality.freeKick => -0.08,
      ChanceQuality.penalty => 0.44,
      ChanceQuality.normal => 0.0,
    };
    final onTargetP =
        (config.onTargetBase +
                config.onTargetScale * (shooterEff / 100) +
                qualityOnTargetBonus)
            .clamp(0.10, 0.95);

    // Goalkeeper reaction (GDD 12.3 step 8) — BOUNDED conversion: the
    // shooter-minus-keeper edge moves the goal rate by at most a few
    // points per side (goalDiffScale), so a superstar against a weak
    // keeper converts ~+10..15 points, never 'scores every time'. This
    // is what keeps even huge power gaps producing real scorelines:
    // more chances for the favourite, not certain goals.
    final qualityGoalFactor = switch (quality) {
      ChanceQuality.bigChance => 1.85,
      ChanceQuality.header => 0.72,
      ChanceQuality.freeKick => 0.68,
      ChanceQuality.penalty => 1.55,
      ChanceQuality.normal => 1.0,
    };
    final goalPGivenOnTarget =
        (config.goalBase +
                config.goalScale * qualityGoalFactor +
                config.goalDiffScale * ((shooterEff - gkEff) / 100))
            .clamp(0.04, 0.88);

    // xG (GDD 13.2): P(on target) × P(goal | on target).
    final xg = onTargetP * goalPGivenOnTarget;

    // Penalties get a dedicated draw (GDD 13.1): no block layer — a
    // 28%-blocked penalty is not football — a near-certain on-target
    // rate and a high, shooter-vs-keeper dependent conversion.
    final isPenalty = quality == ChanceQuality.penalty;
    final penaltyOnTargetP = (config.penaltyOnTarget).clamp(0.10, 0.99);
    final penaltyGoalP =
        (config.penaltyGoalBase +
                config.penaltyGoalEdgeScale * ((shooterEff - gkEff) / 100))
            .clamp(0.30, 0.95);
    final penaltyXg = penaltyOnTargetP * penaltyGoalP;

    ShotOutcome outcome;
    if (isPenalty) {
      outcome = _random.chance(penaltyOnTargetP)
          ? (_random.chance(penaltyGoalP)
                ? ShotOutcome.goal
                : ShotOutcome.saved)
          : ShotOutcome.offTarget;
    } else if (_random.chance(config.blockChance)) {
      outcome = ShotOutcome.blocked;
    } else if (_random.chance(onTargetP / (1 - config.blockChance))) {
      outcome = _random.chance(goalPGivenOnTarget)
          ? ShotOutcome.goal
          : ShotOutcome.saved;
    } else {
      outcome = ShotOutcome.offTarget;
    }

    produced.add(
      _emit(
        minute: minute,
        type: MatchEventType.shot,
        side: attackerSide,
        primaryPlayerId: shooter.playerId,
        secondaryPlayerId: assister?.playerId,
        shotOutcome: outcome,
        quality: quality,
        xg: isPenalty ? penaltyXg : xg,
        metadata: {
          'isBigChance':
              quality == ChanceQuality.bigChance ||
              quality == ChanceQuality.penalty,
          'gkPlayerId': gk?.playerId,
        },
      ),
    );

    if (outcome == ShotOutcome.goal) {
      _involvedThisMinute.add(gk?.playerId ?? -1);
      if (attackerSide == MatchSide.home) {
        _scoreHome++;
      } else {
        _scoreAway++;
      }
      produced.add(
        _emit(
          minute: minute,
          type: MatchEventType.goal,
          side: attackerSide,
          primaryPlayerId: shooter.playerId,
          secondaryPlayerId: assister?.playerId,
          shotOutcome: ShotOutcome.goal,
          quality: quality,
          xg: xg,
        ),
      );
      return produced;
    }
    if (outcome == ShotOutcome.saved) {
      // Keeper claims it: the save is the GK's visible contribution to
      // the minute (GDD 14 — keepers must appear in involvement lists
      // even in low-scoring matches, not only when they concede).
      if (gk != null && !gk.sentOff) {
        _involvedThisMinute.add(gk.playerId);
      }
      // A share of saves ends in a corner: the keeper parries the ball
      // out behind his own goal line (GDD 13.2 corners).
      if (_random.chance(config.cornerFromSave)) {
        produced.addAll(
          _corner(minute, attackerSide, att, headerChance: false),
        );
      }
    }
    if (outcome == ShotOutcome.blocked &&
        _random.chance(config.cornerFromBlock)) {
      produced.addAll(_corner(minute, attackerSide, att, headerChance: true));
    }
    return produced;
  }

  // -------------------------------------------------------------------------
  // Selection helpers (position-weighted, GDD 12.4 player positions)
  // -------------------------------------------------------------------------

  static const Map<Position, double> _shooterWeights = {
    Position.st: 4.0,
    Position.lw: 2.6,
    Position.rw: 2.6,
    Position.cam: 2.4,
    Position.lm: 1.4,
    Position.rm: 1.4,
    Position.cm: 1.0,
    Position.cdm: 0.4,
    Position.lb: 0.4,
    Position.rb: 0.4,
    Position.cb: 0.7,
    Position.gk: 0.01,
  };

  static const Map<Position, double> _creatorWeights = {
    Position.cam: 4.0,
    Position.lw: 2.6,
    Position.rw: 2.6,
    Position.cm: 2.4,
    Position.lm: 2.0,
    Position.rm: 2.0,
    Position.st: 1.6,
    Position.cdm: 1.0,
    Position.lb: 0.9,
    Position.rb: 0.9,
    Position.cb: 0.4,
    Position.gk: 0.01,
  };

  static const Map<Position, double> _defenderWeights = {
    Position.cdm: 3.2,
    Position.cb: 3.0,
    Position.lb: 2.2,
    Position.rb: 2.2,
    Position.cm: 2.0,
    Position.lm: 1.2,
    Position.rm: 1.2,
    Position.cam: 0.8,
    Position.lw: 0.6,
    Position.rw: 0.6,
    Position.st: 0.4,
    Position.gk: 0.05,
  };

  MatchPlayer? _pickWeighted(
    Iterable<MatchPlayer> players,
    Map<Position, double> weights, {
    double Function(MatchPlayer)? weightAdjust,
  }) {
    final pool = players.where((p) => !p.sentOff).toList();
    if (pool.isEmpty) return null;
    final ticket = <MatchPlayer, double>{};
    var total = 0.0;
    for (final p in pool) {
      var w = weights[p.position] ?? 0.5;
      if (weightAdjust != null) w *= weightAdjust(p);
      total += w;
      ticket[p] = w;
    }
    var roll = _random.nextDouble() * total;
    for (final e in ticket.entries) {
      roll -= e.value;
      if (roll <= 0) return e.key;
    }
    return pool.last;
  }

  MatchPlayer? _pickAttacker(_TeamRuntime team) =>
      _pickWeighted(team.onPitch.whereType<MatchPlayer>(), _creatorWeights);

  MatchPlayer? _pickShooter(_TeamRuntime team) =>
      _pickWeighted(team.onPitch.whereType<MatchPlayer>(), _shooterWeights);

  MatchPlayer? _pickAssister(
    _TeamRuntime team, {
    required MatchPlayer exclude,
  }) => _pickWeighted(
    team.onPitch.whereType<MatchPlayer>().where((p) => p != exclude),
    _creatorWeights,
  );

  MatchPlayer? _pickDefender(_TeamRuntime team) => _pickWeighted(
    team.onPitch.whereType<MatchPlayer>(),
    _defenderWeights,
    // A booked player eases off challenges so he does not see a second
    // yellow (the real-world 'playing on a card' behaviour): his foul
    // weight drops to a third. This is what keeps card volume realistic
    // — without it the same defensive core commits every foul and
    // second-yellow reds explode once yellow frequency is calibrated.
    weightAdjust: (p) => p.yellowCards > 0 ? 0.35 : 1.0,
  );

  // -------------------------------------------------------------------------
  // Stamina
  // -------------------------------------------------------------------------

  void _drainStamina() {
    for (final side in MatchSide.values) {
      final rt = _runtimeOf(side);
      final styleStamina =
          rt.style.modifiers.stamina *
          rt.mentality.staminaMod *
          _activeActionModifiersOf(side).stamina *
          rt.pepTalkModifiers.stamina;
      for (final p in rt.onPitch.whereType<MatchPlayer>()) {
        final drain = staminaDrainForMinute(
          config: config.staminaConfig,
          position: p.position,
          styleStamina: styleStamina,
          mentalityStamina: 1.0,
          involvedInEvent: _involvedThisMinute.contains(p.playerId),
        );
        p.stamina = (p.stamina - drain).clamp(0, 100);
        p.minutesPlayed++;
      }
      // Bench players don't consume match stamina (GDD 11.3).
    }
  }

  // -------------------------------------------------------------------------
  // Commands and AI
  // -------------------------------------------------------------------------

  List<MatchEvent> _applyDueCommands(int minute) {
    final produced = <MatchEvent>[];
    final due = _pending.where((c) => c.atMinute <= minute).toList()
      ..sort((a, b) => a.atMinute.compareTo(b.atMinute));
    for (final command in due) {
      _pending.remove(command);
      final event = _applyCommand(command, minute);
      if (event != null) produced.add(event);
    }
    return produced;
  }

  MatchEvent? _applyCommand(MatchCommand command, int minute) {
    final rt = _runtimeOf(command.side);
    MatchEvent? event;
    switch (command) {
      case ChangeFormationCommand(:final formationCode):
        rt.changeFormation(formationByCode(formationCode), _random);
        event = _event(
          minute: minute,
          type: MatchEventType.tacticalChange,
          side: command.side,
          metadata: {'change': 'formation', 'value': formationCode},
        );
      case ChangeStyleCommand(:final style):
        rt.style = style;
        event = _event(
          minute: minute,
          type: MatchEventType.tacticalChange,
          side: command.side,
          metadata: {'change': 'style', 'value': style.name},
        );
      case ChangeMentalityCommand(:final mentality):
        rt.mentality = mentality;
        event = _event(
          minute: minute,
          type: MatchEventType.tacticalChange,
          side: command.side,
          metadata: {'change': 'mentality', 'value': mentality.name},
        );
      case SubstitutionCommand(:final outPlayerId, :final inPlayerId):
        rt.substitute(outPlayerId, inPlayerId, config.maxSubstitutions);
        event = _event(
          minute: minute,
          type: MatchEventType.substitution,
          side: command.side,
          primaryPlayerId: outPlayerId,
          secondaryPlayerId: inPlayerId,
        );
      case LiveActionCommand(:final action):
        rt.activeAction = action;
        rt.actionExpiresMinute = minute + config.liveActionDuration;
        event = _event(
          minute: minute,
          type: MatchEventType.liveAction,
          side: command.side,
          metadata: {'action': action.name},
        );
      case PepTalkCommand(:final talk):
        rt.pepTalkModifiers = talk.modifiers;
        event = _event(
          minute: minute,
          type: MatchEventType.tacticalChange,
          side: command.side,
          metadata: {'change': 'pepTalk', 'value': talk.id},
        );
    }
    if (event != null) _events.add(event);
    _applied.add(command);
    return event;
  }

  /// Rule-based AI adaptation (GDD 12.6): tactical reasons, never constant
  /// flip-flopping (bounded count, spacing, score/time triggers).
  List<MatchEvent> _maybeAdaptAi(MatchSide side, int minute) {
    final rt = _runtimeOf(side);
    if (!rt.aiControlled) return const [];
    final produced = <MatchEvent>[];

    // Substitutions first (GDD 10.5): an AI side refreshes tired legs
    // from its bench — the same rotation pressure the user's squad has.
    // Starters below the age-dependent band (80 after 65', 72 after 80')
    // come off for the best compatible bench body, and a trailing side
    // gambles with an attacker after 70', so AI clubs rotate when
    // fitness or the scoreline demands it.
    produced.addAll(_maybeAiSubstitutions(side, rt, minute));

    if (rt.aiChanges >= config.aiMaxChanges) return produced;
    if (minute < 55) return produced;
    if (minute - rt.lastAiChangeMinute < config.aiMinMinutesBetweenChanges) {
      return produced;
    }
    final diff = side == MatchSide.home
        ? _scoreHome - _scoreAway
        : _scoreAway - _scoreHome;
    final index = rt.mentality.index;
    final last = Mentality.values.length - 1;
    String? reason;
    Mentality? next;
    if (diff <= -2 && index < last) {
      reason = 'trailing by two or more';
      next = rt.mentality.moreAttacking();
    } else if (diff == -1 && minute >= 75 && index < last) {
      reason = 'chasing an equaliser late';
      next = rt.mentality.moreAttacking();
    } else if (diff >= 2 && index > 0) {
      reason = 'protecting a lead';
      next = rt.mentality.moreDefensive();
    }
    if (next == null || next == rt.mentality) return produced;
    rt.mentality = next;
    rt.aiChanges++;
    rt.lastAiChangeMinute = minute;
    final event = _event(
      minute: minute,
      type: MatchEventType.tacticalChange,
      side: side,
      metadata: {
        'change': 'mentality',
        'value': next.name,
        'ai': true,
        'reason': reason,
      },
    );
    _events.add(event);
    produced.add(event);
    return produced;
  }

  /// AI substitutions (GDD 10.5/11): the outgoing player stops draining
  /// stamina the moment he is off (bench never drains), the substitute
  /// drains only from his entrance — the engine runtime already models
  /// this; here the AI just decides WHEN. The gates must intersect the
  /// REAL stamina curve: a balanced full-match starter finishes near 70,
  /// so the tired bands sit at 80 (from 65') and 72 (from 80') — the old
  /// 40/30 gates never triggered and AI subs were dead code. A team
  /// trailing after 70' also gambles with a defender-for-attacker swap
  /// (GDD 12.6). At most one AI change per team per 5 minutes, so the
  /// window budget is spread through the final third like real matches.
  List<MatchEvent> _maybeAiSubstitutions(
    MatchSide side,
    _TeamRuntime rt,
    int minute,
  ) {
    if (rt.substitutionsUsed >= config.maxSubstitutions) return const [];
    if (rt.bench.isEmpty) return const [];
    if (minute < 65) return const [];
    if (minute - rt.lastAiSubMinute < 12) return const [];
    final produced = <MatchEvent>[];

    // Chasing the game (GDD 12.6) FIRST — it is the stronger signal and
    // must claim the window (and the bench attacker) before rotation
    // does: a trailing side throws an attacker on for a defender after
    // 70', even when nobody is exhausted.
    final diff = side == MatchSide.home
        ? _scoreHome - _scoreAway
        : _scoreAway - _scoreHome;
    if (diff < 0 &&
        minute >= 70 &&
        !rt.aiChaseSubDone &&
        rt.substitutionsUsed < config.maxSubstitutions) {
      final event = _aiChaseSubstitution(side, rt, minute);
      if (event != null) produced.add(event);
    }

    // Tired threshold sinks as the match ages: 76 after 65', 70 after 80'.
    final threshold = minute >= 80 ? 70 : 76;
    final onPitch = rt.onPitch.whereType<MatchPlayer>().toList()
      ..sort((a, b) => a.stamina.compareTo(b.stamina));
    for (final tired in onPitch) {
      if (rt.substitutionsUsed >= config.maxSubstitutions) break;
      if (tired.position == Position.gk) continue;
      if (tired.stamina >= threshold) {
        break; // sorted ascending: nobody left is tired
      }
      final slotIndex = rt.onPitch.indexWhere(
        (p) => p?.playerId == tired.playerId,
      );
      if (slotIndex == -1) continue;
      final slotPosition = slotIndex < rt.formation.slots.length
          ? rt.formation.slots[slotIndex].position
          : tired.position;
      final bestIn = _bestBenchForSlot(rt, slotPosition);
      if (bestIn == null) continue;
      final event = _applyAiSubstitution(
        side: side,
        rt: rt,
        minute: minute,
        outgoing: tired,
        incoming: bestIn,
        reason: 'tired',
      );
      if (event != null) {
        produced.add(event);
        break; // one change per window: subs spread like real matches
      }
    }
    return produced;
  }

  /// Best remaining bench body for [slotPosition]: slot compatibility
  /// first, then overall quality, with freshness as the tiebreaker.
  MatchPlayer? _bestBenchForSlot(_TeamRuntime rt, Position slotPosition) {
    MatchPlayer? best;
    var bestScore = -1.0;
    for (final candidate in rt.bench) {
      final compat = const SquadEngine().compatibilityOf(
        candidate.position,
        slotPosition,
      );
      if (compat <= 0.1) continue;
      final score =
          compat *
          (candidate.attack + candidate.support + candidate.defence) *
          (0.75 + 0.25 * (candidate.stamina / 100));
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    return best;
  }

  /// Executes one AI swap and emits the corresponding event.
  MatchEvent? _applyAiSubstitution({
    required MatchSide side,
    required _TeamRuntime rt,
    required int minute,
    required MatchPlayer outgoing,
    required MatchPlayer incoming,
    required String reason,
  }) {
    if (!rt.bench.any((p) => p.playerId == incoming.playerId)) return null;
    rt.substitute(outgoing.playerId, incoming.playerId, config.maxSubstitutions);
    rt.lastAiSubMinute = minute;
    final event = _event(
      minute: minute,
      type: MatchEventType.substitution,
      side: side,
      primaryPlayerId: outgoing.playerId,
      secondaryPlayerId: incoming.playerId,
      metadata: {'ai': true, 'reason': reason},
    );
    _events.add(event);
    return event;
  }

  /// Chasing-game gamble (GDD 12.6): the best bench attacker takes the
  /// defensive slot that compromises him least — the weariest defender
  /// makes way when the options are otherwise equal.
  MatchEvent? _aiChaseSubstitution(
    MatchSide side,
    _TeamRuntime rt,
    int minute,
  ) {
    MatchPlayer? outDefender;
    MatchPlayer? inAttacker;
    var bestScore = -1.0;
    for (var slot = 0; slot < rt.onPitch.length; slot++) {
      final defender = rt.onPitch[slot];
      if (defender == null) continue;
      final slotPosition = slot < rt.formation.slots.length
          ? rt.formation.slots[slot].position
          : defender.position;
      const defenders = {Position.cb, Position.lb, Position.rb, Position.cdm};
      if (!defenders.contains(slotPosition)) continue;
      for (final attacker in rt.bench) {
        const attackers = {Position.st, Position.lw, Position.rw, Position.cam};
        if (!attackers.contains(attacker.position)) continue;
        final compat = const SquadEngine().compatibilityOf(
          attacker.position,
          slotPosition,
        );
        if (compat <= 0.1) continue;
        final score =
            compat * attacker.attack + (100 - defender.stamina) * 0.05;
        if (score > bestScore) {
          bestScore = score;
          outDefender = defender;
          inAttacker = attacker;
        }
      }
    }
    if (outDefender == null || inAttacker == null) return null;
    rt.aiChaseSubDone = true;
    return _applyAiSubstitution(
      side: side,
      rt: rt,
      minute: minute,
      outgoing: outDefender,
      incoming: inAttacker,
      reason: 'chasing',
    );
  }

  ActionModifiers _activeActionModifiersOf(MatchSide side) {
    final rt = _runtimeOf(side);
    final action = rt.activeAction;
    if (action == null || _minute > rt.actionExpiresMinute) {
      return const ActionModifiers(attack: 1, defence: 1, stamina: 1);
    }
    return action.modifiers;
  }

  // -------------------------------------------------------------------------
  // Plumbing
  // -------------------------------------------------------------------------

  _TeamRuntime _runtimeOf(MatchSide side) =>
      side == MatchSide.home ? _home : _away;

  _TeamRuntime _oppositeRuntime(MatchSide side) =>
      side == MatchSide.home ? _away : _home;

  MatchSide _opposite(MatchSide side) =>
      side == MatchSide.home ? MatchSide.away : MatchSide.home;

  MatchEvent _event({
    required int minute,
    required MatchEventType type,
    required MatchSide side,
    int? primaryPlayerId,
    int? secondaryPlayerId,
    ShotOutcome? shotOutcome,
    ChanceQuality? quality,
    double? xg,
    Map<String, dynamic> metadata = const {},
  }) {
    // Second-half minutes are displayed relative to 45 (GDD 13.3 timeline).
    final displayMinute = minute <= _halfTimeMinute
        ? minute
        : minute - _firstHalfStoppage;
    return MatchEvent(
      eventId: _eventId++,
      minute: displayMinute,
      second: _random.nextInt(60),
      type: type,
      side: side,
      teamId: side == MatchSide.home ? _home.teamId : _away.teamId,
      primaryPlayerId: primaryPlayerId,
      secondaryPlayerId: secondaryPlayerId,
      shotOutcome: shotOutcome,
      quality: quality,
      xg: xg,
      metadata: metadata,
    );
  }

  MatchEvent _emit({
    required int minute,
    required MatchEventType type,
    required MatchSide side,
    int? primaryPlayerId,
    int? secondaryPlayerId,
    ShotOutcome? shotOutcome,
    ChanceQuality? quality,
    double? xg,
    Map<String, dynamic> metadata = const {},
  }) {
    final event = _event(
      minute: minute,
      type: type,
      side: side,
      primaryPlayerId: primaryPlayerId,
      secondaryPlayerId: secondaryPlayerId,
      shotOutcome: shotOutcome,
      quality: quality,
      xg: xg,
      metadata: metadata,
    );
    _events.add(event);
    return event;
  }
}

/// Seeded PRNG wrapper (GDD 26.2): one fixed initial seed, an advancing
/// internal state and a draw counter. The seed is never regenerated.
class MatchRandom {
  MatchRandom(this.initialSeed) : _random = math.Random(initialSeed);

  final int initialSeed;
  final math.Random _random;
  int drawCount = 0;

  double nextDouble() {
    drawCount++;
    return _random.nextDouble();
  }

  int nextInt(int max) {
    drawCount++;
    return _random.nextInt(max);
  }

  bool chance(num p) => nextDouble() < p;
}

/// Per-team mutable match runtime.
class _TeamRuntime {
  _TeamRuntime.from(MatchTeamInput input)
    : teamId = input.teamId,
      teamName = input.teamName,
      formation = formationByCode(input.formationCode),
      style = input.style,
      mentality = input.mentality,
      aiControlled = input.aiControlled,
      onPitch = [for (final p in input.starters) p.clone()],
      bench = [for (final p in input.bench) p.clone()],
      offPitch = [];

  final int teamId;
  final String teamName;
  Formation formation;
  PlayingStyle style;
  Mentality mentality;
  final bool aiControlled;

  /// On-pitch players by formation slot; null = empty slot (sent off).
  final List<MatchPlayer?> onPitch;
  final List<MatchPlayer> bench;
  final List<MatchPlayer> offPitch;

  int substitutionsUsed = 0;
  LiveMatchAction? activeAction;
  int actionExpiresMinute = 0;
  int aiChanges = 0;
  int lastAiChangeMinute = 0;

  /// AI substitution bookkeeping: last minute an AI sub was made (subs
  /// are spaced ≥ 5 minutes apart) and whether the chasing-game
  /// attacker swap has already been used this match.
  int lastAiSubMinute = 0;
  bool aiChaseSubDone = false;

  /// Active pep talk (GDD 15): persistent multipliers, at most one at a
  /// time — a later talk replaces the earlier one.
  ActionModifiers pepTalkModifiers = const ActionModifiers(
    attack: 1,
    defence: 1,
    stamina: 1,
  );

  /// Team totals (GDD 12.2): 1. stamina scaling per player, 2. mentality,
  /// 3. playing style, 4. home advantage — in this order.
  TeamTotals computeTotals({
    required bool isHome,
    required double homeAdvantage,
    required ActionModifiers actionModifiers,
  }) {
    double attackSum = 0, supportSum = 0, defenceSum = 0;
    var attackW = 0.0, supportW = 0.0, defenceW = 0.0;
    double gkEff = 0;
    for (var slot = 0; slot < onPitch.length; slot++) {
      final player = onPitch[slot];
      if (player == null) continue;
      final slotPosition = slot < formation.slots.length
          ? formation.slots[slot].position
          : player.position;
      // Out-of-position penalty via squad compatibility (GDD 6.3).
      final compat = const SquadEngine().compatibilityOf(
        player.position,
        slotPosition,
      );
      final stamina = player.stamina / 100;
      final aw = _MatchEngineRole.attack[slotPosition]! * compat;
      final sw = _MatchEngineRole.support[slotPosition]! * compat;
      final dw = _MatchEngineRole.defence[slotPosition]! * compat;
      attackSum += player.attack * stamina * aw;
      attackW += aw;
      supportSum += player.support * stamina * sw;
      supportW += sw;
      defenceSum += player.defence * stamina * dw;
      defenceW += dw;
      if (slotPosition == Position.gk) gkEff = player.goalkeeping * stamina;
    }
    final attack =
        (attackW > 0 ? attackSum / attackW : 0) *
        mentality.attackMod *
        style.modifiers.attack *
        actionModifiers.attack *
        pepTalkModifiers.attack;
    final support =
        supportW > 0 ? supportSum / supportW : 0;
    final defence =
        (defenceW > 0 ? defenceSum / defenceW : 0) *
        mentality.defenceMod *
        style.modifiers.defence *
        actionModifiers.defence *
        pepTalkModifiers.defence;
    final goalkeeping = gkEff * mentality.defenceMod * style.modifiers.defence;
    final homeFactor = isHome ? homeAdvantage : 1.0;
    return TeamTotals(
      attack: attack * homeFactor,
      support: support * homeFactor,
      defence: defence * homeFactor,
      goalkeeping: goalkeeping * homeFactor,
    );
  }

  /// Reassigns on-pitch players to a new formation's slots (GDD 10.1):
  /// greedy best-fit by compatibility-weighted slot rating.
  void changeFormation(Formation newFormation, MatchRandom random) {
    formation = newFormation;
    final players = onPitch.whereType<MatchPlayer>().toList();
    final assigned = <MatchPlayer, int>{};
    // Rarest slot first: GK, then fewest natural fits.
    final slotOrder = List.generate(newFormation.slots.length, (i) => i)
      ..sort((a, b) {
        final pa = _naturalFits(newFormation.slots[a].position, players);
        final pb = _naturalFits(newFormation.slots[b].position, players);
        return pa != pb ? pa.compareTo(pb) : a.compareTo(b);
      });
    final available = {...players.map((p) => p.playerId)};
    for (final slotIndex in slotOrder) {
      final slot = newFormation.slots[slotIndex];
      int? bestId;
      var bestScore = -1.0;
      for (final id in available) {
        final p = players.firstWhere((x) => x.playerId == id);
        final compat = const SquadEngine().compatibilityOf(
          p.position,
          slot.position,
        );
        final score = compat * (p.attack + p.support + p.defence);
        if (score > bestScore) {
          bestScore = score;
          bestId = id;
        }
      }
      if (bestId != null) {
        assigned[players.firstWhere((x) => x.playerId == bestId)] = slotIndex;
        available.remove(bestId);
      }
    }
    onPitch.fillRange(0, onPitch.length, null);
    for (final e in assigned.entries) {
      onPitch[e.value] = e.key;
    }
  }

  int _naturalFits(Position slotPosition, List<MatchPlayer> players) => players
      .where(
        (p) =>
            const SquadEngine().compatibilityOf(p.position, slotPosition) > 0.5,
      )
      .length;

  /// Substitution (GDD 10.5): the substitute takes the outgoing player's
  /// slot; totals, stamina, statistics and ratings update from this point.
  void substitute(int outPlayerId, int inPlayerId, int maxSubstitutions) {
    if (substitutionsUsed >= maxSubstitutions) {
      throw StateError('Maximum substitutions reached');
    }
    final index = onPitch.indexWhere((p) => p?.playerId == outPlayerId);
    if (index == -1) {
      throw StateError('Player $outPlayerId is not on the pitch');
    }
    final benchIndex = bench.indexWhere((p) => p.playerId == inPlayerId);
    if (benchIndex == -1) {
      throw StateError('Player $inPlayerId is not on the bench');
    }
    final incoming = bench.removeAt(benchIndex);
    final outgoing = onPitch[index]!;
    onPitch[index] = incoming;
    offPitch.add(outgoing);
    substitutionsUsed++;
  }
}

/// Role weights referenced by the runtime (kept separate from the engine
/// class body for readability).
class _MatchEngineRole {
  static const Map<Position, double> attack = {
    Position.st: 1.0,
    Position.lw: 0.85,
    Position.rw: 0.85,
    Position.cam: 0.85,
    Position.lm: 0.6,
    Position.rm: 0.6,
    Position.cm: 0.6,
    Position.cdm: 0.4,
    Position.lb: 0.35,
    Position.rb: 0.35,
    Position.cb: 0.25,
    Position.gk: 0.05,
  };
  static const Map<Position, double> support = {
    Position.cam: 1.0,
    Position.cm: 1.0,
    Position.lw: 0.85,
    Position.rw: 0.85,
    Position.lm: 0.85,
    Position.rm: 0.85,
    Position.cdm: 0.8,
    Position.st: 0.7,
    Position.lb: 0.7,
    Position.rb: 0.7,
    Position.cb: 0.6,
    Position.gk: 0.1,
  };
  static const Map<Position, double> defence = {
    Position.cb: 1.0,
    Position.lb: 0.9,
    Position.rb: 0.9,
    Position.cdm: 0.9,
    Position.cm: 0.7,
    Position.lm: 0.6,
    Position.rm: 0.6,
    Position.cam: 0.5,
    Position.lw: 0.4,
    Position.rw: 0.4,
    Position.st: 0.4,
    Position.gk: 0.05,
  };
}
