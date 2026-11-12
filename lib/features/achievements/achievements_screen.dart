/// FCM Rivals — the Achievements hub screen (T-0110, GDD 26).
///
/// REPLACES the Collection tab in-place (owner decision 2026-11-10:
/// the browsing grid moved to the Team tab's entry points; this is
/// where coins are WON). Structure: club header (crest + coach + the
/// equipped title when present — T-0112's column rendered
/// empty-safe), the overall completion ring (claimed / visible tiers),
/// then category sections in slivers — every tier row isolated in its
/// own RepaintBoundary (the always-on ambient animation makes every
/// rebuild hot; per-row painters stay cheap the way the store's foil
/// cells do).
///
/// The claim UX contract (T-0108 fixed it): unclaimed-eligible tiers
/// carry the claim action; claimed tiers render claimed FROM THE
/// CLAIMS TABLE (the live drift watch — no local flags); AlreadyClaimed
/// results re-render silently. Badges are painter-drawn tier metals;
/// progress bars are geometric-honest (`value / threshold` capped at
/// 1.0 — "9 / 16 wins").
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/fcm_coin.dart';
import '../../core/ui/fcm_panel.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_button.dart';
import '../../core/ui/scene_loading.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_context.dart';
import 'achievement_catalog.dart';
import 'achievement_catalog_data.dart';
import 'achievement_progress.dart' show CareerMetrics;
import 'achievements_badge_painter.dart';
import 'achievements_providers.dart';
import '../economy/streak_card.dart' show StreakCard;
import '../profile/title_badge_showcase.dart'
    show EquippedTitleChip;

/// The Achievements tab screen.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(careerMetricsProvider);
    final claims = ref.watch(claimsProvider);

    return metrics.when(
      loading: () => const SceneLoadingMarker(),
      error: (e, _) => Center(child: Text('$e')),
      data: (m) => claims.when(
        loading: () => const SceneLoadingMarker(),
        error: (e, _) => Center(child: Text('$e')),
        data: (claimed) => CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              sliver: SliverToBoxAdapter(
                child: _Header(
                  metrics: m,
                  claimedKeys: claimed,
                ),
              ),
            ),
            // The daily rewards streak — moved from the profile (the
            // achievements tab is the rewards hub now, so the claim
            // surface lives beside the claimable cards).
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(14, 6, 14, 0),
              sliver: SliverToBoxAdapter(
                child: RepaintBoundary(child: StreakCard()),
              ),
            ),
            ...[
              for (final category in AchievementCatalog.categories)
                _CategorySection(
                  category: category,
                  metrics: m,
                  claimedKeys: claimed,
                ),
            ],
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

// ---- l10n bridge --------------------------------------------------------
// The catalog carries key NAMES; AppLocalizations exposes getters. This
// static table bridges them — one line per key, no mirrors, no dynamic
// codegen. The catalog test's EN+AR completeness lock guarantees every
// key below exists as a generated getter in BOTH locales.

/// Invokes a no-arg getter by key name on the generated localization.
String? _call(AppLocalizations l10n, String key) {
  final m = _noArgGetters[key];
  return m == null ? null : m(l10n);
}

String _categoryText(AppLocalizations l10n, String prefix, String suffix) =>
    _call(l10n, '$prefix$suffix') ?? prefix;

String _defText(AppLocalizations l10n, String key) => _call(l10n, key) ?? key;

final Map<String, String Function(AppLocalizations)> _noArgGetters = () {
  final table = <String, String Function(AppLocalizations)>{};
  void add(String k, String Function(AppLocalizations) f) => table[k] = f;
  add('achCareerTitle', (l) => l.achCareerTitle);
  add('achCareerSubtitle', (l) => l.achCareerSubtitle);
  add('achAttackTitle', (l) => l.achAttackTitle);
  add('achAttackSubtitle', (l) => l.achAttackSubtitle);
  add('achDefenceTitle', (l) => l.achDefenceTitle);
  add('achDefenceSubtitle', (l) => l.achDefenceSubtitle);
  add('achSilverwareTitle', (l) => l.achSilverwareTitle);
  add('achSilverwareSubtitle', (l) => l.achSilverwareSubtitle);
  add('achSquadTitle', (l) => l.achSquadTitle);
  add('achSquadSubtitle', (l) => l.achSquadSubtitle);
  add('achPacksTitle', (l) => l.achPacksTitle);
  add('achPacksSubtitle', (l) => l.achPacksSubtitle);
  add('achEconomyTitle', (l) => l.achEconomyTitle);
  add('achEconomySubtitle', (l) => l.achEconomySubtitle);
  add('achCampusTitle', (l) => l.achCampusTitle);
  add('achCampusSubtitle', (l) => l.achCampusSubtitle);
  add('achLoyaltyTitle', (l) => l.achLoyaltyTitle);
  add('achLoyaltySubtitle', (l) => l.achLoyaltySubtitle);
  add('achMastermindTitle', (l) => l.achMastermindTitle);
  add('achMastermindSubtitle', (l) => l.achMastermindSubtitle);
  add('achAttackGoals', (l) => l.achAttackGoals);
  add('achAttackGoalsDesc', (l) => l.achAttackGoalsDesc);
  add('achAttackGoalsSingleMatch', (l) => l.achAttackGoalsSingleMatch);
  add('achAttackGoalsSingleMatchDesc', (l) => l.achAttackGoalsSingleMatchDesc);
  add('achCampusFacilityLevels', (l) => l.achCampusFacilityLevels);
  add('achCampusFacilityLevelsDesc', (l) => l.achCampusFacilityLevelsDesc);
  add('achCampusRecoveryLevel', (l) => l.achCampusRecoveryLevel);
  add('achCampusRecoveryLevelDesc', (l) => l.achCampusRecoveryLevelDesc);
  add('achCareerAwayMatches', (l) => l.achCareerAwayMatches);
  add('achCareerAwayMatchesDesc', (l) => l.achCareerAwayMatchesDesc);
  add('achCareerDraws', (l) => l.achCareerDraws);
  add('achCareerDrawsDesc', (l) => l.achCareerDrawsDesc);
  add('achCareerHomeMatches', (l) => l.achCareerHomeMatches);
  add('achCareerHomeMatchesDesc', (l) => l.achCareerHomeMatchesDesc);
  add('achCareerLosses', (l) => l.achCareerLosses);
  add('achCareerLossesDesc', (l) => l.achCareerLossesDesc);
  add('achCareerMatches', (l) => l.achCareerMatches);
  add('achCareerMatchesDesc', (l) => l.achCareerMatchesDesc);
  add('achCareerUnbeatenStreak', (l) => l.achCareerUnbeatenStreak);
  add('achCareerUnbeatenStreakDesc', (l) => l.achCareerUnbeatenStreakDesc);
  add('achCareerWinStreak', (l) => l.achCareerWinStreak);
  add('achCareerWinStreakDesc', (l) => l.achCareerWinStreakDesc);
  add('achCareerWins', (l) => l.achCareerWins);
  add('achCareerWinsDesc', (l) => l.achCareerWinsDesc);
  add('achDefenceCleanSheets', (l) => l.achDefenceCleanSheets);
  add('achDefenceCleanSheetsDesc', (l) => l.achDefenceCleanSheetsDesc);
  add('achDefenceGoalsAgainst', (l) => l.achDefenceGoalsAgainst);
  add('achDefenceGoalsAgainstDesc', (l) => l.achDefenceGoalsAgainstDesc);
  add('achDefenceScoredFirst', (l) => l.achDefenceScoredFirst);
  add('achDefenceScoredFirstDesc', (l) => l.achDefenceScoredFirstDesc);
  add('achDefenceShutoutStreak', (l) => l.achDefenceShutoutStreak);
  add('achDefenceShutoutStreakDesc', (l) => l.achDefenceShutoutStreakDesc);
  add('achEconomyLifetimeEarned', (l) => l.achEconomyLifetimeEarned);
  add('achEconomyLifetimeEarnedDesc', (l) => l.achEconomyLifetimeEarnedDesc);
  add('achEconomyPackSpend', (l) => l.achEconomyPackSpend);
  add('achEconomyPackSpendDesc', (l) => l.achEconomyPackSpendDesc);
  add('achEconomyPlayerSales', (l) => l.achEconomyPlayerSales);
  add('achEconomyPlayerSalesDesc', (l) => l.achEconomyPlayerSalesDesc);
  add('achEconomyUpgradeSpend', (l) => l.achEconomyUpgradeSpend);
  add('achEconomyUpgradeSpendDesc', (l) => l.achEconomyUpgradeSpendDesc);
  add('achLoyaltyRelegations', (l) => l.achLoyaltyRelegations);
  add('achLoyaltyRelegationsDesc', (l) => l.achLoyaltyRelegationsDesc);
  add('achLoyaltySeasons', (l) => l.achLoyaltySeasons);
  add('achLoyaltySeasonsDesc', (l) => l.achLoyaltySeasonsDesc);
  add('achMastermindTacticsChanged', (l) => l.achMastermindTacticsChanged);
  add('achMastermindTacticsChangedDesc', (l) => l.achMastermindTacticsChangedDesc);
  add('achMilestoneFirstEpic', (l) => l.achMilestoneFirstEpic);
  add('achMilestoneFirstEpicDesc', (l) => l.achMilestoneFirstEpicDesc);
  add('achMilestoneFirstFacilityMax', (l) => l.achMilestoneFirstFacilityMax);
  add('achMilestoneFirstFacilityMaxDesc', (l) => l.achMilestoneFirstFacilityMaxDesc);
  add('achMilestoneFirstLegendary', (l) => l.achMilestoneFirstLegendary);
  add('achMilestoneFirstLegendaryDesc', (l) => l.achMilestoneFirstLegendaryDesc);
  add('achMilestoneFirstLegendaryPull', (l) => l.achMilestoneFirstLegendaryPull);
  add('achMilestoneFirstLegendaryPullDesc', (l) => l.achMilestoneFirstLegendaryPullDesc);
  add('achMilestoneFirstMillion', (l) => l.achMilestoneFirstMillion);
  add('achMilestoneFirstMillionDesc', (l) => l.achMilestoneFirstMillionDesc);
  add('achMilestoneFirstSeason', (l) => l.achMilestoneFirstSeason);
  add('achMilestoneFirstSeasonDesc', (l) => l.achMilestoneFirstSeasonDesc);
  add('achMilestoneFirstTitle', (l) => l.achMilestoneFirstTitle);
  add('achMilestoneFirstTitleDesc', (l) => l.achMilestoneFirstTitleDesc);
  add('achMilestoneFirstWin', (l) => l.achMilestoneFirstWin);
  add('achMilestoneFirstWinDesc', (l) => l.achMilestoneFirstWinDesc);
  add('achPacksOpened', (l) => l.achPacksOpened);
  add('achPacksOpenedDesc', (l) => l.achPacksOpenedDesc);
  add('achPacksPurchased', (l) => l.achPacksPurchased);
  add('achPacksPurchasedDesc', (l) => l.achPacksPurchasedDesc);
  add('achPacksRewarded', (l) => l.achPacksRewarded);
  add('achPacksRewardedDesc', (l) => l.achPacksRewardedDesc);
  add('achPacksStartingPacks', (l) => l.achPacksStartingPacks);
  add('achPacksStartingPacksDesc', (l) => l.achPacksStartingPacksDesc);
  add('achSilverwarePromotions', (l) => l.achSilverwarePromotions);
  add('achSilverwarePromotionsDesc', (l) => l.achSilverwarePromotionsDesc);
  add('achSilverwareTitles', (l) => l.achSilverwareTitles);
  add('achSilverwareTitlesDesc', (l) => l.achSilverwareTitlesDesc);
  add('achSquadCardsOwned', (l) => l.achSquadCardsOwned);
  add('achSquadCardsOwnedDesc', (l) => l.achSquadCardsOwnedDesc);
  add('achSquadEpics', (l) => l.achSquadEpics);
  add('achSquadEpicsDesc', (l) => l.achSquadEpicsDesc);
  add('achSquadHighestUpgrade', (l) => l.achSquadHighestUpgrade);
  add('achSquadHighestUpgradeDesc', (l) => l.achSquadHighestUpgradeDesc);
  add('achSquadLegendaries', (l) => l.achSquadLegendaries);
  add('achSquadLegendariesDesc', (l) => l.achSquadLegendariesDesc);
  add('achSquadUpgrades', (l) => l.achSquadUpgrades);
  add('achSquadUpgradesDesc', (l) => l.achSquadUpgradesDesc);
  add('achTitleCareerWins1', (l) => l.achTitleCareerWins1);
  add('achTitleCareerWins2', (l) => l.achTitleCareerWins2);
  add('achTitleCleanSheets1', (l) => l.achTitleCleanSheets1);
  add('achTitleCleanSheets2', (l) => l.achTitleCleanSheets2);
  add('achTitleCoins1', (l) => l.achTitleCoins1);
  add('achTitleCoins2', (l) => l.achTitleCoins2);
  add('achTitleGoals1', (l) => l.achTitleGoals1);
  add('achTitleGoals2', (l) => l.achTitleGoals2);
  add('achTitleLegendaries1', (l) => l.achTitleLegendaries1);
  add('achTitleLegendaries2', (l) => l.achTitleLegendaries2);
  add('achTitleMastermind1', (l) => l.achTitleMastermind1);
  add('achTitleMastermind2', (l) => l.achTitleMastermind2);
  add('achTitlePacks1', (l) => l.achTitlePacks1);
  add('achTitlePacks2', (l) => l.achTitlePacks2);
  add('achTitleSeasons1', (l) => l.achTitleSeasons1);
  add('achTitleSeasons2', (l) => l.achTitleSeasons2);
  add('achTitleTitles1', (l) => l.achTitleTitles1);
  add('achTitleTitles2', (l) => l.achTitleTitles2);
  add('achTitleUnbeaten1', (l) => l.achTitleUnbeaten1);
  add('achTitleUnbeaten2', (l) => l.achTitleUnbeaten2);
  return table;
}();

/// The club header: crest, coach, equipped title and the completion
/// ring. Empty-safe: no equipped title → no title chip renders.
class _Header extends StatelessWidget {
  const _Header({
    required this.metrics,
    required this.claimedKeys,
  });

  final CareerMetrics metrics;
  final Set<String> claimedKeys;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    return FcmPanel(
      child: Row(
        children: [
          const _CrestIcon(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.achHubTitle,
                  style: const TextStyle(
                    color: FcmColors.goldSoft,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                // T-0112: the shared equipped-title chip — live on
                // equip, domain-resolved (unknown ids never render).
                const EquippedTitleChip(compact: true),
                const SizedBox(height: 2),
                Text(
                  l10n.achHubSubtitle(_claimedCount(), _visibleTierCount()),
                  style: const TextStyle(
                    color: FcmColors.textDim,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _CompletionRing(
            claimed: _claimedCount(),
            total: _visibleTierCount(),
          ),
        ],
      ),
    );
  }

  int _claimedCount() {
    var n = 0;
    for (final d in AchievementCatalog.definitions) {
      for (final tier in d.tiers(AchievementCatalog.economy)) {
        if (claimedKeys.contains('${d.id}:${tier.threshold}')) n++;
      }
    }
    return n;
  }

  int _visibleTierCount() {
    var n = 0;
    for (final d in AchievementCatalog.definitions) {
      n += d.tiers(AchievementCatalog.economy).length;
    }
    return n;
  }
}

/// The screen's identity crest (the house emblem — the club row is not
/// a claimable metric; T-0112's profile carries the real crest).
class _CrestIcon extends StatelessWidget {
  const _CrestIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: FcmColors.goldGradient,
        boxShadow: [
          BoxShadow(
            color: FcmColors.gold.withValues(alpha: 0.35),
            blurRadius: 12,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.military_tech_rounded,
        color: FcmColors.ink,
        size: 26,
      ),
    );
  }
}

/// The overall completion ring (claimed / visible tiers).
class _CompletionRing extends StatelessWidget {
  const _CompletionRing({required this.claimed, required this.total});

  final int claimed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : (claimed / total).clamp(0.0, 1.0);
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: ratio,
            strokeWidth: 4,
            strokeCap: StrokeCap.round,
            backgroundColor: FcmColors.bronze.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation(FcmColors.gold),
          ),
          Text(
            '${(ratio * 100).round()}%',
            style: const TextStyle(
              color: FcmColors.goldSoft,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// One category's section: heading + its achievement rows.
class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.metrics,
    required this.claimedKeys,
  });

  final AchievementCategory category;
  final CareerMetrics metrics;
  final Set<String> claimedKeys;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final defs = AchievementCatalog.definitions
        .where((d) => d.category == category.id)
        .toList();

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Icon(
                  _categoryIcon(category.iconName),
                  color: FcmColors.gold,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _categoryText(l10n, category.l10nPrefix, 'Title'),
                    style: const TextStyle(
                      color: FcmColors.goldSoft,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  _categoryText(l10n, category.l10nPrefix, 'Subtitle'),
                  style: const TextStyle(
                    color: FcmColors.textDim,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                // THE hot-path isolation: every tier row repaints in
                // its own layer; the ambient animation touches one
                // row, not the section.
                child: RepaintBoundary(
                  child: _AchievementCard(
                    definition: defs[i],
                    metrics: metrics,
                    claimedKeys: claimedKeys,
                  ),
                ),
              ),
              childCount: defs.length,
            ),
          ),
        ),
      ],
    );
  }
}

/// One achievement: badge, name, description, geometric progress and
/// the claim affordance.
class _AchievementCard extends ConsumerWidget {
  const _AchievementCard({
    required this.definition,
    required this.metrics,
    required this.claimedKeys,
  });

  final AchievementDefinition definition;
  final CareerMetrics metrics;
  final Set<String> claimedKeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = l10nOf(context);
    final progress = metrics.progressFor(definition.metricId) ?? 0;
    final tiers = definition.tiers(AchievementCatalog.economy);

    // The rung the player is climbing: the first unclaimed tier
    // (eligible → claimable), else the ladder's last visible rung.
    var tier = tiers.last;
    for (final t in tiers) {
      if (claimedKeys.contains('${definition.id}:${t.threshold}')) {
        continue;
      }
      tier = t;
      break;
    }
    // Claimed history: rungs already banked (rendered as the card's
    // claimed badge count — the claimed state the contract demands).
    final claimedRungs = tiers
        .where((t) => claimedKeys.contains('${definition.id}:${t.threshold}'))
        .length;
    final claimed = claimedKeys.contains(
      '${definition.id}:${tier.threshold}',
    );
    final eligible = progress >= tier.threshold && !claimed;

    return FcmPanel(
      accent: claimed ? FcmColors.gold : null,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CustomPaint(
              painter: FcmBadgePainter(metal: tier.badgeMetal),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _defText(l10n, definition.titleKey),
                  style: const TextStyle(
                    color: FcmColors.goldSoft,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _defText(l10n, definition.descriptionKey),
                  style: const TextStyle(
                    color: FcmColors.textDim,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _ProgressBar(
                        value: progress,
                        threshold: tier.threshold,
                      ),
                    ),
                    if (claimedRungs > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: FcmColors.success.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: FcmColors.success,
                              size: 10,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              l10n.achClaimedRungs(claimedRungs),
                              style: const TextStyle(
                                color: FcmColors.success,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _ClaimColumn(
            tier: tier,
            claimed: claimed,
            eligible: eligible,
            definition: definition,
          ),
        ],
      ),
    );
  }
}

/// The honest geometric bar + the "9 / 16" readout.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.threshold});

  final int value;
  final int threshold;

  @override
  Widget build(BuildContext context) {
    final ratio = threshold == 0
        ? 0.0
        : (value / threshold).clamp(0.0, 1.0);
    final complete = value >= threshold;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: FcmColors.ember.withValues(alpha: 0.8),
                valueColor: AlwaysStoppedAnimation(
                  complete ? FcmColors.success : FcmColors.gold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$value / $threshold',
          style: TextStyle(
            color: complete ? FcmColors.success : FcmColors.textDim,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// The right column: reward chip + claim / claimed / locked states with scale-in claim feedback.
class _ClaimColumn extends ConsumerStatefulWidget {
  const _ClaimColumn({
    required this.tier,
    required this.claimed,
    required this.eligible,
    required this.definition,
  });

  final AchievementTier tier;
  final bool claimed;
  final bool eligible;
  final AchievementDefinition definition;

  @override
  ConsumerState<_ClaimColumn> createState() => _ClaimColumnState();
}

class _ClaimColumnState extends ConsumerState<_ClaimColumn>
    with SingleTickerProviderStateMixin {
  bool _justClaimed = false;
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  )..value = 1.0;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    if (widget.claimed || _justClaimed) {
      return ScaleTransition(
        scale: Tween<double>(begin: 0.7, end: 1.0).animate(
          CurvedAnimation(parent: _anim, curve: Curves.easeOutBack),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: FcmColors.success, size: 22),
            const SizedBox(height: 2),
            Text(
              l10n.achClaimedLabel,
              style: const TextStyle(
                color: FcmColors.success,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }
    if (!widget.eligible) {
      return FcmCoinChip(coins: widget.tier.coinReward);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FcmCoinChip(coins: widget.tier.coinReward),
        const SizedBox(height: 6),
        FcmButton(
          label: l10n.achClaimAction,
          compact: true,
          onPressed: () async {
            setState(() => _justClaimed = true);
            _anim.forward(from: 0.0);
            await ref.read(
              claimTierProvider(
                ClaimArgs(widget.definition.id, widget.tier.threshold.toString()),
              ).future,
            );
            refreshAchievements(ref);
          },
        ),
      ],
    );
  }
}

/// Category icon mapping (catalog icon names → IconData).
IconData _categoryIcon(String iconName) => switch (iconName) {
      'whistle' => Icons.sports_rounded,
      'goal' => Icons.sports_soccer_rounded,
      'shield' => Icons.shield_rounded,
      'trophy' => Icons.emoji_events_rounded,
      'cards' => Icons.style_rounded,
      'pack' => Icons.inventory_2_rounded,
      'coins' => Icons.paid_rounded,
      'campus' => Icons.apartment_rounded,
      'heart' => Icons.favorite_rounded,
      'brain' => Icons.psychology_rounded,
      _ => Icons.military_tech_rounded,
    };
