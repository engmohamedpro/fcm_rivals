/// FCM Rivals — Transitions instruction group (GDD 10.2).
///
/// Counter-press, attack on recovery, rest defence and the group
/// container, split verbatim out of `tactics.dart` (T-0039).
library;

import 'in_possession_tactics.dart';
import 'tactic_modifiers.dart';
import 'tactic_sliders.dart';

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
///
/// All three are also continuous 0–99 sliders ([scales], see
/// `tactic_sliders.dart`): the enum fields always hold the nearest step,
/// a stored override carries the exact position the engine blends
/// between the tuned anchors. No override → the legacy enum math,
/// bit-identical.
class TransitionTactics {
  const TransitionTactics({
    this.counterPress = CounterPress.balanced,
    this.attackOnRecovery = AttackOnRecovery.balanced,
    this.restDefence = RestDefence.standard,
    this.scales = const {},
  });

  final CounterPress counterPress;
  final AttackOnRecovery attackOnRecovery;
  final RestDefence restDefence;

  /// Slider overrides by [TacticAxisId.key]; empty = every instruction
  /// sits exactly on its enum step.
  final Map<String, int> scales;

  static const _counterAxis = ScaleAxisSpec(
    TacticAxisId.counterPress,
    CounterPress.values,
  );
  static const _recoveryAxis = ScaleAxisSpec(
    TacticAxisId.attackOnRecovery,
    AttackOnRecovery.values,
  );
  static const _restAxis = ScaleAxisSpec(
    TacticAxisId.restDefence,
    RestDefence.values,
  );

  /// The axes this group owns, in display order.
  static const List<TacticAxisId> axes = [
    TacticAxisId.counterPress,
    TacticAxisId.attackOnRecovery,
    TacticAxisId.restDefence,
  ];

  /// Current 0–99 slider position of [axis] (default 50).
  int scaleOf(TacticAxisId axis) => switch (axis) {
    TacticAxisId.counterPress => _counterAxis.valueOf(scales, counterPress),
    TacticAxisId.attackOnRecovery => _recoveryAxis.valueOf(
      scales,
      attackOnRecovery,
    ),
    TacticAxisId.restDefence => _restAxis.valueOf(scales, restDefence),
    _ => kScaleMid,
  };

  /// This group with [axis] slid to [value] (0–99). The matching enum
  /// field follows to the nearest step; an override equal to a step's
  /// canonical position is dropped (the enum already says it).
  TransitionTactics withScale(TacticAxisId axis, int value) {
    final v = clampScale(value);
    switch (axis) {
      case TacticAxisId.counterPress:
        return _copy(
          counterPress: _counterAxis.stepOf(v) as CounterPress,
          scales: _counterAxis.apply(scales, v),
        );
      case TacticAxisId.attackOnRecovery:
        return _copy(
          attackOnRecovery: _recoveryAxis.stepOf(v) as AttackOnRecovery,
          scales: _recoveryAxis.apply(scales, v),
        );
      case TacticAxisId.restDefence:
        return _copy(
          restDefence: _restAxis.stepOf(v) as RestDefence,
          scales: _restAxis.apply(scales, v),
        );
      default:
        return this;
    }
  }

  TransitionTactics _copy({
    CounterPress? counterPress,
    AttackOnRecovery? attackOnRecovery,
    RestDefence? restDefence,
    required Map<String, int> scales,
  }) => TransitionTactics(
    counterPress: counterPress ?? this.counterPress,
    attackOnRecovery: attackOnRecovery ?? this.attackOnRecovery,
    restDefence: restDefence ?? this.restDefence,
    scales: scales,
  );

  bool get isDefault =>
      counterPress == CounterPress.balanced &&
      attackOnRecovery == AttackOnRecovery.balanced &&
      restDefence == RestDefence.standard &&
      scales.isEmpty;

  /// Composed through the tuning seam (`.tuned`): the shipped
  /// constants when no sweep override is installed. With no slider
  /// override this is exactly the legacy enum product.
  TacticModifiers get modifiers {
    if (scales.isEmpty) {
      return counterPress.tuned * attackOnRecovery.tuned * restDefence.tuned;
    }
    return _counterAxis.modifiersOf(scales, counterPress) *
        _recoveryAxis.modifiersOf(scales, attackOnRecovery) *
        _restAxis.modifiersOf(scales, restDefence);
  }

  /// Human-visible effect summary (GDD 10.3: effects must be visible).
  String get effectSummary => modifiers.effectSummary;

  Map<String, dynamic> toJson() => {
    if (counterPress != CounterPress.balanced)
      'counterPress': counterPress.name,
    if (attackOnRecovery != AttackOnRecovery.balanced)
      'attackOnRecovery': attackOnRecovery.name,
    if (restDefence != RestDefence.standard) 'restDefence': restDefence.name,
    if (scales.isNotEmpty) 'scales': Map<String, int>.of(scales),
  };

  factory TransitionTactics.fromJson(Map<String, dynamic> json) {
    var t = TransitionTactics(
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
    // Fold stored slider positions in through the normalising setter so
    // enum fields and overrides always agree.
    final stored = parseScales(json['scales'], axes);
    for (final axis in axes) {
      final v = stored[axis.key];
      if (v != null) t = t.withScale(axis, v);
    }
    return t;
  }

  /// Sets an instruction to an exact enum step. Choosing a step drops
  /// the slider override of that instruction (the step IS its position).
  TransitionTactics copyWith({
    CounterPress? counterPress,
    AttackOnRecovery? attackOnRecovery,
    RestDefence? restDefence,
  }) {
    final next = Map<String, int>.of(scales);
    if (counterPress != null) next.remove(TacticAxisId.counterPress.key);
    if (attackOnRecovery != null) {
      next.remove(TacticAxisId.attackOnRecovery.key);
    }
    if (restDefence != null) next.remove(TacticAxisId.restDefence.key);
    return _copy(
      counterPress: counterPress,
      attackOnRecovery: attackOnRecovery,
      restDefence: restDefence,
      scales: next,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TransitionTactics &&
      other.counterPress == counterPress &&
      other.attackOnRecovery == attackOnRecovery &&
      other.restDefence == restDefence &&
      scalesEqual(other.scales, scales);

  @override
  int get hashCode => Object.hash(
    counterPress,
    attackOnRecovery,
    restDefence,
    scalesHash(scales),
  );
}
