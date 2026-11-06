/// FCM Rivals — In Possession instruction group (GDD 10.2).
///
/// Build-up style, tempo, width, final-third approach and the
/// group container, split verbatim out of `tactics.dart` (T-0039).
library;

import 'dart:math' as math;

import 'tactic_modifiers.dart';

/// In Possession instructions (GDD 10.2): build-up, tempo, width and
/// final-third approach. Phase 0 scaffold — the fields arrive in
/// phase 1, so this carries only the group identity.
/// Build-up style: how the team plays out from the back (GDD 10.2 In
/// Possession). Anchor values are GDD rule 14 placeholders, tuned by
/// the balance harness.
enum BuildUpStyle implements InstructionOption {
  playOut(
    'Play Out from the Back',
    TacticModifiers(possession: 1.06, passAccuracy: 1.05, chance: 0.94),
  ),
  mixed('Mixed Build-Up', TacticModifiers.identity),
  longBall(
    'Long Ball',
    TacticModifiers(
      possession: 0.95,
      passAccuracy: 0.91,
      chance: 1.06,
      stamina: 0.96,
    ),
  );

  const BuildUpStyle(this.displayName, this.modifiers);

  final String displayName;
  @override
  final TacticModifiers modifiers;
}

/// Tempo: how quickly the ball moves forward.
enum AttackTempo implements InstructionOption {
  slow('Slow', TacticModifiers(possession: 1.03, chance: 0.95, stamina: 0.94)),
  standard('Standard', TacticModifiers.identity),
  fast(
    'Fast',
    // Final trim 2026-11-06 (anchor pass, task
    // `2026-11-06_tactics_phase3-anchor-pass-and-gates`): chance
    // 1.05 -> 1.06, passing 0.97 -> 0.99, stamina 1.04 -> 1.02
    // (possession stays 0.97). Aligned-harness sweep lines (suite
    // pool = the suite's own seeds; sweep pool disjoint): `fast`
    // single 45.3% W (red, band 46-54) at 1.05/0.97/1.04; chance
    // alone 1.06 moved it only to 45.4 (+0.1pp); the combined trim ->
    // 47.3% W green, sweep pool 47.4% green. Stack rows held:
    // maxDirect 45.5/47.8, allAttack no-collapse 42.3/43.7 (band
    // >=38), corners allAttack goals 2.65/2.60 (<=3.2).
    TacticModifiers(
      possession: 0.97,
      chance: 1.06,
      passAccuracy: 0.99,
      stamina: 1.02,
    ),
  );

  const AttackTempo(this.displayName, this.modifiers);

  final String displayName;
  @override
  final TacticModifiers modifiers;
}

/// Width: where the attacks are staged from.
enum AttackWidth implements InstructionOption {
  narrow('Narrow', TacticModifiers(passAccuracy: 1.04, chance: 0.96)),
  standard('Standard', TacticModifiers.identity),
  wide('Wide', TacticModifiers(passAccuracy: 0.96, chance: 1.03));

  const AttackWidth(this.displayName, this.modifiers);

  final String displayName;
  @override
  final TacticModifiers modifiers;
}

/// Final-third approach: how chances are hunted near goal.
enum FinalThirdApproach implements InstructionOption {
  workBallIntoBox(
    'Work Ball into Box',
    // Final trim 2026-11-06 (anchor pass): shot quality 1.08 -> 1.10.
    // Aligned-harness sweep lines: allDefence goals 2.38 (red, band
    // >=2.4) -> 2.41 green with the patient chance trim landed
    // together (see AttackOnRecovery.patient); the row is the
    // cross-phase corners floor. Matrix note: shot quality rides the
    // playOut+slow+wide+workBall combo (+0.3pp W at 1.10) — covered
    // by the possession-hoard damp close (ComposeRule comment);
    // maxPossession goals 2.80/2.84 (band 2.4-3.1), `workBall` single
    // 49.8/50.6 green on both pools.
    TacticModifiers(chance: 0.92, shotQuality: 1.10),
  ),
  balanced('Balanced', TacticModifiers.identity),
  earlyCrosses(
    'Early Crosses',
    TacticModifiers(chance: 1.04, shotQuality: 0.95, passAccuracy: 0.96),
  ),
  shootOnSight(
    'Shoot on Sight',
    TacticModifiers(chance: 1.04, shotQuality: 0.94),
  );

  const FinalThirdApproach(this.displayName, this.modifiers);

  final String displayName;
  @override
  final TacticModifiers modifiers;
}

/// In Possession instructions (GDD 10.2): build-up, tempo, width and
/// final-third approach. Every default (Mixed / Standard / Standard /
/// Balanced) contributes the identity, so a default group changes
/// nothing — combinations rebuild the removed possession/direct/long-
/// ball/wing styles (Play Out + Slow + Narrow ≈ old Tiki-Taka).
///
/// "Attacking freedom / fluidity" is deliberately NOT here: the engine
/// has no off-ball-movement axis to express it honestly, and fake depth
/// is worse than absent depth.
class InPossessionTactics {
  const InPossessionTactics({
    this.buildUp = BuildUpStyle.mixed,
    this.tempo = AttackTempo.standard,
    this.width = AttackWidth.standard,
    this.finalThird = FinalThirdApproach.balanced,
  });

  /// How the team plays out from the back.
  final BuildUpStyle buildUp;

  /// How quickly the ball moves forward.
  final AttackTempo tempo;

  /// Where attacks are staged from.
  final AttackWidth width;

  /// How chances are hunted near goal.
  final FinalThirdApproach finalThird;

  /// Whether every instruction sits at its default.
  bool get isDefault =>
      buildUp == BuildUpStyle.mixed &&
      tempo == AttackTempo.standard &&
      width == AttackWidth.standard &&
      finalThird == FinalThirdApproach.balanced;

  /// The group's composed contribution to the engine bundle.
  /// Composed through the tuning seam (`.tuned`): the shipped
  /// constants when no sweep override is installed.
  TacticModifiers get modifiers =>
      buildUp.tuned * tempo.tuned * width.tuned * finalThird.tuned;

  /// Human-visible effect summary (GDD 10.3: effects must be visible),
  /// in the same honest-estimate format as the old possession line.
  String get effectSummary => modifiers.effectSummary;

  /// Estimated possession share at even strength from the composed
  /// possession multiplier — the honest-share formula the engine's
  /// power competition actually produces (`m^1.4 / (m^1.4 + 1)`).
  int get estimatedPossessionShare {
    final m = modifiers.possession;
    final w = math.pow(m, 1.4).toDouble();
    return (100 * w / (w + 1)).round();
  }

  Map<String, dynamic> toJson() => {
    if (buildUp != BuildUpStyle.mixed) 'buildUp': buildUp.name,
    if (tempo != AttackTempo.standard) 'tempo': tempo.name,
    if (width != AttackWidth.standard) 'width': width.name,
    if (finalThird != FinalThirdApproach.balanced)
      'finalThird': finalThird.name,
  };

  factory InPossessionTactics.fromJson(Map<String, dynamic> json) =>
      InPossessionTactics(
        buildUp: enumOr(
          BuildUpStyle.values,
          json['buildUp'],
          BuildUpStyle.mixed,
        ),
        tempo: enumOr(AttackTempo.values, json['tempo'], AttackTempo.standard),
        width: enumOr(AttackWidth.values, json['width'], AttackWidth.standard),
        finalThird: enumOr(
          FinalThirdApproach.values,
          json['finalThird'],
          FinalThirdApproach.balanced,
        ),
      );

  /// Tolerant enum parse: unknown or missing keys fall back to default
  /// so a payload from any earlier phase keeps loading.
  static T enumOr<T extends Enum>(List<T> values, Object? raw, T fallback) {
    if (raw is! String) return fallback;
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return fallback;
  }

  InPossessionTactics copyWith({
    BuildUpStyle? buildUp,
    AttackTempo? tempo,
    AttackWidth? width,
    FinalThirdApproach? finalThird,
  }) => InPossessionTactics(
    buildUp: buildUp ?? this.buildUp,
    tempo: tempo ?? this.tempo,
    width: width ?? this.width,
    finalThird: finalThird ?? this.finalThird,
  );

  @override
  bool operator ==(Object other) =>
      other is InPossessionTactics &&
      other.buildUp == buildUp &&
      other.tempo == tempo &&
      other.width == width &&
      other.finalThird == finalThird;

  @override
  int get hashCode => Object.hash(buildUp, tempo, width, finalThird);
}
