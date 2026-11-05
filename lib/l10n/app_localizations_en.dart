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
}
