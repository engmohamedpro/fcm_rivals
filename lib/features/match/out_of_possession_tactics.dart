/// FCM Rivals — Out of Possession instruction group (GDD 10.2).
///
/// Defensive line, pressing intensity, tackling aggression, the
/// offside trap constants and the group container, split verbatim
/// out of `tactics.dart` (T-0039).
library;

import 'in_possession_tactics.dart';
import 'tactic_modifiers.dart';
import 'tactic_sliders.dart';

/// Out of Possession instructions (GDD 10.2): line height, pressing,
/// tackling and the offside trap. Phase 0 scaffold — the fields arrive
/// in phase 2.
/// Defensive line height (GDD 10.2 Out of Possession).
enum DefensiveLine implements InstructionOption {
  // Phase-3 landing 2026-11-06: deep possession 0.91 -> 0.92. Sweep
  // line (aligned harness, both pools): `deep` single 47.8% W suite
  // pool / 46.3% sweep pool (green, band 46-54) at 0.92; parkTheBus
  // possession 41.8/41.9 stays green (band 30-42) — the low-press
  // trim landed together (0.86, see PressingIntensity.low).
  deep('Deep Line', TacticModifiers(defence: 1.05, possession: 0.92)),
  standard('Standard', TacticModifiers.identity),
  high('High Line', TacticModifiers(defence: 0.94, possession: 1.04));

  const DefensiveLine(this.displayName, this.modifiers);

  final String displayName;
  @override
  final TacticModifiers modifiers;
}

/// Pressing intensity. The High-press stamina cost (1.28) is anchored
/// to the §34 gegenpress cost of 1.30.
enum PressingIntensity implements InstructionOption {
  // Anchor pass 2026-11-06 on the High Press bundle: defence
  // 1.28 -> 1.34, chance 1.04 -> 1.16. Sweep line (aligned harness,
  // both pools): `highPress` single 48.6% suite pool / 46.6% sweep
  // pool W (green, band 46-54) at 1.34/1.16; allAttack no-collapse
  // 42.3/43.7 green (the stack's press finally pays its way);
  // gegenpress late goals close through the stamina-stack damp and
  // the press-bill slope (see ComposeRule and TuningOverrides
  // comments — the slope moved 2.0 -> 4.2 in the phase-3 landing and
  // is frozen since).
  low(
    'Low Press',
    // Final trim 2026-11-06 (anchor pass): possession 0.94 -> 0.86.
    // Aligned-harness sweep lines (both pools): parkTheBus possession
    // 41.8/41.9 green (band 30-42) at 0.86 with the deep-line and
    // fast-counter trims landed; `lowPress` single 47.9/46.5% W
    // (band 46-54) across the landed range. (An earlier comment here
    // recorded 0.88 while the constant carried 0.86 — the pre-alignment
    // tool's numbers; corrected to the landed value.)
    TacticModifiers(defence: 1.02, stamina: 0.88, possession: 0.86),
  ),
  mid('Mid Press', TacticModifiers.identity),
  high(
    'High Press',
    TacticModifiers(defence: 1.34, chance: 1.16, stamina: 1.30),
  );

  const PressingIntensity(this.displayName, this.modifiers);

  final String displayName;
  @override
  final TacticModifiers modifiers;
}

/// Tackling aggression. The foul and yellow scaling factors ride the
/// engine's per-side foul/card probabilities (phase 2 Task 2), not
/// this bundle.
enum TacklingAggression implements InstructionOption {
  clean(
    'Clean',
    TacticModifiers(defence: 0.98),
    foulScale: 0.75,
    yellowScale: 0.70,
  ),
  balanced(
    'Balanced',
    TacticModifiers.identity,
    foulScale: 1.00,
    yellowScale: 1.00,
  ),
  aggressive(
    'Aggressive',
    TacticModifiers(defence: 1.04),
    foulScale: 1.30,
    // The engine applies foulScale AND yellowScale on the same path,
    // so the composed yellow delta is their product minus one. 1.30 ×
    // 1.04 ≈ +35%, inside the review's +30-40% band.
    yellowScale: 1.04,
  );

  const TacklingAggression(
    this.displayName,
    this.modifiers, {
    required this.foulScale,
    required this.yellowScale,
  });

  final String displayName;
  @override
  final TacticModifiers modifiers;

  /// Multiplier on this side's foul-emission probability.
  final double foulScale;

  /// Multiplier on this side's yellow-card probability.
  final double yellowScale;
}

/// The offside trap's shape (GDD 10.2): a stochastic hook on conceded
/// chances — most get worse (×0.94), a beaten trap (6%) gets amplified
/// (×1.15). Net negative for the opponent, with tail risk. The state
/// itself is a plain bool on the instruction group.
class OffsideTrapToggles {
  const OffsideTrapToggles._();

  /// Share of conceded chances that beat the trap while it is on.
  static const double beatenShare = 0.06;

  /// Quality multiplier applied to conceded chances while the trap
  /// holds (the majority case).
  static const double heldQuality = 0.94;

  /// Quality multiplier for the beaten-trap tail risk.
  static const double beatenQuality = 1.15;
}

/// Out of Possession instructions (GDD 10.2): line height, pressing,
/// tackling aggression and the offside trap. Defaults (Standard / Mid /
/// Balanced / Off) are the identity; combinations rebuild the removed
/// High Press, Gegenpressing (with phase 3) and Low Block styles.
///
/// Line height, pressing and tackling are also continuous 0–99 sliders
/// ([scales], see `tactic_sliders.dart`): the enum fields always hold
/// the nearest step (what the set-piece logic and summaries read), a
/// stored override carries the exact position the engine blends between
/// the tuned anchors. No override → the legacy enum math, bit-identical.
/// The offside trap is a switch, not a scale.
class OutOfPossessionTactics {
  const OutOfPossessionTactics({
    this.defensiveLine = DefensiveLine.standard,
    this.pressing = PressingIntensity.mid,
    this.tackling = TacklingAggression.balanced,
    this.offsideTrap = false,
    this.scales = const {},
  });

  final DefensiveLine defensiveLine;
  final PressingIntensity pressing;
  final TacklingAggression tackling;

  /// Whether the offside trap is on.
  final bool offsideTrap;

  /// Slider overrides by [TacticAxisId.key]; empty = every instruction
  /// sits exactly on its enum step.
  final Map<String, int> scales;

  static const _lineAxis = ScaleAxisSpec(
    TacticAxisId.defensiveLine,
    DefensiveLine.values,
  );
  static const _pressAxis = ScaleAxisSpec(
    TacticAxisId.pressing,
    PressingIntensity.values,
  );
  static const _tackleAxis = ScaleAxisSpec(
    TacticAxisId.tackling,
    TacklingAggression.values,
  );

  /// The axes this group owns, in display order.
  static const List<TacticAxisId> axes = [
    TacticAxisId.defensiveLine,
    TacticAxisId.pressing,
    TacticAxisId.tackling,
  ];

  /// Current 0–99 slider position of [axis] (default 50).
  int scaleOf(TacticAxisId axis) => switch (axis) {
    TacticAxisId.defensiveLine => _lineAxis.valueOf(scales, defensiveLine),
    TacticAxisId.pressing => _pressAxis.valueOf(scales, pressing),
    TacticAxisId.tackling => _tackleAxis.valueOf(scales, tackling),
    _ => kScaleMid,
  };

  /// This group with [axis] slid to [value] (0–99). The matching enum
  /// field follows to the nearest step; an override equal to a step's
  /// canonical position is dropped (the enum already says it).
  OutOfPossessionTactics withScale(TacticAxisId axis, int value) {
    final v = clampScale(value);
    switch (axis) {
      case TacticAxisId.defensiveLine:
        return _copy(
          defensiveLine: _lineAxis.stepOf(v) as DefensiveLine,
          scales: _lineAxis.apply(scales, v),
        );
      case TacticAxisId.pressing:
        return _copy(
          pressing: _pressAxis.stepOf(v) as PressingIntensity,
          scales: _pressAxis.apply(scales, v),
        );
      case TacticAxisId.tackling:
        return _copy(
          tackling: _tackleAxis.stepOf(v) as TacklingAggression,
          scales: _tackleAxis.apply(scales, v),
        );
      default:
        return this;
    }
  }

  OutOfPossessionTactics _copy({
    DefensiveLine? defensiveLine,
    PressingIntensity? pressing,
    TacklingAggression? tackling,
    bool? offsideTrap,
    required Map<String, int> scales,
  }) => OutOfPossessionTactics(
    defensiveLine: defensiveLine ?? this.defensiveLine,
    pressing: pressing ?? this.pressing,
    tackling: tackling ?? this.tackling,
    offsideTrap: offsideTrap ?? this.offsideTrap,
    scales: scales,
  );

  bool get isDefault =>
      defensiveLine == DefensiveLine.standard &&
      pressing == PressingIntensity.mid &&
      tackling == TacklingAggression.balanced &&
      !offsideTrap &&
      scales.isEmpty;

  /// Multiplier on this side's foul-emission probability — the tackling
  /// slider blended between the tuned Clean / Balanced / Aggressive
  /// scales (exactly the enum's own at the three anchors).
  double get foulScale {
    final v = scales[TacticAxisId.tackling.key];
    if (v == null) return tackling.foulScale;
    return axisScalar(
      low: TacklingAggression.clean.foulScale,
      mid: TacklingAggression.balanced.foulScale,
      high: TacklingAggression.aggressive.foulScale,
      value: v,
    );
  }

  /// Multiplier on this side's yellow-card probability, blended the
  /// same way as [foulScale].
  double get yellowScale {
    final v = scales[TacticAxisId.tackling.key];
    if (v == null) return tackling.yellowScale;
    return axisScalar(
      low: TacklingAggression.clean.yellowScale,
      mid: TacklingAggression.balanced.yellowScale,
      high: TacklingAggression.aggressive.yellowScale,
      value: v,
    );
  }

  /// Composed through the tuning seam (`.tuned`): the shipped
  /// constants when no sweep override is installed. With no slider
  /// override this is exactly the legacy enum product.
  TacticModifiers get modifiers {
    if (scales.isEmpty) {
      return defensiveLine.tuned * pressing.tuned * tackling.tuned;
    }
    return _lineAxis.modifiersOf(scales, defensiveLine) *
        _pressAxis.modifiersOf(scales, pressing) *
        _tackleAxis.modifiersOf(scales, tackling);
  }

  /// Human-visible effect summary (GDD 10.3: effects must be visible).
  String get effectSummary {
    final base = modifiers.effectSummary;
    if (!offsideTrap) return base;
    final trapLine = 'Offside trap: tighter line, 6% breakaway risk';
    return base == 'No modifiers' ? trapLine : '$base · $trapLine';
  }

  Map<String, dynamic> toJson() => {
    if (defensiveLine != DefensiveLine.standard)
      'defensiveLine': defensiveLine.name,
    if (pressing != PressingIntensity.mid) 'pressing': pressing.name,
    if (tackling != TacklingAggression.balanced) 'tackling': tackling.name,
    if (offsideTrap) 'offsideTrap': true,
    if (scales.isNotEmpty) 'scales': Map<String, int>.of(scales),
  };

  factory OutOfPossessionTactics.fromJson(Map<String, dynamic> json) {
    var t = OutOfPossessionTactics(
      defensiveLine: InPossessionTactics.enumOr(
        DefensiveLine.values,
        json['defensiveLine'],
        DefensiveLine.standard,
      ),
      pressing: InPossessionTactics.enumOr(
        PressingIntensity.values,
        json['pressing'],
        PressingIntensity.mid,
      ),
      tackling: InPossessionTactics.enumOr(
        TacklingAggression.values,
        json['tackling'],
        TacklingAggression.balanced,
      ),
      offsideTrap: json['offsideTrap'] == true,
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
  OutOfPossessionTactics copyWith({
    DefensiveLine? defensiveLine,
    PressingIntensity? pressing,
    TacklingAggression? tackling,
    bool? offsideTrap,
  }) {
    final next = Map<String, int>.of(scales);
    if (defensiveLine != null) next.remove(TacticAxisId.defensiveLine.key);
    if (pressing != null) next.remove(TacticAxisId.pressing.key);
    if (tackling != null) next.remove(TacticAxisId.tackling.key);
    return _copy(
      defensiveLine: defensiveLine,
      pressing: pressing,
      tackling: tackling,
      offsideTrap: offsideTrap,
      scales: next,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OutOfPossessionTactics &&
      other.defensiveLine == defensiveLine &&
      other.pressing == pressing &&
      other.tackling == tackling &&
      other.offsideTrap == offsideTrap &&
      scalesEqual(other.scales, scales);

  @override
  int get hashCode => Object.hash(
    defensiveLine,
    pressing,
    tackling,
    offsideTrap,
    scalesHash(scales),
  );
}
