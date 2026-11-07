/// FCM Rivals — shared tactical setup surface (GDD 10/11).
///
/// One implementation of the tactics screen, used in two places:
///
///  * the Team tab — every change goes straight to the club's saved
///    setup and becomes the permanent default (GDD 10.4);
///  * the pre-match tactics phase — the same controls and the same pitch,
///    but the selection lives only for the match about to be played and
///    the saved setup is never touched.
///
/// The screen itself is dominated by the pitch: a single compact control
/// card at the top carries the team rating, the formation dropdown
/// DIRECTLY on it (one tap switches shape — no detour into a sheet) and
/// opens the tactic options (playing style dropdown, mentality scale
/// slider) in a bottom sheet, so no option walls eat screen space.
library;

export 'squad_pitch_view.dart';
export 'tactics_setup_view.dart';
