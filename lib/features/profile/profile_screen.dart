/// FCM Rivals — the Profile tab (T-0111, GDD 26, 2026-11-13
/// redesign): the manager's career card, one glance.
///
/// The redesign's three acts, top to bottom:
///
///  1. THE MANAGER CARD — a hero identity plate: the crest on a
///     lit stage, club + coach + founded date + the equipped title
///     chip, and a RIGHT-EDGE ribbon of the two career headline
///     numbers (seasons, trophies) so the identity is never
///     text-only.
///  2. THE RECORD — the W/D/L split as ONE segmented bar (win rate
///     reads from its length, no math needed), then the stat grid:
///     a hero win-rate ring beside the two streak records, and the
///     counting stats (goals, clean sheets, matches) as compact
///     tiles. Numbers lead, labels whisper.
///  3. THE LEGACY — silverware as a trophy shelf (count + one
///     plate per division), the season history timeline, then the
///     title/badge showcase.
///
/// Every number still COMPOSES from T-0107's one derivation — the
/// screen never re-queries. All copy is localized (EN/AR) with
/// RTL-correct layouts (AlignmentDirectional, Row-reversal safe).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/crest.dart';
import '../../core/ui/fcm_crest.dart';
import '../../core/ui/fcm_panel.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/scene_loading.dart';
import '../../l10n/l10n_context.dart';
import '../achievements/achievements_providers.dart'
    show careerMetricsProvider;
import 'profile_providers.dart';
import 'title_badge_showcase.dart';

/// The Profile tab screen.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club = ref.watch(profileClubProvider);
    final metrics = ref.watch(careerMetricsProvider);

    return metrics.when(
      loading: () => const SceneLoadingMarker(),
      error: (e, _) => Center(child: Text('$e')),
      data: (m) => club.when(
        loading: () => const SceneLoadingMarker(),
        error: (e, _) => Center(child: Text('$e')),
        data: (clubRow) => CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              sliver: SliverToBoxAdapter(
                child: RepaintBoundary(
                  child: _ManagerCard(
                    clubName: clubRow?.name,
                    coachName: clubRow?.managerName,
                    crestEncoded: clubRow?.crest,
                    crestIndex: clubRow?.crestIndex ?? 0,
                    joinedAt: m.joinedAt,
                    seasons: m.seasonsCompleted,
                    trophies: m.titlesByDivisionTotal,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              sliver: SliverToBoxAdapter(
                child: RepaintBoundary(child: _CareerRecord(metrics: m)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              sliver: SliverToBoxAdapter(child: _Silverware(metrics: m)),
            ),
            const _SeasonHistory(),
            const TitleBadgeShowcase(),
            const SliverPadding(
              padding: EdgeInsets.only(bottom: 24),
              sliver: SliverToBoxAdapter(child: SizedBox(height: 8)),
            ),
          ],
        ),
      ),
    );
  }
}

/// ACT 1 — the manager card: crest on a lit stage, identity block,
/// and a headline-figures ribbon on the trailing edge (seasons and
/// trophies: the two numbers a manager brags with).
class _ManagerCard extends StatelessWidget {
  const _ManagerCard({
    required this.clubName,
    required this.coachName,
    required this.crestEncoded,
    required this.crestIndex,
    required this.joinedAt,
    required this.seasons,
    required this.trophies,
  });

  final String? clubName;
  final String? coachName;
  final String? crestEncoded;
  final int crestIndex;
  final DateTime? joinedAt;
  final int seasons;
  final int trophies;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final spec = CrestSpec.fromJsonString(crestEncoded) ??
        CrestSpec.legacy(crestIndex);
    final joined = joinedAt;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FcmColors.surfaceHigh,
            FcmColors.night.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: FcmColors.gold.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: FcmColors.gold.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The crest's stage: a soft gold pool under it, the plate
          // clipped to a squircle so the crest feels mounted, not
          // floating.
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  FcmColors.gold.withValues(alpha: 0.14),
                  FcmColors.surface.withValues(alpha: 0.0),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: FcmCrest(spec: spec, width: 64),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clubName ?? l10n.profileUnsetClub,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  coachName ?? l10n.profileUnsetName,
                  style: TextStyle(
                    color: FcmColors.goldSoft.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                const EquippedTitleChip(compact: true),
                if (joined != null) ...[
                  const SizedBox(height: 8),
                  // The founded row can exceed the narrow RTL column
                  // (Arabic label + digits) — FittedBox shrink instead
                  // of a hard min-size Row (the column is unbounded,
                  // so Flexible is wrong here).
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: FcmColors.textDim.withValues(alpha: 0.7),
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${l10n.profileFounded}: '
                          '${joined.year}-${joined.month.toString().padLeft(2, '0')}-${joined.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: FcmColors.textDim,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // The headline ribbon: seasons + trophies stacked on the
          // trailing edge — the manager's bragging numbers sit with
          // the identity, not buried in a grid.
          _HeadlineFigure(
            value: '$seasons',
            label: l10n.profileHeadlineSeasons,
            icon: Icons.stadium_rounded,
          ),
          const SizedBox(height: 14),
          const _HeadlineDivider(),
          const SizedBox(height: 14),
          _HeadlineFigure(
            value: '$trophies',
            label: l10n.profileHeadlineTrophies,
            icon: Icons.emoji_events_rounded,
            gold: true,
          ),
        ],
      ),
    );
  }
}

/// The vertical ribbon divider between the two headline figures.
class _HeadlineDivider extends StatelessWidget {
  const _HeadlineDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: FcmColors.bronze.withValues(alpha: 0.35),
    );
  }
}

/// One headline figure: big number, tiny icon + label under it.
/// The `gold` flag lights the number gold (trophies earn it).
class _HeadlineFigure extends StatelessWidget {
  const _HeadlineFigure({
    required this.value,
    required this.label,
    required this.icon,
    this.gold = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final color = gold ? FcmColors.gold : FcmColors.silver;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Icon(icon, size: 12, color: color.withValues(alpha: 0.8)),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: FcmColors.textDim,
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

/// ACT 2 — the career record. One segmented W/D/L bar (the win-rate
/// is the GREEN share's length — readable without math), the win
/// rate called out beside it, then the stat grid.
class _CareerRecord extends StatelessWidget {
  const _CareerRecord({required this.metrics});

  final CareerMetricsView metrics;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final matches = metrics.matchesManaged;
    final hasMatches = matches > 0;
    final winRateVal = hasMatches
        ? double.parse(((metrics.wins / matches) * 100).toStringAsFixed(1))
        : 0.0;

    return FcmPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bar_chart_rounded,
                color: FcmColors.goldSoft,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.profileStatsSectionTitle,
                style: const TextStyle(
                  color: FcmColors.goldSoft,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // The W/D/L split bar: one rounded track, three segments.
          // Heights equal, colors semantic (green/dim/red) — the
          // proportions ARE the story.
          _RecordBar(
            wins: metrics.wins,
            draws: metrics.draws,
            losses: metrics.losses,
          ),
          const SizedBox(height: 6),
          // The legend row doubles as exact counts.
          Row(
            children: [
              _RecordLegendSwatch(
                color: FcmColors.success,
                label: '${l10n.profileStatWins} ${metrics.wins}',
              ),
              const SizedBox(width: 10),
              _RecordLegendSwatch(
                color: FcmColors.silver.withValues(alpha: 0.5),
                label: '${l10n.profileStatDraws} ${metrics.draws}',
              ),
              const SizedBox(width: 10),
              _RecordLegendSwatch(
                color: FcmColors.danger,
                label: '${l10n.profileStatLosses} ${metrics.losses}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Hero row: the win-rate number large beside the two
          // streak records — form stories before counting stats.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _WinRateDial(
                percent: hasMatches ? winRateVal : 0,
                hasMatches: hasMatches,
                fallback: l10n.profileNoMatches,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _StreakTile(
                      label: l10n.profileStatWinStreak,
                      value: '${metrics.longestWinStreak}',
                      icon: Icons.local_fire_department_rounded,
                    ),
                    const SizedBox(height: 6),
                    _StreakTile(
                      label: l10n.profileStatUnbeaten,
                      value: '${metrics.longestUnbeatenStreak}',
                      icon: Icons.shield_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // The counting stats: two rows of three compact tiles.
          Row(
            children: [
              Expanded(
                child: _CountTile(
                  label: l10n.profileStatMatches,
                  value: '$matches',
                  icon: Icons.sports_soccer_rounded,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CountTile(
                  label: l10n.profileStatGoalsFor,
                  value: '${metrics.goalsFor}',
                  icon: Icons.sports_score_rounded,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CountTile(
                  label: l10n.profileStatGoalsAgainst,
                  value: '${metrics.goalsAgainst}',
                  icon: Icons.shield_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _CountTile(
                  label: l10n.profileStatCleanSheets,
                  value: '${metrics.cleanSheets}',
                  icon: Icons.security_rounded,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CountTile(
                  label: l10n.profileStatWinStreak,
                  value: '${metrics.longestWinStreak}',
                  icon: Icons.bolt_rounded,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CountTile(
                  label: l10n.profileStatUnbeaten,
                  value: '${metrics.longestUnbeatenStreak}',
                  icon: Icons.verified_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The segmented W/D/L bar: one rounded track split by proportion.
/// Empty record (0 matches) renders the neutral track alone — no
/// fake zero-width segments, no NaN.
class _RecordBar extends StatelessWidget {
  const _RecordBar({
    required this.wins,
    required this.draws,
    required this.losses,
  });

  final int wins;
  final int draws;
  final int losses;

  @override
  Widget build(BuildContext context) {
    final total = wins + draws + losses;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: total == 0
            ? Container(
                color: Colors.white.withValues(alpha: 0.08),
              )
            : Row(
                children: [
                  Flexible(
                    flex: wins,
                    child: Container(color: FcmColors.success),
                  ),
                  Flexible(
                    flex: draws,
                    child: Container(
                      color: FcmColors.silver.withValues(alpha: 0.45),
                    ),
                  ),
                  Flexible(
                    flex: losses,
                    child: Container(color: FcmColors.danger),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A legend swatch: colored dot + label. 8px dot for glancability.
class _RecordLegendSwatch extends StatelessWidget {
  const _RecordLegendSwatch({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: FcmColors.textDim,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// The win-rate dial: a 64px ring with the percent inside — the ONE
/// number managers quote first. The ring sweeps gold.
class _WinRateDial extends StatelessWidget {
  const _WinRateDial({
    required this.percent,
    required this.hasMatches,
    required this.fallback,
  });

  final double percent;
  final bool hasMatches;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              value: hasMatches ? (percent / 100).clamp(0.0, 1.0) : 0,
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              color: FcmColors.gold,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasMatches ? l10n.profilePercent(percent) : fallback,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
                  height: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                l10n.profileStatWinRate,
                style: const TextStyle(
                  color: FcmColors.textDim,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One streak record: a fire/shield chip with the number leading.
class _StreakTile extends StatelessWidget {
  const _StreakTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: FcmColors.night.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: FcmColors.gold.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: FcmColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: FcmColors.goldSoft,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FcmColors.textDim,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
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

/// One compact counting-stat tile.
class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: FcmColors.night.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: FcmColors.silver.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: FcmColors.goldSoft),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: FcmColors.goldSoft,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FcmColors.textDim,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// ACT 3 — silverware as a trophy shelf: the count leads, one gold
/// plate per division beneath.
class _Silverware extends StatelessWidget {
  const _Silverware({required this.metrics});

  final CareerMetricsView metrics;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final titles = metrics.titlesByDivision;
    final total = metrics.titlesByDivisionTotal;

    return FcmPanel(
      accent: total > 0 ? FcmColors.gold : null,
      glow: total > 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (total > 0 ? FcmColors.gold : FcmColors.textDim)
                      .withValues(alpha: 0.15),
                ),
                child: Icon(
                  Icons.emoji_events_rounded,
                  color: total > 0 ? FcmColors.gold : FcmColors.textDim,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.profileSilverwareTitle,
                      style: const TextStyle(
                        color: FcmColors.goldSoft,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      total > 0
                          ? l10n.profileTitlesCount(total)
                          : l10n.profileNoTitles,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (titles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final div in (titles.keys.toList()..sort()))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: FcmColors.gold.withValues(alpha: 0.6),
                      ),
                      gradient: LinearGradient(
                        colors: [
                          FcmColors.gold.withValues(alpha: 0.18),
                          FcmColors.gold.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                    child: Text(
                      l10n.profileDivisionPlate(div, titles[div]!),
                      style: const TextStyle(
                        color: FcmColors.goldSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The season history timeline: newest season first, one row per
/// completed season, forever.
class _SeasonHistory extends ConsumerWidget {
  const _SeasonHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = l10nOf(context);
    final seasons = ref.watch(seasonHistoryProvider);

    return seasons.when(
      loading: () => const SliverToBoxAdapter(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('$e'))),
      data: (rows) => SliverMainAxisGroup(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
            sliver: SliverToBoxAdapter(
              child: Text(
                l10n.profileSeasonHistory.toUpperCase(),
                style: const TextStyle(
                  color: FcmColors.goldSoft,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          if (rows.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              sliver: SliverToBoxAdapter(
                child: FcmPanel(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: FcmColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: FcmColors.silver.withValues(alpha: 0.15),
                            ),
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            color: FcmColors.textDim,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            l10n.profileNoSeasons,
                            style: const TextStyle(
                              color: FcmColors.textDim,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              sliver: SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SeasonRow(season: rows[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One season row: the ordinal badge on the start edge, division +
/// final position, and the outcome pill on the end edge. Champions'
/// rows carry the gold accent.
class _SeasonRow extends StatelessWidget {
  const _SeasonRow({required this.season});

  final SeasonHistoryRow season;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final (outcomeLabel, outcomeColor, outcomeIcon) = switch (season.outcome) {
      'promoted' => (
        l10n.profileOutcomePromoted,
        FcmColors.success,
        Icons.trending_up_rounded,
      ),
      'relegated' => (
        l10n.profileOutcomeRelegated,
        FcmColors.danger,
        Icons.trending_down_rounded,
      ),
      _ => (
        l10n.profileOutcomeStayed,
        FcmColors.textDim,
        Icons.trending_flat_rounded,
      ),
    };
    final champion = season.finalPosition == 1;

    return FcmPanel(
      accent: champion ? FcmColors.gold : null,
      child: Row(
        children: [
          // The season ordinal in a squircle plate — the timeline's
          // node. Champions get the gold treatment.
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: champion
                  ? FcmColors.goldGradient
                  : null,
              color: champion
                  ? null
                  : FcmColors.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: champion
                  ? null
                  : Border.all(
                      color: FcmColors.silver.withValues(alpha: 0.15),
                    ),
            ),
            child: Text(
              '${season.ordinal}',
              style: TextStyle(
                color: champion ? FcmColors.ink : FcmColors.silver,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.profileSeasonTitle(season.ordinal, season.division),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                // The final-position row can exceed the narrow RTL
                // column (Arabic label + digits) — FittedBox shrink
                // instead of a hard min-size Row (the column is
                // unbounded vertically, so Flexible is wrong here).
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        champion
                            ? Icons.emoji_events_rounded
                            : Icons.flag_rounded,
                        size: 12,
                        color: champion
                            ? FcmColors.gold
                            : FcmColors.textDim.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.profileFinalPosition(season.finalPosition ?? 0),
                        style: const TextStyle(
                          color: FcmColors.textDim,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: outcomeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: outcomeColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(outcomeIcon, color: outcomeColor, size: 14),
                const SizedBox(width: 4),
                Text(
                  outcomeLabel,
                  style: TextStyle(
                    color: outcomeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
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
