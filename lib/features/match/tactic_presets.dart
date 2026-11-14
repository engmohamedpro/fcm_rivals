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
///    counter-attack, wing play, all-out attack) plus the neutral
///    Balanced.
///  * UI localization (T-0139): each preset carries only its l10n key
///    stem; the chip label and its semantics hint resolve through the
///    AppLocalizations getters `tacticsPreset<Key>` /
///    `tacticsPreset<Key>Hint` (EN + AR in the ARB files), so the
///    catalogue holds no user-visible strings at all.
library;

import '../../l10n/app_localizations.dart';
import 'in_possession_tactics.dart';
import 'out_of_possession_tactics.dart';
import 'team_tactics.dart';
import 'transition_tactics.dart';

/// One named preset: the tactic values it applies when tapped.
class TacticPreset {
  const TacticPreset({
    required this.id,
    required this.l10nKey,
    required this.tactics,
  });

  /// Stable id (persisting a chosen preset later, analytics).
  final String id;

  /// l10n key stem: the label getter is `tacticsPreset<Key>`, the
  /// one-line style hint `tacticsPreset<Key>Hint`.
  final String l10nKey;

  /// The full combination applied on tap. Replaces every instruction
  /// group (mentality untouched — it is engine ground truth, set from
  /// the live match panel per the owner's 2026-11-13 ruling).
  final TeamTactics tactics;

  /// Localized chip label (EN / AR from the ARB catalogues).
  String label(AppLocalizations l10n) => switch (l10nKey) {
        'Balanced' => l10n.tacticsPresetBalanced,
        'Possession' => l10n.tacticsPresetPossession,
        'ParkTheBus' => l10n.tacticsPresetParkTheBus,
        'Gegenpress' => l10n.tacticsPresetGegenpress,
        'CounterAttack' => l10n.tacticsPresetCounterAttack,
        'WingPlay' => l10n.tacticsPresetWingPlay,
        'AllOutAttack' => l10n.tacticsPresetAllOutAttack,
        _ => l10n.tacticsPresetBalanced,
      };

  /// Localized one-line description of the style (semantics hint).
  String hint(AppLocalizations l10n) => switch (l10nKey) {
        'Balanced' => l10n.tacticsPresetBalancedHint,
        'Possession' => l10n.tacticsPresetPossessionHint,
        'ParkTheBus' => l10n.tacticsPresetParkTheBusHint,
        'Gegenpress' => l10n.tacticsPresetGegenpressHint,
        'CounterAttack' => l10n.tacticsPresetCounterAttackHint,
        'WingPlay' => l10n.tacticsPresetWingPlayHint,
        'AllOutAttack' => l10n.tacticsPresetAllOutAttackHint,
        _ => l10n.tacticsPresetBalancedHint,
      };
}

/// The catalogue, in sheet display order.
const List<TacticPreset> tacticPresets = [
  TacticPreset(
    id: 'balanced',
    l10nKey: 'Balanced',
    tactics: TeamTactics(),
  ),
  TacticPreset(
    id: 'tikiTaka',
    l10nKey: 'Possession',
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
    l10nKey: 'ParkTheBus',
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
    l10nKey: 'Gegenpress',
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
    l10nKey: 'CounterAttack',
    tactics: TeamTactics(
      inPossession: InPossessionTactics(
        buildUp: BuildUpStyle.longBall,
        tempo: AttackTempo.fast,
        finalThird: FinalThirdApproach.earlyCrosses,
      ),
      outOfPossession: OutOfPossessionTactics(
        defensiveLine: DefensiveLine.deep,
        pressing: PressingIntensity.mid,
      ),
      transitions: TransitionTactics(
        attackOnRecovery: AttackOnRecovery.fast,
      ),
    ),
  ),
  TacticPreset(
    id: 'wingPlay',
    l10nKey: 'WingPlay',
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
