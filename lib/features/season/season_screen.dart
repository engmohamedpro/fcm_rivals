import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../core/database/app_database.dart' show PlayerSeasonStat;
import '../../core/domain/crest.dart';
import '../../core/ui/fcm_crest.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../match/tactics.dart' show MatchPepTalk;
import '../squad/formations.dart' show Formation;
import '../match/pre_match_tactics_selection.dart';
import 'season_engine.dart' show StandingEntry;
import 'season_store.dart';

export 'pre_match_route.dart';

/// Season screen (GDD 9): standings, the next fixture and season
/// management — start, play, quick-sim, complete and roll into the next
/// division.
class SeasonScreen extends ConsumerStatefulWidget {
  const SeasonScreen({super.key});

  @override
  ConsumerState<SeasonScreen> createState() => _SeasonScreenState();
}

class _SeasonScreenState extends ConsumerState<SeasonScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function(SeasonStore store) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(await ref.read(seasonStoreProvider.future));
      ref.invalidate(seasonSummaryProvider);
      ref.invalidate(standingsProvider);
      ref.invalidate(playerSeasonStatsProvider);
      ref.invalidate(playerSeasonStatsProvider);
      ref.invalidate(nextFixtureProvider);
      ref.invalidate(availablePacksProvider);
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e'.replaceFirst('SeasonException: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startSeason() =>
      _run((store) => store.startSeason(division: 1));

  /// Plays the next league fixture as a full matchday (GDD 13/16): the
  /// pre-match analysis screen (opponent form, W/D/L forecast, strength),
  /// the tactics screen (same as the Team tab, but the setup applies to
  /// this match only), the dressing-room pep talk (GDD 15.1), then the
  /// minute-by-minute engine with live tactics and substitutions,
  /// post-match recovery choice and the report — then the result is
  /// committed to the season (FR-038) and the round's AI fixtures resolve
  /// in lockstep (GDD 9.2).
  Future<void> _playNextFixture() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final store = await ref.read(seasonStoreProvider.future);
      final next = await store.getNextFixture();
      if (next == null) {
        // The fixture card can be a beat stale — a committed result or a
        // mid-flight provider refresh may have consumed the fixture between
        // the rebuild and this tap. Refresh and step out quietly instead of
        // crashing on a null unwrap.
        ref.invalidate(nextFixtureProvider);
        ref.invalidate(seasonSummaryProvider);
        ref.invalidate(standingsProvider);
      ref.invalidate(playerSeasonStatsProvider);
        ref.invalidate(playerSeasonStatsProvider);
        if (mounted) setState(() => _error = null);
        return;
      }
      if (!mounted) return;
      // No complete starting XI yet: send the player to the Team tab to
      // pick one instead of opening the pre-match flow on an error.
      final squad = await (await ref.read(collectionStoreProvider.future))
          .getSquad();
      if (!mounted) return;
      final xiComplete = [
        for (var slot = 0; slot < Formation.startingXiSize; slot++)
          squad.containsKey(slot),
      ].every((filled) => filled);
      if (!xiComplete) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Pick your starting XI to play the match'),
              duration: Duration(seconds: 3),
            ),
          );
        ref.read(shellTabRequestProvider.notifier).state = 1;
        return;
      }
      // The matchday build-up: analysis + match-only tactics + dressing
      // room, then the chosen pep talk (null = no talk). Ad-free by design
      // (FR-043). The tactic selection is handed back at kick-off and used
      // for this match only — the saved default setup is never touched.
      MatchPepTalk? talk;
      PreMatchTacticSelection? tactics;
      final kickedOff = await AppRoutes.preMatch(
        context,
        loadData: () => store.loadPreMatchData(
          ref.read(collectionStoreProvider).value!,
        ),
        onKickOff: (t, selection) {
          talk = t;
          tactics = selection;
        },
      );
      if (!mounted || kickedOff != true) return;
      final collection = await ref.read(collectionStoreProvider.future);
      final session = await store.startNextFixture(
        collection,
        preMatchTalk: talk,
        tactics: tactics,
      );
      if (!mounted) return;
      setState(() => _error = null);
      // Broadcast-style tag (owner request 2026-11-13): 'D1 · Round 3' —
      // division and round feed the live header's competition column,
      // Bein-sports style.
      final season = await store.getActiveSeason();
      if (!mounted) return;
      await AppRoutes.leagueMatch(
        context,
        session: session,
        title: 'D${season?.division ?? 1} · Round ${next.round}',
        onFullTime: (report) => store.commitFixtureResult(session, next),
      );
      ref.invalidate(seasonSummaryProvider);
      ref.invalidate(standingsProvider);
      ref.invalidate(playerSeasonStatsProvider);
      ref.invalidate(nextFixtureProvider);
      ref.invalidate(collectionProvider);
      ref.invalidate(squadProvider);
      ref.invalidate(availablePacksProvider);
      await _maybeCompleteSeason();
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e'.replaceFirst('SeasonException: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showCompletion(SeasonCompletion completion) {
    final (
      outcomeLabel,
      outcomeColor,
      outcomeIcon,
    ) = switch (completion.outcome) {
      'promoted' => ('Promoted!', FcmColors.success, Icons.trending_up),
      'relegated' => ('Relegated', FcmColors.danger, Icons.trending_down),
      _ => ('Stayed up', FcmColors.gold, Icons.shield),
    };
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (context, v, child) =>
                    Transform.scale(scale: v.clamp(0.0, 1.2), child: child),
                child: FcmIconBadge(
                  icon: Icons.emoji_events_rounded,
                  color: outcomeColor,
                  size: 92,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Season complete',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(outcomeIcon, color: outcomeColor),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FitText(
                      '$outcomeLabel You finished ${completion.finalPosition} of 20.',
                      style: TextStyle(
                        color: outcomeColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FcmPanel(
                padding: const EdgeInsets.all(14),
                radius: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Season reward: ${completion.rewardCoins} coins',
                      style: const TextStyle(
                        color: FcmColors.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Next division: ${completion.nextDivision}'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FcmButton(
                label: 'Continue',
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Auto-completes the season when the last fixture is played. Runs under
  /// the same [_busy] gate as every other store action, so a double tap
  /// (or a completion racing the match flow's own call) executes exactly
  /// once — the second caller sees the flag and steps out.
  Future<void> _maybeCompleteSeason() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final store = await ref.read(seasonStoreProvider.future);
      final next = await store.getNextFixture();
      if (next != null) return;
      final collection = await ref.read(collectionStoreProvider.future);
      final completion = await store.completeSeason(collection);
      ref.invalidate(seasonSummaryProvider);
      ref.invalidate(standingsProvider);
      ref.invalidate(playerSeasonStatsProvider);
      ref.invalidate(availablePacksProvider);
      if (mounted) await _showCompletion(completion);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = ref.watch(seasonSummaryProvider).valueOrNull;
    final standings = ref.watch(standingsProvider).valueOrNull;
    final crests =
        ref.watch(standingCrestsProvider).valueOrNull ?? const <int, CrestSpec>{};
    final next = ref.watch(nextFixtureProvider).valueOrNull;
    final clubName = ref.watch(clubProvider).valueOrNull?.name;

    if (ref.watch(seasonSummaryProvider).isLoading) {
      return const SceneLoadingMarker();
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FcmPanel(
            accent: FcmColors.danger,
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    if (summary == null) {
      // No season yet: start the first campaign (GDD 9.1: division 1).
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: FcmEntrance(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FcmIconBadge(icon: Icons.stadium_rounded, size: 96),
                const SizedBox(height: 22),
                Text(
                  AppLocalizations.of(context)!.startSeason,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Division 1 · 20 clubs · 38 matches',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: FcmColors.textDim,
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: 240,
                  child: FcmButton(
                    onPressed: _busy ? null : _startSeason,
                    loading: _busy,
                    icon: Icons.flag_rounded,
                    label: 'Start season',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final progress = summary.roundsTotal == 0
        ? 0.0
        : (summary.roundsPlayed / summary.roundsTotal).clamp(0.0, 1.0);

    // The opponent's current table position, shown on the next-fixture
    // card (null while standings load or if the club is somehow absent).
    int? opponentPos;
    CrestSpec? opponentCrest;
    if (next != null) {
      for (final e in standings ?? const <StandingEntry>[]) {
        if (e.clubId == next.opponentClubId) {
          opponentPos = e.position;
          break;
        }
      }
      opponentCrest = crests[next.opponentClubId];
    }

    // Top padding matches the sides, so the header card sits in even
    // whitespace like the tactics control card.
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        // Header: division, progress and outcome.
        FcmEntrance(
          child: FcmPanel(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: FcmColors.goldGradient,
                        boxShadow: [
                          BoxShadow(
                            color: FcmColors.gold.withValues(alpha: 0.4),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: FitText(
                        'D${summary.division}',
                        align: Alignment.center,
                        style: const TextStyle(
                          color: FcmColors.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FitText(
                            summary.isCompleted
                                ? 'Season ${summary.ordinal} · Division ${summary.division} · finished'
                                : 'Season ${summary.ordinal} · Division ${summary.division}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            summary.isCompleted
                                ? 'Final position: ${summary.finalPosition} (${summary.outcome})'
                                : 'Round ${next?.round ?? summary.roundsTotal} of ${summary.roundsTotal}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: FcmColors.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      children: [
                        Container(color: Colors.white.withValues(alpha: 0.10)),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: progress),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (context, f, _) => FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: f,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: FcmColors.goldGradient,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Next fixture card (GDD 9.2) or season controls.
        if (!summary.isCompleted && next != null)
          FcmEntrance(
            index: 1,
            child: FcmPanel(
              accent: FcmColors.gold,
              glow: true,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Next fixture · round ${next.round}',
                          style: const TextStyle(
                            color: FcmColors.gold,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      FcmPill(
                        next.isHome ? 'HOME' : 'AWAY',
                        color: next.isHome
                            ? FcmColors.success
                            : FcmColors.bronze,
                        filled: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // The opponent's crest and name (home/away already
                  // shown in the card's top-end pill) with their
                  // current table position as #N — one shrinking line
                  // so long club names never overflow.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (opponentCrest != null) ...[
                          FcmCrest(spec: opponentCrest, width: 22),
                          const SizedBox(width: 7),
                        ],
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: next.opponentName,
                              ),
                              if (opponentPos != null)
                                TextSpan(
                                  text: '  ·  #$opponentPos',
                                  style: const TextStyle(
                                    color: FcmColors.goldSoft,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Every fixture is played as a live matchday; the round's
                  // AI fixtures resolve automatically in lockstep when the
                  // result commits (GDD 9.2), so there is no sim-rest.
                  FcmButton(
                    onPressed: _busy ? null : _playNextFixture,
                    compact: true,
                    icon: Icons.play_arrow_rounded,
                    label: AppLocalizations.of(context)!.playMatch,
                  ),
                ],
              ),
            ),
          ),
        if (!summary.isCompleted && next == null)
          FcmEntrance(
            index: 1,
            child: FcmPanel(
              accent: FcmColors.gold,
              child: FcmButton(
                onPressed: _busy ? null : _maybeCompleteSeason,
                loading: _busy,
                icon: Icons.emoji_events,
                label: AppLocalizations.of(context)!.completeSeason,
              ),
            ),
          ),
        if (summary.isCompleted)
          FcmEntrance(
            index: 1,
            child: FcmPanel(
              accent: FcmColors.gold,
              glow: true,
              child: FcmButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                        (store) => store.startNextSeason(
                          ref.read(collectionStoreProvider).value!,
                        ),
                      ),
                loading: _busy,
                icon: Icons.flag_rounded,
                label:
                    'Start season in division ${summary.outcome == 'promoted'
                        ? summary.division + 1
                        : summary.outcome == 'relegated'
                        ? (summary.division > 1 ? summary.division - 1 : 1)
                        : summary.division}',
              ),
            ),
          ),

        // Standings (GDD 9.3).
        const FcmSectionTitle('Standings'),
        if (standings == null || standings.isEmpty)
          const FcmPanel(
            child: Text(
              'No matches played yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: FcmColors.textDim),
            ),
          )
        else
          FcmPanel(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 4, 14, 8),
                  child: Row(
                    children: [
                      SizedBox(width: 34, child: _Hdr('#')),
                      SizedBox(width: 30),
                      Expanded(child: _Hdr('Club')),
                      SizedBox(width: 34, child: _Hdr('P', end: true)),
                      SizedBox(width: 38, child: _Hdr('GD', end: true)),
                      SizedBox(width: 40, child: _Hdr('Pts', end: true)),
                    ],
                  ),
                ),
                for (final e in standings)
                  FcmEntrance(
                    index: e.position,
                    dx: 16,
                    dy: 0,
                    stagger: const Duration(milliseconds: 35),
                    maxStaggered: 12,
                    child: _StandingRow(
                      entry: e,
                      crest: crests[e.clubId],
                      isUser: clubName != null && e.name == clubName,
                    ),
                  ),
              ],
            ),
          ),

        // T-0130: the season's statistical leaders under the table —
        // the golden boot, playmaker, best-rated and clean-sheet races.
        // T-0148: each row also carries the player's club crest and
        // name, resolved from the same standings/crest maps the table
        // above already watches.
        _SeasonLeaderboards(
          clubName: clubName,
          standings: standings ?? const <StandingEntry>[],
          crests: crests,
        ),
      ],
    );
  }
}

/// The season's statistical leaderboards (T-0130): top-3 per category
/// under the standings table, every number accumulated from the SAME
/// MatchEvents the ratings derive from (schema v18, GDD 26.4 — never
/// side calculations). Hidden entirely until the first match commits
/// stats (no empty placeholders). T-0148: every row shows the player's
/// club crest and name next to the player name (owner request
/// 2026-11-14) — the club maps come from the standings the table above
/// already loaded, so no extra queries.
class _SeasonLeaderboards extends ConsumerWidget {
  const _SeasonLeaderboards({
    this.clubName,
    this.standings = const <StandingEntry>[],
    this.crests = const <int, CrestSpec>{},
  });

  /// The user's club name — kept for the follow-up that marks the
  /// user's own players in gold (needs the club-id mapping).
  final String? clubName;

  /// The season's standings — club names by [StandingEntry.clubId].
  final List<StandingEntry> standings;

  /// Club crests by club id (null while loading; the row keeps a fixed
  /// slot so nothing shifts when they land).
  final Map<int, CrestSpec> crests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(playerSeasonStatsProvider).valueOrNull;
    if (stats == null || stats.isEmpty) return const SizedBox.shrink();

    // Club identity by club id (T-0148): name from the standings, crest
    // from the shared map. A club missing from both falls back to a
    // bare dash so the row still renders aligned.
    final clubNames = {
      for (final e in standings) e.clubId: e.name,
    };
    (String, CrestSpec?) clubOf(int clubId) =>
        (clubNames[clubId] ?? '-', crests[clubId]);

    // Player boards — the standard award set. Minimum appearances gate
    // the average-rating board so one great match cannot top it.
    List<PlayerSeasonStat> topBy(
      int Function(PlayerSeasonStat) of,
    ) => (stats.toList()..sort((a, b) => of(b).compareTo(of(a))))
        .take(3)
        .toList();
    final scorers = topBy((s) => s.goals).where((s) => s.goals > 0).toList();
    final playmakers = topBy((s) => s.assists)
        .where((s) => s.assists > 0)
        .toList();
    final rated = (stats.where((s) => s.appearances >= 3).toList()
          ..sort(
            (a, b) => (b.ratingSum / b.appearances)
                .compareTo(a.ratingSum / a.appearances),
          ))
        .take(3)
        .toList();
    final keepers = (stats
            .where((s) => s.position == 'GK' && s.cleanSheets > 0)
            .toList()
          ..sort((a, b) => b.cleanSheets.compareTo(a.cleanSheets)))
        .take(3);

    if (scorers.isEmpty &&
        playmakers.isEmpty &&
        rated.isEmpty &&
        keepers.isEmpty) {
      return const SizedBox.shrink();
    }

    // T-0139: the leaderboards' headings render localized (EN/AR)
    // from the ARB catalogue.
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        FcmSectionTitle(l10n.seasonLeadersTitle),
        _LeaderboardPanel(
          icon: Icons.sports_soccer_rounded,
          title: l10n.seasonLeadersGoals,
          rows: [
            for (final s in scorers)
              (s.playerName, '${s.goals}', clubOf(s.clubId)),
          ],
        ),
        if (playmakers.isNotEmpty) ...[
          const SizedBox(height: 12),
          _LeaderboardPanel(
            icon: Icons.auto_awesome_rounded,
            title: l10n.seasonLeadersAssists,
            rows: [
              for (final s in playmakers)
                (s.playerName, '${s.assists}', clubOf(s.clubId)),
            ],
          ),
        ],
        if (rated.isNotEmpty) ...[
          const SizedBox(height: 12),
          _LeaderboardPanel(
            icon: Icons.star_rounded,
            title: l10n.seasonLeadersRating,
            rows: [
              for (final s in rated)
                (
                  s.playerName,
                  (s.ratingSum / s.appearances).toStringAsFixed(2),
                  clubOf(s.clubId),
                ),
            ],
          ),
        ],
        if (keepers.isNotEmpty) ...[
          const SizedBox(height: 12),
          _LeaderboardPanel(
            icon: Icons.front_hand_rounded,
            title: l10n.seasonLeadersCleanSheets,
            rows: [
              for (final s in keepers)
                (s.playerName, '${s.cleanSheets}', clubOf(s.clubId)),
            ],
          ),
        ],
      ],
    );
  }
}

/// One leaderboard panel: icon + title header, top-3 rows. Each row
/// (T-0148): rank, player name with the club crest and club name
/// beneath it, then the stat value.
class _LeaderboardPanel extends StatelessWidget {
  const _LeaderboardPanel({
    required this.icon,
    required this.title,
    required this.rows,
  });

  final IconData icon;
  final String title;

  /// (name, value, (clubName, crest)) triples.
  final List<(String, String, (String, CrestSpec?))> rows;

  @override
  Widget build(BuildContext context) {
    return FcmPanel(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: FcmColors.gold),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: FcmColors.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final (i, (name, value, club)) in rows.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: FcmColors.textDim,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Fixed crest slot: an empty SizedBox while the crest
                  // map loads so rows never shift when it lands.
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: club.$2 == null
                        ? null
                        : FcmCrest(spec: club.$2!, width: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          club.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FcmColors.textDim,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: FcmColors.goldSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Hdr extends StatelessWidget {
  const _Hdr(this.text, {this.end = false});

  final String text;
  final bool end;

  @override
  Widget build(BuildContext context) => FitText(
    text.toUpperCase(),
    align: end ? Alignment.centerRight : Alignment.centerLeft,
    style: const TextStyle(
      color: FcmColors.textDim,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    ),
  );
}

/// One table row: zone-coloured position badge, club, played, GD, points.
class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.entry,
    required this.isUser,
    this.crest,
  });

  final StandingEntry entry;

  /// The club's crest; null while the crest map loads (the column then
  /// holds an empty slot so rows never shift).
  final CrestSpec? crest;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final pos = e.position;
    final zone = pos <= 3
        ? FcmColors.success
        : (pos > 17 ? FcmColors.danger : Colors.transparent);
    final gd = e.goalDifference;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isUser ? FcmColors.gold.withValues(alpha: 0.14) : null,
        border: isUser
            ? Border.all(color: FcmColors.gold.withValues(alpha: 0.6))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 22,
                  decoration: BoxDecoration(
                    color: zone,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FitText(
                    '$pos',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 30,
            child: crest == null
                ? null
                : Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FcmCrest(spec: crest!, width: 24),
                  ),
          ),
          Expanded(
            child: FitText(
              e.name,
              style: TextStyle(
                color: isUser ? FcmColors.gold : Colors.white,
                fontWeight: isUser ? FontWeight.w900 : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: FitText(
              '${e.played}',
              align: Alignment.centerRight,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          SizedBox(
            width: 38,
            child: FitText(
              gd >= 0 ? '+$gd' : '$gd',
              align: Alignment.centerRight,
              style: TextStyle(
                color: gd > 0
                    ? FcmColors.success
                    : (gd < 0 ? FcmColors.danger : Colors.white70),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: FitText(
              '${e.points}',
              align: Alignment.centerRight,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
