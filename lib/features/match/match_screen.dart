import 'dart:async' show Completer, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../collection/collection_store.dart' show CollectionStore;
import '../../app/routes.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../core/ui/match_backdrop.dart';
import '../../l10n/l10n_context.dart';
import '../../l10n/injury_l10n.dart';
import '../../l10n/pep_talk_l10n.dart';
import 'live_commentary_feed.dart';
import 'live_match_views.dart';
import 'live_tactics_panel.dart';
import 'match_audio.dart';
import 'match_engine.dart';
import 'match_report.dart';
import 'match_report_view.dart';
import 'match_session.dart';
import 'stamina.dart';
import 'tactics.dart';

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
  PepTalk? _pepTalk;
  bool _usedAdBoost = false;
  String? _error;
  bool _halfTimeOffered = false;

  /// True while the half-time card is up OVER the frozen match (the
  /// auto-play clock stops for it). Separate from [_sheetOpen], which
  /// the tactics editor toggles: editing tactics at half time must NOT
  /// dismiss the pep-talk choice — the card comes back when the editor
  /// closes, until the manager talks or skips.
  bool _halfTimeCardUp = false;
  bool _finishing = false;

  /// True while the post-match recovery card is up over the full-time
  /// scoreboard — the match flow is paused on the manager's decision.
  bool _recoveryPending = false;

  /// Resolves when the manager answers the post-match recovery card —
  /// the card's tap handlers complete it instead of polling a field.
  Completer<RecoveryChoice>? _recoveryChoice;

  /// Guards double-taps: the card answers exactly once.
  bool _choiceMade = false;

  /// True after the first scrim tap on the recovery card — the skip
  /// demands a second, deliberate confirmation.
  bool _scrimSkipArmed = false;

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
    // The screen went away while the recovery card was still up: unblock
    // the parked finish instead of leaving it awaiting forever.
    final choice = _recoveryChoice;
    if (choice != null && !choice.isCompleted) {
      choice.completeError(
        StateError('MatchScreen disposed before the recovery choice'),
      );
    }
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
      // One rebuild per minute: the ticker and the momentum bar swap
      // together.
      setState(() {
        _lines.addAll(lines);
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
      // Every event in the minute just simulated drives its sound. Each
      // goal rings out its own cheer over the bed — home goals at the
      // home crowd's volume, away goals much quieter — and the whistle
      // events park the bed: half time ends it for the break, the
      // second-half kick-off brings it back. Full time ends it for good
      // below, with the report flow.
      for (final event in events) {
        if (event.type == MatchEventType.goal) {
          unawaited(_audio.goalCheer(isHome: event.side == MatchSide.home));
        } else if (event.type == MatchEventType.halfTime) {
          unawaited(_audio.halfTimeBreak());
        } else if (event.type == MatchEventType.kickoff &&
            event.metadata['secondHalf'] == true) {
          unawaited(_audio.secondHalfKickOff());
        }
      }
    }
    _maybeOfferHalfTimeTalk();
    if (session.isFinished) {
      // Full time: the whistle ends the ambience too ("first-half
      // kick-off to second-half end"), before the report flow starts.
      // A cheer still ringing from a late goal keeps playing to its end
      // — the crowd does not stop mid-roar.
      unawaited(_audio.stop());
      _finishMatch();
    }
  }

  void _maybeOfferHalfTimeTalk() {
    final session = widget.session;
    if (_halfTimeOffered) return;
    final state = session.engine.state;
    // Offer once when the clock first reaches/reaches past half time.
    if (state.minute >= 45 && !state.isFinished) {
      _halfTimeOffered = true;
      _showHalfTimeTalk();
    }
  }

  /// Half-time pep talk (GDD 15.2) as a touchline card ON the match —
  /// not a modal sheet. The auto-play clock is held while the card is
  /// up, so the match waits for the decision; effects apply from the
  /// second-half kick-off, ad-free like every pep talk (FR-043).
  void _showHalfTimeTalk() {
    setState(() {
      _sheetOpen = true;
      _halfTimeCardUp = true;
    });
  }

  void _hideHalfTimeTalk({MatchPepTalk? talk}) {
    final session = widget.session;
    setState(() {
      _sheetOpen = false;
      _halfTimeCardUp = false;
    });
    if (talk != null && !session.isFinished) {
      session.queueHalfTimeTalk(talk);
    }
  }

  Future<void> _finishMatch() async {
    final session = widget.session;
    if (_finishing) return;
    _finishing = true;
    try {
      // Post-match pep talk (GDD 15.3/11.6) or the ad-supported boosted
      // recovery (GDD 19.3) — mutually exclusive (GDD 19.4), chosen BEFORE
      // persistence runs so the choice is real this time. Same touchline
      // card design as the half-time talk.
      _choiceMade = false;
      _scrimSkipArmed = false;
      final choiceCompleter = Completer<RecoveryChoice>();
      _recoveryChoice = choiceCompleter;
      if (mounted) setState(() => _recoveryPending = true);
      // The card's tap handlers resolve the completer — no polling.
      RecoveryChoice? choice;
      try {
        choice = await choiceCompleter.future;
      } catch (_) {
        // The screen went away before the card was answered.
      }
      if (mounted) setState(() => _recoveryPending = false);
      var usedAdBoost = false;
      PepTalk? talk;
      if (choice != null) {
        if (choice.boosted) {
          usedAdBoost = true;
        } else {
          talk = choice.pepTalk;
        }
      }

      final report = await session.finish(
        pepTalk: talk,
        adBoostedRecovery: usedAdBoost,
      );
      // Persistent-competition hook (GDD 9.2): the league fixture is
      // committed with the result, AI stamina and lockstep simulation.
      await widget.onFullTime?.call(report);
      if (mounted) {
        setState(() {
          _finished = true;
          _report = report;
          _pepTalk = talk;
          _usedAdBoost = usedAdBoost;
        });
        ref.invalidate(collectionProvider);
        ref.invalidate(squadProvider);
        ref.invalidate(campusProvider);
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      _finishing = false;
    }
  }

  /// Answers the recovery card exactly once: the first tap wins, later
  /// taps are swallowed while the finish proceeds.
  void _answerRecovery(RecoveryChoice choice) {
    if (_choiceMade) return;
    _choiceMade = true;
    _recoveryChoice?.complete(choice);
    // Feed back immediately: the card steps aside the moment it is
    // answered, so the report lands without a dead frame.
    if (mounted) setState(() => _recoveryPending = false);
  }

  /// Chooses the post-match recovery path: a normal pep talk (free,
  /// FR-043) or the ad-boosted +15% recovery (GDD 19.3) when ads remain.
  /// Rendered as the touchline card over the full-time scoreboard —
  /// the same design as the half-time talk.
  Widget _buildPostMatchRecoveryCard() {
    final session = widget.session;
    final userAtHome = session.userSide == MatchSide.home;
    final userGoals = userAtHome
        ? session.engine.state.scoreHome
        : session.engine.state.scoreAway;
    final opponentGoals = userAtHome
        ? session.engine.state.scoreAway
        : session.engine.state.scoreHome;
    final won = userGoals > opponentGoals;
    final l10n = l10nOf(context);

    return Positioned.fill(
      child: GestureDetector(
        // The scrim demands a deliberate double tap to skip: one stray
        // tap outside the card must NOT throw the boosted option away —
        // the first tap only arms the hint, the second confirms.
        onTap: _confirmSkipOnScrim,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: FcmPanel(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            accent: FcmColors.bronze,
            glow: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.healing_rounded,
                      color: FcmColors.gold,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.postMatchRecoveryTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.postMatchRecoveryIntro,
                  style: const TextStyle(
                    color: FcmColors.textDim,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                for (final choice in PepTalk.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: RecoveryOption(
                      title: l10n.pepTalkName(choice),
                      effect: l10n.recoveryBonusEffect(
                        (choice.recoveryBonus * 100).round(),
                      ),
                      onTap: () =>
                          _answerRecovery(RecoveryChoice(pepTalk: choice)),
                    ),
                  ),
                if (!won)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: RecoveryOption(
                      title: l10n.watchAdBoostedRecovery,
                      effect: l10n.watchAdBoostedEffect,
                      gold: true,
                      onTap: () =>
                          _answerRecovery(const RecoveryChoice.boosted()),
                    ),
                  ),
                TextButton(
                  onPressed: () =>
                      _answerRecovery(const RecoveryChoice.none()),
                  child: Text(
                    l10n.noPepTalkDefault,
                    style: const TextStyle(
                      color: FcmColors.textDim,
                      fontSize: 12,
                    ),
                  ),
                ),
                // Armed by the first scrim tap: the skip needs a second,
                // deliberate confirmation before it takes effect.
                if (_scrimSkipArmed)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l10n.tapAgainToSkip,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: FcmColors.gold,
                        fontSize: 11,
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

  /// First scrim tap arms the skip hint; the second confirms the skip.
  void _confirmSkipOnScrim() {
    if (_scrimSkipArmed) {
      _answerRecovery(const RecoveryChoice.none());
      return;
    }
    setState(() => _scrimSkipArmed = true);
  }

  /// The half-time touchline card, shown over the frozen match.
  Widget _buildHalfTimeCard() {
    final session = widget.session;
    final state = session.engine.state;
    return TouchlinePepTalkCard(
      title: 'HALF TIME',
      scoreHeader:
          '${session.homeTeamName} ${state.scoreHome} – ${state.scoreAway} '
          '${session.awayTeamName}',
      subtitle:
          'Pep talk for the second half — applies from kick-off. The match '
          'waits. You can also edit tactics before the restart.',
      talks: halfTimePepTalks,
      onChoose: (talk) => _hideHalfTimeTalk(talk: talk),
      onSkip: _hideHalfTimeTalk,
      onEditTactics: () => _openLiveTactics(context),
    );
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
        // The stadium backdrop flows behind the transparent app bar, so
        // the photo frames the scoreboard instead of a flat bar.
        extendBodyBehindAppBar: true,
        appBar: _finished
            ? null
            : AppBar(
                automaticallyImplyLeading: false,
                title: Text(widget.title ?? 'Live match'),
              ),
        body: FcmMatchBackdrop(
          // The photo runs edge to edge behind the app bar; the content
          // column stays below it.
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
                              scoreHome: state.scoreHome,
                              scoreAway: state.scoreAway,
                              minute: state.minute,
                              fullTime: _finished || state.isFinished,
                              userIsHome: session.userSide == MatchSide.home,
                              paused: _paused,
                              speed: _speed,
                              onTogglePause: _togglePause,
                              onSetSpeed: _setSpeed,
                              onTactics: () => _openLiveTactics(context),
                            ),
                            // Momentum meter: who is on top RIGHT NOW,
                            // said in words (status pill), as a tug-of-
                            // war bar whose knob slides every minute
                            // and as a trend wave of the match so far.
                            // The user's crest colour tints their side.
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                              child: FcmPanel(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  8,
                                ),
                                accent: FcmColors.bronze,
                                child: MomentumBar(
                                  series: _momentumSeries ?? const [],
                                  homeTeamName: session.homeTeamName,
                                  awayTeamName: session.awayTeamName,
                                  homeColor: userIsHome
                                      ? userColor
                                      : opponentMomentumColor,
                                  awayColor: userIsHome
                                      ? opponentMomentumColor
                                      : userColor,
                                ),
                              ),
                            ),
                          ],
                          // Commentary feed / report. Under the momentum
                          // meter: the newest moment on a premium card
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
                                    pepTalk: _pepTalk,
                                    adBoostedRecovery: _usedAdBoost,
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
                                enabled:
                                    !_halfTimeCardUp &&
                                    !_recoveryPending &&
                                    !_sheetOpen,
                                onOpenEditor: () => _openLiveTactics(context),
                              ),
                            ),
                        ],
                      ),
                      // Half-time touchline card over the frozen match.
                      if (!_finished && _halfTimeCardUp && !_recoveryPending)
                        _buildHalfTimeCard(),
                      // Post-match recovery card over the full-time
                      // scoreboard — same touchline design.
                      if (_recoveryPending) _buildPostMatchRecoveryCard(),
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
          // Back from the editor: the clock stays held while the
          // half-time card is still pending its decision.
          _sheetOpen = _halfTimeCardUp;
        });
      }
    }
  }
}
