/// FCM Rivals — In Possession instruction group (GDD 10.2).
///
/// Build-up style, tempo, width, final-third approach and the
/// group container, split verbatim out of `tactics.dart` (T-0039).
library;

import 'dart:math' as math;

import 'tactic_modifiers.dart';
import 'tactic_sliders.dart';

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
/// Each instruction is also a continuous 0–99 slider ([scales], see
/// `tactic_sliders.dart`): the enum fields always hold the NEAREST step
/// (what the set-piece logic, summaries and the AI read), while a stored
/// override carries the exact slider position the engine blends between
/// the tuned anchors. No override → the legacy enum math, bit-identical.
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
    this.scales = const {},
  });

  /// How the team plays out from the back.
  final BuildUpStyle buildUp;

  /// How quickly the ball moves forward.
  final AttackTempo tempo;

  /// Where attacks are staged from.
  final AttackWidth width;

  /// How chances are hunted near goal.
  final FinalThirdApproach finalThird;

  /// Slider overrides by [TacticAxisId.key]; empty = every instruction
  /// sits exactly on its enum step.
  final Map<String, int> scales;

  static const _buildUpAxis = ScaleAxisSpec(
    TacticAxisId.buildUp,
    BuildUpStyle.values,
  );
  static const _tempoAxis = ScaleAxisSpec(
    TacticAxisId.tempo,
    AttackTempo.values,
  );
  static const _widthAxis = ScaleAxisSpec(
    TacticAxisId.width,
    AttackWidth.values,
  );

  /// The axes this group owns, in display order.
  static const List<TacticAxisId> axes = [
    TacticAxisId.buildUp,
    TacticAxisId.tempo,
    TacticAxisId.width,
    TacticAxisId.shotSelection,
    TacticAxisId.crossing,
  ];

  /// Current 0–99 slider position of [axis] (default 50).
  int scaleOf(TacticAxisId axis) => switch (axis) {
    TacticAxisId.buildUp => _buildUpAxis.valueOf(scales, buildUp),
    TacticAxisId.tempo => _tempoAxis.valueOf(scales, tempo),
    TacticAxisId.width => _widthAxis.valueOf(scales, width),
    TacticAxisId.shotSelection =>
      scales['shotSelection'] ??
          switch (finalThird) {
            FinalThirdApproach.workBallIntoBox => 0,
            FinalThirdApproach.shootOnSight => kScaleMax,
            _ => kScaleMid,
          },
    TacticAxisId.crossing =>
      scales['crossing'] ??
          (finalThird == FinalThirdApproach.earlyCrosses
              ? kScaleMax
              : kScaleMid),
    _ => kScaleMid,
  };

  /// This group with [axis] slid to [value] (0–99). The matching enum
  /// field follows to the nearest step; an override equal to a step's
  /// canonical position is dropped (the enum already says it).
  InPossessionTactics withScale(TacticAxisId axis, int value) {
    final v = clampScale(value);
    switch (axis) {
      case TacticAxisId.buildUp:
        return _copy(
          buildUp: _buildUpAxis.stepOf(v) as BuildUpStyle,
          scales: _buildUpAxis.apply(scales, v),
        );
      case TacticAxisId.tempo:
        return _copy(
          tempo: _tempoAxis.stepOf(v) as AttackTempo,
          scales: _tempoAxis.apply(scales, v),
        );
      case TacticAxisId.width:
        return _copy(
          width: _widthAxis.stepOf(v) as AttackWidth,
          scales: _widthAxis.apply(scales, v),
        );
      case TacticAxisId.shotSelection:
        return _withFinalThird(shot: v, cross: scaleOf(TacticAxisId.crossing));
      case TacticAxisId.crossing:
        return _withFinalThird(
          shot: scaleOf(TacticAxisId.shotSelection),
          cross: v,
        );
      default:
        return this;
    }
  }

  /// The final third is two sliders (shot selection and crossing) over a
  /// four-option enum. A pair that is exactly an old option collapses
  /// back to it; any other pair is stored and the enum follows the
  /// nearest option.
  InPossessionTactics _withFinalThird({required int shot, required int cross}) {
    final next = Map<String, int>.of(scales)
      ..remove(TacticAxisId.shotSelection.key)
      ..remove(TacticAxisId.crossing.key);
    FinalThirdApproach? exact;
    if (cross == kScaleMid) {
      exact = switch (shot) {
        0 => FinalThirdApproach.workBallIntoBox,
        kScaleMid => FinalThirdApproach.balanced,
        kScaleMax => FinalThirdApproach.shootOnSight,
        _ => null,
      };
    } else if (cross == kScaleMax && shot == kScaleMid) {
      exact = FinalThirdApproach.earlyCrosses;
    }
    if (exact != null) return _copy(finalThird: exact, scales: next);
    next[TacticAxisId.shotSelection.key] = shot;
    next[TacticAxisId.crossing.key] = cross;
    return _copy(finalThird: _nearestFinalThird(shot, cross), scales: next);
  }

  static FinalThirdApproach _nearestFinalThird(int shot, int cross) {
    if (cross >= 75) return FinalThirdApproach.earlyCrosses;
    if (shot <= 24) return FinalThirdApproach.workBallIntoBox;
    if (shot >= 75) return FinalThirdApproach.shootOnSight;
    return FinalThirdApproach.balanced;
  }

  InPossessionTactics _copy({
    BuildUpStyle? buildUp,
    AttackTempo? tempo,
    AttackWidth? width,
    FinalThirdApproach? finalThird,
    required Map<String, int> scales,
  }) => InPossessionTactics(
    buildUp: buildUp ?? this.buildUp,
    tempo: tempo ?? this.tempo,
    width: width ?? this.width,
    finalThird: finalThird ?? this.finalThird,
    scales: scales,
  );

  /// Whether every instruction sits at its default.
  bool get isDefault =>
      buildUp == BuildUpStyle.mixed &&
      tempo == AttackTempo.standard &&
      width == AttackWidth.standard &&
      finalThird == FinalThirdApproach.balanced &&
      scales.isEmpty;

  /// The final third's bundle: the enum's own, or — once either of its
  /// two sliders has been moved off the old options — the product of
  /// the shot-selection blend and the crossing blend. The crossing low
  /// end has no tuned enum behind it, so it is the mirror image of the
  /// tuned Early Crosses anchor.
  TacticModifiers get _finalThirdModifiers {
    if (!scales.containsKey(TacticAxisId.shotSelection.key) &&
        !scales.containsKey(TacticAxisId.crossing.key)) {
      return finalThird.tuned;
    }
    final shot = axisModifiers(
      low: FinalThirdApproach.workBallIntoBox.tuned,
      mid: FinalThirdApproach.balanced.tuned,
      high: FinalThirdApproach.shootOnSight.tuned,
      value: scaleOf(TacticAxisId.shotSelection),
    );
    final cross = axisModifiers(
      low: mirrorModifiers(FinalThirdApproach.earlyCrosses.tuned),
      mid: FinalThirdApproach.balanced.tuned,
      high: FinalThirdApproach.earlyCrosses.tuned,
      value: scaleOf(TacticAxisId.crossing),
    );
    return shot * cross;
  }

  /// The group's composed contribution to the engine bundle.
  /// Composed through the tuning seam (`.tuned`): the shipped
  /// constants when no sweep override is installed. With no slider
  /// override this is exactly the legacy enum product.
  TacticModifiers get modifiers {
    if (scales.isEmpty) {
      return buildUp.tuned * tempo.tuned * width.tuned * finalThird.tuned;
    }
    return _buildUpAxis.modifiersOf(scales, buildUp) *
        _tempoAxis.modifiersOf(scales, tempo) *
        _widthAxis.modifiersOf(scales, width) *
        _finalThirdModifiers;
  }

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
    if (scales.isNotEmpty) 'scales': Map<String, int>.of(scales),
  };

  factory InPossessionTactics.fromJson(Map<String, dynamic> json) {
    var t = InPossessionTactics(
      buildUp: enumOr(BuildUpStyle.values, json['buildUp'], BuildUpStyle.mixed),
      tempo: enumOr(AttackTempo.values, json['tempo'], AttackTempo.standard),
      width: enumOr(AttackWidth.values, json['width'], AttackWidth.standard),
      finalThird: enumOr(
        FinalThirdApproach.values,
        json['finalThird'],
        FinalThirdApproach.balanced,
      ),
    );
    // Fold the stored slider positions in through the normalising setter
    // so the enum fields and the overrides always agree, whatever the
    // payload said.
    final stored = parseScales(json['scales'], axes);
    for (final axis in axes) {
      final v = stored[axis.key];
      if (v != null) t = t.withScale(axis, v);
    }
    return t;
  }

  /// Tolerant enum parse: unknown or missing keys fall back to default
  /// so a payload from any earlier phase keeps loading.
  static T enumOr<T extends Enum>(List<T> values, Object? raw, T fallback) {
    if (raw is! String) return fallback;
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return fallback;
  }

  /// Sets an instruction to an exact enum step. Choosing a step drops
  /// the slider override of that instruction (the step IS its position).
  InPossessionTactics copyWith({
    BuildUpStyle? buildUp,
    AttackTempo? tempo,
    AttackWidth? width,
    FinalThirdApproach? finalThird,
  }) {
    final next = Map<String, int>.of(scales);
    if (buildUp != null) next.remove(TacticAxisId.buildUp.key);
    if (tempo != null) next.remove(TacticAxisId.tempo.key);
    if (width != null) next.remove(TacticAxisId.width.key);
    if (finalThird != null) {
      next
        ..remove(TacticAxisId.shotSelection.key)
        ..remove(TacticAxisId.crossing.key);
    }
    return _copy(
      buildUp: buildUp,
      tempo: tempo,
      width: width,
      finalThird: finalThird,
      scales: next,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is InPossessionTactics &&
      other.buildUp == buildUp &&
      other.tempo == tempo &&
      other.width == width &&
      other.finalThird == finalThird &&
      scalesEqual(other.scales, scales);

  @override
  int get hashCode =>
      Object.hash(buildUp, tempo, width, finalThird, scalesHash(scales));
}
