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
///
/// Barrel (T-0039): the families live in `tactic_modifiers.dart`,
/// `in_possession_tactics.dart`, `out_of_possession_tactics.dart`,
/// `transition_tactics.dart` and `team_tactics.dart`; this file keeps
/// the historical `features/match/tactics.dart` import path stable.
library;

export 'in_possession_tactics.dart';
export 'out_of_possession_tactics.dart';
export 'tactic_modifiers.dart';
export 'team_tactics.dart';
export 'transition_tactics.dart';
