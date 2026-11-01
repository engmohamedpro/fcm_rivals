/// FCM Rivals — tactical domain (GDD 10, GDD 16).
///
/// Playing Styles, Mentalities and Live Match Actions as pure data with
/// explicit percentage modifiers. All effects are visible to the user
/// (GDD 10.3): the numbers below are surfaced by the UI and are
/// pre-balance placeholders (GDD rule 14) gathered for simulation tuning.
library;

/// Ten supported playing styles (GDD 10.2).
enum PlayingStyle {
  possession('Possession', StyleModifiers(attack: 1.00, defence: 1.00, possession: 1.20, chance: 0.95, stamina: 1.00, passAccuracy: 1.06)),
  tikiTaka('Tiki-Taka', StyleModifiers(attack: 0.95, defence: 1.02, possession: 1.28, chance: 0.92, stamina: 0.95, passAccuracy: 1.10)),
  directPlay('Direct Play', StyleModifiers(attack: 1.08, defence: 0.96, possession: 0.88, chance: 1.08, stamina: 1.02, passAccuracy: 0.92)),
  counterAttack('Counter Attack', StyleModifiers(attack: 1.12, defence: 1.05, possession: 0.82, chance: 1.15, stamina: 0.92, passAccuracy: 0.90)),
  gegenpressing('Gegenpressing', StyleModifiers(attack: 1.10, defence: 0.94, possession: 1.05, chance: 1.10, stamina: 1.30, passAccuracy: 0.94)),
  highPress('High Press', StyleModifiers(attack: 1.06, defence: 0.92, possession: 1.05, chance: 1.06, stamina: 1.22, passAccuracy: 0.94)),
  wingPlay('Wing Play', StyleModifiers(attack: 1.06, defence: 1.00, possession: 0.98, chance: 1.05, stamina: 1.05, passAccuracy: 0.98)),
  longBall('Long Ball', StyleModifiers(attack: 1.02, defence: 1.03, possession: 0.85, chance: 1.02, stamina: 0.94, passAccuracy: 0.84)),
  lowBlock('Low Block', StyleModifiers(attack: 0.88, defence: 1.14, possession: 0.80, chance: 0.88, stamina: 0.85, passAccuracy: 0.92)),
  balanced('Balanced', StyleModifiers(attack: 1.00, defence: 1.00, possession: 1.00, chance: 1.00, stamina: 1.00, passAccuracy: 1.00));

  const PlayingStyle(this.displayName, this.modifiers);

  final String displayName;
  final StyleModifiers modifiers;
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
}

/// Seven mentalities (GDD 10.3): percentage changes to the team's Attack
/// and Defence balance.
enum Mentality {
  veryDefensive('Very Defensive', 0.80, 1.20, 0.90),
  defensive('Defensive', 0.90, 1.10, 0.95),
  cautious('Cautious', 0.95, 1.06, 0.98),
  balanced('Balanced', 1.00, 1.00, 1.00),
  positive('Positive', 1.06, 0.95, 1.03),
  attacking('Attacking', 1.12, 0.90, 1.08),
  veryAttacking('Very Attacking', 1.20, 0.82, 1.15);

  const Mentality(this.displayName, this.attackMod, this.defenceMod, this.staminaMod);

  final String displayName;

  /// Percentage change applied to Attack.
  final double attackMod;

  /// Percentage change applied to Defence.
  final double defenceMod;

  /// Stamina consumption multiplier (GDD 11.3: attacking systems
  /// consume more).
  final double staminaMod;

  /// Shifts one step towards attacking; clamps at the range ends.
  Mentality moreAttacking() => index == values.length - 1 ? this : values[index + 1];

  /// Shifts one step towards defensive; clamps at the range ends.
  Mentality moreDefensive() => index == 0 ? this : values[index - 1];
}

/// Live Match Actions (GDD 16): temporary in-match boosts with explicit
/// percentage modifiers. One active per team at a time; a new action
/// replaces the previous one.
enum LiveMatchAction {
  pushForward('Push Forward', ActionModifiers(attack: 1.15, defence: 0.90, stamina: 1.05)),
  defendDeep('Defend Deep', ActionModifiers(attack: 0.88, defence: 1.14, stamina: 0.95)),
  pressMore('Press More', ActionModifiers(attack: 1.02, defence: 1.04, stamina: 1.25)),
  stayCalm('Stay Calm', ActionModifiers(attack: 1.00, defence: 1.02, stamina: 0.90)),
  playMoreDirect('Play More Direct', ActionModifiers(attack: 1.08, defence: 0.98, stamina: 1.00));

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
