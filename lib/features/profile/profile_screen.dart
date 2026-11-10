/// FCM Rivals — the Profile tab (T-0111, GDD 26): the manager's career
/// card — who am I as a manager, one glance.
///
/// Identity (crest + club + coach + joined date + the equipped title
/// chip, empty-safe), the career stat panel (matches, W/D/L, win rate,
/// goals, clean sheets, streak records), silverware (titles grouped by
/// division) and the season history list (ordinal, division, final
/// position, outcome in the standings' colour language). Every number
/// COMPOSES from T-0107's one derivation — the screen never re-queries
/// (a missing stat is a derivation change, not a private query).
///
/// The career grows forever: the history is sliver-based (60fps at any
/// depth), the header and stat panel live in RepaintBoundarys (the
/// ambient animation's hot-path isolation). RTL mirrors through
/// directional insets; numbers format locale-aware (win rate one
/// decimal, percent through the locale — never a hardcoded '%').
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/crest.dart';
import '../../core/ui/fcm_crest.dart';
import '../../core/ui/fcm_panel.dart';
import '../../core/ui/fcm_style.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_context.dart';
import '../achievements/achievements_providers.dart'
    show careerMetricsProvider, equippedTitleProvider;
import 'profile_providers.dart';

/// The Profile tab screen.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club = ref.watch(profileClubProvider);
    final metrics = ref.watch(careerMetricsProvider);
    final equipped = ref.watch(equippedTitleProvider);

    return metrics.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (m) => club.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (clubRow) => CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              sliver: SliverToBoxAdapter(
                // The identity header: static after load — isolate it.
                child: RepaintBoundary(
                  child: _IdentityHeader(
                    clubName: clubRow?.name,
                    coachName: clubRow?.managerName,
                    crestEncoded: clubRow?.crest,
                    crestIndex: clubRow?.crestIndex ?? 0,
                    joinedAt: m.joinedAt,
                    equippedTitleId: equipped.valueOrNull,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              sliver: SliverToBoxAdapter(
                // The stat panel: numbers that never move while
                // browsing — isolate the painters.
                child: RepaintBoundary(child: _StatPanel(metrics: m)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              sliver: SliverToBoxAdapter(
                child: _Silverware(metrics: m),
              ),
            ),
            // The history: grows forever — sliver list, 60fps at any
            // career depth.
            const _SeasonHistory(),
            // Bottom breathing room above the nav bar.
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

/// The identity header: crest, names, joined date, equipped title.
class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({
    required this.clubName,
    required this.coachName,
    required this.crestEncoded,
    required this.crestIndex,
    required this.joinedAt,
    required this.equippedTitleId,
  });

  final String? clubName;
  final String? coachName;
  final String? crestEncoded;
  final int crestIndex;
  final DateTime? joinedAt;
  final String? equippedTitleId;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final spec = CrestSpec.fromJsonString(crestEncoded) ??
        CrestSpec.legacy(crestIndex);
    final joined = joinedAt;

    return FcmPanel(
      child: Row(
        children: [
          FcmCrest(spec: spec, width: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coachName ?? l10n.profileUnsetName,
                  style: const TextStyle(
                    color: FcmColors.goldSoft,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  clubName ?? l10n.profileUnsetClub,
                  style: const TextStyle(
                    color: FcmColors.textDim,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (equippedTitleId != null) ...[
                      _TitleChip(l10n: l10n, titleId: equippedTitleId!),
                      const SizedBox(width: 8),
                    ],
                    if (joined != null)
                      Icon(
                        Icons.cake_rounded,
                        color: FcmColors.textDim.withValues(alpha: 0.7),
                        size: 14,
                      ),
                    if (joined != null) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          l10n.profileJoined(
                            joined.year,
                            joined.month,
                            joined.day,
                          ),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FcmColors.textDim,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The equipped-title chip (T-0112 owns the equip flow; this renders
/// whatever is equipped — empty-safe by never building).
class _TitleChip extends StatelessWidget {
  const _TitleChip({required this.l10n, required this.titleId});

  final AppLocalizations l10n;
  final String titleId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FcmColors.gold.withValues(alpha: 0.6)),
        gradient: FcmColors.goldGradient,
      ),
      child: Text(
        _resolveTitle(l10n, titleId),
        style: const TextStyle(
          color: FcmColors.ink,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _resolveTitle(AppLocalizations l10n, String titleId) {
  // Same registry the achievements screen reads (T-0112 hardens the
  // unknown-id fallback for the showcase; here the chip renders the
  // localized string or the raw id — never a crash).
  return switch (titleId) {
    'career_wins-title1' => l10n.achTitleCareerWins1,
    'career_wins-title2' => l10n.achTitleCareerWins2,
    'career_unbeaten_streak-title1' => l10n.achTitleUnbeaten1,
    'career_unbeaten_streak-title2' => l10n.achTitleUnbeaten2,
    'attack_goals-title1' => l10n.achTitleGoals1,
    'attack_goals-title2' => l10n.achTitleGoals2,
    'defence_clean_sheets-title1' => l10n.achTitleCleanSheets1,
    'defence_clean_sheets-title2' => l10n.achTitleCleanSheets2,
    'silverware_titles-title1' => l10n.achTitleTitles1,
    'silverware_titles-title2' => l10n.achTitleTitles2,
    'squad_legendaries-title1' => l10n.achTitleLegendaries1,
    'squad_legendaries-title2' => l10n.achTitleLegendaries2,
    'packs_opened-title1' => l10n.achTitlePacks1,
    'packs_opened-title2' => l10n.achTitlePacks2,
    'economy_lifetime_earned-title1' => l10n.achTitleCoins1,
    'economy_lifetime_earned-title2' => l10n.achTitleCoins2,
    'loyalty_seasons-title1' => l10n.achTitleSeasons1,
    'loyalty_seasons-title2' => l10n.achTitleSeasons2,
    'mastermind_tactics_changed-title1' => l10n.achTitleMastermind1,
    'mastermind_tactics_changed-title2' => l10n.achTitleMastermind2,
    _ => titleId,
  };
}

/// The career stat panel: the numbers the owner listed.
class _StatPanel extends StatelessWidget {
  const _StatPanel({required this.metrics});

  final CareerMetricsView metrics;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final matches = metrics.matchesManaged;
    // Win rate: locale-aware, one decimal, no hardcoded '%' — the
    // fresh save shows the inviting zero copy, never NaN.
    final hasMatches = matches > 0;
    final winRate = hasMatches ? metrics.wins / matches : 0.0;

    return FcmPanel(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: l10n.profileStatMatches,
                  value: _fmt(context, matches),
                ),
              ),
              Expanded(
                child: _StatTile(
                  label: l10n.profileStatWinRate,
                  value: hasMatches
                      ? l10n.profilePercent(winRate * 100)
                      : l10n.profileNoMatches,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: l10n.profileStatWins,
                  value: _fmt(context, metrics.wins),
                  accent: FcmColors.success,
                ),
              ),
              Expanded(
                child: _StatTile(
                  label: l10n.profileStatDraws,
                  value: _fmt(context, metrics.draws),
                ),
              ),
              Expanded(
                child: _StatTile(
                  label: l10n.profileStatLosses,
                  value: _fmt(context, metrics.losses),
                  accent: FcmColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: l10n.profileStatGoalsFor,
                  value: _fmt(context, metrics.goalsFor),
                ),
              ),
              Expanded(
                child: _StatTile(
                  label: l10n.profileStatGoalsAgainst,
                  value: _fmt(context, metrics.goalsAgainst),
                ),
              ),
              Expanded(
                child: _StatTile(
                  label: l10n.profileStatCleanSheets,
                  value: _fmt(context, metrics.cleanSheets),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: l10n.profileStatWinStreak,
                  value: _fmt(context, metrics.longestWinStreak),
                ),
              ),
              Expanded(
                child: _StatTile(
                  label: l10n.profileStatUnbeaten,
                  value: _fmt(context, metrics.longestUnbeatenStreak),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(BuildContext context, int v) {
    // The HUD convention: Western digits for values, the locale owns
    // the wording — NumberFormat through the l10n's own helpers when
    // the repo gains one; today the plain readout (matches the
    // coin chip's digits).
    return '$v';
  }
}

/// One stat tile.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.accent,
  });

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: accent ?? FcmColors.goldSoft,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: FcmColors.textDim,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
              Icon(
                Icons.emoji_events_rounded,
                color: total > 0 ? FcmColors.gold : FcmColors.textDim,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  total > 0
                      ? l10n.profileTitlesCount(total)
                      : l10n.profileNoTitles,
                  style: const TextStyle(
                    color: FcmColors.goldSoft,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (titles.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Sorted by division: the career's reading order.
                for (final div in (titles.keys.toList()..sort()))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: FcmColors.gold.withValues(alpha: 0.55),
                      ),
                      color: FcmColors.gold.withValues(alpha: 0.10),
                    ),
                    child: Text(
                      l10n.profileDivisionPlate(div, titles[div]!),
                      style: const TextStyle(
                        color: FcmColors.goldSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
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
                l10n.profileSeasonHistory,
                style: const TextStyle(
                  color: FcmColors.goldSoft,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (rows.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              sliver: SliverToBoxAdapter(
                child: FcmPanel(
                  child: Text(
                    l10n.profileNoSeasons,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: FcmColors.textDim,
                      fontSize: 12,
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

/// One season row: ordinal, division, final position, outcome — the
/// standings' colour language (green promoted / red relegated).
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.profileSeasonTitle(season.ordinal, season.division),
                  style: const TextStyle(
                    color: FcmColors.goldSoft,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.profileFinalPosition(season.finalPosition ?? 0),
                  style: const TextStyle(
                    color: FcmColors.textDim,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(outcomeIcon, color: outcomeColor, size: 18),
          const SizedBox(width: 6),
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
    );
  }
}
