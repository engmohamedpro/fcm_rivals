// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FCM Rivals';

  @override
  String get navSeason => 'Season';

  @override
  String get navTeam => 'Team';

  @override
  String get navCollection => 'Collection';

  @override
  String get navCampus => 'Campus';

  @override
  String get navStore => 'Store';

  @override
  String get createYourClub => 'Create your club';

  @override
  String get clubNameLabel => 'Club name';

  @override
  String get clubNameHint => 'The name on the crest';

  @override
  String get managerNameLabel => 'Manager name';

  @override
  String get managerNameHint => 'How the commentary calls you';

  @override
  String get chooseCrest => 'Choose your crest';

  @override
  String get chooseFormation => 'Starter formation';

  @override
  String get startClub => 'START CLUB';

  @override
  String get startSeason => 'Start your first season';

  @override
  String get playMatch => 'Play match';

  @override
  String get completeSeason => 'Complete season';

  @override
  String startSeasonInDivision(int division) {
    return 'Start season in division $division';
  }

  @override
  String nextFixtureRound(int round) {
    return 'Next fixture · round $round';
  }

  @override
  String get noFixtureReady => 'No fixture ready — refreshing.';

  @override
  String get bestSquadSelected => 'Best squad selected';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageEn => 'English';

  @override
  String get languageAr => 'العربية';

  @override
  String get languageSystem => 'System';

  @override
  String get matchSpeedLabel => 'Match playback speed';

  @override
  String get settingsTitle => 'Settings';

  @override
  String coinCompactMillions(String value) {
    return '${value}M';
  }

  @override
  String coinCompactThousands(String value) {
    return '${value}K';
  }

  @override
  String get openPacksHint =>
      'Open packs to collect players, then tap Auto Pick.';

  @override
  String get clubCrestSection => 'CLUB CREST';

  @override
  String get crestShapeLabel => 'Shape';

  @override
  String get crestPrimaryLabel => 'Primary colour';

  @override
  String get crestSecondaryLabel => 'Secondary colour';

  @override
  String get crestIconLabel => 'Icon';

  @override
  String get crestPatternLabel => 'Pattern';

  @override
  String get starterFormationSection => 'STARTER FORMATION';

  @override
  String get startManaging => 'Start managing';

  @override
  String get fieldRequired => 'Required';

  @override
  String get clubNameHintField => 'The name on the crest';

  @override
  String get managerNameHintField => 'How the commentary calls you';

  @override
  String packsSoldFor(String coins) {
    return 'Sold for $coins coins';
  }

  @override
  String get packsNotEnoughCoins => 'Not enough coins for another pack';

  @override
  String get packsNewCard => 'New';

  @override
  String get revealBack => 'Back';

  @override
  String get revealSell => 'Sell';

  @override
  String get revealUpgrade => 'Upgrade';

  @override
  String get liveTacticsTitle => 'Touchline';

  @override
  String get liveTacticsCancelSelection => 'Cancel selection';

  @override
  String get tacticsInPossessionTitle => 'In Possession';

  @override
  String get tacticsOutOfPossessionTitle => 'Out of Possession';

  @override
  String get tacticsTransitionsTitle => 'Transitions';

  @override
  String get tacticsSectionDefault => 'Default setup';

  @override
  String get tacticsLabel => 'Tactics';

  @override
  String get tacticsBuildUp => 'Build-up';

  @override
  String get tacticsTempo => 'Tempo';

  @override
  String get tacticsWidth => 'Width';

  @override
  String get tacticsFinalThird => 'Final third';

  @override
  String get buildUpPlayOut => 'Play Out from the Back';

  @override
  String get buildUpMixed => 'Mixed Build-Up';

  @override
  String get buildUpLongBall => 'Long Ball';

  @override
  String get tempoSlow => 'Slow';

  @override
  String get tempoStandard => 'Standard';

  @override
  String get tempoFast => 'Fast';

  @override
  String get widthNarrow => 'Narrow';

  @override
  String get widthStandardWidth => 'Standard';

  @override
  String get widthWide => 'Wide';

  @override
  String get finalThirdWorkBall => 'Work Ball into Box';

  @override
  String get finalThirdBalanced => 'Balanced';

  @override
  String get finalThirdEarlyCrosses => 'Early Crosses';

  @override
  String get finalThirdShootOnSight => 'Shoot on Sight';

  @override
  String get tacticsDefensiveLine => 'Defensive line';

  @override
  String get tacticsPressing => 'Pressing';

  @override
  String get tacticsTackling => 'Tackling';

  @override
  String get tacticsOffsideTrap => 'Offside trap';

  @override
  String get lineDeep => 'Deep';

  @override
  String get lineStandard => 'Standard';

  @override
  String get lineHigh => 'High';

  @override
  String get pressLow => 'Low';

  @override
  String get pressMid => 'Mid';

  @override
  String get pressHigh => 'High';

  @override
  String get tackleClean => 'Clean';

  @override
  String get tackleBalanced => 'Balanced';

  @override
  String get tackleAggressive => 'Aggressive';

  @override
  String get trapOn => 'On';

  @override
  String get trapOff => 'Off';

  @override
  String get trapDeepWarning =>
      'No benefit with a deep line — pure risk. Raise the line or turn the trap off.';

  @override
  String get tacticsCounterPress => 'Counter-press';

  @override
  String get tacticsAttackOnRecovery => 'Attack on recovery';

  @override
  String get tacticsRestDefence => 'Rest defence';

  @override
  String get cpRetreat => 'Retreat to Shape';

  @override
  String get cpBalanced => 'Balanced';

  @override
  String get cpImmediate => 'Immediate Counter-Press';

  @override
  String get arPatient => 'Patient';

  @override
  String get arBalanced => 'Balanced';

  @override
  String get arFast => 'Fast Counter';

  @override
  String get rdConservative => 'Conservative · 4 back';

  @override
  String get rdStandard => 'Standard · 3 back';

  @override
  String get rdAggressive => 'Aggressive · 2 back';

  @override
  String injuryCommentaryKnock(Object player) {
    return '$player picks up a knock and can\'t continue.';
  }

  @override
  String injuryCommentaryMuscle(Object player) {
    return '$player pulls up with a muscle injury — his day is done.';
  }

  @override
  String injuryCommentarySerious(Object player) {
    return '$player suffers a serious injury. That doesn\'t look good.';
  }

  @override
  String get injuryCommentaryPlaysShort =>
      ' They have no replacement and play a man short.';

  @override
  String get statInjuries => 'Injuries';

  @override
  String get cardClassPremium => 'PREMIUM';

  @override
  String get packRarityRare => 'Rare';

  @override
  String get packRarityEpic => 'Epic';

  @override
  String get packRarityLegendary => 'Legendary';

  @override
  String get packRarityPremium => 'Premium';

  @override
  String injuryBadgeSemantics(int n) {
    return 'Injured, out for $n matches';
  }

  @override
  String injuryOutForMatches(int n) {
    return 'Out for $n matches';
  }

  @override
  String injuryChipOut(int n) {
    return 'OUT $n';
  }

  @override
  String get prematchMedicalTitle => 'Medical room';

  @override
  String get injuryStaminaRiskHint => 'Low fitness raises injury risk.';

  @override
  String get injuryKindKnock => 'Knock';

  @override
  String get injuryKindMuscle => 'Muscle injury';

  @override
  String get injuryKindSerious => 'Serious injury';

  @override
  String reportInjuries(int n) {
    return '$n player(s) injured';
  }

  @override
  String get tacticsMentality => 'Mentality';

  @override
  String get teamChemistry => 'Chemistry';

  @override
  String get mentalityVeryDefensive => 'Very Defensive';

  @override
  String get mentalityDefensive => 'Defensive';

  @override
  String get mentalityCautious => 'Cautious';

  @override
  String get mentalityBalanced => 'Balanced';

  @override
  String get mentalityPositive => 'Positive';

  @override
  String get mentalityAttacking => 'Attacking';

  @override
  String get mentalityVeryAttacking => 'Very Attacking';

  @override
  String get achCareerTitle => 'Career';

  @override
  String get achCareerSubtitle => 'The touchline years';

  @override
  String get achAttackTitle => 'Attack';

  @override
  String get achAttackSubtitle => 'Goals win games';

  @override
  String get achDefenceTitle => 'Defence';

  @override
  String get achDefenceSubtitle => 'Solid at the back';

  @override
  String get achSilverwareTitle => 'Silverware';

  @override
  String get achSilverwareSubtitle => 'Titles and promotions';

  @override
  String get achSquadTitle => 'Squad';

  @override
  String get achSquadSubtitle => 'The collection you build';

  @override
  String get achPacksTitle => 'Packs';

  @override
  String get achPacksSubtitle => 'Ripping open the market';

  @override
  String get achEconomyTitle => 'Economy';

  @override
  String get achEconomySubtitle => 'The coin ledger';

  @override
  String get achCampusTitle => 'Campus';

  @override
  String get achCampusSubtitle => 'Built brick by brick';

  @override
  String get achLoyaltyTitle => 'Loyalty';

  @override
  String get achLoyaltySubtitle => 'Season after season';

  @override
  String get achMastermindTitle => 'Mastermind';

  @override
  String get achMastermindSubtitle => 'The thinking coach';

  @override
  String get achCareerMatches => 'Matches Managed';

  @override
  String get achCareerMatchesDesc =>
      'Every match you have managed, from the first whistle.';

  @override
  String get achCareerWins => 'Wins';

  @override
  String get achCareerWinsDesc => 'Matches won across your career.';

  @override
  String get achCareerWinStreak => 'Winning Streak';

  @override
  String get achCareerWinStreakDesc =>
      'Your longest run of back-to-back victories.';

  @override
  String get achCareerUnbeatenStreak => 'Unbeaten Run';

  @override
  String get achCareerUnbeatenStreakDesc =>
      'Wins and draws without tasting defeat.';

  @override
  String get achAttackGoals => 'Goals Scored';

  @override
  String get achAttackGoalsDesc =>
      'Every goal your club has put past a keeper.';

  @override
  String get achAttackGoalsSingleMatch => 'Goal Haul';

  @override
  String get achAttackGoalsSingleMatchDesc =>
      'The most goals your club scored in one match.';

  @override
  String get achDefenceCleanSheets => 'Clean Sheets';

  @override
  String get achDefenceCleanSheetsDesc => 'Matches finished without conceding.';

  @override
  String get achDefenceShutoutStreak => 'Shutout Streak';

  @override
  String get achDefenceShutoutStreakDesc =>
      'Consecutive matches keeping the nets untouched.';

  @override
  String get achSilverwareTitles => 'Champion';

  @override
  String get achSilverwareTitlesDesc =>
      'Division championships won, at any level.';

  @override
  String get achSilverwarePromotions => 'Promotions';

  @override
  String get achSilverwarePromotionsDesc =>
      'Seasons finished with a climb up the ladder.';

  @override
  String get achSquadCardsOwned => 'Cards Owned';

  @override
  String get achSquadCardsOwnedDesc => 'The players your club holds right now.';

  @override
  String get achSquadLegendaries => 'Legendary Squad';

  @override
  String get achSquadLegendariesDesc =>
      'Legendary cards (80+ overall) owned at once.';

  @override
  String get achSquadEpics => 'Epic Squad';

  @override
  String get achSquadEpicsDesc => 'Epic cards (70–79 overall) owned at once.';

  @override
  String get achSquadUpgrades => 'Merges Completed';

  @override
  String get achSquadUpgradesDesc => 'Duplicates merged into stronger cards.';

  @override
  String get achSquadHighestUpgrade => 'Masterwork';

  @override
  String get achSquadHighestUpgradeDesc =>
      'The highest upgrade level one card has reached.';

  @override
  String get achPacksOpened => 'Packs Opened';

  @override
  String get achPacksOpenedDesc =>
      'Every pack ripped open, whatever its source.';

  @override
  String get achPacksPurchased => 'Packs Purchased';

  @override
  String get achPacksPurchasedDesc => 'Packs bought with hard-earned coins.';

  @override
  String get achPacksRewarded => 'Rewards Earned';

  @override
  String get achPacksRewardedDesc => 'Packs granted by season rewards.';

  @override
  String get achEconomyLifetimeEarned => 'Lifetime Earnings';

  @override
  String get achEconomyLifetimeEarnedDesc =>
      'Every coin the club has ever earned.';

  @override
  String get achEconomyPackSpend => 'Market Spending';

  @override
  String get achEconomyPackSpendDesc => 'Coins spent on the pack market.';

  @override
  String get achEconomyUpgradeSpend => 'Investment Spending';

  @override
  String get achEconomyUpgradeSpendDesc =>
      'Coins poured into upgrades and facilities.';

  @override
  String get achCampusFacilityLevels => 'Facility Levels';

  @override
  String get achCampusFacilityLevelsDesc =>
      'The sum of every level across your campus.';

  @override
  String get achLoyaltySeasons => 'Seasons Completed';

  @override
  String get achLoyaltySeasonsDesc =>
      'Full seasons seen through to the final whistle.';

  @override
  String get achMastermindTacticsChanged => 'Touchline Calls';

  @override
  String get achMastermindTacticsChangedDesc =>
      'Tactical instructions changed from the dugout.';

  @override
  String get achMilestoneFirstWin => 'First Victory';

  @override
  String get achMilestoneFirstWinDesc => 'The win that started it all.';

  @override
  String get achMilestoneFirstTitle => 'First Championship';

  @override
  String get achMilestoneFirstTitleDesc => 'Lift your first division title.';

  @override
  String get achMilestoneFirstLegendary => 'The Golden Signature';

  @override
  String get achMilestoneFirstLegendaryDesc => 'Own your first legendary card.';

  @override
  String get achMilestoneFirstEpic => 'A Cut Above';

  @override
  String get achMilestoneFirstEpicDesc => 'Own your first epic card.';

  @override
  String get achMilestoneFirstLegendaryPull => 'Golden Pull';

  @override
  String get achMilestoneFirstLegendaryPullDesc =>
      'Pull a legendary card from a pack.';

  @override
  String get achMilestoneFirstMillion => 'Millionaire Manager';

  @override
  String get achMilestoneFirstMillionDesc =>
      'Earn one million coins in your career.';

  @override
  String get achMilestoneFirstSeason => 'The Long Haul';

  @override
  String get achMilestoneFirstSeasonDesc => 'Complete your first full season.';

  @override
  String get achMilestoneFirstFacilityMax => 'Campus Landmark';

  @override
  String get achMilestoneFirstFacilityMaxDesc =>
      'Take one facility to its maximum level.';

  @override
  String get achTitleCareerWins1 => 'The Winner';

  @override
  String get achTitleCareerWins2 => 'Serial Winner';

  @override
  String get achTitleUnbeaten1 => 'Unbeaten';

  @override
  String get achTitleUnbeaten2 => 'Fortress Manager';

  @override
  String get achTitleGoals1 => 'The Marksman';

  @override
  String get achTitleGoals2 => 'Goal Machine';

  @override
  String get achTitleCleanSheets1 => 'The Wall';

  @override
  String get achTitleCleanSheets2 => 'Locked Down';

  @override
  String get achTitleTitles1 => 'Champion';

  @override
  String get achTitleTitles2 => 'Dynasty Builder';

  @override
  String get achTitleLegendaries1 => 'Galactico';

  @override
  String get achTitleLegendaries2 => 'Squad of Legends';

  @override
  String get achTitlePacks1 => 'Market Raider';

  @override
  String get achTitleCoins1 => 'The Banker';

  @override
  String get achTitleSeasons1 => 'Loyal Gaffer';

  @override
  String get achTitleMastermind1 => 'The Tactician';

  @override
  String achievementDivisionChampion(int division) {
    return 'Division $division Champion';
  }

  @override
  String get achCareerDraws => 'Shares of the Spoils';

  @override
  String get achCareerDrawsDesc => 'Matches that ended all square.';

  @override
  String get achCareerLosses => 'Hard Lessons';

  @override
  String get achCareerLossesDesc =>
      'The defeats that shaped the manager you became.';

  @override
  String get achDefenceGoalsAgainst => 'Goals Conceded';

  @override
  String get achDefenceGoalsAgainstDesc =>
      'Every goal shipped at the wrong end — the counterweight of the clean sheets.';

  @override
  String get achDefenceScoredFirst => 'First Blood';

  @override
  String get achDefenceScoredFirstDesc =>
      'Matches where your club struck the opening goal.';

  @override
  String get achCareerAwayMatches => 'Travelling Support';

  @override
  String get achCareerAwayMatchesDesc => 'Matches managed on hostile ground.';

  @override
  String get achEconomyPlayerSales => 'Market Sales';

  @override
  String get achEconomyPlayerSalesDesc =>
      'Players moved on for the right price.';

  @override
  String get achLoyaltyRelegations => 'Weathered the Storm';

  @override
  String get achLoyaltyRelegationsDesc =>
      'Relegations endured without walking away.';

  @override
  String get achPacksStartingPacks => 'From the Ground Up';

  @override
  String get achPacksStartingPacksDesc =>
      'The starter packs that built the first squad.';

  @override
  String get achCareerHomeMatches => 'Home Fortress';

  @override
  String get achCareerHomeMatchesDesc =>
      'Matches managed in front of your own crowd.';

  @override
  String get achCampusRecoveryLevel => 'The Recovery Room';

  @override
  String get achCampusRecoveryLevelDesc =>
      'The Recovery Centre\'s level — where tired legs come back.';

  @override
  String get achTitlePacks2 => 'Market Mogul';

  @override
  String get achTitleCoins2 => 'The Magnate';

  @override
  String get achTitleSeasons2 => 'Club Legend';

  @override
  String get achTitleMastermind2 => 'The Professor';

  @override
  String get navAchievements => 'Achievements';

  @override
  String get achHubTitle => 'The Trophy Room';

  @override
  String achHubSubtitle(int claimed, int total) {
    return '$claimed of $total tiers claimed';
  }

  @override
  String get achClaimedLabel => 'Claimed';

  @override
  String get achClaimAction => 'Claim';

  @override
  String get teamOpenCollection => 'Full collection';

  @override
  String achClaimedRungs(int count) {
    return '$count claimed';
  }

  @override
  String get navProfile => 'Profile';

  @override
  String get profileUnsetName => 'The New Coach';

  @override
  String get profileUnsetClub => 'A new club';

  @override
  String profileJoined(int year, int month, int day) {
    return 'Here since $year-$month-$day';
  }

  @override
  String get profileStatMatches => 'Matches';

  @override
  String get profileStatWinRate => 'Win rate';

  @override
  String get profileStatWins => 'Wins';

  @override
  String get profileStatDraws => 'Draws';

  @override
  String get profileStatLosses => 'Losses';

  @override
  String get profileStatGoalsFor => 'Goals for';

  @override
  String get profileStatGoalsAgainst => 'Goals against';

  @override
  String get profileStatCleanSheets => 'Clean sheets';

  @override
  String get profileStatWinStreak => 'Best win run';

  @override
  String get profileStatUnbeaten => 'Best unbeaten';

  @override
  String get profileNoMatches => 'Starts now';

  @override
  String profilePercent(num value) {
    return '$value%';
  }

  @override
  String profileTitlesCount(int count) {
    return '$count trophies won';
  }

  @override
  String get profileNoTitles => 'The cabinet is waiting';

  @override
  String profileDivisionPlate(int division, int count) {
    return 'Div $division ×$count';
  }

  @override
  String get profileSeasonHistory => 'Season history';

  @override
  String get profileNoSeasons => 'Your career starts now';

  @override
  String profileSeasonTitle(int ordinal, int division) {
    return 'Season $ordinal · Div $division';
  }

  @override
  String profileFinalPosition(int position) {
    return 'Finished $position';
  }

  @override
  String get profileOutcomePromoted => 'Promoted';

  @override
  String get profileOutcomeRelegated => 'Relegated';

  @override
  String get profileOutcomeStayed => 'Stayed';

  @override
  String get badgeCabinetTitle => 'The Badge Cabinet';

  @override
  String get titlesGalleryTitle => 'Titles';

  @override
  String get titleEquipAction => 'Wear';

  @override
  String get titleUnequipAction => 'Worn';

  @override
  String titleSourceAchievement(String achievement, int threshold) {
    return 'Earned at $achievement tier $threshold';
  }

  @override
  String titleSourceDivision(int division) {
    return 'Finish 1st in Division $division';
  }
}
