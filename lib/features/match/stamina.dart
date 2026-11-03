/// FCM Rivals — stamina system (GDD 11).
///
/// Dynamic consumption during matches and post-match recovery with pep
/// talk bonuses. Consumption happens inside the Match Engine using
/// [StaminaConfig]; recovery runs post-match via [recoverStamina] and
/// [applyPepTalkBonus]. All values are pre-balance placeholders.
library;

import '../../core/domain/players.dart';

/// Tunable stamina parameters (GDD 11.4: no fixed per-minute drain).
class StaminaConfig {
  const StaminaConfig({
    this.baseDrainPerMinute = 0.45,
    this.positionWorkload = defaultPositionWorkload,
    this.eventActivityDrain = 0.10,
    this.minStamina = 0,
    this.maxStamina = 100,
    this.baseRecovery = 18,
    // Calibrated by the §30/§31 simulation harness: a 38-match season
    // (GDD 9.2) plays roughly every 3–4 days, and a full match drains
    // ~45 points. Recovery must exceed that or squads spiral from 100
    // down to ~20 within five fixtures (18 + 3×14 = 60 ≥ 45).
    this.recoveryPerRestDay = 14,
    this.minutesPlayedPenalty = 12,
    this.substituteRecoveryBonus = 6,
    this.exhaustedThreshold = 60,
    this.subPlayedThresholdMinutes = 45,
  });

  /// Base stamina points lost per minute on the pitch before style,
  /// mentality and workload factors.
  final double baseDrainPerMinute;

  /// Position workload multipliers (GDD 11.4 dynamic workload): box-to-box
  /// and wide roles run more than anchors or keepers.
  final Map<Position, double> positionWorkload;

  /// Extra drain for players directly involved in the minute's events.
  final double eventActivityDrain;

  final double minStamina;
  final double maxStamina;

  /// Natural recovery between matches (percentage points, GDD 11.5):
  /// full-match players recover more slowly than substitutes.
  final double baseRecovery;
  final double recoveryPerRestDay;
  final double minutesPlayedPenalty;
  final double substituteRecoveryBonus;

  /// Pep talk targeting thresholds (GDD 11.6).
  final double exhaustedThreshold;
  final int subPlayedThresholdMinutes;

  static const Map<Position, double> defaultPositionWorkload = {
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

const StaminaConfig defaultStaminaConfig = StaminaConfig();

/// Drain for one player over one simulated minute (GDD 11.2–11.4).
///
/// [styleStamina] and [mentalityStamina] come from the active tactics;
/// [involvedInEvent] adds the dynamic workload component; the live-action
/// multiplier is folded into [styleStamina] by the engine.
double staminaDrainForMinute({
  required StaminaConfig config,
  required Position position,
  required double styleStamina,
  required double mentalityStamina,
  bool involvedInEvent = false,
}) {
  var drain = config.baseDrainPerMinute *
      styleStamina *
      mentalityStamina *
      (config.positionWorkload[position] ?? 1.0);
  if (involvedInEvent) drain += config.eventActivityDrain;
  return drain;
}

/// Post-match natural recovery (GDD 11.5). Depends on rest interval,
/// minutes played and current stamina; never resets to 100% in one go
/// unless the player was already nearly fresh with a long rest.
/// [campusRecoveryBonus] adds the Recovery Centre's percentage points
/// (GDD 3.5) on top of the natural amount.
double recoverStamina({
  required StaminaConfig config,
  required double currentStamina,
  required int minutesPlayed,
  required int restDays,
  double campusRecoveryBonus = 0,
}) {
  var recovery = config.baseRecovery +
      restDays * config.recoveryPerRestDay -
      (minutesPlayed / 90) * config.minutesPlayedPenalty +
      campusRecoveryBonus;
  if (minutesPlayed > 0 && minutesPlayed < 30) {
    recovery += config.substituteRecoveryBonus;
  }
  final next = currentStamina + recovery;
  // Players close to full heal to full; drained players stay below 100
  // unless the rest interval was long.
  if (next > config.maxStamina) {
    final overflowPenalty = (restDays >= 6 && currentStamina > 70) ? 0.0 : 8.0;
    return (config.maxStamina - overflowPenalty).clamp(0, config.maxStamina);
  }
  return next.clamp(0, config.maxStamina);
}

/// Post-match pep talk choices (GDD 11.6): a bonus multiplier applied to
/// the player's natural recovery, not a direct stamina addition.
enum PepTalk {
  restEveryone('Rest, everyone deserves it!', 0.05, PepTalkTarget.all),
  focusExhausted('Focus on exhausted players!', 0.10, PepTalkTarget.belowThreshold),
  rewardSubstitutes('Reward the substitutes!', 0.10, PepTalkTarget.playedUnderThreshold),
  everyoneGaveBest('Everyone gave their best!', 0.07, PepTalkTarget.playedThresholdOrMore);

  const PepTalk(this.displayName, this.recoveryBonus, this.target);

  final String displayName;

  /// Bonus fraction of the natural recovery (e.g. 0.10 = +10%).
  final double recoveryBonus;

  final PepTalkTarget target;
}

enum PepTalkTarget { all, belowThreshold, playedUnderThreshold, playedThresholdOrMore }

/// Whether a player is affected by [pepTalk] (GDD 11.6: the game must show
/// the affected player count before confirmation).
bool pepTalkAppliesTo({
  required PepTalk pepTalk,
  required StaminaConfig config,
  required double staminaAfterNaturalRecovery,
  required int minutesPlayed,
}) {
  switch (pepTalk.target) {
    case PepTalkTarget.all:
      return true;
    case PepTalkTarget.belowThreshold:
      return staminaAfterNaturalRecovery < config.exhaustedThreshold;
    case PepTalkTarget.playedUnderThreshold:
      return minutesPlayed > 0 && minutesPlayed < config.subPlayedThresholdMinutes;
    case PepTalkTarget.playedThresholdOrMore:
      return minutesPlayed >= config.subPlayedThresholdMinutes;
  }
}

/// Applies the pep talk: a bonus to the player's natural recovery amount
/// (never a direct stamina point addition, GDD 11.6).
double applyPepTalkBonus({
  required PepTalk pepTalk,
  required double currentStamina,
  required double naturalRecovery,
  required double staminaAfterNaturalRecovery,
  required int minutesPlayed,
  StaminaConfig config = defaultStaminaConfig,
}) {
  if (!pepTalkAppliesTo(
      pepTalk: pepTalk,
      config: config,
      staminaAfterNaturalRecovery: staminaAfterNaturalRecovery,
      minutesPlayed: minutesPlayed)) {
    return staminaAfterNaturalRecovery;
  }
  return (staminaAfterNaturalRecovery + naturalRecovery * pepTalk.recoveryBonus)
      .clamp(0, config.maxStamina);
}
