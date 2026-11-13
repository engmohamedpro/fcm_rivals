/// FCM Rivals — pre-match tactic selection model (GDD 10.4).
///
/// Data-only split out of `pre_match_screen.dart` (T-0060): the pure
/// session/store layer (`match_session.dart`, `season_store.dart`) and
/// headless batch sims consume this value type WITHOUT importing the
/// widget screen — the whole match-session chain stays runnable under
/// plain `dart run`. The screen re-exports it so its existing importers
/// keep working.
library;

import 'tactics.dart';

/// The tactic choices made in the pre-match tactics phase (GDD 10.4):
/// MATCH-ONLY overrides — the session is built from them, and the club's
/// saved default setup stays exactly as it was.
class PreMatchTacticSelection {
  const PreMatchTacticSelection({
    required this.formationCode,
    required this.tactics,
    this.mentality,
  });

  final String formationCode;
  final TeamTactics tactics;

  /// The match-only mentality override, or null to kick off with the
  /// club's saved value (the default since the pre-match surface
  /// stopped editing it, owner request 2026-11-13). Headless sims may
  /// still pin one.
  final Mentality? mentality;
}
