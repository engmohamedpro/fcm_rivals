/// FCM Rivals — team tactical setup, mentalities and live boosts
/// (GDD 10.3, GDD 15, GDD 16).
///
/// [TeamTactics] composing the three instruction groups, the DB
/// payload codec, the seven mentalities with their scale helpers,
/// live match actions and pep talks, split verbatim out of
/// `tactics.dart` (T-0039).
library;

import 'dart:convert';

import 'in_possession_tactics.dart';
import 'out_of_possession_tactics.dart';
import 'tactic_modifiers.dart';
import 'transition_tactics.dart';

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
