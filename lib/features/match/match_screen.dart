import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../core/ui/match_backdrop.dart';
import '../squad/formations.dart';
import 'live_match_views.dart';
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
/// live stats, commentary feed, live tactical changes and the post-match
/// report with the pep talk choice (GDD 11.6).
///
/// The match plays itself: a ticker-driven clock advances one minute per
/// [_minuteDuration] of elapsed time, multiplied by the selected speed
/// (1x–4x). The clock pauses while the half-time talk or the tactics
/// sheet is open, and the user can pause/resume at any time — there is no
/// skip-to-end; every match is watched to its final minute.
///
/// Layout: the compact [MatchHeader] (score + clock + controls fused
/// into one panel), the live stats strip and the commentary feed —
/// newest at the bottom, the whole history scrolls up above it.
///
/// Performance: one setState per match minute (800ms at 1x, 200ms at
/// 4x) — every row is a plain stateless widget, no per-row entrance
/// animations or controllers (the old side-slide-in rows were the jank
/// source at 4x), and the stats are recomputed incrementally from the
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
  bool _finishing = false;

  /// Live team statistics (GDD 13.2), shown above the commentary feed.
  /// Rebuilt from the minutes played so far — [computeStats] is linear
  /// in events and the event list for one match is small, so the plain
  /// recompute stays far cheaper than any incremental bookkeeping.
  MatchStatsReport _stats = MatchStatsReport(
    home: TeamMatchStats.empty(),
    away: TeamMatchStats.empty(),
  );

  /// Folded state of the live stats strip — one tap collapses five rows
  /// into a single summary line when the commentary matters more.
  bool _statsCollapsed = false;

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
  }

  void _togglePause() {
    fcmTick();
    setState(() => _paused = !_paused);
  }

  void _toggleStats() {
    fcmTick();
    setState(() => _statsCollapsed = !_statsCollapsed);
  }

  void _advance() {
    final session = widget.session;
    if (session.isFinished) return;
    final events = session.advanceMinute();
    if (events.isNotEmpty) {
      final lines = generateCommentary(
        events,
        playerNames: session.allPlayerNames,
        homeTeamName: session.homeTeamName,
        awayTeamName: session.awayTeamName,
      );
      // One rebuild per minute: rows, stats and score update together.
      setState(() {
        _lines.addAll(lines);
        // Friendly previews without a persisted club have no team ids —
        // the strip stays empty rather than mis-attributing events.
        final homeId = session.homeTeamId;
        final awayId = session.awayTeamId;
        if (homeId != null && awayId != null) {
          _stats = computeStats(
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
      _chooseHalfTimeTalk();
    }
  }

  Future<void> _chooseHalfTimeTalk() async {
    final session = widget.session;
    // Half-time pep talk (GDD 15.2): effects apply to the second half,
    // ad-free like every pep talk (FR-043). The auto-play clock is held
    // while the sheet is up, so the match waits for the decision.
    _sheetOpen = true;
    try {
      final talk = await showPepTalkChooser(
        context: context,
        title: 'Half-time pep talk',
        subtitle:
            'One choice for the second half — applies from kick-off '
            'of the second half.',
        talks: halfTimePepTalks,
      );
      if (talk != null && mounted && !session.isFinished) {
        session.queueHalfTimeTalk(talk);
      }
    } finally {
      _sheetOpen = false;
    }
  }

  Future<void> _finishMatch() async {
    final session = widget.session;
    if (_finishing) return;
    _finishing = true;
    try {
      // Post-match pep talk (GDD 15.3/11.6) or the ad-supported boosted
      // recovery (GDD 19.3) — mutually exclusive (GDD 19.4), chosen BEFORE
      // persistence runs so the choice is real this time.
      var usedAdBoost = false;
      PepTalk? talk;
      final choice = await _choosePostMatchRecovery();
      if (choice == null) {
        // nothing chosen: default recovery
      } else if (choice.boosted) {
        usedAdBoost = true;
      } else {
        talk = choice.pepTalk;
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
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      _finishing = false;
    }
  }

  /// Chooses the post-match recovery path: a normal pep talk (free,
  /// FR-043) or the ad-boosted +15% recovery (GDD 19.3) when ads remain.
  Future<_RecoveryChoice?> _choosePostMatchRecovery() async {
    final theme = Theme.of(context);
    final session = widget.session;
    final userAtHome = session.userSide == MatchSide.home;
    final userGoals = userAtHome
        ? session.engine.state.scoreHome
        : session.engine.state.scoreAway;
    final opponentGoals = userAtHome
        ? session.engine.state.scoreAway
        : session.engine.state.scoreHome;
    final won = userGoals > opponentGoals;

    return showModalBottomSheet<_RecoveryChoice>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              'Post-match recovery',
              style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose one recovery focus for the squad (bonus to natural '
              'recovery, GDD 11.6):',
              style: theme.textTheme.bodySmall?.copyWith(
                color: FcmColors.textDim,
              ),
            ),
            const SizedBox(height: 12),
            for (final choice in PepTalk.values)
              SheetOption(
                title: choice.displayName,
                subtitle:
                    '+${(choice.recoveryBonus * 100).round()}% natural recovery',
                icon: Icons.healing_rounded,
                onTap: () => Navigator.pop(
                  sheetContext,
                  _RecoveryChoice(pepTalk: choice),
                ),
              ),
            if (!won)
              SheetOption(
                title: 'Watch ad: boosted recovery',
                subtitle: '+15% natural recovery for the whole squad (GDD 19.3)',
                icon: Icons.movie_rounded,
                accent: FcmColors.gold,
                onTap: () => Navigator.pop(
                  sheetContext,
                  const _RecoveryChoice.boosted(),
                ),
              ),
            SheetOption(
              title: 'No pep talk',
              subtitle: 'Default recovery',
              icon: Icons.block_rounded,
              muted: true,
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyPepTalk(PepTalk pepTalk) async {
    // Informational selection on the report screen; the persistence
    // already ran with the choice made at full time.
    setState(() => _pepTalk = pepTalk);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final state = session.engine.state;

    return Scaffold(
      // The stadium backdrop flows behind the transparent app bar, so
      // the photo frames the scoreboard instead of a flat bar.
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(widget.title ?? 'Live match')),
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
              : Column(
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
                        onTactics: () => _showTacticsSheet(context),
                      ),
                      // Live stats strip above the commentary feed
                      // (GDD 13.2) — every value recomputed each minute.
                      LiveMatchStatsPanel(
                        stats: _stats,
                        homeTeamName: session.homeTeamName,
                        awayTeamName: session.awayTeamName,
                        collapsed: _statsCollapsed,
                        onToggle: _toggleStats,
                      ),
                    ],
                    // Commentary feed / report: newest at the bottom,
                    // the whole history scrolls up above it. Plain
                    // forward list — rows render in place, no entrance
                    // animation, stable keys so minutes append cheaply.
                    Expanded(
                      child: _finished && _report != null
                          ? MatchReportView(
                              report: _report!,
                              homeTeamName: session.homeTeamName,
                              awayTeamName: session.awayTeamName,
                              pepTalk: _pepTalk,
                              adBoostedRecovery: _usedAdBoost,
                              onPepTalk: _applyPepTalk,
                              userSide: session.userSide,
                            )
                          : _lines.isEmpty
                          ? Center(
                              child: Text(
                                _paused
                                    ? 'Paused — press play to continue.'
                                    : 'Kick-off! The match plays itself — '
                                      'change speed or open tactics any '
                                      'time.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: FcmColors.textDim,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _feedScroll,
                              padding:
                                  const EdgeInsets.fromLTRB(14, 6, 14, 16),
                              itemCount: _lines.length,
                              itemBuilder: (context, index) => CommentaryRow(
                                key: ValueKey('line-$index'),
                                line: _lines[index],
                              ),
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Live tactical changes (GDD 10.4): formation, style, mentality and
  /// live actions with their explicit percentage effects (GDD 16), plus
  /// substitutions (FR-023: five available). The auto-play clock is held
  /// while the sheet is open, so changes are never made mid-minute.
  Future<void> _showTacticsSheet(BuildContext context) async {
    final session = widget.session;
    final nextMinute = session.engine.state.minute + 1;
    _sheetOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) {
          Widget section(String title, List<Widget> children) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: FcmColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              ...children,
            ],
          );
          return ListView(
            children: [
              section('Formation', [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in formations)
                        FcmOptionChip(
                          label: f.name,
                          selected:
                              f.code ==
                              session.engine.formationOf(session.userSide),
                          onTap: () {
                            session.queueCommand(
                              ChangeFormationCommand(
                                atMinute: nextMinute,
                                side: session.userSide,
                                formationCode: f.code,
                              ),
                            );
                            Navigator.pop(sheetContext);
                          },
                        ),
                    ],
                  ),
                ),
              ]),
              section('Playing style', [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in PlayingStyle.values)
                        FcmOptionChip(
                          label: s.displayName,
                          selected:
                              s == session.engine.styleOf(session.userSide),
                          onTap: () {
                            session.queueCommand(
                              ChangeStyleCommand(
                                atMinute: nextMinute,
                                side: session.userSide,
                                style: s,
                              ),
                            );
                            Navigator.pop(sheetContext);
                          },
                        ),
                    ],
                  ),
                ),
              ]),
              section('Mentality', [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in Mentality.values)
                      ActionChip(
                        label: Text(m.displayName),
                        onPressed: () {
                          session.queueCommand(
                            ChangeMentalityCommand(
                              atMinute: nextMinute,
                              side: session.userSide,
                              mentality: m,
                            ),
                          );
                          Navigator.pop(sheetContext);
                        },
                      ),
                  ],
                ),
              ]),
              section('Live action (10 minutes)', [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in LiveMatchAction.values)
                      ActionChip(
                        label: Text(a.displayName),
                        onPressed: () {
                          session.queueCommand(
                            LiveActionCommand(
                              atMinute: nextMinute,
                              side: session.userSide,
                              action: a,
                            ),
                          );
                          Navigator.pop(sheetContext);
                        },
                      ),
                  ],
                ),
              ]),
              _SubstitutionSection(
                session: session,
                side: session.userSide,
                onSubstitutionQueued: () => Navigator.pop(sheetContext),
              ),
              section('Effects', [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Mentality shifts Attack and Defence by up to ±20%. '
                    'Live actions apply explicit Attack/Defence/Stamina '
                    'modifiers for 10 minutes and can be replaced any time.',
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 24),
              ]),
            ],
          );
        },
      );
    } finally {
      _sheetOpen = false;
    }
  }
}

/// Substitution picker (FR-023: five subs, engine-enforced): tap the
/// player coming off, then the substitute coming on. Commands take
/// effect at the next minute boundary like every live change.
class _SubstitutionSection extends StatefulWidget {
  const _SubstitutionSection({
    required this.session,
    required this.side,
    required this.onSubstitutionQueued,
  });

  final MatchSession session;
  final MatchSide side;
  final VoidCallback onSubstitutionQueued;

  @override
  State<_SubstitutionSection> createState() => _SubstitutionSectionState();
}

class _SubstitutionSectionState extends State<_SubstitutionSection> {
  MatchPlayer? _selectedOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = widget.session;
    final used = session.engine.substitutionsUsedOf(widget.side);
    final max = session.engine.config.maxSubstitutions;
    final onPitch = session.engine.onPitchOf(widget.side);
    final bench = session.engine.benchOf(widget.side);
    final remaining = max - used;

    if (remaining <= 0 || bench.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          'Substitutions ($used/$max used — none remaining)',
          style: theme.textTheme.titleSmall,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Substitutions ($used/$max used)',
            style: theme.textTheme.titleSmall,
          ),
        ),
        if (_selectedOut != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Coming off: ${_selectedOut!.name} — pick the substitute:',
              style: theme.textTheme.bodySmall,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_selectedOut == null)
                for (final p in onPitch)
                  ActionChip(
                    avatar: CircleAvatar(
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      child: Text(
                        '${p.stamina.round()}%',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                    label: Text('${p.name} (${p.position.code})'),
                    onPressed: () => setState(() => _selectedOut = p),
                  )
              else
                for (final p in bench)
                  ActionChip(
                    avatar: CircleAvatar(
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      child: Text(
                        '${p.stamina.round()}%',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                    label: Text('${p.name} (${p.position.code})'),
                    onPressed: () => _queueSubstitution(p),
                  ),
            ],
          ),
        ),
        if (_selectedOut != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton(
              onPressed: () => setState(() => _selectedOut = null),
              child: const Text('Cancel selection'),
            ),
          ),
      ],
    );
  }

  void _queueSubstitution(MatchPlayer inPlayer) {
    final out = _selectedOut;
    if (out == null) return;
    widget.session.queueCommand(
      SubstitutionCommand(
        atMinute: widget.session.engine.state.minute + 1,
        side: widget.side,
        outPlayerId: out.playerId,
        inPlayerId: inPlayer.playerId,
      ),
    );
    widget.onSubstitutionQueued();
  }
}

/// Post-match report (GDD 14 post-match screen): result, scorers, ratings,
/// Man of the Match, team statistics and the pep talk choice.
class MatchReportView extends StatelessWidget {
  const MatchReportView({
    super.key,
    required this.report,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.pepTalk,
    required this.onPepTalk,
    this.adBoostedRecovery = false,
    this.userSide,
  });

  final MatchReportResult report;
  final String homeTeamName;
  final String awayTeamName;
  final PepTalk? pepTalk;
  final ValueChanged<PepTalk> onPepTalk;

  /// Whether the ad-supported boosted recovery was applied (GDD 19.3).
  final bool adBoostedRecovery;

  /// Which side the player managed; drives the VICTORY / DEFEAT banner.
  final MatchSide? userSide;

  static Color _ratingColor(double r) {
    if (r >= 7.5) return FcmColors.success;
    if (r >= 6.5) return FcmColors.gold;
    if (r >= 5.5) return const Color(0xFFC89A5B);
    return FcmColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final stats = report.stats;
    final home = report.state.scoreHome;
    final away = report.state.scoreAway;
    String? verdict;
    var verdictColor = FcmColors.gold;
    if (userSide != null) {
      final mine = userSide == MatchSide.home ? home : away;
      final theirs = userSide == MatchSide.home ? away : home;
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
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
                  'Full time: $homeTeamName $home - $away $awayTeamName',
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
                    const Icon(
                      Icons.monetization_on_rounded,
                      color: FcmColors.gold,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Reward: ${report.rewardCoins} coins',
                      style: const TextStyle(
                        color: FcmColors.gold,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
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
                          'Man of the Match · rating ${report.manOfTheMatch!.rating.toStringAsFixed(1)}',
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
        const FcmSectionTitle('Team statistics'),
        FcmEntrance(index: 2, child: _StatsTable(stats: stats)),
        const FcmSectionTitle('Player ratings'),
        FcmEntrance(
          index: 3,
          child: FcmPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                for (final r
                    in report.homeRatings.where((r) => r.played).take(11))
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
          ),
        ),
        const FcmSectionTitle('Pep talk'),
        if (adBoostedRecovery)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.movie, size: 18, color: FcmColors.gold),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Ad-boosted recovery applied: +15% natural recovery '
                    '(GDD 19.3)',
                    style: TextStyle(color: FcmColors.gold, fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else
          const Text(
            'Choose one recovery focus for the squad (bonus to natural recovery, GDD 11.6):',
            style: TextStyle(color: FcmColors.textDim, fontSize: 12),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final choice in PepTalk.values)
              ChoiceChip(
                label: Text(choice.displayName),
                selected: pepTalk == choice,
                showCheckmark: false,
                onSelected: (_) => onPepTalk(choice),
              ),
          ],
        ),
      ],
    );
  }
}

/// Comparative team statistics with a home/away share bar per row.
class _StatsTable extends StatelessWidget {
  const _StatsTable({required this.stats});

  final MatchStatsReport stats;

  static const _rows = [
    ('Possession', 'possess'),
    ('Shots', 'shots'),
    ('Shots on target', 'onTarget'),
    ('Expected goals', 'xg'),
    ('Big chances', 'bigChances'),
    ('Pass accuracy', 'passAccuracy'),
    ('Corners', 'corners'),
    ('Fouls', 'fouls'),
    ('Yellow cards', 'yellow'),
    ('Saves', 'saves'),
  ];

  /// Numeric value (for the bar) and display text for one side.
  (double, String) _side(TeamMatchStats s, String key) {
    switch (key) {
      case 'possess':
        final v = stats.possessionPercent(s).toDouble();
        return (v, '${v.round()}%');
      case 'shots':
        return (s.shots.toDouble(), '${s.shots}');
      case 'onTarget':
        return (s.shotsOnTarget.toDouble(), '${s.shotsOnTarget}');
      case 'xg':
        return (s.xg.toDouble(), s.xg.toStringAsFixed(1));
      case 'bigChances':
        return (s.bigChances.toDouble(), '${s.bigChances}');
      case 'passAccuracy':
        return s.passesAttempted == 0
            ? (0.0, '—')
            : (
                100 * s.passAccuracy.toDouble(),
                '${(100 * s.passAccuracy).round()}%',
              );
      case 'corners':
        return (s.corners.toDouble(), '${s.corners}');
      case 'fouls':
        return (s.fouls.toDouble(), '${s.fouls}');
      case 'yellow':
        return (s.yellowCards.toDouble(), '${s.yellowCards}');
      case 'saves':
        return (s.saves.toDouble(), '${s.saves}');
    }
    return (0.0, '—');
  }

  @override
  Widget build(BuildContext context) {
    return FcmPanel(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          for (final (label, key) in _rows)
            Builder(
              builder: (context) {
                final (hv, hs) = _side(stats.home, key);
                final (av, aw) = _side(stats.away, key);
                final total = hv + av;
                final share = total <= 0 ? 0.5 : (hv / total).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: FitText(
                              hs,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: FitText(
                              label,
                              align: Alignment.center,
                              style: const TextStyle(
                                color: FcmColors.textDim,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: FitText(
                              aw,
                              align: Alignment.centerRight,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.5, end: share),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (context, f, _) {
                          final left = (f * 1000).round().clamp(1, 999);
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              height: 6,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: left,
                                    child: const DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: FcmColors.goldGradient,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    flex: 1000 - left,
                                    child: const DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: FcmColors.steelGradient,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
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

  final PepTalk? pepTalk;
  final bool boosted;
}
