/// FCM Rivals — the titles & badges showcase (T-0112): the prestige
/// layer on the Profile tab.
///
/// The badge cabinet (every catalog badge by metal tier — earned ones
/// in full painter colour with the earned glow, unearned as engraved
/// silhouettes at reduced opacity with the progress hint: visible,
/// aspirational, never hidden), the titles gallery (owned titles with
/// their source lines + the equip toggle; unowned greyed with their
/// earning condition), and the shared equipped-title chip other
/// surfaces reuse. Every state flows from ONE domain resolution —
/// the two-way ownership rule lives in `title_domain.dart`, consumed
/// here and by both headers, never duplicated.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/fcm_panel.dart';
import '../../core/ui/fcm_style.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_context.dart';
import '../achievements/achievement_catalog.dart';
import '../achievements/achievement_catalog_data.dart';
import '../achievements/achievements_badge_painter.dart';
import '../achievements/achievements_providers.dart' as ach;
import 'title_domain.dart';
import 'title_showcase_providers.dart';

/// The showcase section: cabinet + gallery, appended to the Profile
/// screen's slivers (this task's surface).
class TitleBadgeShowcase extends ConsumerWidget {
  const TitleBadgeShowcase({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cabinet = ref.watch(titleCabinetProvider);
    final metrics = ref.watch(ach.careerMetricsProvider);
    final claims = ref.watch(ach.claimsProvider);
    final l10n = l10nOf(context);

    return cabinet.when(
      loading: () => const SliverToBoxAdapter(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Center(child: Text('$e')),
      ),
      data: (cab) => metrics.maybeWhen(
        orElse: () => const SliverToBoxAdapter(child: SizedBox()),
        data: (m) => claims.maybeWhen(
          orElse: () => const SliverToBoxAdapter(child: SizedBox()),
          data: (claimed) => SliverMainAxisGroup(
            slivers: [
              // ---- The badge cabinet (claimed badges only) ---------
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    l10n.badgeCabinetTitle,
                    style: const TextStyle(
                      color: FcmColors.goldSoft,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              _BadgeCabinet(metrics: m, claimedKeys: claimed),
              // ---- The titles gallery (owned titles only) ----------
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    l10n.titlesGalleryTitle,
                    style: const TextStyle(
                      color: FcmColors.goldSoft,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              _TitlesGallery(cabinet: cab),
            ],
          ),
        ),
      ),
    );
  }
}

/// The badge cabinet: category by category, every tier's metal badge
/// — earned in colour, unearned engraved. One RepaintBoundary per
/// cell (the cabinet grows with the catalog).
class _BadgeCabinet extends StatelessWidget {
  const _BadgeCabinet({required this.metrics, required this.claimedKeys});

  final dynamic metrics;

  /// The club's claimed tier keys — the profile shows ONLY claimed
  /// badges (the full ladder lives in the achievements tab).
  final Set<String> claimedKeys;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final defs = AchievementCatalog.definitions;

    final hasAnyClaimed = defs.any((def) {
      return def.tiers(AchievementCatalog.economy).any(
        (tier) => claimedKeys.contains('${def.id}:${tier.threshold}'),
      );
    });

    if (!hasAnyClaimed) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        sliver: SliverToBoxAdapter(
          child: const _EmptyShowcaseCard(
            icon: Icons.military_tech_outlined,
            title: 'Badge Cabinet Empty',
            subtitle: 'Complete achievements and milestones to earn and display your metal badges here.',
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      sliver: SliverList.builder(
        itemCount: defs.length,
        itemBuilder: (context, i) {
          final def = defs[i];
          final progress = metrics.progressFor(def.metricId) ?? 0;
          // Only the tiers actually CLAIMED render a badge cell —
          // the profile is the showcase of what the player took, not
          // the ladder of what is left.
          final claimedTiers = [
            for (final tier in def.tiers(AchievementCatalog.economy))
              if (claimedKeys.contains('${def.id}:${tier.threshold}')) tier,
          ];
          if (claimedTiers.isEmpty) {
            // Definition with nothing claimed yet: no cabinet row at
            // all (an empty panel reads as a broken list).
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RepaintBoundary(
              child: FcmPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _defText(l10n, def.titleKey),
                      style: const TextStyle(
                        color: FcmColors.goldSoft,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 78,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final tier in claimedTiers)
                            RepaintBoundary(
                              child: _BadgeCell(
                                metal: tier.badgeMetal,
                                earned: true,
                                label: 'T${tier.index}',
                                progress: '$progress/${tier.threshold}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One badge cell: earned → full colour + glow; unearned → engraved
/// silhouette at reduced opacity with the progress hint.
class _BadgeCell extends StatelessWidget {
  const _BadgeCell({
    required this.metal,
    required this.earned,
    required this.label,
    required this.progress,
  });

  final BadgeMetal metal;
  final bool earned;
  final String label;
  final String progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: earned
                  ? [
                      BoxShadow(
                        color: FcmColors.gold.withValues(alpha: 0.45),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Opacity(
              opacity: earned ? 1.0 : 0.35,
              child: CustomPaint(
                painter: FcmBadgePainter(metal: metal),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            earned ? label : progress,
            style: TextStyle(
              color: earned ? FcmColors.goldSoft : FcmColors.textDim,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// The titles gallery: owned + source line + equip toggle; unowned
/// greyed with the earning condition.
class _TitlesGallery extends ConsumerWidget {
  const _TitlesGallery({required this.cabinet});

  final TitleCabinet cabinet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = l10nOf(context);
    // The profile shows only what the player actually HAS — locked
    // titles belong to the achievements tab's ladder, not here.
    final ownedTitles = [
      ...cabinet.achievementTitles.where((t) => t.owned),
      ...cabinet.divisionTitles.where((t) => t.owned),
    ];

    if (ownedTitles.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        sliver: SliverToBoxAdapter(
          child: const _EmptyShowcaseCard(
            icon: Icons.workspace_premium_rounded,
            title: 'No Titles Unlocked',
            subtitle: 'Win league divisions or complete achievements to unlock prestige manager titles.',
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      sliver: SliverList.builder(
        itemCount: ownedTitles.length,
        itemBuilder: (context, i) {
          final title = ownedTitles[i];
          final isAch = cabinet.achievementTitles.any((t) => t.id == title.id);
          final equipped = cabinet.equippedId == title.id;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RepaintBoundary(
              child: FcmPanel(
                accent: FcmColors.gold,
                child: Row(
                  children: [
                    Icon(
                      isAch
                          ? Icons.military_tech_rounded
                          : Icons.emoji_events_rounded,
                      color: FcmColors.gold,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titleText(l10n, title),
                            style: const TextStyle(
                              color: FcmColors.goldSoft,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _sourceText(l10n, title),
                            style: const TextStyle(
                              color: FcmColors.textDim,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Direct manipulation (the repo's favour): tap
                    // toggles equip/unequip — no dialog, instant.
                    _EquipToggle(
                      equipped: equipped,
                      onTap: () => ref
                          .read(equipTitleProvider)
                          (equipped ? null : title.id),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The equip toggle: the gold-pill treatment when worn.
class _EquipToggle extends StatelessWidget {
  const _EquipToggle({required this.equipped, required this.onTap});

  final bool equipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: equipped ? FcmColors.goldGradient : null,
          border: Border.all(
            color: equipped
                ? FcmColors.goldSoft.withValues(alpha: 0.5)
                : FcmColors.bronze.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          equipped ? l10n.titleUnequipAction : l10n.titleEquipAction,
          style: TextStyle(
            color: equipped ? FcmColors.ink : FcmColors.goldSoft,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// The REUSABLE equipped-title chip — the one widget other surfaces
/// (match headers, reports) drop in; no ad-hoc title renders.
class EquippedTitleChip extends ConsumerWidget {
  const EquippedTitleChip({super.key, this.compact = false});

  /// Smaller padding for dense headers.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cabinet = ref.watch(titleCabinetProvider);
    final l10n = l10nOf(context);
    return cabinet.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (cab) {
        final key = cab.equippedL10nKey;
        if (key == null) return const SizedBox.shrink();
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 3 : 4,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: FcmColors.gold.withValues(alpha: 0.6)),
            gradient: FcmColors.goldGradient,
          ),
          child: Text(
            _plainKey(l10n, key),
            style: TextStyle(
              color: FcmColors.ink,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      },
    );
  }
}

// ---- l10n bridges --------------------------------------------------------

String _defText(AppLocalizations l10n, String key) =>
    _plainKey(l10n, key);

String _titleText(AppLocalizations l10n, OwnedTitleState title) {
  if (title.l10nKey == 'achievementDivisionChampion') {
    return l10n.achievementDivisionChampion(title.sourceArg);
  }
  return _plainKey(l10n, title.l10nKey);
}

String _sourceText(AppLocalizations l10n, OwnedTitleState title) {
  if (title.sourceL10nKey == 'titleSourceDivision') {
    return l10n.titleSourceDivision(title.sourceArg);
  }
  return l10n.titleSourceAchievement(
    _defText(l10n, _defIdOf(title.id)),
    title.sourceArg,
  );
}

String _defIdOf(String titleId) {
  final dash = titleId.lastIndexOf('-title');
  final defId = titleId.substring(0, dash);
  final definition = AchievementCatalog.byId(defId);
  return definition?.titleKey ?? defId;
}

String _plainKey(AppLocalizations l10n, String key) =>
    switch (key) {
      'achCareerTitle' => l10n.achCareerTitle,
      'achCareerSubtitle' => l10n.achCareerSubtitle,
      'achAttackTitle' => l10n.achAttackTitle,
      'achAttackSubtitle' => l10n.achAttackSubtitle,
      'achDefenceTitle' => l10n.achDefenceTitle,
      'achDefenceSubtitle' => l10n.achDefenceSubtitle,
      'achSilverwareTitle' => l10n.achSilverwareTitle,
      'achSilverwareSubtitle' => l10n.achSilverwareSubtitle,
      'achSquadTitle' => l10n.achSquadTitle,
      'achSquadSubtitle' => l10n.achSquadSubtitle,
      'achPacksTitle' => l10n.achPacksTitle,
      'achPacksSubtitle' => l10n.achPacksSubtitle,
      'achEconomyTitle' => l10n.achEconomyTitle,
      'achEconomySubtitle' => l10n.achEconomySubtitle,
      'achCampusTitle' => l10n.achCampusTitle,
      'achCampusSubtitle' => l10n.achCampusSubtitle,
      'achLoyaltyTitle' => l10n.achLoyaltyTitle,
      'achLoyaltySubtitle' => l10n.achLoyaltySubtitle,
      'achMastermindTitle' => l10n.achMastermindTitle,
      'achMastermindSubtitle' => l10n.achMastermindSubtitle,
      'achCareerMatches' => l10n.achCareerMatches,
      'achCareerMatchesDesc' => l10n.achCareerMatchesDesc,
      'achCareerWins' => l10n.achCareerWins,
      'achCareerWinsDesc' => l10n.achCareerWinsDesc,
      'achCareerWinStreak' => l10n.achCareerWinStreak,
      'achCareerWinStreakDesc' => l10n.achCareerWinStreakDesc,
      'achCareerUnbeatenStreak' => l10n.achCareerUnbeatenStreak,
      'achCareerUnbeatenStreakDesc' => l10n.achCareerUnbeatenStreakDesc,
      'achCareerDraws' => l10n.achCareerDraws,
      'achCareerDrawsDesc' => l10n.achCareerDrawsDesc,
      'achCareerLosses' => l10n.achCareerLosses,
      'achCareerLossesDesc' => l10n.achCareerLossesDesc,
      'achCareerHomeMatches' => l10n.achCareerHomeMatches,
      'achCareerHomeMatchesDesc' => l10n.achCareerHomeMatchesDesc,
      'achCareerAwayMatches' => l10n.achCareerAwayMatches,
      'achCareerAwayMatchesDesc' => l10n.achCareerAwayMatchesDesc,
      'achAttackGoals' => l10n.achAttackGoals,
      'achAttackGoalsDesc' => l10n.achAttackGoalsDesc,
      'achAttackGoalsSingleMatch' => l10n.achAttackGoalsSingleMatch,
      'achAttackGoalsSingleMatchDesc' =>
          l10n.achAttackGoalsSingleMatchDesc,
      'achDefenceCleanSheets' => l10n.achDefenceCleanSheets,
      'achDefenceCleanSheetsDesc' => l10n.achDefenceCleanSheetsDesc,
      'achDefenceShutoutStreak' => l10n.achDefenceShutoutStreak,
      'achDefenceShutoutStreakDesc' => l10n.achDefenceShutoutStreakDesc,
      'achDefenceGoalsAgainst' => l10n.achDefenceGoalsAgainst,
      'achDefenceGoalsAgainstDesc' => l10n.achDefenceGoalsAgainstDesc,
      'achDefenceScoredFirst' => l10n.achDefenceScoredFirst,
      'achDefenceScoredFirstDesc' => l10n.achDefenceScoredFirstDesc,
      'achSilverwareTitles' => l10n.achSilverwareTitles,
      'achSilverwareTitlesDesc' => l10n.achSilverwareTitlesDesc,
      'achSilverwarePromotions' => l10n.achSilverwarePromotions,
      'achSilverwarePromotionsDesc' => l10n.achSilverwarePromotionsDesc,
      'achSquadCardsOwned' => l10n.achSquadCardsOwned,
      'achSquadCardsOwnedDesc' => l10n.achSquadCardsOwnedDesc,
      'achSquadLegendaries' => l10n.achSquadLegendaries,
      'achSquadLegendariesDesc' => l10n.achSquadLegendariesDesc,
      'achSquadEpics' => l10n.achSquadEpics,
      'achSquadEpicsDesc' => l10n.achSquadEpicsDesc,
      'achSquadUpgrades' => l10n.achSquadUpgrades,
      'achSquadUpgradesDesc' => l10n.achSquadUpgradesDesc,
      'achSquadHighestUpgrade' => l10n.achSquadHighestUpgrade,
      'achSquadHighestUpgradeDesc' => l10n.achSquadHighestUpgradeDesc,
      'achPacksOpened' => l10n.achPacksOpened,
      'achPacksOpenedDesc' => l10n.achPacksOpenedDesc,
      'achPacksPurchased' => l10n.achPacksPurchased,
      'achPacksPurchasedDesc' => l10n.achPacksPurchasedDesc,
      'achPacksRewarded' => l10n.achPacksRewarded,
      'achPacksRewardedDesc' => l10n.achPacksRewardedDesc,
      'achPacksStartingPacks' => l10n.achPacksStartingPacks,
      'achPacksStartingPacksDesc' => l10n.achPacksStartingPacksDesc,
      'achEconomyLifetimeEarned' => l10n.achEconomyLifetimeEarned,
      'achEconomyLifetimeEarnedDesc' => l10n.achEconomyLifetimeEarnedDesc,
      'achEconomyPackSpend' => l10n.achEconomyPackSpend,
      'achEconomyPackSpendDesc' => l10n.achEconomyPackSpendDesc,
      'achEconomyUpgradeSpend' => l10n.achEconomyUpgradeSpend,
      'achEconomyUpgradeSpendDesc' => l10n.achEconomyUpgradeSpendDesc,
      'achEconomyPlayerSales' => l10n.achEconomyPlayerSales,
      'achEconomyPlayerSalesDesc' => l10n.achEconomyPlayerSalesDesc,
      'achCampusFacilityLevels' => l10n.achCampusFacilityLevels,
      'achCampusFacilityLevelsDesc' => l10n.achCampusFacilityLevelsDesc,
      'achCampusRecoveryLevel' => l10n.achCampusRecoveryLevel,
      'achCampusRecoveryLevelDesc' => l10n.achCampusRecoveryLevelDesc,
      'achLoyaltySeasons' => l10n.achLoyaltySeasons,
      'achLoyaltySeasonsDesc' => l10n.achLoyaltySeasonsDesc,
      'achLoyaltyRelegations' => l10n.achLoyaltyRelegations,
      'achLoyaltyRelegationsDesc' => l10n.achLoyaltyRelegationsDesc,
      'achMastermindTacticsChanged' => l10n.achMastermindTacticsChanged,
      'achMastermindTacticsChangedDesc' =>
          l10n.achMastermindTacticsChangedDesc,
      'achMilestoneFirstWin' => l10n.achMilestoneFirstWin,
      'achMilestoneFirstWinDesc' => l10n.achMilestoneFirstWinDesc,
      'achMilestoneFirstTitle' => l10n.achMilestoneFirstTitle,
      'achMilestoneFirstTitleDesc' => l10n.achMilestoneFirstTitleDesc,
      'achMilestoneFirstLegendary' => l10n.achMilestoneFirstLegendary,
      'achMilestoneFirstLegendaryDesc' => l10n.achMilestoneFirstLegendaryDesc,
      'achMilestoneFirstEpic' => l10n.achMilestoneFirstEpic,
      'achMilestoneFirstEpicDesc' => l10n.achMilestoneFirstEpicDesc,
      'achMilestoneFirstLegendaryPull' => l10n.achMilestoneFirstLegendaryPull,
      'achMilestoneFirstLegendaryPullDesc' =>
          l10n.achMilestoneFirstLegendaryPullDesc,
      'achMilestoneFirstMillion' => l10n.achMilestoneFirstMillion,
      'achMilestoneFirstMillionDesc' => l10n.achMilestoneFirstMillionDesc,
      'achMilestoneFirstSeason' => l10n.achMilestoneFirstSeason,
      'achMilestoneFirstSeasonDesc' => l10n.achMilestoneFirstSeasonDesc,
      'achMilestoneFirstFacilityMax' => l10n.achMilestoneFirstFacilityMax,
      'achMilestoneFirstFacilityMaxDesc' =>
          l10n.achMilestoneFirstFacilityMaxDesc,
      'achTitleCareerWins1' => l10n.achTitleCareerWins1,
      'achTitleCareerWins2' => l10n.achTitleCareerWins2,
      'achTitleUnbeaten1' => l10n.achTitleUnbeaten1,
      'achTitleUnbeaten2' => l10n.achTitleUnbeaten2,
      'achTitleGoals1' => l10n.achTitleGoals1,
      'achTitleGoals2' => l10n.achTitleGoals2,
      'achTitleCleanSheets1' => l10n.achTitleCleanSheets1,
      'achTitleCleanSheets2' => l10n.achTitleCleanSheets2,
      'achTitleTitles1' => l10n.achTitleTitles1,
      'achTitleTitles2' => l10n.achTitleTitles2,
      'achTitleLegendaries1' => l10n.achTitleLegendaries1,
      'achTitleLegendaries2' => l10n.achTitleLegendaries2,
      'achTitlePacks1' => l10n.achTitlePacks1,
      'achTitlePacks2' => l10n.achTitlePacks2,
      'achTitleCoins1' => l10n.achTitleCoins1,
      'achTitleCoins2' => l10n.achTitleCoins2,
      'achTitleSeasons1' => l10n.achTitleSeasons1,
      'achTitleSeasons2' => l10n.achTitleSeasons2,
      'achTitleMastermind1' => l10n.achTitleMastermind1,
      'achTitleMastermind2' => l10n.achTitleMastermind2,
      _ => key,
    };

/// A premium empty-state card when the cabinet or titles gallery has nothing yet.
class _EmptyShowcaseCard extends StatelessWidget {
  const _EmptyShowcaseCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return FcmPanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FcmColors.gold.withValues(alpha: 0.1),
                border: Border.all(
                  color: FcmColors.gold.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(
                icon,
                color: FcmColors.goldSoft,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
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
    );
  }
}
