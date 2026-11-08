/// FCM Rivals — live match widgets (GDD 13): re-export barrel.
///
/// The widget families live in sibling files and re-export here (the
/// `fcm_widgets.dart` barrel pattern), so feature imports never churn
/// when a family moves again (task
/// `2026-11-05_app-structure_split-live-match-views`):
///
/// - `match_header.dart` — the compact scoreboard header, its
///   play/pause + speed + tactics controls and the momentum bar;
/// - `touchline_pep_talk.dart` — the half-time touchline talk card,
///   its chooser sheet and the shared `SheetOption` row.
///
/// The live commentary itself lives in [CommentaryTicker]
/// (`commentary_ticker.dart`) — one moment at a time, lower-third style.
library;

export 'injury_live_banner.dart';
export 'match_header.dart';
export 'touchline_pep_talk.dart';
