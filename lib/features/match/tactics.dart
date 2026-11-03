/// FCM Rivals — tactical domain (GDD 10, GDD 16).
///
/// Playing Styles, Mentalities and Live Match Actions as pure data with
/// explicit percentage modifiers. All effects are visible to the user
/// (GDD 10.3): the numbers below are surfaced by the UI and are
/// pre-balance placeholders (GDD rule 14) gathered for simulation tuning.
library;

/// Ten supported playing styles (GDD 10.2).
///
/// Balance-tuned by the §34 deep-balance simulation (see
/// test/balance/match_engine_balance_test.dart): every style vs an
/// identical balanced opponent lands in the 36-52% win-rate band with a
/// real spread between strongest and weakest. The possession multipliers
/// stay close to 1.0 because the engine's possession competition raises
/// support totals to the power 1.6 — a +6% multiplier compounds into a
/// big possession share, so 1.20/1.28 made Possession/Tiki-Taka win
/// 64-67% of matches outright (a free dominant strategy). Gegenpressing
/// and High Press sit below 50% by design: their 1.30/1.22 stamina
/// multipliers are the real cost.
enum PlayingStyle {
  possession(
    'Possession',
    StyleModifiers(
      attack: 1.00,
      defence: 1.00,
      possession: 1.06,
      chance: 0.95,
      stamina: 1.00,
      passAccuracy: 1.06,
    ),
  ),
  tikiTaka(
    'Tiki-Taka',
    StyleModifiers(
      attack: 0.95,
      defence: 1.02,
      possession: 1.08,
      chance: 0.92,
      stamina: 0.95,
      passAccuracy: 1.10,
    ),
  ),
  directPlay(
    'Direct Play',
    StyleModifiers(
      attack: 1.08,
      defence: 0.96,
      possession: 0.94,
      chance: 1.08,
      stamina: 1.02,
      passAccuracy: 0.92,
    ),
  ),
  counterAttack(
    'Counter Attack',
    StyleModifiers(
      attack: 1.12,
      defence: 1.05,
      possession: 0.88,
      chance: 1.15,
      stamina: 0.92,
      passAccuracy: 0.90,
    ),
  ),
  gegenpressing(
    'Gegenpressing',
    StyleModifiers(
      attack: 1.10,
      defence: 0.94,
      possession: 1.03,
      chance: 1.10,
      stamina: 1.30,
      passAccuracy: 0.94,
    ),
  ),
  highPress(
    'High Press',
    StyleModifiers(
      attack: 1.06,
      defence: 0.92,
      possession: 1.03,
      chance: 1.06,
      stamina: 1.22,
      passAccuracy: 0.94,
    ),
  ),
  wingPlay(
    'Wing Play',
    StyleModifiers(
      attack: 1.06,
      defence: 1.00,
      possession: 0.98,
      chance: 1.05,
      stamina: 1.05,
      passAccuracy: 0.98,
    ),
  ),
  longBall(
    'Long Ball',
    StyleModifiers(
      attack: 1.02,
      defence: 1.03,
      possession: 0.90,
      chance: 1.02,
      stamina: 0.94,
      passAccuracy: 0.84,
    ),
  ),
  lowBlock(
    'Low Block',
    StyleModifiers(
      attack: 0.88,
      defence: 1.14,
      possession: 0.88,
      chance: 0.88,
      stamina: 0.85,
      passAccuracy: 0.92,
    ),
  ),
  balanced(
    'Balanced',
    StyleModifiers(
      attack: 1.00,
      defence: 1.00,
      possession: 1.00,
      chance: 1.00,
      stamina: 1.00,
      passAccuracy: 1.00,
    ),
  );

  const PlayingStyle(this.displayName, this.modifiers);

  final String displayName;
  final StyleModifiers modifiers;

  /// Human-visible effect summary (GDD 10.3: effects must be visible).
  String get effectSummary => modifiers.effectSummary;
}

/// Percentage multipliers applied by a playing style (GDD 10.2 effects).
class StyleModifiers {
  const StyleModifiers({
    required this.attack,
    required this.defence,
    required this.possession,
    required this.chance,
    required this.stamina,
    required this.passAccuracy,
  });

  /// Multiplier on team Attack total.
  final double attack;

  /// Multiplier on team Defence total.
  final double defence;

  /// Multiplier on possession bias.
  final double possession;

  /// Multiplier on chance creation probability.
  final double chance;

  /// Multiplier on stamina consumption (GDD 11.3).
  final double stamina;

  /// Multiplier on pass completion probability.
  final double passAccuracy;

  /// Human-visible effect summary (GDD 10.3: effects must be visible).
  String get effectSummary {
    final parts = <String>[];

    void describe(String name, double multiplier) {
      final percent = ((multiplier - 1) * 100).round();
      if (percent == 0) return;
      parts.add('$name ${percent > 0 ? '+' : ''}$percent%');
    }

    describe('Attack', attack);
    describe('Defence', defence);
    describe('Possession', possession);
    describe('Chances', chance);
    describe('Stamina use', stamina);
    describe('Passing', passAccuracy);
    return parts.isEmpty ? 'No modifiers' : parts.join(' · ');
  }
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
