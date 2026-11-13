/// FCM Rivals — the Profile tab (T-0111, GDD 26): the manager's career
/// card — who am I as a manager, one glance.
///
/// Identity (crest + club + coach + joined date + the equipped title
/// chip, empty-safe), the career stat panel (matches, W/D/L, win rate,
/// goals, clean sheets, streak records), silverware (titles grouped by
/// division) and the season history list (ordinal, division, final
/// position, outcome in the standings' colour language). Every number
/// COMPOSES from T-0107's one derivation — the screen never re-queries.
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
                  child: _IdentityHeader(
                    clubName: clubRow?.name,
                    coachName: clubRow?.managerName,
                    crestEncoded: clubRow?.crest,
                    crestIndex: clubRow?.crestIndex ?? 0,
                    joinedAt: m.joinedAt,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              sliver: SliverToBoxAdapter(
                child: RepaintBoundary(child: _StatPanel(metrics: m)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              sliver: SliverToBoxAdapter(
                child: _Silverware(metrics: m),
              ),
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

/// The identity header: crest, names, joined date, equipped title with premium card styling.
class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({
    required this.clubName,
    required this.coachName,
    required this.crestEncoded,
    required this.crestIndex,
    required this.joinedAt,
  });

  final String? clubName;
  final String? coachName;
  final String? crestEncoded;
  final int crestIndex;
  final DateTime? joinedAt;

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
            FcmColors.surface,
            FcmColors.night.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: FcmColors.gold.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: FcmColors.gold.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          FcmCrest(spec: spec, width: 68),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clubName ?? l10n.profileUnsetClub,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
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
                const SizedBox(height: 6),
                const EquippedTitleChip(compact: true),
                if (joined != null) ...[
                  const SizedBox(height: 6),
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
                          'Founded: ${joined.year}-${joined.month.toString().padLeft(2, '0')}-${joined.day.toString().padLeft(2, '0')}',
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
        ],
      ),
    );
  }
}

/// The career stat panel with themed compact stat cards and icons.
class _StatPanel extends StatelessWidget {
  const _StatPanel({required this.metrics});

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
              const Icon(Icons.bar_chart_rounded, color: FcmColors.goldSoft, size: 16),
              const SizedBox(width: 8),
              const Text(
                'CAREER STATISTICS',
                style: TextStyle(
                  color: FcmColors.goldSoft,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: l10n.profileStatMatches,
                  value: '$matches',
                  icon: Icons.sports_soccer_rounded,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatTile(
                  label: l10n.profileStatWins,
                  value: '${metrics.wins}',
                  accent: FcmColors.success,
                  icon: Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatTile(
                  label: l10n.profileStatWinRate,
                  value: hasMatches
                      ? l10n.profilePercent(winRateVal)
                      : l10n.profileNoMatches,
                  icon: Icons.pie_chart_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: l10n.profileStatDraws,
                  value: '${metrics.draws}',
                  icon: Icons.drag_handle_rounded,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatTile(
                  label: l10n.profileStatLosses,
                  value: '${metrics.losses}',
                  accent: FcmColors.danger,
                  icon: Icons.trending_down_rounded,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatTile(
                  label: l10n.profileStatCleanSheets,
                  value: '${metrics.cleanSheets}',
                  icon: Icons.security_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: l10n.profileStatGoalsFor,
                  value: '${metrics.goalsFor}',
                  icon: Icons.sports_score_rounded,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatTile(
                  label: l10n.profileStatGoalsAgainst,
                  value: '${metrics.goalsAgainst}',
                  icon: Icons.shield_outlined,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatTile(
                  label: l10n.profileStatWinStreak,
                  value: '${metrics.longestWinStreak}',
                  icon: Icons.local_fire_department_rounded,
                  accent: FcmColors.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One compact stat tile with icon and card container.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.accent,
    this.icon,
  });

  final String label;
  final String value;
  final Color? accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: FcmColors.night.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (accent ?? FcmColors.silver).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: accent ?? FcmColors.goldSoft),
            const SizedBox(height: 2),
          ],
          Text(
            value,
            style: TextStyle(
              color: accent ?? FcmColors.goldSoft,
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

/// Silverware: the trophy count + per-division plates.
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (total > 0 ? FcmColors.gold : FcmColors.textDim).withValues(alpha: 0.15),
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
                      'SILVERWARE & TROPHIES',
                      style: TextStyle(
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

/// The season history: one row per completed season, forever.
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

/// One season row: ordinal, division, final position, outcome.
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

    return FcmPanel(
      accent: season.finalPosition == 1 ? FcmColors.gold : null,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (season.finalPosition == 1 ? FcmColors.gold : FcmColors.surface)
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              season.finalPosition == 1 ? Icons.emoji_events_rounded : Icons.sports_soccer_rounded,
              color: season.finalPosition == 1 ? FcmColors.gold : FcmColors.silver,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
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
