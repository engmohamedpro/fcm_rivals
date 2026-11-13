/// FCM Rivals — the seeded achievement catalog (T-0105, GDD 26).
///
/// The concrete catalog the whole feature reads: 10 categories, 42
/// definitions (34 endless ladders + 8 milestones), 16 achievement
/// titles plus the division-championship titles (seeded for
/// divisions 1..5, generated on demand beyond). Metric ids match
/// T-0107's derivation inventory exactly — a metric with no persisted
/// trace would be dropped there in a documented catalog edit, never
/// faked here.
///
/// The shape discipline (library doc of `achievement_catalog.dart`):
/// every countable metric climbs a geometric ladder (ratio 2) with
/// FLAT coins; milestones are unique feats with fixed budgets. No
/// magic numbers outside this file and `AchievementEconomyConfig`.
library;

import 'achievement_catalog.dart';
import 'achievement_economy_config.dart';

/// The catalog's one instance (immutable, pure data).
class AchievementCatalog {
  const AchievementCatalog._();

  /// The economy parameters the tiers are priced with (pre-balance
  /// placeholders; T-0109's sweep re-pins them).
  static const AchievementEconomyConfig economy =
      AchievementEconomyConfig();

  /// Perf pass 2026-11-12 (LOW): memoized tier lists per definition,
  /// keyed by (definition id, economy). The screen's header counters
  /// and progress rows used to REGENERATE every definition's tiers
  /// (a List.generate with ladder maths per rung) on every build —
  /// 42 definitions × their rungs, per frame the screen rebuilds. The
  /// catalog is immutable and callers pass one economy, so this cache
  /// has exactly one entry per definition in practice.
  static final Map<String, List<AchievementTier>> _tiersByDefinition = {};

  /// The memoized [AchievementDefinition.tiers] of [definition] under
  /// [economy] — the public path every caller already uses.
  static List<AchievementTier> tiersOf(
    AchievementDefinition definition,
    AchievementEconomyConfig economy,
  ) {
    return _tiersByDefinition['${definition.id}@${economy.hashCode}'] ??=
        definition.tiers(economy);
  }

  // ---- Categories (10) ----------------------------------------------

  static const career = AchievementCategory(
    id: 'career',
    iconName: 'whistle',
    l10nPrefix: 'achCareer',
  );
  static const attack = AchievementCategory(
    id: 'attack',
    iconName: 'goal',
    l10nPrefix: 'achAttack',
  );
  static const defence = AchievementCategory(
    id: 'defence',
    iconName: 'shield',
    l10nPrefix: 'achDefence',
  );
  static const silverware = AchievementCategory(
    id: 'silverware',
    iconName: 'trophy',
    l10nPrefix: 'achSilverware',
  );
  static const squad = AchievementCategory(
    id: 'squad',
    iconName: 'cards',
    l10nPrefix: 'achSquad',
  );
  static const packs = AchievementCategory(
    id: 'packs',
    iconName: 'pack',
    l10nPrefix: 'achPacks',
  );
  static const economyCat = AchievementCategory(
    id: 'economy',
    iconName: 'coins',
    l10nPrefix: 'achEconomy',
  );
  static const campus = AchievementCategory(
    id: 'campus',
    iconName: 'campus',
    l10nPrefix: 'achCampus',
  );
  static const loyalty = AchievementCategory(
    id: 'loyalty',
    iconName: 'heart',
    l10nPrefix: 'achLoyalty',
  );
  static const mastermind = AchievementCategory(
    id: 'mastermind',
    iconName: 'brain',
    l10nPrefix: 'achMastermind',
  );

  /// All categories, display order.
  static const List<AchievementCategory> categories = [
    career,
    attack,
    defence,
    silverware,
    squad,
    packs,
    economyCat,
    campus,
    loyalty,
    mastermind,
  ];

  /// Ladder builder — plain function (constructor tear-offs cannot
  /// drive const-correct call sites cleanly at every ratio). No
  /// tierCount means ENDLESS (tiers on demand); tierCount means a
  /// finite ladder — the two ladder shapes the catalog uses.
  static AchievementLadder _mk({
    required int baseThreshold,
    required double thresholdRatio,
    int? tierCount,
    int maxGeneratedTiers = 24,
  }) => AchievementLadder(
    baseThreshold: baseThreshold,
    thresholdRatio: thresholdRatio,
    tierCount: tierCount,
    endless: tierCount == null,
    maxGeneratedTiers: maxGeneratedTiers,
  );

  // ---- Endless ladders (geometric thresholds, flat coins) ----------
  //
  // base/ratio choices per metric: match-scale counts start at 1 with
  // ratio 2 (1, 2, 4, 8 … 8.4M at tier 24); volume counts (goals,
  // coins, packs) start at a round base so tier 1 is a real milestone.


  static final List<AchievementDefinition> _endless = [
    AchievementDefinition(
      id: 'career_matches',
      category: 'career',
      metricId: 'matchesManaged',
      titleKey: 'achCareerMatches',
      descriptionKey: 'achCareerMatchesDesc',
      hint: 'Matches managed in any competition.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'career_wins',
      confersTitles: true,
      category: 'career',
      metricId: 'wins',
      titleKey: 'achCareerWins',
      descriptionKey: 'achCareerWinsDesc',
      hint: 'Matches won.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'career_win_streak',
      category: 'career',
      metricId: 'longestWinStreak',
      titleKey: 'achCareerWinStreak',
      descriptionKey: 'achCareerWinStreakDesc',
      hint: 'Longest consecutive-win streak (career-scoped).',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 2, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'career_unbeaten_streak',
      confersTitles: true,
      category: 'career',
      metricId: 'longestUnbeatenStreak',
      titleKey: 'achCareerUnbeatenStreak',
      descriptionKey: 'achCareerUnbeatenStreakDesc',
      hint: 'Longest unbeaten run (wins + draws).',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 3, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'attack_goals',
      confersTitles: true,
      category: 'attack',
      metricId: 'goalsFor',
      titleKey: 'achAttackGoals',
      descriptionKey: 'achAttackGoalsDesc',
      hint: 'Goals scored by the user club.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 10, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'attack_goals_single_match',
      category: 'attack',
      metricId: 'mostGoalsInOneMatch',
      titleKey: 'achAttackGoalsSingleMatch',
      descriptionKey: 'achAttackGoalsSingleMatchDesc',
      hint: 'Most goals scored in one match.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 3, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'defence_clean_sheets',
      confersTitles: true,
      category: 'defence',
      metricId: 'cleanSheets',
      titleKey: 'achDefenceCleanSheets',
      descriptionKey: 'achDefenceCleanSheetsDesc',
      hint: 'Matches with zero conceded.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'defence_shutout_streak',
      category: 'defence',
      metricId: 'longestCleanSheetStreak',
      titleKey: 'achDefenceShutoutStreak',
      descriptionKey: 'achDefenceShutoutStreakDesc',
      hint: 'Consecutive matches without conceding.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 2, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'silverware_titles',
      confersTitles: true,
      category: 'silverware',
      metricId: 'titlesByDivisionTotal',
      titleKey: 'achSilverwareTitles',
      descriptionKey: 'achSilverwareTitlesDesc',
      hint: 'Division championships won, any division.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'silverware_promotions',
      category: 'silverware',
      metricId: 'promotions',
      titleKey: 'achSilverwarePromotions',
      descriptionKey: 'achSilverwarePromotionsDesc',
      hint: 'Seasons finished with promotion.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'squad_cards_owned',
      category: 'squad',
      metricId: 'cardsOwned',
      titleKey: 'achSquadCardsOwned',
      descriptionKey: 'achSquadCardsOwnedDesc',
      hint: 'Players currently owned.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 3, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'squad_legendaries',
      confersTitles: true,
      category: 'squad',
      metricId: 'legendaryCardsOwned',
      titleKey: 'achSquadLegendaries',
      descriptionKey: 'achSquadLegendariesDesc',
      hint: 'Legendary players (80+ overall) owned at once.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'squad_epics',
      category: 'squad',
      metricId: 'epicCardsOwned',
      titleKey: 'achSquadEpics',
      descriptionKey: 'achSquadEpicsDesc',
      hint: 'Epic players (70..79) owned at once.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'squad_upgrades',
      category: 'squad',
      metricId: 'upgradesCompleted',
      titleKey: 'achSquadUpgrades',
      descriptionKey: 'achSquadUpgradesDesc',
      hint: 'Duplicate merges completed (unlimited levels).',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'squad_highest_upgrade',
      category: 'squad',
      metricId: 'highestUpgradeLevel',
      titleKey: 'achSquadHighestUpgrade',
      descriptionKey: 'achSquadHighestUpgradeDesc',
      hint: 'Highest upgrade level reached on one card.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'packs_opened',
      confersTitles: true,
      category: 'packs',
      metricId: 'packsOpened',
      titleKey: 'achPacksOpened',
      descriptionKey: 'achPacksOpenedDesc',
      hint: 'Packs opened, every source.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 3, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'packs_purchased',
      category: 'packs',
      metricId: 'packsPurchased',
      titleKey: 'achPacksPurchased',
      descriptionKey: 'achPacksPurchasedDesc',
      hint: 'Packs bought with coins.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'packs_rewarded',
      category: 'packs',
      metricId: 'packsRewarded',
      titleKey: 'achPacksRewarded',
      descriptionKey: 'achPacksRewardedDesc',
      hint: 'Packs granted by season rewards.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'economy_lifetime_earned',
      confersTitles: true,
      category: 'economy',
      metricId: 'lifetimeCoinsEarned',
      titleKey: 'achEconomyLifetimeEarned',
      descriptionKey: 'achEconomyLifetimeEarnedDesc',
      hint: 'Lifetime coins earned (sum of positive ledger rows).',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1_000, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'economy_pack_spend',
      category: 'economy',
      metricId: 'coinsSpentOnPacks',
      titleKey: 'achEconomyPackSpend',
      descriptionKey: 'achEconomyPackSpendDesc',
      hint: 'Coins spent on packs.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1_000, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'economy_upgrade_spend',
      category: 'economy',
      metricId: 'coinsSpentOnUpgrades',
      titleKey: 'achEconomyUpgradeSpend',
      descriptionKey: 'achEconomyUpgradeSpendDesc',
      hint: 'Coins spent on upgrades and facilities.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1_000, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'campus_facility_levels',
      category: 'campus',
      metricId: 'facilityLevelTotal',
      titleKey: 'achCampusFacilityLevels',
      descriptionKey: 'achCampusFacilityLevelsDesc',
      hint: 'Sum of all facility levels.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'loyalty_seasons',
      confersTitles: true,
      category: 'loyalty',
      metricId: 'seasonsCompleted',
      titleKey: 'achLoyaltySeasons',
      descriptionKey: 'achLoyaltySeasonsDesc',
      hint: 'Seasons completed.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'career_draws',
      category: 'career',
      metricId: 'draws',
      titleKey: 'achCareerDraws',
      descriptionKey: 'achCareerDrawsDesc',
      hint: 'Matches shared with the opponent.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'career_losses',
      category: 'career',
      metricId: 'losses',
      titleKey: 'achCareerLosses',
      descriptionKey: 'achCareerLossesDesc',
      hint: 'Matches lost — character-building.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'attack_goals_against',
      category: 'defence',
      metricId: 'goalsAgainst',
      titleKey: 'achDefenceGoalsAgainst',
      descriptionKey: 'achDefenceGoalsAgainstDesc',
      hint: 'Goals conceded (a small number is the achievement '
          'environment for the clean-sheet ladders).',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 10, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'defence_scored_first',
      category: 'defence',
      metricId: 'matchesScoredFirst',
      titleKey: 'achDefenceScoredFirst',
      descriptionKey: 'achDefenceScoredFirstDesc',
      hint: 'Matches where the club scored the opening goal.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'career_matches_away',
      category: 'career',
      metricId: 'awayMatches',
      titleKey: 'achCareerAwayMatches',
      descriptionKey: 'achCareerAwayMatchesDesc',
      hint: 'Matches managed on the road.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'economy_player_sales',
      category: 'economy',
      metricId: 'playerSalesCompleted',
      titleKey: 'achEconomyPlayerSales',
      descriptionKey: 'achEconomyPlayerSalesDesc',
      hint: 'Players sold on the market.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'loyalty_relegations',
      category: 'loyalty',
      metricId: 'relegations',
      titleKey: 'achLoyaltyRelegations',
      descriptionKey: 'achLoyaltyRelegationsDesc',
      hint: 'Seasons finished with relegation — stayed loyal anyway.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'packs_starting_packs',
      category: 'packs',
      metricId: 'startingPacksOpened',
      titleKey: 'achPacksStartingPacks',
      descriptionKey: 'achPacksStartingPacksDesc',
      hint: 'Starter packs opened at club creation.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'career_matches_home',
      category: 'career',
      metricId: 'homeMatches',
      titleKey: 'achCareerHomeMatches',
      descriptionKey: 'achCareerHomeMatchesDesc',
      hint: 'Matches managed in front of the home crowd.',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'campus_recovery_level',
      category: 'campus',
      metricId: 'recoveryCentreLevel',
      titleKey: 'achCampusRecoveryLevel',
      descriptionKey: 'achCampusRecoveryLevelDesc',
      hint: 'The Recovery Centre\'s level alone (stamina pipeline).',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2),
    ),
    AchievementDefinition(
      id: 'mastermind_tactics_changed',
      confersTitles: true,
      category: 'mastermind',
      metricId: 'tacticsInstructionsChanged',
      titleKey: 'achMastermindTacticsChanged',
      descriptionKey: 'achMastermindTacticsChangedDesc',
      hint: 'Tactic instruction changes (pre-match + live).',
      kind: AchievementKind.endlessLadder,
      ladder: _mk(baseThreshold: 5, thresholdRatio: 2),
    ),
  ];

  // ---- One-time milestones (fixed budgets) --------------------------

  static final List<AchievementDefinition> _milestones = [
    AchievementDefinition(
      id: 'milestone_first_win',
      category: 'career',
      metricId: 'wins',
      titleKey: 'achMilestoneFirstWin',
      descriptionKey: 'achMilestoneFirstWinDesc',
      hint: 'The first victory of the career.',
      kind: AchievementKind.milestone,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2, tierCount: 1),
      milestoneReward: economy.milestoneCareerFirstWin,
    ),
    AchievementDefinition(
      id: 'milestone_first_title',
      category: 'silverware',
      metricId: 'titlesByDivisionTotal',
      titleKey: 'achMilestoneFirstTitle',
      descriptionKey: 'achMilestoneFirstTitleDesc',
      hint: 'The first division championship.',
      kind: AchievementKind.milestone,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2, tierCount: 1),
      milestoneReward: economy.milestoneCareerFirstTitle,
    ),
    AchievementDefinition(
      id: 'milestone_first_legendary',
      category: 'squad',
      metricId: 'legendaryCardsOwned',
      titleKey: 'achMilestoneFirstLegendary',
      descriptionKey: 'achMilestoneFirstLegendaryDesc',
      hint: 'First legendary card owned.',
      kind: AchievementKind.milestone,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2, tierCount: 1),
      milestoneReward: economy.milestoneSquadFirstLegendary,
    ),
    AchievementDefinition(
      id: 'milestone_first_epic',
      category: 'squad',
      metricId: 'epicCardsOwned',
      titleKey: 'achMilestoneFirstEpic',
      descriptionKey: 'achMilestoneFirstEpicDesc',
      hint: 'First epic card owned.',
      kind: AchievementKind.milestone,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2, tierCount: 1),
      milestoneReward: economy.milestoneSquadFirstEpic,
    ),
    AchievementDefinition(
      id: 'milestone_first_legendary_pull',
      category: 'packs',
      metricId: 'legendaryPulls',
      titleKey: 'achMilestoneFirstLegendaryPull',
      descriptionKey: 'achMilestoneFirstLegendaryPullDesc',
      hint: 'First legendary pulled from a pack.',
      kind: AchievementKind.milestone,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2, tierCount: 1),
      milestoneReward: economy.milestonePacksFirstLegendaryPull,
    ),
    AchievementDefinition(
      id: 'milestone_first_million',
      category: 'economy',
      metricId: 'lifetimeCoinsEarned',
      titleKey: 'achMilestoneFirstMillion',
      descriptionKey: 'achMilestoneFirstMillionDesc',
      hint: 'Lifetime earnings pass one million coins.',
      kind: AchievementKind.milestone,
      ladder: _mk(baseThreshold: 1_000_000, thresholdRatio: 2, tierCount: 1),
      milestoneReward: economy.milestoneEconomyFirstMillion,
    ),
    AchievementDefinition(
      id: 'milestone_first_season',
      category: 'loyalty',
      metricId: 'seasonsCompleted',
      titleKey: 'achMilestoneFirstSeason',
      descriptionKey: 'achMilestoneFirstSeasonDesc',
      hint: 'The first completed season.',
      kind: AchievementKind.milestone,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2, tierCount: 1),
      milestoneReward: economy.milestoneLoyaltyFirstSeason,
    ),
    AchievementDefinition(
      id: 'milestone_first_facility_max',
      category: 'campus',
      metricId: 'facilityLevelsAtMax',
      titleKey: 'achMilestoneFirstFacilityMax',
      descriptionKey: 'achMilestoneFirstFacilityMaxDesc',
      hint: 'One facility reaches its maximum level.',
      kind: AchievementKind.milestone,
      ladder: _mk(baseThreshold: 1, thresholdRatio: 2, tierCount: 1),
      milestoneReward: economy.milestoneCampusFirstFacilityMax,
    ),
  ];

  /// Every definition, categories in display order then ladders
  /// before milestones inside each category.
  ///
  /// Perf pass 2026-11-12 (LOW): the getter used to regroup the 42
  /// definitions into a fresh map + list on EVERY read — and it is
  /// read all over (the screen's two header counters alone call it
  /// once per definition per build). The catalog is immutable
  /// (compile-time lists, fixed categories), so the grouping is
  /// computed once and memoized.
  static List<AchievementDefinition> get definitions {
    return _definitionsCached ??= _buildDefinitions();
  }

  static List<AchievementDefinition>? _definitionsCached;

  static List<AchievementDefinition> _buildDefinitions() {
    final byCat = <String, List<AchievementDefinition>>{};
    for (final d in [..._endless, ..._milestones]) {
      byCat.putIfAbsent(d.category, () => []).add(d);
    }
    return [
      for (final c in categories)
        ...?byCat[c.id],
    ];
  }

  /// The definition with [id], or null.
  static AchievementDefinition? byId(String id) =>
      definitions.firstWhereOrNull((d) => d.id == id);

  // ---- Titles ---------------------------------------------------------
  //
  // 16 achievement titles (tier-conferred, prestige-only — no coins)
  // + the division championship titles (seeded 1..5, on demand after).

  /// Titles are PRESTIGE with a capped registry: every flagship
  /// confers at rungs 3 and 6 (two titles each — tier 9+ confers
  /// nothing new; the ladder keeps climbing for coins-asymptote and
  /// badge metals). Adding a third title to a flagship = one entry
  /// here + one key pair in each arb: the registry stays the truth.
  static const List<TitleDefinition> achievementTitles = [
    TitleDefinition(id: 'career_wins-title1', l10nKey: 'achTitleCareerWins1'),
    TitleDefinition(id: 'career_wins-title2', l10nKey: 'achTitleCareerWins2'),
    TitleDefinition(
      id: 'career_unbeaten_streak-title1',
      l10nKey: 'achTitleUnbeaten1',
    ),
    TitleDefinition(
      id: 'career_unbeaten_streak-title2',
      l10nKey: 'achTitleUnbeaten2',
    ),
    TitleDefinition(id: 'attack_goals-title1', l10nKey: 'achTitleGoals1'),
    TitleDefinition(id: 'attack_goals-title2', l10nKey: 'achTitleGoals2'),
    TitleDefinition(id: 'defence_clean_sheets-title1', l10nKey: 'achTitleCleanSheets1'),
    TitleDefinition(id: 'defence_clean_sheets-title2', l10nKey: 'achTitleCleanSheets2'),
    TitleDefinition(id: 'silverware_titles-title1', l10nKey: 'achTitleTitles1'),
    TitleDefinition(id: 'silverware_titles-title2', l10nKey: 'achTitleTitles2'),
    TitleDefinition(id: 'squad_legendaries-title1', l10nKey: 'achTitleLegendaries1'),
    TitleDefinition(id: 'squad_legendaries-title2', l10nKey: 'achTitleLegendaries2'),
    TitleDefinition(id: 'packs_opened-title1', l10nKey: 'achTitlePacks1'),
    TitleDefinition(id: 'economy_lifetime_earned-title1', l10nKey: 'achTitleCoins1'),
    TitleDefinition(id: 'loyalty_seasons-title1', l10nKey: 'achTitleSeasons1'),
    TitleDefinition(id: 'mastermind_tactics_changed-title1', l10nKey: 'achTitleMastermind1'),
      TitleDefinition(id: 'packs_opened-title2', l10nKey: 'achTitlePacks2'),
    TitleDefinition(id: 'economy_lifetime_earned-title2', l10nKey: 'achTitleCoins2'),
    TitleDefinition(id: 'loyalty_seasons-title2', l10nKey: 'achTitleSeasons2'),
    TitleDefinition(id: 'mastermind_tactics_changed-title2', l10nKey: 'achTitleMastermind2'),
];

  /// The seeded division championship titles (divisions 1..5).
  static List<DivisionTitleDefinition> get seededDivisionTitles => [
    for (final d in DivisionTitleDefinition.seededDivisions)
      DivisionTitleDefinition(division: d),
  ];

  /// The division championship title for ANY division — generated on
  /// demand beyond the seeded five (the ladder is endless upward,
  /// so are its titles).
  static DivisionTitleDefinition divisionChampionTitle(int division) =>
      seededDivisionTitles.length >= division && division >= 1
      ? seededDivisionTitles[division - 1]
      : DivisionTitleDefinition(division: division);

  /// Every title id the game knows: achievement-conferred + division
  /// championships (seeded horizon only — deeper divisions generate
  /// the same id pattern on demand).
  static List<String> get allTitleIds => [
    for (final t in achievementTitles) t.id,
    for (final t in seededDivisionTitles) t.id,
  ];
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
