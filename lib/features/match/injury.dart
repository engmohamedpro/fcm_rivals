/// FCM Rivals — injury system (GDD 11.7).
///
/// Pure, seeded, unit-testable injury-risk model: the gameplay role
/// stamina used to play (performance scaling) became injury risk with the
/// owner's 2026-11-07 fatigue decoupling (T-0052). Risk is computed per
/// player-minute; the engine (T-0054) decides WHEN to roll and calls
/// [rollInjury] with its own seeded draw. No Flutter imports, no RNG
/// state inside — server-port ready (README). All values are pre-balance
/// placeholders (GDD rule 14); the real-rate calibration gate is
/// T-0054's engine calibration group.
library;

import '../../core/domain/players.dart';

/// Severity of a sustained injury (GDD 11.7 severity table).
///
/// Display-name l10n keys (T-0056 adds the ARB strings; no user-facing
/// strings live in this layer):
/// - [InjuryKind.knock] → `injuryKindKnock`
/// - [InjuryKind.muscle] → `injuryKindMuscle`
/// - [InjuryKind.serious] → `injuryKindSerious`
enum InjuryKind { knock, muscle, serious }

/// One sustained injury: what it is and how many matches the player
/// misses. Persisted as `injuryKind` (the kind's name) +
/// `injuryMatchesRemaining` on OwnedPlayers/AiPlayers (schema v12).
class PlayerInjury {
  const PlayerInjury({required this.kind, required this.matchesOut});

  final InjuryKind kind;

  /// Matches the player misses, counted down per round (T-0055).
  final int matchesOut;

  @override
  bool operator ==(Object other) =>
      other is PlayerInjury &&
      other.kind == kind &&
      other.matchesOut == matchesOut;

  @override
  int get hashCode => Object.hash(kind, matchesOut);

  @override
  String toString() => 'PlayerInjury(${kind.name}, out $matchesOut)';
}

/// Tunable injury parameters (GDD 11.7) — the StaminaConfig pattern:
/// every knob lives here, no magic numbers anywhere else.
class InjuryConfig {
  const InjuryConfig({
    this.baseRiskPerMinuteAtFullStamina = 0.00003,
    this.fatigueRiskThreshold = 70,
    this.fatigueRiskSlope = 40,
    this.maxRiskPerMinute = 0.0035,
    this.positionRiskMultiplier = defaultPositionRiskMultiplier,
    this.medicalRiskReductionPerLevel = 0.006,
    this.maxMedicalCentreLevel = 5,
    this.maxInjuriesPerTeamPerMatch = 2,
    this.knockShare = 0.55,
    this.muscleShare = 0.35,
    this.muscleLongOdds = 0.5,
    this.seriousMinMatchesOut = 4,
    this.seriousMaxExtra = 3,
  }) : assert(knockShare >= 0 && muscleShare >= 0),
       assert(knockShare + muscleShare <= 1),
       assert(seriousMaxExtra >= 1);

  /// Per-minute injury probability for a fully-fit player before any
  /// other factor (~0.0027 per full match) — the "≈ 0 at full stamina"
  /// floor, not a hard zero: nobody is immune. Tuned by T-0054's engine
  /// calibration so fresh squads land under 0.05 injuries/team/match
  /// while exhausted squads clear 0.25.
  final double baseRiskPerMinuteAtFullStamina;

  /// Stamina at or above which the fatigue ramp does not engage: starters
  /// finish a full match around 70 (GDD 11.4), so only congested spells
  /// and heavy styles cross into the risk zone.
  final double fatigueRiskThreshold;

  /// Quadratic ramp below [fatigueRiskThreshold]:
  /// `risk = base × (1 + slope × t²)` with
  /// `t = (threshold − stamina) / threshold` clamped to [0, 1] — identity
  /// at the threshold, rising steeply toward the exhausted band.
  /// Slope 40 (T-0054 calibration) → ~41× base at stamina 0 before the
  /// cap: the steep separation is what puts exhausted squads ~10× above
  /// fresh ones while fresh squads stay essentially injury-free.
  final double fatigueRiskSlope;

  /// Hard per-minute ceiling for any player, documented bound — even a
  /// spent keeper in a congested spell cannot exceed it.
  final double maxRiskPerMinute;

  /// Position workload multipliers — same semantics (and default values)
  /// as StaminaConfig.positionWorkload: box-to-box and wide roles pick up
  /// more knocks than anchors or keepers.
  final Map<Position, double> positionRiskMultiplier;

  /// Multiplicative risk reduction per Medical Centre level: consumes the
  /// Facility.medical hook (0.6 percentage points per level) as a
  /// fraction, so level 5 removes 3% of the remaining risk.
  final double medicalRiskReductionPerLevel;

  final int maxMedicalCentreLevel;

  /// Per-match cap guard: the engine (T-0054) stops rolling for a team
  /// after this many injuries in one match (squad sanity).
  final int maxInjuriesPerTeamPerMatch;

  /// Severity weights (GDD 11.7 table). Expected recovery must stay
  /// short — a 38-round season with 23-man squads cannot absorb long
  /// bills: knock 1 match, muscle 2–3, serious 4–6.
  final double knockShare;
  final double muscleShare;

  /// Odds a muscle injury is the long variant (3 matches, not 2).
  final double muscleLongOdds;

  /// Serious injuries: [seriousMinMatchesOut] + uniform extra in
  /// [0, seriousMaxExtra) → 4–6 matches with the default 4 + 3.
  final int seriousMinMatchesOut;
  final int seriousMaxExtra;

  /// Expected matchesOut under the default weights:
  /// 0.55·1 + 0.35·2.5 + 0.10·5 = 1.925 — a knock-heavy, short-bill
  /// distribution on purpose.
  double get expectedMatchesOut =>
      knockShare * 1 +
      muscleShare * (2 + muscleLongOdds) +
      (1 - knockShare - muscleShare) *
          (seriousMinMatchesOut + (seriousMaxExtra - 1) / 2);

  static const Map<Position, double> defaultPositionRiskMultiplier = {
    Position.gk: 0.55,
    Position.cb: 0.95,
    Position.lb: 1.12,
    Position.rb: 1.12,
    Position.cdm: 1.05,
    Position.cm: 1.18,
    Position.cam: 1.05,
    Position.lm: 1.12,
    Position.rm: 1.12,
    Position.lw: 1.10,
    Position.rw: 1.10,
    Position.st: 1.00,
  };
}

const InjuryConfig defaultInjuryConfig = InjuryConfig();

/// Per-minute injury probability for one player (GDD 11.7).
///
/// Pure: base risk × fatigue ramp (identity at/above the threshold,
/// quadratic below) × position workload × Medical Centre protection,
/// clamped to [InjuryConfig.maxRiskPerMinute].
double injuryChanceForMinute({
  required InjuryConfig config,
  required double stamina,
  required Position position,
  int medicalCentreLevel = 0,
}) {
  final t =
      ((config.fatigueRiskThreshold - stamina) / config.fatigueRiskThreshold)
          .clamp(0.0, 1.0);
  var risk =
      config.baseRiskPerMinuteAtFullStamina *
      (1 + config.fatigueRiskSlope * t * t);
  risk *= config.positionRiskMultiplier[position] ?? 1.0;
  final level = medicalCentreLevel.clamp(0, config.maxMedicalCentreLevel);
  risk *= 1 - config.medicalRiskReductionPerLevel * level;
  return risk.clamp(0.0, config.maxRiskPerMinute);
}

/// The engine's draw callback: a uniform double in [0, 1). MatchRandom
/// (match_engine_runtime.dart) satisfies this with a method tear-off; the
/// engine decides when to roll so the draw count stays inside its fixed
/// per-minute budget (GDD 12.5 determinism).
typedef RandomDraw = double Function();

/// Roll one player's per-minute injury (GDD 11.7). Returns null when the
/// draw misses [chancePerMinute]; otherwise a [PlayerInjury] with the
/// kind drawn from the severity weights and matchesOut from the kind's
/// range. Deterministic per seed: the same draw sequence yields the same
/// result on every platform.
PlayerInjury? rollInjury({
  required InjuryConfig config,
  required double chancePerMinute,
  required RandomDraw draw,
}) {
  if (draw() >= chancePerMinute) return null;
  final severity = draw();
  if (severity < config.knockShare) {
    return const PlayerInjury(kind: InjuryKind.knock, matchesOut: 1);
  }
  if (severity < config.knockShare + config.muscleShare) {
    return PlayerInjury(
      kind: InjuryKind.muscle,
      matchesOut: draw() < config.muscleLongOdds ? 3 : 2,
    );
  }
  return PlayerInjury(
    kind: InjuryKind.serious,
    matchesOut:
        config.seriousMinMatchesOut + (draw() * config.seriousMaxExtra).floor(),
  );
}
