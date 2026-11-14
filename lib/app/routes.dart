/// FCM Rivals — the central route table.
///
/// Every full-screen route the game pushes lives here as one typed
/// method: call sites state WHERE they are going and WHAT they hand
/// over, while this file alone owns the MaterialPageRoute creation —
/// transition style, fullscreenDialog flags and (later) route names,
/// deep links and restoration change in exactly one place.
///
/// Dialogs and bottom sheets stay local to their call sites: their
/// `Navigator.pop(context, value)` calls are modal communication, not
/// navigation, and centralising them would just relocate their state.
///
/// Layering: this file sits in `app/` (above `features/`, below
/// `main.dart`) because it needs the feature screens' constructors —
/// `core/` must stay feature-free.
library;

import 'package:flutter/material.dart';

import '../features/match/live_tactics_screen.dart';
import '../features/match/match_screen.dart';
import '../features/match/match_session.dart';
import '../features/match/pre_match_screen.dart'
    show PreMatchTacticSelection;
import '../features/packs/pack_contents_screen.dart';
import '../features/packs/pack_opening_screen.dart';
import '../features/packs/pack_engine.dart';
import '../features/season/season_screen.dart' show PreMatchRoute;
import '../core/domain/players.dart' show BasePlayer;
import '../features/match/match_forecast.dart' show PreMatchData;

/// One method per full-screen route; see the library doc above.
class AppRoutes {
  AppRoutes._();

  /// The pre-match room: squad review and the tactics phase (the
  /// pep-talk choice is gone — owner request 2026-11-14). Pops with
  /// `true` at kick-off, handing the match-only tactic selection back
  /// through [onKickOff] before the route closes.
  static Future<bool?> preMatch(
    BuildContext context, {
    required Future<PreMatchData> Function() loadData,
    required void Function(PreMatchTacticSelection? tactics) onKickOff,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PreMatchRoute(
          loadData: loadData,
          onKickOff: onKickOff,
        ),
      ),
    );
  }

  /// A league fixture: the live match screen with its session and the
  /// full-time commit hook. Pops when the report is dismissed.
  static Future<void> leagueMatch(
    BuildContext context, {
    required MatchSession session,
    required String title,
    required MatchFullTimeCallback onFullTime,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchScreen(
          session: session,
          title: title,
          onFullTime: onFullTime,
        ),
      ),
    );
  }

  /// The in-match tactic editor, opened as a fullscreen sheet so the
  /// clock visually pauses behind it. Changes queue for the next minute
  /// boundary.
  static Future<void> liveTactics(
    BuildContext context, {
    required MatchSession session,
    required int minuteQueuedFrom,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => LiveTacticsScreen(
          session: session,
          minuteQueuedFrom: minuteQueuedFrom,
        ),
      ),
    );
  }

  /// The pack-reveal cinematic. Pops with `true` when the player chose
  /// OPEN ANOTHER — the caller chains the next pack of the same shelf
  /// slot. [onSell] sells a revealed player straight from the reveal.
  static Future<bool?> packReveal(
    BuildContext context, {
    required List<BasePlayer> players,
    required List<int> ownedIds,
    List<bool> newFlags = const [],
    Color? packTint,
    int packStars = 3,
    PackChainInfo? chainInfo,
    int? Function()? queryBalance,
    Future<void> Function(int ownedId)? onSell,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => PackOpeningScreen(
          players: players,
          ownedIds: ownedIds,
          newFlags: newFlags,
          packTint: packTint,
          packStars: packStars,
          chainInfo: chainInfo,
          queryBalance: queryBalance,
          onSell: onSell,
        ),
      ),
    );
  }

  /// The contents browser behind a store cell's players icon: the pool
  /// a pack tier draws from, filtered by the offer's scope.
  static Future<void> packContents(
    BuildContext context, {
    required String title,
    required PackCategory category,
    String? scopeValue,
    required PackTier tier,
    required Future<List<BasePlayer>> Function() loadPlayers,
    Future<Map<int, double>> Function()? loadOdds,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PackContentsScreen(
          title: title,
          category: category,
          scopeValue: scopeValue,
          tier: tier,
          loadPlayers: loadPlayers,
          loadOdds: loadOdds,
        ),
      ),
    );
  }
}
