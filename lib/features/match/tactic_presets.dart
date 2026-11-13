/// FCM Rivals — preset tactic combinations (T-0129).
///
/// One-stop catalogue of named presets the tactics options sheet
/// offers: tapping one applies the WHOLE combination of instruction
/// values at once, on top of the sliders the sheet already exposes.
/// Data only — the sheet owns the UI.
///
/// Design notes:
///  * Presets are combinations of the tuned enum anchors ONLY (no
///    slider overrides): every value below is an enum default or a
///    step the engine already balances around, so a preset can never
///    compose an untuned stack. The balance harness's frozen gates
///    (see the enum comments) were measured on these anchors.
///  * The names map to the playing-style archetypes the GDD 10.2
///    combinations rebuild (possession, park-the-bus, gegenpress,
///    counter-attack, all-out attack) plus the neutral Balanced.
///  * UI localization: each preset's label comes through [nameAr] /
///    a fallback to the English label; the ARB pass (see task) can
///    move these into l10n later without touching this catalogue.
library;

import 'in_possession_tactics.dart';
import 'out_of_possession_tactics.dart';
import 'team_tactics.dart';
import 'transition_tactics.dart';

/// One named preset: the tactic values it applies when tapped.
class TacticPreset {
  const TacticPreset({
    required this.id,
    required this.name,
    this.nameAr,
    required this.tactics,
    required this.blurb,
  });

  /// Stable id (persisting a chosen preset later, analytics).
  final String id;

  /// English label shown on the chip.
  final String name;

  /// Arabic label; null falls back to [name].
  final String? nameAr;

  /// The full combination applied on tap. Replaces every instruction
  /// group (mentality untouched — it is an engine concern, set from
  /// the live match panel per the owner's 2026-11-13 ruling).
  final TeamTactics tactics;

  /// One-line description of the style.
  final String blurb;

  String label({bool arabic = false}) => arabic && nameAr != null
      ? nameAr!
      : name;
}

/// The catalogue, in sheet display order.
const List<TacticPreset> tacticPresets = [
  TacticPreset(
    id: 'balanced',
    name: 'Balanced',
    nameAr: 'متوازن',
    blurb: 'Neutral defaults on every axis.',
    tactics: TeamTactics(),
  ),
  TacticPreset(
    id: 'tikiTaka',
    name: 'Possession',
    nameAr: 'استحواذ',
    blurb: 'Play out, slow tempo, patient, work the ball in.',
    tactics: TeamTactics(
      inPossession: InPossessionTactics(
        buildUp: BuildUpStyle.playOut,
        tempo: AttackTempo.slow,
        width: AttackWidth.narrow,
        finalThird: FinalThirdApproach.workBallIntoBox,
      ),
      outOfPossession: OutOfPossessionTactics(
        defensiveLine: DefensiveLine.high,
        pressing: PressingIntensity.mid,
      ),
      transitions: TransitionTactics(
        attackOnRecovery: AttackOnRecovery.patient,
      ),
    ),
  ),
  TacticPreset(
    id: 'parkTheBus',
    name: 'Park the Bus',
    nameAr: 'مركن دفاعي',
    blurb: 'Deep block, low press, retreat and stay solid.',
    tactics: TeamTactics(
      inPossession: InPossessionTactics(
        buildUp: BuildUpStyle.longBall,
        tempo: AttackTempo.slow,
        width: AttackWidth.wide,
      ),
      outOfPossession: OutOfPossessionTactics(
        defensiveLine: DefensiveLine.deep,
        pressing: PressingIntensity.low,
        tackling: TacklingAggression.clean,
      ),
      transitions: TransitionTactics(
        counterPress: CounterPress.retreat,
        restDefence: RestDefence.conservative,
      ),
    ),
  ),
  TacticPreset(
    id: 'gegenpress',
    name: 'Gegenpress',
    nameAr: 'ضغط عالي',
    blurb: 'High line, immediate counter-press, aggressive.',
    tactics: TeamTactics(
      inPossession: InPossessionTactics(
        tempo: AttackTempo.fast,
        finalThird: FinalThirdApproach.shootOnSight,
      ),
      outOfPossession: OutOfPossessionTactics(
        defensiveLine: DefensiveLine.high,
        pressing: PressingIntensity.high,
        tackling: TacklingAggression.aggressive,
      ),
      transitions: TransitionTactics(
        counterPress: CounterPress.immediate,
        restDefence: RestDefence.aggressive,
      ),
    ),
  ),
  TacticPreset(
    id: 'counterAttack',
    name: 'Counter Attack',
    nameAr: 'هجوم مرتد',
    blurb: 'Deep-ish block, fast breaks on recovery.',
    tactics: TeamTactics(
      inPossession: InPossessionTactics(
        buildUp: BuildUpStyle.longBall,
        tempo: AttackTempo.fast,
        width: AttackWidth.wide,
        finalThird: FinalThirdApproach.earlyCrosses,
      ),
      outOfPossession: OutOfPossessionTactics(
        defensiveLine: DefensiveLine.standard,
        pressing: PressingIntensity.mid,
      ),
      transitions: TransitionTactics(
        counterPress: CounterPress.retreat,
        attackOnRecovery: AttackOnRecovery.fast,
      ),
    ),
  ),
  TacticPreset(
    id: 'wingPlay',
    name: 'Wing Play',
    nameAr: 'لعب الأطراف',
    blurb: 'Wide staging, early crosses into the box.',
    tactics: TeamTactics(
      inPossession: InPossessionTactics(
        width: AttackWidth.wide,
        finalThird: FinalThirdApproach.earlyCrosses,
      ),
      outOfPossession: OutOfPossessionTactics(
        pressing: PressingIntensity.mid,
      ),
      transitions: TransitionTactics(
        attackOnRecovery: AttackOnRecovery.fast,
      ),
    ),
  ),
];
