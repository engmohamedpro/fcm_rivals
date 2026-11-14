/// FCM Rivals — tactics modifier math (GDD 10, GDD 16).
///
/// The composed modifier bundle the engine consumes, the
/// instruction-option interface, the compose damp rule and the
/// balance-sweep tuning seam — pure data with explicit percentage
/// modifiers, split verbatim out of `tactics.dart` (T-0039). The
/// domain overview lives on the `tactics.dart` barrel.
library;

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
  /// shipped [ComposeRule] carries 0.84 (costs), 0.60 (stamina), 0.70
  /// on stacked possession-HOARDING and 1.0 on stacked possession-
  /// ceding (linear — a low-block counter side's identity IS ceding
  /// the ball), anchor-pass tuned (task
  /// `2026-11-06_tactics_phase3-anchor-pass-and-gates`), so this
  /// method is bit-identical to the no-seam build in production.
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
  /// stacks) independently (review Task 2 options a/b). The ceding
  /// factor ships 1.0 (linear), the hoarding factor 0.70 (anchor pass
  /// 2026-11-06, task `2026-11-06_tactics_phase3-anchor-pass-and-gates`:
  /// the lever that pulled the playOut×slow matrix combos off the 60%
  /// ceiling) — see [ComposeRule.possessionStackDampAbove].
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
/// 2026-11-05_tactics_phase3-balance-bands-and-sweep, Task 2; anchor
/// pass 2026-11-06, task
/// `2026-11-06_tactics_phase3-anchor-pass-and-gates` — mechanism
/// guard cited per the `2026-11-05_reviews_lifecycle-compliance-audit`
/// Task 3 amendment). The shipped rule: cost axes damp stacked excess
/// at 0.84, stamina at 0.60, possession hoarding at 0.70 and ceding
/// at 1.0 (linear). Sweep lines (aligned harness — the tool's matrix
/// block re-mirrored the suite's 300/combo; per-group seeds, both
/// pools):
///  * cost damp 0.70 -> allAttack no-collapse 32.9% (red, band >=38);
///    0.84 -> allAttack 40.5% green with matrix worst 57.8 once
///    hpDefence 1.34/hpChance 1.16 landed (phase-3 landing line);
///  * stamina damp 0.55 -> gegenpress late goals 112% (red, >=1.15
///    required) on the suite pool; 0.60 -> 122% green with gegenpress
///    W 49.6 (<=58), stamina@75 69.7 < 76.4 and allAttack no-collapse
///    42.3 (>=38) — the singles never stack, so the lever moves the
///    stacked bills and no single row;
///  * possession hoard damp 1.0 -> matrix worst (playOut+slow+wide+
///    workBall) 61.0% W (red, 1 combo out of 38-60); 0.70 -> 59.3%
///    (0 out) — the damp reads only stacked HOARDING pairs, so every
///    single and every ceding stack is untouched.
class ComposeRule {
  const ComposeRule({
    this.costStackDamp = 0.84,
    this.staminaStackDamp = 0.60,
    this.possessionStackDampAbove = 0.70,
    this.possessionStackDampBelow = 1.0,
  });

  /// The shipped compose rule (identity of this class's defaults).
  static const ComposeRule shipped = ComposeRule();

  /// Damp on stacked same-direction excess for the cost axes
  /// (attack/defence/chance/passAccuracy/shotQuality).
  final double costStackDamp;

  /// Damp on stacked stamina costs (the gegenpress bill). Anchor pass
  /// 2026-11-06: 0.55 -> 0.60 (sweep line above) — the surgical fix
  /// for the gegenpress late-goals band while the press-bill slope
  /// stays frozen (the review's third-move ban).
  final double staminaStackDamp;

  /// Damp on stacked possession-HOARDING pushes (both factors > 1).
  /// Anchor pass 2026-11-06: 1.0 -> 0.70 (sweep line above) — the
  /// possession-hoarding matrix combos had stacked at full strength
  /// and rode over the 60% ceiling.
  final double possessionStackDampAbove;

  /// Damp on stacked possession-CEDING pushes (both factors < 1).
  /// 1.0 = linear, the shipped rule: a low-block side's ceded share
  /// is its identity and stacks at full strength.
  final double possessionStackDampBelow;
}

/// Late-game escalation knobs (GDD 12.4): the pure time-based shape that
/// replaced the removed average-stamina fatigue term (fatigue-decoupling
/// owner decision 2026-11-07 — stamina never feeds performance, so the
/// "late game opens up" calibration band is held by this config, not by
/// player exhaustion).
class LateGameOpenConfig {
  const LateGameOpenConfig({
    this.openStartMinute = 60,
    this.slope = 0.55,
  });

  /// First minute the escalation applies. The factor is the identity
  /// before it.
  final int openStartMinute;

  /// Quadratic escalation strength: the factor reaches `1 + slope` at
  /// full time and is clamped there — the documented maximum. Shipped
  /// 0.55: the measured contribution of the removed stamina term at
  /// full time (2.0 × (1 − avg/100) ≈ 0.52–0.54 with a balanced side
  /// finishing near 73%).
  final double slope;
}

/// Late-game chance-creation escalation on PURE TIME (GDD 12.4): identity
/// before [LateGameOpenConfig.openStartMinute], strictly increasing after
/// it, bounded at `1 + slope` at full time (clamped beyond). Pure and
/// seed-independent — the `staminaDrainForMinute` pattern: a top-level
/// function over (minute, full time, config) with the knobs in
/// [TuningOverrides] so the balance sweep can move them.
double lateGameOpenFactor(
  int minute,
  int fullTimeMinute,
  LateGameOpenConfig config,
) {
  if (minute < config.openStartMinute) return 1.0;
  final span = (fullTimeMinute - config.openStartMinute).clamp(1, 1000);
  final t = ((minute - config.openStartMinute) / span).clamp(0.0, 1.0);
  return (1.0 + config.slope * t * t).clamp(1.0, 1.0 + config.slope);
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
    // pressBillSlope stays 4.2 (T-0052 measured sweep,
    // `tool/fatigue_reanchor_probe.dart`): raising it (tested 6-12)
    // taxes the composed bundle — attacking MENTALITIES pay the same
    // bill as pressing instructions and the mentality ladder band
    // breaks (ladder spread 0.073 > 0.05 at slope 10) — while the
    // press-late-goals ratio still saturates below its band (0.87 at
    // slope 12 vs >= 1.08): the untaxed press defence multiplier
    // dominates the away edge inside the logistic. The slope cannot
    // hold those bands; conflicts recorded in the task's Developer
    // Notes for the owner.
    this.pressBillSlope = 4.2,
    this.lateGameOpen = const LateGameOpenConfig(),
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

  /// The engine's press-bill slope (match_engine_simulation.dart): how
  /// hard a pressing side's stamina bill multiplies the late-game
  /// escalation term. History: 2.0 -> 4.2 (anchor pass 2026-11-06, task
  /// `2026-11-06_tactics_phase3-anchor-pass-and-gates` — the decoupled
  /// bill reads the composed bundle's excess). T-0052 swept it 4.2-12
  /// and kept 4.2: higher slopes tax attacking mentalities through the
  /// composed bundle and break the mentality ladder, while the
  /// press-late-goals ratio saturates below its band regardless — see
  /// the T-0052 Developer Notes.
  final double pressBillSlope;

  /// The engine's late-game escalation knobs (match_engine_simulation's
  /// `_defensiveOpenness`): the pure-time shape holding the "late game
  /// opens up" calibration band after the stamina term was removed
  /// (T-0052). Shipped `const LateGameOpenConfig()`.
  final LateGameOpenConfig lateGameOpen;

  /// The instruction's effective bundle: the sweep's override for it,
  /// or its shipped constant when no override is installed.
  TacticModifiers of(InstructionOption option) =>
      _instructions[option] ?? option.modifiers;

  /// Builds an overrides set for the tuning sweep. Production never
  /// calls this; only `tool/tactics_tuning_sweep.dart` does.
  factory TuningOverrides.withValues({
    Map<InstructionOption, TacticModifiers> instructions = const {},
    ComposeRule compose = ComposeRule.shipped,
    double pressBillSlope = 4.2,
    LateGameOpenConfig lateGameOpen = const LateGameOpenConfig(),
  }) => TuningOverrides._(
    Map.of(instructions),
    compose,
    pressBillSlope: pressBillSlope,
    lateGameOpen: lateGameOpen,
  );
}

/// The effective bundle of an instruction option: the sweep's override
/// when one is installed, the shipped anchor otherwise.
extension TunedInstruction on InstructionOption {
  TacticModifiers get tuned => TuningOverrides.current.of(this);
}
