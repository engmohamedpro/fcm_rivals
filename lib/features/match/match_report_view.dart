/// FCM Rivals — post-match report view (extracted from
/// `match_screen.dart`, app-structure review task
/// `2026-11-05_app-structure_split-match-screen-report`): the report
/// screen with the tabbed ratings panels, the momentum graph and the
/// touchline recovery options (pep talk / boosted recovery).
library;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../l10n/l10n_context.dart';
import 'live_match_views.dart';
import 'match_engine.dart';
import 'match_report.dart';
import 'match_session.dart';

/// Post-match report (GDD 14 post-match screen): result, reward, Man
/// of the Match, the full-match momentum flow and both squads' player
/// ratings in ONE tabbed panel — the user's XI opens first, the
/// opponent one tap away. The team-statistics table is gone — the
/// momentum graph (the same one the live match shows) tells how the
/// game flowed (T-0100: the pep-talk step is gone — full time lands
/// here directly); the screen ends with a CONTINUE button that closes
/// the match flow.
class MatchReportView extends StatefulWidget {
  const MatchReportView({
    super.key,
    required this.report,
    required this.homeTeamName,
    required this.awayTeamName,
    this.userSide,
    this.momentumSeries,
    this.userTeamColor = FcmColors.gold,
    required this.onContinue,
  });

  final MatchReportResult report;
  final String homeTeamName;
  final String awayTeamName;

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
                      // The injuries row (T-0056): who got hurt in numbers.
                      if (report.commentary.any((l) => l.kind == CommentaryKind.injury))
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.medical_services_outlined,
                              size: 14,
                              color: FcmColors.danger,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              l10nOf(context).reportInjuries(
                      report.commentary
                          .where((l) => l.kind == CommentaryKind.injury)
                          .length,
                    ),
                              style: const TextStyle(
                                color: FcmColors.danger,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
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
                      // Full time: the whole-match trend only — "who is on
                      // top right now" means nothing after the whistle.
                      live: false,
                      graphHeight: 56,
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
                      padding: const EdgeInsetsDirectional.only(start: 6),
                      child: Text(
                        '⚽ ×${r.goals}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  if (r.assists > 0)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 6),
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
