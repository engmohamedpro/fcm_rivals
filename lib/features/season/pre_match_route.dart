/// FCM Rivals — the pre-match route body (GDD 12, FR-043).
///
/// The matchday build-up route, extracted verbatim out of
/// `season_screen.dart` (T-0044); the screen re-exports it, so existing
/// `season_screen.dart` imports (the AppRoutes route table) keep
/// working.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../match/match_forecast.dart' show PreMatchData;
import '../match/tactics.dart' show MatchPepTalk;
import '../match/pre_match_screen.dart' show PreMatchScreen, PreMatchTacticSelection;

/// Route body for the matchday build-up: loads the pre-match analysis
/// off the database and hands the chosen pep talk and MATCH-ONLY tactic
/// selection back through [onKickOff], then pops `true` so the caller
/// knows kick-off was pressed (vs. backed out, which leaves the fixture
/// unplayed). Nothing is persisted here — the selection lives only for
/// the match the caller is about to create.
class PreMatchRoute extends ConsumerStatefulWidget {
  const PreMatchRoute({
    super.key,
    required this.loadData,
    required this.onKickOff,
  });

  final Future<PreMatchData> Function() loadData;

  /// Receives the chosen pep talk (null = none) and the match-only tactic
  /// selection made in the tactics phase.
  final void Function(MatchPepTalk? talk, PreMatchTacticSelection? tactics)
  onKickOff;

  @override
  ConsumerState<PreMatchRoute> createState() => PreMatchRouteState();
}

class PreMatchRouteState extends ConsumerState<PreMatchRoute> {
  Future<PreMatchData>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loadData();
  }

  void _kickOff(MatchPepTalk? talk) {
    widget.onKickOff(talk, _lastTactics);
    Navigator.of(context).pop(true);
  }

  /// The most recent tactic selection reported by the pre-match screen
  /// (delivered at kick-off alongside the pep talk).
  PreMatchTacticSelection? _lastTactics;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PreMatchData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: FcmColors.night,
            appBar: AppBar(
              leading: BackButton(
                color: FcmColors.gold,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: FcmPanel(
                  accent: FcmColors.danger,
                  child: Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return Scaffold(
            backgroundColor: FcmColors.night,
            body: const SceneLoadingMarker(
              fallback: Center(
                child: CircularProgressIndicator(color: FcmColors.gold),
              ),
            ),
          );
        }
        return PreMatchScreen(
          data: data,
          onKickOff: _kickOff,
          onTacticsSelected: (selection) => _lastTactics = selection,
        );
      },
    );
  }
}
