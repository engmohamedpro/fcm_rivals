/// FCM Rivals — continuous 0–99 tactic sliders (GDD 10.2 Custom Tactics).
///
/// Every ordered instruction (build-up, tempo, width, pressing, …) is a
/// slider from 0 to 99 that players can park anywhere, so no two custom
/// tactics need be alike. This file is the pure math behind it:
///
///  - the [TacticAxisId] list of every slider,
///  - [axisModifiers]: a slider value → the engine's [TacticModifiers],
///    blended smoothly BETWEEN the existing balance-tuned anchors of the
///    instruction's enum (low end = value 0, default = 50, high end =
///    99). A slider parked exactly on an old enum step (0 / 50 / 99)
///    returns that step's shipped bundle UNCHANGED, so everything the
///    balance harness tuned still holds; only the positions between the
///    anchors are new, and they are a geometric blend of two tuned
///    bundles — never extrapolated beyond them,
///  - [ScaleAxisSpec]: the shared mechanics each instruction group uses
///    to store, read and normalise its slider overrides.
///
/// Nothing here touches the engine: the groups fold these bundles into
/// the same composed [TacticModifiers] the engine already consumes.
library;

import 'dart:math' as math;

import 'tactic_modifiers.dart';

/// The slider range: 0 … [kScaleMax], the default in the middle.
const int kScaleMax = 99;

/// The default position — the identity bundle on every axis.
const int kScaleMid = 50;

/// Every continuous tactic slider, grouped like the three instruction
/// groups. [key] is the stable persistence name.
enum TacticAxisId {
  // The team's overall mentality: the first slider of the sheet. It is
  // stored apart from the three instruction groups (see
  // `TeamTactics.mentalityScale`).
  mentality,
  // In possession.
  buildUp,
  tempo,
  width,
  shotSelection,
  crossing,
  // Out of possession.
  defensiveLine,
  pressing,
  tackling,
  // Transitions.
  counterPress,
  attackOnRecovery,
  restDefence;

  String get key => name;
}

/// Clamps any int into the slider range.
int clampScale(int value) => value.clamp(0, kScaleMax);

/// The canonical slider value of step [index] of [count] ordered steps:
/// the first step is 0, the last 99, the middle one 50 (for 3 steps).
int stepToScale(int index, int count) =>
    (index * kScaleMax / (count - 1)).round();

/// The ordered step a slider value falls in: for 3 steps the boundaries
/// are 25 and 75 (Dart `.round()`, half away from zero).
int scaleToStep(int value, int count) =>
    (clampScale(value) * (count - 1) / kScaleMax).round();

double _lerpLog(double a, double b, double t) =>
    math.exp(math.log(a) * (1 - t) + math.log(b) * t);

/// Geometric blend of two bundles ([t] 0 → [a], 1 → [b]): every
/// multiplier moves along a straight line in log space, so a blend of
/// two ×1.10 and ×0.90 style multipliers stays sensible on both sides
/// of 1.0 and never leaves the interval spanned by its anchors.
TacticModifiers lerpModifiers(TacticModifiers a, TacticModifiers b, double t) =>
    TacticModifiers(
      attack: _lerpLog(a.attack, b.attack, t),
      defence: _lerpLog(a.defence, b.defence, t),
      possession: _lerpLog(a.possession, b.possession, t),
      chance: _lerpLog(a.chance, b.chance, t),
      stamina: _lerpLog(a.stamina, b.stamina, t),
      passAccuracy: _lerpLog(a.passAccuracy, b.passAccuracy, t),
      shotQuality: _lerpLog(a.shotQuality, b.shotQuality, t),
    );

/// The reciprocal bundle (every multiplier inverted): the mirror image
/// of an anchor, used for a slider end that has no tuned enum behind it.
TacticModifiers mirrorModifiers(TacticModifiers m) => TacticModifiers(
  attack: 1 / m.attack,
  defence: 1 / m.defence,
  possession: 1 / m.possession,
  chance: 1 / m.chance,
  stamina: 1 / m.stamina,
  passAccuracy: 1 / m.passAccuracy,
  shotQuality: 1 / m.shotQuality,
);

/// A slider [value] as a bundle, between three anchors: [low] at 0,
/// [mid] at 50 (the default, normally the identity), [high] at 99.
/// The three anchor positions return their bundle exactly (no float
/// drift); everything between is a [lerpModifiers] blend.
TacticModifiers axisModifiers({
  required TacticModifiers low,
  required TacticModifiers mid,
  required TacticModifiers high,
  required int value,
}) {
  final v = clampScale(value);
  if (v == 0) return low;
  if (v == kScaleMid) return mid;
  if (v == kScaleMax) return high;
  if (v < kScaleMid) {
    return lerpModifiers(mid, low, (kScaleMid - v) / kScaleMid);
  }
  return lerpModifiers(mid, high, (v - kScaleMid) / (kScaleMax - kScaleMid));
}

/// The same three-anchor blend for a single scalar (foul / yellow-card
/// scales of the tackling slider).
double axisScalar({
  required double low,
  required double mid,
  required double high,
  required int value,
}) {
  final v = clampScale(value);
  if (v == 0) return low;
  if (v == kScaleMid) return mid;
  if (v == kScaleMax) return high;
  if (v < kScaleMid) return _lerpLog(mid, low, (kScaleMid - v) / kScaleMid);
  return _lerpLog(mid, high, (v - kScaleMid) / (kScaleMax - kScaleMid));
}

/// Order-independent equality of two override maps.
bool scalesEqual(Map<String, int> a, Map<String, int> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}

/// Order-independent hash of an override map.
int scalesHash(Map<String, int> m) => Object.hashAllUnordered(
  m.entries.map((e) => Object.hash(e.key, e.value)),
);

/// Reads the override map of a persisted group payload: only the
/// [allowed] axes, only ints, each clamped to the slider range.
/// Anything else is dropped — a hand-edited or newer save never
/// crashes a match build.
Map<String, int> parseScales(Object? raw, Iterable<TacticAxisId> allowed) {
  if (raw is! Map) return const {};
  final out = <String, int>{};
  for (final axis in allowed) {
    final v = raw[axis.key];
    if (v is num) out[axis.key] = clampScale(v.round());
  }
  return out;
}

/// One three-step ordered instruction as a slider: the enum steps
/// (first = low end, middle = default, last = high end) are its tuned
/// anchors, and a persisted override stores the slider value.
///
/// Invariant kept by [apply]: an override is stored ONLY when it differs
/// from the canonical position of the step it falls in (0 / 50 / 99), so
/// two tactics that behave identically also compare equal, and a
/// setup that never leaves the old steps is byte-identical to a
/// pre-slider save.
class ScaleAxisSpec {
  const ScaleAxisSpec(this.id, this.steps);

  final TacticAxisId id;

  /// The enum values in order: low end, default, high end — always
  /// exactly three (every slider axis has three tuned anchors).
  final List<InstructionOption> steps;

  /// The slider value now: the override when one is stored, otherwise
  /// the canonical position of the enum [current].
  int valueOf(Map<String, int> scales, InstructionOption current) =>
      scales[id.key] ?? stepToScale(steps.indexOf(current), steps.length);

  /// The bundle now: the three-anchor blend of the stored override, or
  /// the enum's own tuned bundle when there is none (bit-identical to
  /// the pre-slider build).
  TacticModifiers modifiersOf(
    Map<String, int> scales,
    InstructionOption current,
  ) {
    final v = scales[id.key];
    if (v == null) return current.tuned;
    return axisModifiers(
      low: steps.first.tuned,
      mid: steps[1].tuned,
      high: steps.last.tuned,
      value: v,
    );
  }

  /// The enum step a slider [value] falls in (nearest anchor): what the
  /// rest of the game — set-piece logic, summaries, the AI — keeps
  /// reading.
  InstructionOption stepOf(int value) =>
      steps[scaleToStep(value, steps.length)];

  /// [scales] with this axis set to [value], normalised (see the class
  /// doc): an override equal to its step's canonical position is
  /// removed, because the enum alone already says it.
  Map<String, int> apply(Map<String, int> scales, int value) {
    final v = clampScale(value);
    final next = Map<String, int>.of(scales);
    final canonical = stepToScale(
      scaleToStep(v, steps.length),
      steps.length,
    );
    if (v == canonical) {
      next.remove(id.key);
    } else {
      next[id.key] = v;
    }
    return next;
  }
}
