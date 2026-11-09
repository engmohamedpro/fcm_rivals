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
  String get createYourClubIntro =>
      'You start with coins and 22 free packs — two for every position in your starter formation.';

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
  String get starterFormationSection => 'STARTER FORMATION';

  @override
  String get starterFormationIntro =>
      'This is your starter formation — your team starts in this shape and your 22 free packs match its positions. You can change it any time later from the Team tab.';

  @override
  String get startManaging => 'Start managing';

  @override
  String get fieldRequired => 'Required';

  @override
  String get clubNameHintField => 'The name on the crest';

  @override
  String get managerNameHintField => 'How the commentary calls you';

  @override
  String get tapAgainToSkip => 'Tap outside again to skip without a pep talk';

  @override
  String get postMatchRecoveryTitle => 'Post-match recovery';

  @override
  String get postMatchRecoveryIntro =>
      'One focus for the squad on the rest days ahead:';

  @override
  String recoveryBonusEffect(int bonus) {
    return '+$bonus% natural recovery';
  }

  @override
  String get pepTalkRestEveryone => 'Rest, everyone deserves it!';

  @override
  String get pepTalkFocusExhausted => 'Focus on exhausted players!';

  @override
  String get pepTalkRewardSubstitutes => 'Reward the substitutes!';

  @override
  String get pepTalkEveryoneGaveBest => 'Everyone gave their best!';

  @override
  String get watchAdBoostedRecovery => 'Watch ad: boosted recovery';

  @override
  String get watchAdBoostedEffect =>
      '+15% natural recovery for the whole squad (GDD 19.3)';

  @override
  String get noPepTalkDefault => 'No pep talk — default recovery';

  @override
  String packsSoldFor(String coins) {
    return 'Sold for $coins coins';
  }

  @override
  String get packsNotEnoughCoins => 'Not enough coins for another pack';

  @override
  String get liveTacticsTitle => 'Touchline';

  @override
  String get liveTacticsCancelSelection => 'Cancel selection';

  @override
  String pepTalkRecoveryConfirmation(String pepTalk, int bonus) {
    return '$pepTalk (+$bonus% recovery)';
  }

  @override
  String get tacticsInPossessionTitle => 'In Possession';

  @override
  String get tacticsInPossessionSubtitle =>
      'Build-up, tempo, width and final-third approach';

  @override
  String get tacticsOutOfPossessionTitle => 'Out of Possession';

  @override
  String get tacticsOutOfPossessionSubtitle =>
      'Defensive line, pressing, tackling and the offside trap';

  @override
  String get tacticsTransitionsTitle => 'Transitions';

  @override
  String get tacticsTransitionsSubtitle =>
      'Counter-press, counter-attacking and rest defence';

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
  String tacticsEstPossession(Object share) {
    return 'Est. possession: $share%';
  }

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
  String get restDefenceHint =>
      'More players back means cover but fewer joining attacks.';

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
  String get revealBannerPremium => 'PREMIUM PULL!';

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
}
