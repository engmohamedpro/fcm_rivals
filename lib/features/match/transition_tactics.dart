/// FCM Rivals — Transitions instruction group (GDD 10.2).
///
/// Counter-press, attack on recovery, rest defence and the group
/// container, split verbatim out of `tactics.dart` (T-0039).
library;

import 'in_possession_tactics.dart';
import 'tactic_modifiers.dart';

/// Transitions instructions (GDD 10.2): counter-press, counter-attacking
/// and rest defence. Phase 0 scaffold — the fields arrive in phase 3.
/// Counter-press behaviour right after losing the ball.
enum CounterPress implements InstructionOption {
  retreat(
    'Retreat to Shape',
    TacticModifiers(defence: 1.03, chance: 0.95, stamina: 0.92),
  ),
  balanced('Balanced', TacticModifiers.identity),
  immediate(
    'Immediate Counter-Press',
    TacticModifiers(defence: 1.09, chance: 1.06, stamina: 1.14),
  );

  const CounterPress(this.displayName, this.modifiers);

  final String displayName;
  @override
  final TacticModifiers modifiers;
}

/// What the team does with a recovered ball.
enum AttackOnRecovery implements InstructionOption {
  patient(
    'Patient',
    // Final trim 2026-11-06 (anchor pass): chance 0.94 -> 0.96.
    // Aligned-harness sweep line: allDefence goals 2.38 (red, band
    // >=2.4) -> +0.01 alone (2.39), -> 2.41 green with the work-ball
    // shot-quality trim landed together; transitions never enter the
    // in-possession matrix, so the lever is isolated from the matrix
    // worst combo. `patient` single stays green: 48.9/50.3 W (band
    // 46-54, both pools).
    TacticModifiers(possession: 1.05, chance: 0.96),
  ),
  balanced('Balanced', TacticModifiers.identity),
  fast(
    'Fast Counter',
    // Phase-3 landing 2026-11-06: possession 0.85 -> 0.91. Sweep line
    // (aligned harness, both pools): `fastCounter` single 49.6%
    // suite pool / 50.0% sweep pool W (green, band 46-54) at 0.91;
    // parkTheBus possession 41.8/41.9 green (band 30-42); allAttack
    // no-collapse 42.3/43.7 green (band >=38). (The pre-alignment
    // tool carried different seeds; the 49.0 figure it printed is
    // superseded by the aligned numbers here.)
    TacticModifiers(possession: 0.91, chance: 1.12, shotQuality: 1.03),
  );

  const AttackOnRecovery(this.displayName, this.modifiers);

  final String displayName;
  @override
  final TacticModifiers modifiers;
}

/// How many players stay back while attacking (rest defence).
enum RestDefence implements InstructionOption {
  conservative(
    'Conservative · 4 back',
    TacticModifiers(defence: 1.04, chance: 0.96),
  ),
  standard('Standard · 3 back', TacticModifiers.identity),
  aggressive(
    'Aggressive · 2 back',
    TacticModifiers(defence: 0.96, chance: 1.03),
  );

  const RestDefence(this.displayName, this.modifiers);

  final String displayName;
  @override
  final TacticModifiers modifiers;
}

/// Transitions instructions (GDD 10.2): counter-press, counter-
/// attacking and rest defence. Defaults (Balanced/Balanced/Standard)
/// are the identity; combinations rebuild the removed Gegenpressing
/// (with phase 2) and Counter Attack styles.
class TransitionTactics {
  const TransitionTactics({
    this.counterPress = CounterPress.balanced,
    this.attackOnRecovery = AttackOnRecovery.balanced,
    this.restDefence = RestDefence.standard,
  });

  final CounterPress counterPress;
  final AttackOnRecovery attackOnRecovery;
  final RestDefence restDefence;

  bool get isDefault =>
      counterPress == CounterPress.balanced &&
      attackOnRecovery == AttackOnRecovery.balanced &&
      restDefence == RestDefence.standard;

  /// Composed through the tuning seam (`.tuned`): the shipped
  /// constants when no sweep override is installed.
  TacticModifiers get modifiers =>
      counterPress.tuned * attackOnRecovery.tuned * restDefence.tuned;

  /// Human-visible effect summary (GDD 10.3: effects must be visible).
  String get effectSummary => modifiers.effectSummary;

  Map<String, dynamic> toJson() => {
    if (counterPress != CounterPress.balanced)
      'counterPress': counterPress.name,
    if (attackOnRecovery != AttackOnRecovery.balanced)
      'attackOnRecovery': attackOnRecovery.name,
    if (restDefence != RestDefence.standard) 'restDefence': restDefence.name,
  };

  factory TransitionTactics.fromJson(Map<String, dynamic> json) =>
      TransitionTactics(
        counterPress: InPossessionTactics.enumOr(
          CounterPress.values,
          json['counterPress'],
          CounterPress.balanced,
        ),
        attackOnRecovery: InPossessionTactics.enumOr(
          AttackOnRecovery.values,
          json['attackOnRecovery'],
          AttackOnRecovery.balanced,
        ),
        restDefence: InPossessionTactics.enumOr(
          RestDefence.values,
          json['restDefence'],
          RestDefence.standard,
        ),
      );

  TransitionTactics copyWith({
    CounterPress? counterPress,
    AttackOnRecovery? attackOnRecovery,
    RestDefence? restDefence,
  }) => TransitionTactics(
    counterPress: counterPress ?? this.counterPress,
    attackOnRecovery: attackOnRecovery ?? this.attackOnRecovery,
    restDefence: restDefence ?? this.restDefence,
  );

  @override
  bool operator ==(Object other) =>
      other is TransitionTactics &&
      other.counterPress == counterPress &&
      other.attackOnRecovery == attackOnRecovery &&
      other.restDefence == restDefence;

  @override
  int get hashCode => Object.hash(counterPress, attackOnRecovery, restDefence);
}
