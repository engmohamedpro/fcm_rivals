/// FCM Rivals — live match widgets (GDD 13): re-export barrel.
///
/// The widget families live in sibling files and re-export here (the
/// `fcm_widgets.dart` barrel pattern), so feature imports never churn
/// when a family moves again (task
/// `2026-11-05_app-structure_split-live-match-views`):
///
/// - `match_header.dart` — the compact scoreboard header and its
///   play/pause + speed + tactics controls;
/// - `momentum_bar.dart` — the live momentum meter (tug-of-war bar,
///   plain-words status and trend wave);
/// - `touchline_pep_talk.dart` — the half-time touchline talk card,
///   its chooser sheet and the shared `SheetOption` row.
///
/// The live commentary feed lives in `live_commentary_feed.dart` (the
/// featured moment + fading timeline) and the in-match tactics panel in
/// `live_tactics_panel.dart`; both are used directly by the match screen.
library;

export 'injury_live_banner.dart';
export 'match_header.dart';
export 'momentum_bar.dart';
export 'touchline_pep_talk.dart';
