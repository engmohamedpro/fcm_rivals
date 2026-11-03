import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../core/ui/match_backdrop.dart';
import 'live_match_views.dart';
import 'live_tactics_screen.dart';
import 'match_audio.dart';
import 'match_engine.dart';
import 'match_report.dart';
import 'match_session.dart';
import 'stamina.dart';
import 'tactics.dart';

/// Invoked once when the match finishes and [MatchSession.finish] has
/// persisted stamina and rewards — the league flow commits the fixture
/// result here (standings, AI lockstep) while the report screen is up.
typedef MatchFullTimeCallback = Future<void> Function(MatchReportResult report);

/// Live match screen (GDD 13, GDD 16): minute-by-minute simulation with
/// the momentum bar, commentary feed, live tactical changes and the
/// post-match report with the pep talk choice (GDD 11.6).
///
/// The match plays itself: a ticker-driven clock advances one minute per
/// [_minuteDuration] of elapsed time, multiplied by the selected speed
/// (1x–3x). The clock pauses while the half-time talk or the tactics
/// sheet is open, and the user can pause/resume at any time — there is no
/// skip-to-end; every match is watched to its final minute.
///
/// Layout: the compact [MatchHeader] (score + clock + controls fused
/// into one panel), the momentum bar (per-minute spikes — home above
/// the baseline, away below) and the commentary feed — newest at the
/// bottom, the whole history scrolls up above it.
///
/// Performance: one setState per match minute (800ms at 1x, 267ms at
/// 3x) — every row is a plain stateless widget, no per-row entrance
/// animations or controllers (the old side-slide-in rows were the jank
/// source at top speed), and the momentum series is recomputed from the
/// minutes played so far, not the whole event list each time.
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

  /// The chosen post-match recovery (null until the card is answered).
  _RecoveryChoice? _postMatchChoice;

  /// Live momentum timeline (GDD 13.2): the HOME share per minute
  /// (index 0 = minute 1) driving the momentum bar's spikes. Recomputed
  /// from the minutes played so far — the pass over the event list is
  /// linear and the list for one match is small, so the plain recompute
  /// stays far cheaper than any incremental bookkeeping. Null for
  /// matches without team ids; the bar then stays on its baseline.
  List<double>? _momentumSeries;

  /// The user's crest colour (momentum bar user spikes). Null until the
  /// club row loads; brand gold stands in for that blink.
  Color? _userTeamColor;

  /// Auto-scroll: whether the feed should keep the newest line in view.
  /// Turns off the moment the user scrolls up to read history and back
  /// on when they return to the bottom.
  bool _followLatest = true;

  /// Match-day sound (GDD 13): the stadium ambience loops from kick-off
  /// to full time and a cheer plays over it on every goal. Decorative —
  /// every call inside is best-effort and never breaks the match.
  final MatchAudio _audio = MatchAudio();

  /// Auto-play clock. One match minute costs [_minuteDuration] of real
  /// time at 1x; the speed multiplier divides it (800ms → 200ms at 4x).
  late final Ticker _ticker;
  static const Duration _minuteDuration = Duration(milliseconds: 800);

  /// The commentary feed's scroll controller — pinned so the feed can
  /// jump to the newest line without a lookup.
  final ScrollController _feedScroll = ScrollController();

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

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _feedScroll.addListener(_onFeedScrolled);
    // Kick-off: the ambience starts with the first half and runs until
    // full time (stopped there — the post-match report is silent).
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
        setState(() => _userTeamColor = FcmColors.crestColor(club.crestIndex));
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
    _feedScroll
      ..removeListener(_onFeedScrolled)
      ..dispose();
    unawaited(_audio.dispose());
    super.dispose();
  }

  /// Follow-mode: on when the feed sits at (or within a row of) the
  /// bottom, off as soon as the user scrolls up into history.
  void _onFeedScrolled() {
    if (!_feedScroll.hasClients) return;
    final pos = _feedScroll.position;
    final atBottom = pos.pixels >= pos.maxScrollExtent - 48;
    if (atBottom != _followLatest) _followLatest = atBottom;
  }

  /// Pins the feed to the newest line after a minute appends entries —
  /// only while in follow mode (the user reading history keeps their
  /// place).
  void _jumpToLatest() {
    if (!_followLatest || !_feedScroll.hasClients) return;
    _feedScroll.position.jumpTo(_feedScroll.position.maxScrollExtent);
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
      );
      // One rebuild per minute: rows and the momentum bar update
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
      // Auto-follow: land the newest line in view after the frame
      // measures the grown list.
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLatest());
      // Any goal in the minute just simulated — either side — triggers
      // the crowd cheer over the looped ambience.
      if (events.any((e) => e.type == MatchEventType.goal)) {
        unawaited(_audio.goalCheer());
      }
    }
    _maybeOfferHalfTimeTalk();
    if (session.isFinished) {
      // Full time: the whistle ends the ambience too ("first-half
      // kick-off to second-half end"), before the report flow starts.
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
      _postMatchChoice = null;
      if (mounted) setState(() => _recoveryPending = true);
      while (_postMatchChoice == null && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      final choice = _postMatchChoice;
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
      setState(() {
        _finished = true;
        _report = report;
        _pepTalk = talk;
        _usedAdBoost = usedAdBoost;
      });
      ref.invalidate(clubProvider);
      ref.invalidate(collectionProvider);
      ref.invalidate(squadProvider);
      ref.invalidate(campusProvider);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      _finishing = false;
    }
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

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => _postMatchChoice = const _RecoveryChoice.none(),
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
                const Row(
                  children: [
                    Icon(
                      Icons.healing_rounded,
                      color: FcmColors.gold,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Post-match recovery',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'One focus for the squad on the rest days ahead:',
                  style: TextStyle(
                    color: FcmColors.textDim,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                for (final choice in PepTalk.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _RecoveryOption(
                      title: choice.displayName,
                      effect:
                          '+${(choice.recoveryBonus * 100).round()}% natural '
                          'recovery',
                      onTap: () =>
                          _postMatchChoice = _RecoveryChoice(pepTalk: choice),
                    ),
                  ),
                if (!won)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _RecoveryOption(
                      title: 'Watch ad: boosted recovery',
                      effect:
                          '+15% natural recovery for the whole squad '
                          '(GDD 19.3)',
                      gold: true,
                      onTap: () =>
                          _postMatchChoice = const _RecoveryChoice.boosted(),
                    ),
                  ),
                TextButton(
                  onPressed: () =>
                      _postMatchChoice = const _RecoveryChoice.none(),
                  child: const Text(
                    'No pep talk — default recovery',
                    style: TextStyle(color: FcmColors.textDim, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                            // Momentum bar where the old live stats
                            // strip sat: per-minute spikes — the home
                            // side's pressure rises ABOVE the baseline,
                            // the away side's hangs BELOW it — so who
                            // is on top reads at a glance. The user's
                            // crest colour tints their side's spikes.
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
                          // Commentary feed / report: newest at the
                          // bottom, the whole history scrolls up above
                          // it. Plain forward list — rows render in
                          // place, no entrance animation, stable keys so
                          // minutes append cheaply.
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
                                : _lines.isEmpty
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
                                : ListView.builder(
                                    controller: _feedScroll,
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      6,
                                      14,
                                      16,
                                    ),
                                    itemCount: _lines.length,
                                    itemBuilder: (context, index) =>
                                        CommentaryRow(
                                          key: ValueKey('line-$index'),
                                          line: _lines[index],
                                        ),
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
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => LiveTacticsScreen(
            session: session,
            minuteQueuedFrom: session.engine.state.minute + 1,
          ),
        ),
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

/// One post-match recovery option row (touchline card style).
class _RecoveryOption extends StatelessWidget {
  const _RecoveryOption({
    required this.title,
    required this.effect,
    required this.onTap,
    this.gold = false,
  });

  final String title;
  final String effect;
  final VoidCallback onTap;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return FcmPressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: gold ? FcmColors.gold : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    effect,
                    style: const TextStyle(
                      color: FcmColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: FcmColors.textDim,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Post-match report (GDD 14 post-match screen): result, reward, Man
/// of the Match, the full-match momentum flow and both squads' player
/// ratings in ONE tabbed panel — the user's XI opens first, the
/// opponent one tap away. The team-statistics table is gone — the
/// momentum graph (the same one the live match shows) tells how the
/// game flowed. The pep-talk choice is gone from here (it happens on
/// the full-time touchline card); the screen ends with a CONTINUE
/// button that closes the match flow.
class MatchReportView extends StatefulWidget {
  const MatchReportView({
    super.key,
    required this.report,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.pepTalk,
    this.adBoostedRecovery = false,
    this.userSide,
    this.momentumSeries,
    this.userTeamColor = FcmColors.gold,
    required this.onContinue,
  });

  final MatchReportResult report;
  final String homeTeamName;
  final String awayTeamName;

  /// The post-match pep talk applied at full time (shown as a status
  /// line — the choice itself was made on the touchline card).
  final PepTalk? pepTalk;

  /// Whether the ad-supported boosted recovery was applied (GDD 19.3).
  final bool adBoostedRecovery;

  /// Which side the player managed; drives the VICTORY / DEFEAT banner
  /// and which ratings tab opens first.
  final MatchSide? userSide;

  /// The full-match momentum timeline (per-minute HOME shares) — the
  /// live bar's series at full time. Null when the match carried no
  /// team ids; the section then stays off.
  final List<double>? momentumSeries;

  /// The user's crest colour, tinting their side's spikes.
  final Color userTeamColor;

  /// Ends the match flow — the ONLY exit (no back button above).
  final VoidCallback onContinue;

  @override
  State<MatchReportView> createState() => _MatchReportViewState();
}

class _MatchReportViewState extends State<MatchReportView> {
  /// Which squad's ratings are shown: the user's team opens first —
  /// after the final whistle you read your own players before the
  /// opponent's.
  late int _ratingsTab = _initialTab;

  int get _initialTab {
    final side = widget.userSide;
    if (side == null) return 0;
    return side == MatchSide.home ? 0 : 1;
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final home = report.state.scoreHome;
    final away = report.state.scoreAway;
    String? verdict;
    var verdictColor = FcmColors.gold;
    if (widget.userSide != null) {
      final mine = widget.userSide == MatchSide.home ? home : away;
      final theirs = widget.userSide == MatchSide.home ? away : home;
      if (mine > theirs) {
        verdict = 'VICTORY';
        verdictColor = FcmColors.success;
      } else if (mine < theirs) {
        verdict = 'DEFEAT';
        verdictColor = FcmColors.danger;
      } else {
        verdict = 'DRAW';
      }
    }
    final userTeamName = _initialTab == 0
        ? widget.homeTeamName
        : widget.awayTeamName;
    final opponentTeamName = _initialTab == 0
        ? widget.awayTeamName
        : widget.homeTeamName;
    final userRatings = _initialTab == 0
        ? report.homeRatings
        : report.awayRatings;
    final opponentRatings = _initialTab == 0
        ? report.awayRatings
        : report.homeRatings;
    // Spike colours: the user's crest colour tints their side, the
    // opponent's stays dimmed white (brand gold when no user side).
    Color homeColor = FcmColors.gold;
    Color awayColor = opponentMomentumColor;
    if (widget.userSide != null) {
      homeColor = widget.userSide == MatchSide.home
          ? widget.userTeamColor
          : opponentMomentumColor;
      awayColor = widget.userSide == MatchSide.home
          ? opponentMomentumColor
          : widget.userTeamColor;
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
            children: [
              FcmEntrance(
                child: FcmPanel(
                  accent: verdictColor,
                  glow: true,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                  child: Column(
                    children: [
                      if (verdict != null) ...[
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.6, end: 1),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.elasticOut,
                          builder: (context, v, child) =>
                              Transform.scale(scale: v, child: child),
                          child: FitText(
                            verdict,
                            align: Alignment.center,
                            style: TextStyle(
                              color: verdictColor,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 5,
                              shadows: [
                                Shadow(
                                  color: verdictColor.withValues(alpha: 0.6),
                                  blurRadius: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        'Full time: ${widget.homeTeamName} $home - $away '
                        '${widget.awayTeamName}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // The same C coin the top bar shows — one
                          // currency, one icon everywhere.
                          const FcmCoinGlyph(size: 20),
                          const SizedBox(width: 6),
                          Text(
                            'Reward: ${report.rewardCoins}',
                            style: const TextStyle(
                              color: FcmColors.gold,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // The recovery decision made on the full-time
                      // touchline card, restated as a status line.
                      if (widget.adBoostedRecovery)
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.movie, size: 14, color: FcmColors.gold),
                            SizedBox(width: 5),
                            Text(
                              'Ad-boosted recovery applied (+15% natural '
                              'recovery)',
                              style: TextStyle(
                                color: FcmColors.gold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        )
                      else if (widget.pepTalk != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.healing_rounded,
                              size: 14,
                              color: FcmColors.success,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                '${widget.pepTalk!.displayName} '
                                '(+${(widget.pepTalk!.recoveryBonus * 100).round()}% '
                                'recovery)',
                                style: const TextStyle(
                                  color: FcmColors.success,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              if (report.manOfTheMatch != null) ...[
                const SizedBox(height: 12),
                FcmEntrance(
                  index: 1,
                  child: FcmPanel(
                    accent: FcmColors.gold,
                    child: Row(
                      children: [
                        const FcmIconBadge(
                          icon: Icons.emoji_events_rounded,
                          size: 50,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FitText(
                                report.manOfTheMatch!.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Man of the Match · rating '
                                '${report.manOfTheMatch!.rating.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  color: FcmColors.textDim,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              // The full-match momentum flow where the team-statistics
              // table used to be: the same spike bar the live match
              // shows, now over the whole 90 minutes.
              if (widget.momentumSeries != null &&
                  widget.momentumSeries!.isNotEmpty) ...[
                const FcmSectionTitle('Momentum'),
                FcmEntrance(
                  index: 2,
                  child: FcmPanel(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: MomentumBar(
                      series: widget.momentumSeries!,
                      homeTeamName: widget.homeTeamName,
                      awayTeamName: widget.awayTeamName,
                      homeColor: homeColor,
                      awayColor: awayColor,
                    ),
                  ),
                ),
              ],
              // Both squads' ratings in ONE tabbed panel: the user's
              // team is the first tab and opens first.
              const FcmSectionTitle('Player ratings'),
              FcmEntrance(
                index: 3,
                child: _RatingsTabs(
                  firstLabel: userTeamName,
                  secondLabel: opponentTeamName,
                  firstRatings: userRatings,
                  secondRatings: opponentRatings,
                  current: _ratingsTab,
                  onChanged: (tab) => setState(() => _ratingsTab = tab),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        // CONTINUE — the only way out of the finished match: a full-width
        // bar pinned to the bottom of the screen.
        SafeArea(
          minimum: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: FcmButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: widget.onContinue,
          ),
        ),
      ],
    );
  }
}

/// Tab pair for the two squads' player ratings: gold segment for the
/// active squad, steel for the idle one. One tap switches lists.
class _RatingsTabs extends StatelessWidget {
  const _RatingsTabs({
    required this.firstLabel,
    required this.secondLabel,
    required this.firstRatings,
    required this.secondRatings,
    required this.current,
    required this.onChanged,
  });

  final String firstLabel;
  final String secondLabel;
  final List<PlayerMatchRating> firstRatings;
  final List<PlayerMatchRating> secondRatings;
  final int current;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 40,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: FcmColors.steelGradient,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FcmColors.bronze.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              for (final (i, label) in [firstLabel, secondLabel].indexed)
                Expanded(
                  child: FcmPressable(
                    onTap: () => onChanged(i),
                    scale: 0.98,
                    child: Container(
                      height: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: i == current ? FcmColors.goldGradient : null,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: FitText(
                        label,
                        style: TextStyle(
                          color: i == current
                              ? FcmColors.ink
                              : FcmColors.textDim,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _RatingsPanel(ratings: current == 0 ? firstRatings : secondRatings),
      ],
    );
  }
}

/// One squad's player ratings: position, name, goal/assist tallies and
/// the colour-coded rating pill. Players who feature only.
class _RatingsPanel extends StatelessWidget {
  const _RatingsPanel({required this.ratings});

  final List<PlayerMatchRating> ratings;

  static Color _ratingColor(double r) {
    if (r >= 7.5) return FcmColors.success;
    if (r >= 6.5) return FcmColors.gold;
    if (r >= 5.5) return const Color(0xFFC89A5B);
    return FcmColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final played = ratings.where((r) => r.played).toList();
    if (played.isEmpty) {
      return const FcmPanel(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Text(
          'No players featured.',
          style: TextStyle(color: FcmColors.textDim, fontSize: 12),
        ),
      );
    }
    return FcmPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          for (final r in played)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: FitText(
                      r.position.code,
                      style: const TextStyle(
                        color: FcmColors.textDim,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: FitText(
                      r.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (r.goals > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        '⚽ ×${r.goals}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  if (r.assists > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        '🅰 ×${r.assists}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  const SizedBox(width: 10),
                  FcmPill(
                    r.rating.toStringAsFixed(1),
                    color: _ratingColor(r.rating),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Post-match recovery choice: one free Pep Talk or the ad-boosted path.
class _RecoveryChoice {
  const _RecoveryChoice({this.pepTalk}) : boosted = false;
  const _RecoveryChoice.boosted() : pepTalk = null, boosted = true;
  const _RecoveryChoice.none() : pepTalk = null, boosted = false;

  final PepTalk? pepTalk;
  final bool boosted;
}
