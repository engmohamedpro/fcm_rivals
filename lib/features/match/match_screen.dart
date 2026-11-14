import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../collection/collection_store.dart' show CollectionStore;
import '../../app/routes.dart';
import '../../core/domain/players.dart' show BasePlayer;
import '../../core/ui/country_flag.dart' show flagEmojiFor;
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../core/ui/match_backdrop.dart';
import '../../l10n/l10n_context.dart';
import '../../l10n/injury_l10n.dart';
import 'live_commentary_feed.dart';
import 'live_match_views.dart';
import 'live_tactics_panel.dart';
import 'goal_banner.dart';
import 'match_audio.dart';
import 'match_engine.dart';
import 'match_report.dart';
import 'match_report_view.dart';
import 'match_session.dart';

/// Everything the live GOAL moment needs (T-0116): the scorer's small
/// card (the only thing it draws besides the wordmark) plus the goal's
/// identity. [scorerId] lets the late portrait lookup confirm it still
/// belongs to the goal on screen before it swaps the richer card in.
typedef _GoalFlash = ({
  String scorer,
  int scorerId,
  String score,
  bool isUserGoal,
  Color color,
  GoalScorerCard? card,
});

/// The card rating the player shows elsewhere in the app: the dataset
/// overall scaled by the upgrade factor the engine already applied to the
/// player's attributes (read off the strongest base attribute, where
/// integer rounding costs the least).
int _goalCardRating(BasePlayer base, MatchPlayer? live) {
  final b = base.baseStats;
  if (live == null) return b.overall;
  var best = (b.attack, live.attack);
  for (final p in [
    (b.support, live.support),
    (b.defence, live.defence),
    (b.goalkeeping, live.goalkeeping),
  ]) {
    if (p.$1 > best.$1) best = p;
  }
  if (best.$1 <= 0) return b.overall;
  return (b.overall * best.$2 / best.$1).round();
}

/// Invoked once when the match finishes and [MatchSession.finish] has
/// persisted stamina and rewards — the league flow commits the fixture
/// result here (standings, AI lockstep) while the report screen is up.
typedef MatchFullTimeCallback = Future<void> Function(MatchReportResult report);

/// Live match screen (GDD 13, GDD 16): minute-by-minute simulation with
/// the momentum bar, the live commentary ticker, live tactical changes
/// and the post-match report with the pep talk choice (GDD 11.6).
///
/// The match plays itself: a ticker-driven clock advances one minute per
/// [_minuteDuration] of elapsed time, multiplied by the selected speed
/// (1x–3x). The clock pauses while the half-time talk or the tactics
/// sheet is open, and the user can pause/resume at any time — there is no
/// skip-to-end; every match is watched to its final minute.
///
/// Layout: the compact [MatchHeader] (score + clock + controls fused
/// into one panel), the momentum bar (per-minute spikes — home above
/// the baseline, away below) and the commentary ticker — one moment at
/// a time, lower-third style: the newest line replaces the last, no
/// scrolling history (the report at full time keeps the full record).
///
/// Performance: one setState per match minute (800ms at 1x, 267ms at
/// 3x) — the ticker is one fixed-height bar (text never wraps, so a
/// swap never re-measures), and the momentum series is recomputed from
/// the minutes played so far, not the whole event list each time. The
/// goal flash runs one controller that is disposed on swap.
///
/// Pushed as a full-screen route over the caller (league fixtures are
/// launched from the Season tab). The [session] arrives ready to play —
/// including any pre-match pep talk already queued at kick-off (GDD 15.1).
class MatchScreen extends ConsumerStatefulWidget {
  const MatchScreen({
    super.key,
    required this.session,
    this.title,
    this.onFullTime,
  });

  final MatchSession session;

  /// AppBar label for the fixture, e.g. 'League · Round 3'.
  final String? title;

  /// Optional commit hook for persistent competitions (GDD 9.2).
  final MatchFullTimeCallback? onFullTime;

  @override
  ConsumerState<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends ConsumerState<MatchScreen>
    with SingleTickerProviderStateMixin {
  final List<CommentaryLine> _lines = [];
  bool _finished = false;
  MatchReportResult? _report;

  String? _error;

  bool _finishing = false;

  /// True while the post-match recovery card is up over the full-time
  /// scoreboard — the match flow is paused on the manager's decision.


  /// Resolves when the manager answers the post-match recovery card —
  /// the card's tap handlers complete it instead of polling a field.


  /// Guards double-taps: the card answers exactly once.


  /// True after the first scrim tap on the recovery card — the skip
  /// demands a second, deliberate confirmation.


  /// Live momentum timeline (GDD 13.2): the HOME share per minute
  /// (index 0 = minute 1) driving the momentum bar's spikes. Recomputed
  /// from the minutes played so far — the pass over the event list is
  /// linear and the list for one match is small, so the plain recompute
  /// stays far cheaper than any incremental bookkeeping. Null for
  /// matches without team ids; the bar then stays on its baseline.
  List<double>? _momentumSeries;

  /// The user's crest colour (momentum bar user spikes, ticker tint).
  /// Null until the club row loads; brand gold stands in for that
  /// blink.
  Color? _userTeamColor;

  /// Match-day sound (GDD 13): the stadium ambience loops from kick-off
  /// to full time and a cheer plays over it on every goal. Decorative —
  /// every call inside is best-effort and never breaks the match.
  final MatchAudio _audio = MatchAudio();

  /// Auto-play clock. One match minute costs [_minuteDuration] of real
  /// time at 1x; the speed multiplier divides it (800ms → 200ms at 4x).
  late final Ticker _ticker;
  static const Duration _minuteDuration = Duration(milliseconds: 800);

  /// Playback speed: 1, 2, 3 or 4.
  int _speed = 1;

  /// User pause. While true the clock swallows elapsed time.
  bool _paused = false;

  /// True while a modal sheet owns the screen (half-time talk, tactics) —
  /// the clock is held so the match never runs behind a decision.
  bool _sheetOpen = false;

  /// Real-time budget already paid toward the next match minute.
  Duration _budget = Duration.zero;
  Duration _lastElapsed = Duration.zero;

  /// The newest commentary moment — the ONE line the ticker shows.
  CommentaryLine? get _latest => _lines.isEmpty ? null : _lines.last;

  /// The goal announcement moment (T-0116): while non-null the GOAL
  /// banner bursts over the pitch. Re-entered on a second goal (the
  /// banner restarts, never queues), cleared when its animation
  /// completes — and never shown while a touchline card holds the
  /// screen (half-time talk), which the mount guard below enforces.
  _GoalFlash? _goalFlash;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    // Kick-off: the ambience starts with the first half. From there the
    // whistle events drive it — half time ends it for the break, the
    // second-half kick-off brings it back, full time ends it for good —
    // and the user's pause button holds it with the match.
    unawaited(_audio.start());
    // The last chosen playback speed carries over — the preference
    // sticks FOREVER, across matches and app restarts (GDD 26.2).
    unawaited(_loadPersistedSpeed());
    // The user's crest colour tints their half of the momentum bar.
    unawaited(_loadUserCrestColor());
  }

  Future<void> _loadUserCrestColor() async {
    try {
      final store = await ref.read(collectionStoreProvider.future);
      final club = await store.getClub();
      if (mounted && club != null) {
        // T-0097 resolver: a spec club's bar uses spec.primaryColor —
        // which for a legacy club IS crestColor(crestIndex), so every
        // existing save keeps its exact tint.
        setState(
          () => _userTeamColor = CollectionStore.crestOf(club).primaryColor,
        );
      }
    } catch (_) {
      // A storage hiccup leaves the bar's user half at brand gold.
    }
  }

  Future<void> _loadPersistedSpeed() async {
    try {
      final store = await ref.read(userSettingsProvider.future);
      final speed = await store.matchSpeed();
      if (speed != _speed && mounted && !_finished) {
        setState(() => _speed = speed);
      }
    } catch (_) {
      // Settings are decorative to the match itself — a storage hiccup
      // just leaves this match at the default speed.
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    unawaited(_audio.dispose());
    super.dispose();
  }

  /// The auto-play heartbeat: converts elapsed real time × speed into
  /// match minutes, stopping for pauses, open sheets and full time.
  void _onTick(Duration elapsed) {
    final session = widget.session;
    final delta = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    if (session.isFinished) {
      _ticker.stop();
      return;
    }
    if (_paused || _sheetOpen || delta <= Duration.zero) return;
    _budget += delta * _speed;
    while (!session.isFinished && !_sheetOpen && _budget >= _minuteDuration) {
      _budget -= _minuteDuration;
      _advance();
    }
  }

  void _setSpeed(int speed) {
    if (speed == _speed || _finished) return;
    fcmTick();
    setState(() => _speed = speed);
    // Remember the choice for every future match (GDD 26.2).
    unawaited(_persistSpeed(speed));
  }

  Future<void> _persistSpeed(int speed) async {
    try {
      final store = await ref.read(userSettingsProvider.future);
      await store.setMatchSpeed(speed);
    } catch (_) {
      // Best-effort: the match itself never depends on the write.
    }
  }

  void _togglePause() {
    fcmTick();
    setState(() => _paused = !_paused);
    // The bed holds with the match: a held match must not sound over
    // the stadium.
    unawaited(_paused ? _audio.pause() : _audio.resume());
  }

  /// Swaps the dataset's real portrait, rating, flag and club crest into
  /// the GOAL moment's scorer card. Best-effort and silent: a missing row
  /// or a slow read leaves the engine-derived card in place, and a result
  /// that arrives after the banner moved on (a newer goal, or cleared) is
  /// dropped instead of landing on the wrong moment.
  Future<void> _enrichGoalFlash(int scorerId) async {
    try {
      final session = widget.session;
      final base = await session.basePlayerOf(scorerId);
      if (base == null || !mounted) return;
      final flash = _goalFlash;
      if (flash == null || flash.scorerId != scorerId) return;
      setState(() {
        _goalFlash = (
          scorer: flash.scorer,
          scorerId: flash.scorerId,
          score: flash.score,
          isUserGoal: flash.isUserGoal,
          color: flash.color,
          card: GoalScorerCard(
            rating: _goalCardRating(base, session.matchPlayerById(scorerId)),
            position: base.position.code,
            flag: flagEmojiFor(base.nationality),
            imageUrl: base.imageUrl,
            clubCrestUrl: base.clubCrestUrl,
            isIcon: base.isIcon,
          ),
        );
      });
    } catch (_) {
      // Decorative: the goal moment never depends on the lookup.
    }
  }

  void _advance() {
    final session = widget.session;
    if (session.isFinished) return;
    final events = session.advanceMinute();
    if (events.isNotEmpty) {
      // Broadcast track only: the feed carries key moments, not every
      // pass and tackle — a real commentator raises his voice for goals,
      // saves, cards and penalties, not for a midfield throw-in.
      final lines = generateCommentary(
        events,
        playerNames: session.allPlayerNames,
        homeTeamName: session.homeTeamName,
        awayTeamName: session.awayTeamName,
        keyEventsOnly: true,
        injuryText: injuryCommentaryLocalizer(l10nOf(context)),
      );
      // Every event in the minute just simulated drives its sound. Each
      // goal rings out its own cheer over the bed — home goals at the
      // home crowd's volume, away goals much quieter — and the whistle
      // events play the referee whistles instantly.
      for (final event in events) {
        if (event.type == MatchEventType.goal) {
          unawaited(_audio.goalCheer(isHome: event.side == MatchSide.home));
        } else if (event.type == MatchEventType.kickoff &&
            event.metadata['secondHalf'] == true) {
          unawaited(_audio.secondHalfKickOff());
        }
      }

      // One rebuild per minute: the ticker and the momentum bar swap
      // together.
      setState(() {
        _lines.addAll(lines);
        // The GOAL announcement (T-0116): the loudest moment gets the
        // loudest channel — a screen-level banner, not a quiet card
        // glow. Only while the live view owns the screen (match not
        // finished); a second goal restarts the banner from the top.
        for (final event in events) {
          if (event.type == MatchEventType.goal &&
              !session.isFinished) {
            final names = session.allPlayerNames;
            final live = session.engine.state;
            final flashColor = event.side == session.userSide
                ? (_userTeamColor ?? FcmColors.gold)
                : opponentMomentumColor;
            final scorerId = event.primaryPlayerId;
            final livePlayer = scorerId == null
                ? null
                : session.matchPlayerById(scorerId);
            _goalFlash = (
              scorer: names[scorerId] ?? '',
              scorerId: scorerId ?? -1,
              score: '${live.scoreHome} - ${live.scoreAway}',
              isUserGoal: event.side == session.userSide,
              color: flashColor,
              // Instant card from the engine's own player (always
              // available); the dataset lookup below swaps in the real
              // portrait and rating well before the card flips over.
              card: livePlayer == null
                  ? null
                  : GoalScorerCard(
                      rating: livePlayer.position.isGoalkeeper
                          ? livePlayer.goalkeeping
                          : [
                              livePlayer.attack,
                              livePlayer.support,
                              livePlayer.defence,
                            ].reduce((a, b) => a > b ? a : b),
                      position: livePlayer.position.code,
                      flag: flagEmojiFor(livePlayer.nationality),
                    ),
            );
            // The store resolves owned-card ids and league-opponent ids
            // alike; it returns null for synthetic friendly players.
            if (scorerId != null) {
              unawaited(_enrichGoalFlash(scorerId));
            }
            break; // one banner per minute even on a double.
          }
        }
        // Friendly previews without a persisted club have no team ids —
        // the bar stays on its baseline rather than mis-attributing
        // events.
        final homeId = session.homeTeamId;
        final awayId = session.awayTeamId;
        if (homeId != null && awayId != null) {
          // Momentum: per-minute trailing-window pressure shares — the
          // spikes rise for whoever is on top right now.
          _momentumSeries = computeMomentumSeries(
            session.engine.events,
            homeTeamId: homeId,
            awayTeamId: awayId,
          );
        }
      });
    }
    if (session.isFinished) {
      // Full time: the whistle ends the ambience too ("first-half
      // kick-off to second-half end"), before the report flow starts.
      // A cheer still ringing from a late goal keeps playing to its end
      // — the crowd does not stop mid-roar.
      unawaited(_audio.stop());
      _finishMatch();
    }
  }

  Future<void> _finishMatch() async {
    final session = widget.session;
    if (_finishing) return;
    _finishing = true;
    // Full time → report is a scene change: raise the scene-loading
    // transition at the whistle (no debounce) and keep it up while the
    // result is committed; it then fades over the report. Null (a no-op)
    // when no host is mounted, e.g. in widget tests.
    final scene = SceneLoadingScope.maybeOf(context)
      ?..begin(immediate: true);
    try {
      // T-0100 (owner request 2026-11-09): full time goes straight to
      // the report — the post-match pep-talk / recovery chooser card
      // is gone, so every match settles with the default recovery
      // (no pep-talk bonus, no ad boost; restDays stays 3).
      final report = await session.finish();
      // Persistent-competition hook (GDD 9.2): the league fixture is
      // committed with the result, AI stamina and lockstep simulation.
      await widget.onFullTime?.call(report);
      if (mounted) {
        setState(() {
          _finished = true;
          _report = report;
        });
        ref.invalidate(collectionProvider);
        ref.invalidate(squadProvider);
        ref.invalidate(campusProvider);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      _finishing = false;
      scene?.end();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final state = session.engine.state;
    final userIsHome = session.userSide == MatchSide.home;
    final userColor = _userTeamColor ?? FcmColors.gold;

    return PopScope(
      // The match plays to its final minute — no backing out of the
      // live screen; the report's Continue button ends the flow.
      canPop: _finished,
      child: Scaffold(
        // No AppBar during live play (T-0114): it held only the fixture
        // label — no back button (PopScope blocks leaving anyway), no
        // actions — while costing the content column ~56px plus its
        // safe-area overlap. The label now whispers inside the header
        // panel and the stadium backdrop starts that much higher. At
        // full time there is no header at all: the report owns the
        // screen exactly as before.
        extendBodyBehindAppBar: true,
        appBar: null,
        body: FcmMatchBackdrop(
          // The photo runs edge to edge; the content column starts at
          // the safe area top instead of below a dead bar.
          child: SafeArea(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: FcmPanel(
                        accent: FcmColors.danger,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 14),
                            FcmButton(
                              onPressed: _finishMatch,
                              label: 'Retry',
                              icon: Icons.refresh_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      Column(
                        children: [
                          if (!_finished) ...[
                            MatchHeader(
                              home: session.homeTeamName,
                              away: session.awayTeamName,
                              homeCrest: session.homeCrest,
                              awayCrest: session.awayCrest,
                              scoreHome: state.scoreHome,
                              scoreAway: state.scoreAway,
                              minute: state.minute,
                              fullTime: _finished || state.isFinished,
                              userIsHome: session.userSide == MatchSide.home,
                              fixtureLabel: widget.title,
                              paused: _paused,
                              speed: _speed,
                              onTogglePause: _togglePause,
                              onSetSpeed: _setSpeed,
                              // Tactics left the header card (owner
                              // request 2026-11-13): the live tactics
                              // panel below and the half-time card keep
                              // the editor one tap away.
                              // Momentum rides the clock bar: the home
                              // share of the latest minute, the user's
                              // crest colour tinting their side.
                              momentumShare: (_momentumSeries?.isNotEmpty ??
                                      false)
                                  ? _momentumSeries!.last
                                  : 0.5,
                              homeColor: userIsHome
                                  ? userColor
                                  : opponentMomentumColor,
                              awayColor: userIsHome
                                  ? opponentMomentumColor
                                  : userColor,
                            ),
                          ],
                          // Commentary feed / report. Under the header:
                          // the newest moment on a premium card
                          // with a short fading timeline beneath it (no
                          // scrolling — the full record stays in the
                          // engine and the report). Below it the live
                          // tactics panel: read the match, react to it,
                          // never leave it.
                          Expanded(
                            child: _finished && _report != null
                                ? MatchReportView(
                                    report: _report!,
                                    homeTeamName: session.homeTeamName,
                                    awayTeamName: session.awayTeamName,

                                    userSide: session.userSide,
                                    momentumSeries: _momentumSeries,
                                    userTeamColor: userColor,
                                    onContinue: () =>
                                        Navigator.of(context).pop(),
                                  )
                                : _latest == null
                                ? Center(
                                    child: Text(
                                      _paused
                                          ? 'Paused — press play to '
                                                'continue.'
                                          : 'Kick-off! The match plays '
                                                'itself — change speed or '
                                                'open tactics any time.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: FcmColors.textDim,
                                      ),
                                    ),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      0,
                                      14,
                                      0,
                                    ),
                                    child: LiveCommentaryFeed(
                                      lines: _lines,
                                      homeColor: userIsHome
                                          ? userColor
                                          : opponentMomentumColor,
                                      awayColor: userIsHome
                                          ? opponentMomentumColor
                                          : userColor,
                                    ),
                                  ),
                          ),
                          // Live tactics: mentality + timed orders, queued
                          // straight into the running match (hidden once
                          // the whistle has gone).
                          if (!_finished && !session.isFinished)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                              child: LiveTacticsPanel(
                                session: session,
                                minute: state.minute,
                                enabled: !_sheetOpen,
                                onOpenEditor: () => _openLiveTactics(context),
                              ),
                            ),
                        ],
                      ),
                      // The GOAL announcement (T-0116): the banner bursts
                      // over the pitch while the match keeps playing —
                      // celebration, not interruption.
                      if (_goalFlash != null)
                        Positioned.fill(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: GoalBanner(
                                scorerName: _goalFlash!.scorer,
                                scoreline: _goalFlash!.score,
                                color: _goalFlash!.color,
                                isUserGoal: _goalFlash!.isUserGoal,
                                scorerCard: _goalFlash!.card,
                                // When the animation completes the banner
                                // clears itself and the screen rebuilds
                                // without it.
                                onFinished: () {
                                  if (mounted && _goalFlash != null) {
                                    setState(() => _goalFlash = null);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// Live tactical changes (GDD 10.4/16): the full pitch editor pushed
  /// over the frozen match — the same formation-pitch surface the user
  /// knows from the Team tab and the pre-match screen (formation, style,
  /// mentality with visible effects, live actions, substitutions). The
  /// auto-play clock is held while the editor is open, so changes are
  /// never made mid-minute and the user edits exactly like before the
  /// match. Changes queue for the next minute boundary.
  Future<void> _openLiveTactics(BuildContext context) async {
    final session = widget.session;
    _sheetOpen = true;
    try {
      await AppRoutes.liveTactics(
        context,
        session: session,
        minuteQueuedFrom: session.engine.state.minute + 1,
      );
    } finally {
      if (mounted) {
        setState(() {
          // Back from the editor: the clock resumes.
          _sheetOpen = false;
        });
      }
    }
  }
}
