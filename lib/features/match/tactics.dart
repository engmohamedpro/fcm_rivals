/// FCM Rivals — tactical domain (GDD 10, GDD 16).
///
/// Custom Tactics, Mentalities and Live Match Actions as pure data with
/// explicit percentage modifiers. All effects are visible to the user
/// (GDD 10.3): the numbers below are surfaced by the UI and are
/// pre-balance placeholders (GDD rule 14) gathered for simulation tuning.
///
/// Phase 0: the ten preset Playing Styles are removed (GDD 10.2 is now
/// "Custom Tactics"). [TeamTactics] composes three instruction groups —
/// In Possession, Out of Possession and Transitions — delivered in
/// phases 1-3. In phase 0 every group carries its defaults only, so the
/// computed modifier bundle is the identity (all 1.00) and gameplay is
/// bit-identical to the legacy Balanced preset. Legacy styles
/// are NOT lost: each is rebuilt as an instruction combination (see the
/// mapping table in GDD 10.2).
library;

import 'dart:convert';
import 'dart:math' as math;

/// The composed modifier bundle the engine consumes — the Custom Tactics
/// successor of the removed style-modifier bundle. One place lists every axis
/// the tactics system can move; the engine applies each axis at exactly
/// one hook site (possession inside the power competition, chance at
/// chance creation, passAccuracy at pass completion, stamina at the
/// drain, shotQuality on the chance→goal conversion path from phase 1).
class TacticModifiers {
  const TacticModifiers({
    this.attack = 1.00,
    this.defence = 1.00,
    this.possession = 1.00,
    this.chance = 1.00,
    this.stamina = 1.00,
    this.passAccuracy = 1.00,
    this.shotQuality = 1.00,
  });

  /// Multiplier on team Attack total.
  final double attack;

  /// Multiplier on team Defence total.
  final double defence;

  /// Multiplier on possession bias — applied ONCE, inside the engine's
  /// possession power competition (`support × possession`, raised to the
  /// power 1.4).
  final double possession;

  /// Multiplier on chance creation probability.
  final double chance;

  /// Multiplier on stamina consumption (GDD 11.3).
  final double stamina;

  /// Multiplier on pass completion probability.
  final double passAccuracy;

  /// Multiplier on the quality of chances created (phase 1 hook on the
  /// chance→goal conversion path).
  final double shotQuality;

  /// The identity bundle: every axis at 1.00, gameplay untouched.
  static const TacticModifiers identity = TacticModifiers();

  /// Composes two bundles multiplicatively (instruction groups stack by
  /// multiplication, never by addition — the same rule the engine's
  /// single-application sites enforce), with diminishing returns on
  /// stacked same-direction pushes: when both sides already deviate
  /// from 1.0 the same way, the excess over 1.0 of the product is
  /// damped — the second aggressive instruction adds less than the
  /// first, so extreme combos stay playable.
  ///
  /// The damp factors come from [TuningOverrides.current.compose]; the
  /// shipped [ComposeRule] carries 0.70 (costs), 0.55 (stamina) and
  /// 1.0 (possession, both directions — LINEAR: a low-block counter
  /// side's identity IS ceding the ball, and hoarding instructions
  /// stack at full strength), so this method is bit-identical to the
  /// no-seam build in production.
  TacticModifiers operator *(TacticModifiers other) {
    final c = TuningOverrides.current.compose;
    return TacticModifiers(
      attack: _damped(attack, other.attack, c.costStackDamp),
      defence: _damped(defence, other.defence, c.costStackDamp),
      possession: _dampedPossession(possession, other.possession, c),
      chance: _damped(chance, other.chance, c.costStackDamp),
      stamina: _dampedStamina(stamina, other.stamina, c.staminaStackDamp),
      passAccuracy: _damped(passAccuracy, other.passAccuracy, c.costStackDamp),
      shotQuality: _damped(shotQuality, other.shotQuality, c.costStackDamp),
    );
  }

  /// Product with damped stacked excess; opposing pushes cancel
  /// naturally through the plain product. [damp] is the share of the
  /// stacked excess that survives.
  static double _damped(double a, double b, double damp) {
    final product = a * b;
    final stacked = (a - 1) * (b - 1) > 0;
    if (!stacked) return product;
    return 1 + (product - 1) * damp;
  }

  /// Possession composes through the same damp rule as the other axes,
  /// with its own per-direction factors so the sweep can damp the
  /// hoarding direction (>1 stacks) and the ceding direction (<1
  /// stacks) independently (review Task 2 options a/b). Both shipped
  /// factors are 1.0, so the compose stays LINEAR in production and
  /// this method returns the plain product bit-identically.
  static double _dampedPossession(double a, double b, ComposeRule c) {
    final product = a * b;
    if ((a - 1) * (b - 1) <= 0) return product;
    final damp = product > 1
        ? c.possessionStackDampAbove
        : c.possessionStackDampBelow;
    if (damp >= 1.0) return product;
    return 1 + (product - 1) * damp;
  }

  /// Stamina stacks are the killer (the gegenpress bill); damp them
  /// harder so three stamina costs compose to a real but survivable
  /// bill.
  static double _dampedStamina(double a, double b, double damp) {
    final product = a * b;
    final stacked = (a - 1) * (b - 1) > 0;
    if (!stacked) return product;
    return 1 + (product - 1) * damp;
  }

  /// Human-visible effect summary (GDD 10.3: effects must be visible).
  ///
  /// The possession line is HONEST: it shows the estimated possession
  /// share the engine's power competition actually produces at even
  /// strength (`m^1.4 / (m^1.4 + 1)`), not the raw multiplier — a +17%
  /// multiplier reads as a big number but swings the measured share by
  /// only ~5-6 points, and the UI must not promise more than the
  /// simulation delivers. The estimate tracks the measured share of a
  /// seeded run within ±2 points.
  String get effectSummary {
    final parts = <String>[];

    void describe(String name, double multiplier) {
      final percent = ((multiplier - 1) * 100).round();
      if (percent == 0) return;
      parts.add('$name ${percent > 0 ? '+' : ''}$percent%');
    }

    if (possession != 1.0) {
      final w = math.pow(possession, 1.4).toDouble();
      final share = 100 * w / (w + 1);
      parts.add('Est. possession ${share.round()}%');
    }
    describe('Attack', attack);
    describe('Defence', defence);
    describe('Chances', chance);
    describe('Shot quality', shotQuality);
    describe('Stamina use', stamina);
    describe('Passing', passAccuracy);
    return parts.isEmpty ? 'No modifiers' : parts.join(' · ');
  }
}

/// A tunable instruction option: every custom-tactics instruction enum
/// implements this so the balance sweep can address any option's
/// modifiers uniformly (see [TuningOverrides]).
abstract interface class InstructionOption {
  /// This option's shipped modifier bundle (a GDD rule 14 anchor).
  TacticModifiers get modifiers;
}

/// The instruction-compose damp factors (review
/// 2026-11-05_tactics_phase3-balance-bands-and-sweep, Task 2). The
/// shipped rule: cost axes damp stacked excess at 0.70, stamina at
/// 0.55, possession composes LINEARLY (both directions at 1.0).
class ComposeRule {
  const ComposeRule({
    this.costStackDamp = 0.70,
    this.staminaStackDamp = 0.55,
    this.possessionStackDampAbove = 1.0,
    this.possessionStackDampBelow = 1.0,
  });

  /// The shipped compose rule (identity of this class's defaults).
  static const ComposeRule shipped = ComposeRule();

  /// Damp on stacked same-direction excess for the cost axes
  /// (attack/defence/chance/passAccuracy/shotQuality).
  final double costStackDamp;

  /// Damp on stacked stamina costs (the gegenpress bill).
  final double staminaStackDamp;

  /// Damp on stacked possession-HOARDING pushes (both factors > 1).
  /// 1.0 = linear, the shipped rule.
  final double possessionStackDampAbove;

  /// Damp on stacked possession-CEDING pushes (both factors < 1).
  /// 1.0 = linear, the shipped rule.
  final double possessionStackDampBelow;
}

/// Tuning seam for the balance sweep (`tool/tactics_tuning_sweep.dart`,
/// review Task 1). Production never touches it: [current] stays
/// [none], so every `.tuned` lookup falls through to the instruction's
/// shipped constant and gameplay is bit-identical to the no-seam
/// build. The sweep installs a candidate (instruction overrides + a
/// compose rule) before building engines and restores [none] after.
class TuningOverrides {
  const TuningOverrides._(
    this._instructions,
    this.compose, {
    this.pressBillSlope = 2.0,
  });

  /// No overrides: shipped constants, the shipped compose rule and the
  /// shipped press-bill slope.
  static const TuningOverrides none = TuningOverrides._(
    {},
    ComposeRule.shipped,
  );

  /// The active overrides; [none] everywhere except inside the sweep.
  static TuningOverrides current = none;

  final Map<InstructionOption, TacticModifiers> _instructions;

  /// The active compose rule; [ComposeRule.shipped] outside the sweep.
  final ComposeRule compose;

  /// The engine's press-bill slope (match_engine.dart:876): how hard a
  /// pressing side's stamina bill multiplies the late-match fatigue
  /// term. Shipped 2.0; the sweep may vary it, but the preferred fix is
  /// retuning the per-instruction stamina anchors (this coefficient has
  /// moved twice already — review Task 3).
  final double pressBillSlope;

  /// The instruction's effective bundle: the sweep's override for it,
  /// or its shipped constant when no override is installed.
  TacticModifiers of(InstructionOption option) =>
      _instructions[option] ?? option.modifiers;

  /// Builds an overrides set for the tuning sweep. Production never
  /// calls this; only `tool/tactics_tuning_sweep.dart` does.
  factory TuningOverrides.withValues({
    Map<InstructionOption, TacticModifiers> instructions = const {},
    ComposeRule compose = ComposeRule.shipped,
    double pressBillSlope = 2.0,
  }) => TuningOverrides._(
    Map.of(instructions),
    compose,
    pressBillSlope: pressBillSlope,
  );
}

/// The effective bundle of an instruction option: the sweep's override
/// when one is installed, the shipped anchor otherwise.
extension TunedInstruction on InstructionOption {
  TacticModifiers get tuned => TuningOverrides.current.of(this);
}

/// A team's full tactical setup (GDD 10.2 Custom Tactics): three
/// instruction groups — what the team does with the ball, without it,
/// and in the moments right after losing or winning it.
///
/// Phase 0 ships the framework with every group at its defaults, so
/// [modifiers] is the identity bundle and matches played with it are
/// bit-identical to the legacy Balanced style (same seeds → same
/// results). Phases 1-3 add instruction fields to the three sub-classes;
/// this class and the engine's hook sites never change shape again.
class TeamTactics {
  const TeamTactics({
    this.inPossession = const InPossessionTactics(),
    this.outOfPossession = const OutOfPossessionTactics(),
    this.transitions = const TransitionTactics(),
  });

  /// What the team does with the ball (phase 1 fills the instructions).
  final InPossessionTactics inPossession;

  /// What the team does without the ball (phase 2 fills the instructions).
  final OutOfPossessionTactics outOfPossession;

  /// What the team does right after losing/winning the ball (phase 3
  /// fills the instructions).
  final TransitionTactics transitions;

  /// The composed bundle the engine consumes at its hook points. Today
  /// every group contributes the identity; each phase multiplies in its
  /// own non-identity axes.
  TacticModifiers get modifiers =>
      inPossession.modifiers *
      outOfPossession.modifiers *
      transitions.modifiers;

  /// Human-visible effect summary (GDD 10.3: effects must be visible).
  String get effectSummary => modifiers.effectSummary;

  /// Short control-card label: how many instruction groups sit away
  /// from their defaults. Localizable by the UI when it needs more
  /// than this neutral form.
  String get label {
    var custom = 0;
    if (!inPossession.isDefault) custom++;
    if (!outOfPossession.isDefault) custom++;
    if (!transitions.isDefault) custom++;
    return custom == 0 ? 'Balanced' : 'Custom ($custom/3)';
  }

  /// Stable JSON payload for persistence (one column on the club row).
  /// Phase 0 stores only the group defaults; later phases extend the
  /// maps, and unknown/missing keys fall back to defaults on load.
  Map<String, dynamic> toJson() => {
    'inPossession': inPossession.toJson(),
    'outOfPossession': outOfPossession.toJson(),
    'transitions': transitions.toJson(),
  };

  /// Parses a persisted payload. Anything missing or malformed maps to
  /// the group defaults — a save from any earlier phase keeps loading.
  factory TeamTactics.fromJson(Map<String, dynamic> json) => TeamTactics(
    inPossession: InPossessionTactics.fromJson(_asMap(json['inPossession'])),
    outOfPossession: OutOfPossessionTactics.fromJson(
      _asMap(json['outOfPossession']),
    ),
    transitions: TransitionTactics.fromJson(_asMap(json['transitions'])),
  );

  static Map<String, dynamic> _asMap(Object? value) =>
      value is Map<String, dynamic> ? value : const {};

  /// Maps a legacy persisted style name (the removed ten presets) to
  /// default tactics. Every legacy style is rebuilt as a combination in
  /// phases 1-3 (mapping table in GDD 10.2); at phase 0 the honest
  /// equivalent of every removed style is the default setup — gameplay
  /// until then is the old Balanced, whatever the save said.
  factory TeamTactics.fromLegacyStyle(String? name) => const TeamTactics();

  TeamTactics copyWith({
    InPossessionTactics? inPossession,
    OutOfPossessionTactics? outOfPossession,
    TransitionTactics? transitions,
  }) => TeamTactics(
    inPossession: inPossession ?? this.inPossession,
    outOfPossession: outOfPossession ?? this.outOfPossession,
    transitions: transitions ?? this.transitions,
  );

  @override
  bool operator ==(Object other) =>
      other is TeamTactics &&
      other.inPossession == inPossession &&
      other.outOfPossession == outOfPossession &&
      other.transitions == transitions;

  @override
  int get hashCode => Object.hash(inPossession, outOfPossession, transitions);
}

/// Parses a persisted club tactics column into [TeamTactics].
///
/// Every non-payload value loads as the default setup: the legacy
/// playing-style names the column carried before v11, an empty/null
/// column, or malformed JSON — a club row must never crash a match
/// build, and phase-0 gameplay is default tactics anyway.
TeamTactics tacticsFromDbPayload(String? raw) {
  if (raw == null || raw.isEmpty || raw == '{}') return const TeamTactics();
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const TeamTactics();
  }
  if (decoded is! Map<String, dynamic>) return const TeamTactics();
  return TeamTactics.fromJson(decoded);
}

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
    TacticModifiers(
      possession: 0.97,
      chance: 1.03,
      passAccuracy: 0.97,
      stamina: 1.04,
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
    TacticModifiers(chance: 0.92, shotQuality: 1.08),
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
        buildUp: _enumOr(
          BuildUpStyle.values,
          json['buildUp'],
          BuildUpStyle.mixed,
        ),
        tempo: _enumOr(AttackTempo.values, json['tempo'], AttackTempo.standard),
        width: _enumOr(AttackWidth.values, json['width'], AttackWidth.standard),
        finalThird: _enumOr(
          FinalThirdApproach.values,
          json['finalThird'],
          FinalThirdApproach.balanced,
        ),
      );

  /// Tolerant enum parse: unknown or missing keys fall back to default
  /// so a payload from any earlier phase keeps loading.
  static T _enumOr<T extends Enum>(List<T> values, Object? raw, T fallback) {
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

/// Out of Possession instructions (GDD 10.2): line height, pressing,
/// tackling and the offside trap. Phase 0 scaffold — the fields arrive
/// in phase 2.
/// Defensive line height (GDD 10.2 Out of Possession).
enum DefensiveLine implements InstructionOption {
  deep('Deep Line', TacticModifiers(defence: 1.05, possession: 0.91)),
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
  low(
    'Low Press',
    TacticModifiers(defence: 1.02, stamina: 0.88, possession: 0.94),
  ),
  mid('Mid Press', TacticModifiers.identity),
  high(
    'High Press',
    TacticModifiers(defence: 1.28, chance: 1.04, stamina: 1.30),
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
class OutOfPossessionTactics {
  const OutOfPossessionTactics({
    this.defensiveLine = DefensiveLine.standard,
    this.pressing = PressingIntensity.mid,
    this.tackling = TacklingAggression.balanced,
    this.offsideTrap = false,
  });

  final DefensiveLine defensiveLine;
  final PressingIntensity pressing;
  final TacklingAggression tackling;

  /// Whether the offside trap is on.
  final bool offsideTrap;

  bool get isDefault =>
      defensiveLine == DefensiveLine.standard &&
      pressing == PressingIntensity.mid &&
      tackling == TacklingAggression.balanced &&
      !offsideTrap;

  /// Composed through the tuning seam (`.tuned`): the shipped
  /// constants when no sweep override is installed.
  TacticModifiers get modifiers =>
      defensiveLine.tuned * pressing.tuned * tackling.tuned;

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
  };

  factory OutOfPossessionTactics.fromJson(Map<String, dynamic> json) =>
      OutOfPossessionTactics(
        defensiveLine: InPossessionTactics._enumOr(
          DefensiveLine.values,
          json['defensiveLine'],
          DefensiveLine.standard,
        ),
        pressing: InPossessionTactics._enumOr(
          PressingIntensity.values,
          json['pressing'],
          PressingIntensity.mid,
        ),
        tackling: InPossessionTactics._enumOr(
          TacklingAggression.values,
          json['tackling'],
          TacklingAggression.balanced,
        ),
        offsideTrap: json['offsideTrap'] == true,
      );

  OutOfPossessionTactics copyWith({
    DefensiveLine? defensiveLine,
    PressingIntensity? pressing,
    TacklingAggression? tackling,
    bool? offsideTrap,
  }) => OutOfPossessionTactics(
    defensiveLine: defensiveLine ?? this.defensiveLine,
    pressing: pressing ?? this.pressing,
    tackling: tackling ?? this.tackling,
    offsideTrap: offsideTrap ?? this.offsideTrap,
  );

  @override
  bool operator ==(Object other) =>
      other is OutOfPossessionTactics &&
      other.defensiveLine == defensiveLine &&
      other.pressing == pressing &&
      other.tackling == tackling &&
      other.offsideTrap == offsideTrap;

  @override
  int get hashCode =>
      Object.hash(defensiveLine, pressing, tackling, offsideTrap);
}

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
  patient('Patient', TacticModifiers(possession: 1.05, chance: 0.94)),
  balanced('Balanced', TacticModifiers.identity),
  fast(
    'Fast Counter',
    TacticModifiers(possession: 0.85, chance: 1.10, shotQuality: 1.03),
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
        counterPress: InPossessionTactics._enumOr(
          CounterPress.values,
          json['counterPress'],
          CounterPress.balanced,
        ),
        attackOnRecovery: InPossessionTactics._enumOr(
          AttackOnRecovery.values,
          json['attackOnRecovery'],
          AttackOnRecovery.balanced,
        ),
        restDefence: InPossessionTactics._enumOr(
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

/// Seven mentalities (GDD 10.3): percentage changes to the team's Attack
/// and Defence balance.
///
/// Balance-tuned by the §34 deep-balance simulation: the engine's chance
/// creation saturates through a logistic curve while defence losses are
/// near-linear, so symmetric pairs (+X% attack, −X% defence) lose more
/// than they win — the pre-tune ladder slid monotonically from 51% (very
/// defensive) to 40% (very attacking), punishing players for using the
/// game's core aggressive mechanic. The tuned pairs pay for attack with
/// proportionally smaller defence drops, so every step lands in the
/// 44-47% band: each extreme trades draws for its own flavour of risk.
enum Mentality {
  veryDefensive('Very Defensive', 0.82, 1.05, 0.90),
  defensive('Defensive', 0.90, 1.06, 0.95),
  cautious('Cautious', 0.95, 1.05, 0.98),
  balanced('Balanced', 1.00, 1.00, 1.00),
  positive('Positive', 1.05, 0.97, 1.03),
  attacking('Attacking', 1.10, 0.95, 1.08),
  veryAttacking('Very Attacking', 1.18, 0.93, 1.15);

  const Mentality(
    this.displayName,
    this.attackMod,
    this.defenceMod,
    this.staminaMod,
  );

  final String displayName;

  /// Percentage change applied to Attack.
  final double attackMod;

  /// Percentage change applied to Defence.
  final double defenceMod;

  /// Stamina consumption multiplier (GDD 11.3: attacking systems
  /// consume more).
  final double staminaMod;

  /// Shifts one step towards attacking; clamps at the range ends.
  Mentality moreAttacking() =>
      index == values.length - 1 ? this : values[index + 1];

  /// Shifts one step towards defensive; clamps at the range ends.
  Mentality moreDefensive() => index == 0 ? this : values[index - 1];

  /// Human-visible effect summary (GDD 10.3: effects must be visible).
  String get effectSummary {
    final parts = <String>[];

    void describe(String name, double multiplier) {
      final percent = ((multiplier - 1) * 100).round();
      if (percent == 0) return;
      parts.add('$name ${percent > 0 ? '+' : ''}$percent%');
    }

    describe('Attack', attackMod);
    describe('Defence', defenceMod);
    describe('Stamina use', staminaMod);
    return parts.isEmpty ? 'No modifiers' : parts.join(' · ');
  }
}

/// The mentality as a 0–100 scale (GDD 10.3): 0 is Very Defensive, 100
/// Very Attacking and 50 — dead centre — Balanced. The seven mentalities
/// are the scale's named steps, so a slid position maps to the step it
/// lands in.
Mentality mentalityFromScale(int value) {
  final steps = Mentality.values.length - 1;
  final i = (value.clamp(0, 100) * steps / 100).round();
  return Mentality.values[i];
}

/// A mentality's canonical scale position: 0, 17, 33, 50, 67, 83, 100 —
/// where the slider's marker rests when a saved mentality is restored.
int mentalityToScale(Mentality mentality) =>
    (mentality.index * 100 / (Mentality.values.length - 1)).round();

/// Live Match Actions (GDD 16): temporary in-match boosts with explicit
/// percentage modifiers. One active per team at a time; a new action
/// replaces the previous one.
enum LiveMatchAction {
  pushForward(
    'Push Forward',
    ActionModifiers(attack: 1.15, defence: 0.90, stamina: 1.05),
  ),
  defendDeep(
    'Defend Deep',
    ActionModifiers(attack: 0.88, defence: 1.14, stamina: 0.95),
  ),
  pressMore(
    'Press More',
    ActionModifiers(attack: 1.02, defence: 1.04, stamina: 1.25),
  ),
  stayCalm(
    'Stay Calm',
    ActionModifiers(attack: 1.00, defence: 1.02, stamina: 0.90),
  ),
  playMoreDirect(
    'Play More Direct',
    ActionModifiers(attack: 1.08, defence: 0.98, stamina: 1.00),
  );

  const LiveMatchAction(this.displayName, this.modifiers);

  final String displayName;
  final ActionModifiers modifiers;
}

class ActionModifiers {
  const ActionModifiers({
    required this.attack,
    required this.defence,
    required this.stamina,
  });

  final double attack;
  final double defence;
  final double stamina;
}

/// Pre-match / half-time pep talk (GDD 15): motivational choices with
/// visible percentage-based performance effects, expressed as team-wide
/// multipliers. A pre-match talk runs from kick-off; a half-time talk
/// applies from the second half. Unlike Live Match Actions these never
/// expire, and a later talk replaces an earlier one (no stacking).
///
/// Values are pre-balance placeholders (GDD rule 14).
class MatchPepTalk {
  const MatchPepTalk({
    required this.id,
    required this.label,
    required this.modifiers,
    required this.description,
  });

  /// Stable identifier for persistence/replay.
  final String id;
  final String label;
  final ActionModifiers modifiers;
  final String description;

  /// Human-visible effect summary (GDD 15: effects must be visible).
  String get effectSummary {
    final parts = <String>[];

    void describe(String name, double multiplier) {
      final percent = ((multiplier - 1) * 100).round();
      if (percent == 0) return;
      parts.add('$name ${percent > 0 ? '+' : ''}$percent%');
    }

    describe('Attack', modifiers.attack);
    describe('Defence', modifiers.defence);
    describe('Stamina use', modifiers.stamina);
    return parts.isEmpty ? 'No effect' : parts.join(' · ');
  }
}

/// Pre-match talks (GDD 15.1): one choice before kick-off, effects last
/// the whole match.
const List<MatchPepTalk> preMatchPepTalks = [
  MatchPepTalk(
    id: 'fearNoOne',
    label: 'Fear no one!',
    modifiers: ActionModifiers(attack: 1.04, defence: 1.04, stamina: 1.00),
    description: 'A confident talk: both lines step up a little.',
  ),
  MatchPepTalk(
    id: 'staySolid',
    label: 'Stay solid at the back!',
    modifiers: ActionModifiers(attack: 0.97, defence: 1.07, stamina: 1.00),
    description: 'Safety first: harder to break, blunter going forward.',
  ),
  MatchPepTalk(
    id: 'allOutAttack',
    label: 'Go at them from the start!',
    modifiers: ActionModifiers(attack: 1.08, defence: 0.95, stamina: 1.05),
    description: 'High tempo pressing game — costs legs over 90 minutes.',
  ),
  MatchPepTalk(
    id: 'calmMinds',
    label: 'Calm minds, clear plan',
    modifiers: ActionModifiers(attack: 1.00, defence: 1.02, stamina: 0.92),
    description: 'Measured football that saves energy for the final stages.',
  ),
];

/// Half-time talks (GDD 15.2): one choice at the interval, effects apply
/// to the second half only.
const List<MatchPepTalk> halfTimePepTalks = [
  MatchPepTalk(
    id: 'keepGoing',
    label: 'Keep going!',
    modifiers: ActionModifiers(attack: 1.03, defence: 1.03, stamina: 1.00),
    description: 'Steady encouragement across both phases.',
  ),
  MatchPepTalk(
    id: 'pushForGoal',
    label: 'We need a goal!',
    modifiers: ActionModifiers(attack: 1.08, defence: 0.94, stamina: 1.06),
    description: 'Chase the game — more attack, more risk, more tired legs.',
  ),
  MatchPepTalk(
    id: 'protectLead',
    label: 'Protect what we have!',
    modifiers: ActionModifiers(attack: 0.93, defence: 1.08, stamina: 1.00),
    description: 'Shut up shop and hold onto the result.',
  ),
  MatchPepTalk(
    id: 'saveLegs',
    label: 'Save your legs!',
    modifiers: ActionModifiers(attack: 1.00, defence: 1.00, stamina: 0.85),
    description: 'Manage the workload: noticeably lighter second half.',
  ),
];
