import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'FCM Rivals'**
  String get appTitle;

  /// No description provided for @navSeason.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get navSeason;

  /// No description provided for @navTeam.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get navTeam;

  /// No description provided for @navCollection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get navCollection;

  /// No description provided for @navCampus.
  ///
  /// In en, this message translates to:
  /// **'Campus'**
  String get navCampus;

  /// No description provided for @navStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get navStore;

  /// No description provided for @createYourClub.
  ///
  /// In en, this message translates to:
  /// **'Create your club'**
  String get createYourClub;

  /// No description provided for @createYourClubIntro.
  ///
  /// In en, this message translates to:
  /// **'You start with coins and 22 free packs — two for every position in your starter formation.'**
  String get createYourClubIntro;

  /// No description provided for @clubNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Club name'**
  String get clubNameLabel;

  /// No description provided for @clubNameHint.
  ///
  /// In en, this message translates to:
  /// **'The name on the crest'**
  String get clubNameHint;

  /// No description provided for @managerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Manager name'**
  String get managerNameLabel;

  /// No description provided for @managerNameHint.
  ///
  /// In en, this message translates to:
  /// **'How the commentary calls you'**
  String get managerNameHint;

  /// No description provided for @chooseCrest.
  ///
  /// In en, this message translates to:
  /// **'Choose your crest'**
  String get chooseCrest;

  /// No description provided for @chooseFormation.
  ///
  /// In en, this message translates to:
  /// **'Starter formation'**
  String get chooseFormation;

  /// No description provided for @startClub.
  ///
  /// In en, this message translates to:
  /// **'START CLUB'**
  String get startClub;

  /// No description provided for @startSeason.
  ///
  /// In en, this message translates to:
  /// **'Start your first season'**
  String get startSeason;

  /// No description provided for @playMatch.
  ///
  /// In en, this message translates to:
  /// **'Play match'**
  String get playMatch;

  /// No description provided for @completeSeason.
  ///
  /// In en, this message translates to:
  /// **'Complete season'**
  String get completeSeason;

  /// No description provided for @startSeasonInDivision.
  ///
  /// In en, this message translates to:
  /// **'Start season in division {division}'**
  String startSeasonInDivision(int division);

  /// No description provided for @nextFixtureRound.
  ///
  /// In en, this message translates to:
  /// **'Next fixture · round {round}'**
  String nextFixtureRound(int round);

  /// No description provided for @noFixtureReady.
  ///
  /// In en, this message translates to:
  /// **'No fixture ready — refreshing.'**
  String get noFixtureReady;

  /// No description provided for @bestSquadSelected.
  ///
  /// In en, this message translates to:
  /// **'Best squad selected'**
  String get bestSquadSelected;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @languageAr.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageAr;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @matchSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Match playback speed'**
  String get matchSpeedLabel;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @coinCompactMillions.
  ///
  /// In en, this message translates to:
  /// **'{value}M'**
  String coinCompactMillions(String value);

  /// No description provided for @coinCompactThousands.
  ///
  /// In en, this message translates to:
  /// **'{value}K'**
  String coinCompactThousands(String value);

  /// No description provided for @openPacksHint.
  ///
  /// In en, this message translates to:
  /// **'Open packs to collect players, then tap Auto Pick.'**
  String get openPacksHint;

  /// No description provided for @clubCrestSection.
  ///
  /// In en, this message translates to:
  /// **'CLUB CREST'**
  String get clubCrestSection;

  /// No description provided for @starterFormationSection.
  ///
  /// In en, this message translates to:
  /// **'STARTER FORMATION'**
  String get starterFormationSection;

  /// No description provided for @starterFormationIntro.
  ///
  /// In en, this message translates to:
  /// **'This is your starter formation — your team starts in this shape and your 22 free packs match its positions. You can change it any time later from the Team tab.'**
  String get starterFormationIntro;

  /// No description provided for @startManaging.
  ///
  /// In en, this message translates to:
  /// **'Start managing'**
  String get startManaging;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// No description provided for @clubNameHintField.
  ///
  /// In en, this message translates to:
  /// **'The name on the crest'**
  String get clubNameHintField;

  /// No description provided for @managerNameHintField.
  ///
  /// In en, this message translates to:
  /// **'How the commentary calls you'**
  String get managerNameHintField;

  /// No description provided for @tapAgainToSkip.
  ///
  /// In en, this message translates to:
  /// **'Tap outside again to skip without a pep talk'**
  String get tapAgainToSkip;

  /// No description provided for @postMatchRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Post-match recovery'**
  String get postMatchRecoveryTitle;

  /// No description provided for @postMatchRecoveryIntro.
  ///
  /// In en, this message translates to:
  /// **'One focus for the squad on the rest days ahead:'**
  String get postMatchRecoveryIntro;

  /// No description provided for @recoveryBonusEffect.
  ///
  /// In en, this message translates to:
  /// **'+{bonus}% natural recovery'**
  String recoveryBonusEffect(int bonus);

  /// No description provided for @pepTalkRestEveryone.
  ///
  /// In en, this message translates to:
  /// **'Rest, everyone deserves it!'**
  String get pepTalkRestEveryone;

  /// No description provided for @pepTalkFocusExhausted.
  ///
  /// In en, this message translates to:
  /// **'Focus on exhausted players!'**
  String get pepTalkFocusExhausted;

  /// No description provided for @pepTalkRewardSubstitutes.
  ///
  /// In en, this message translates to:
  /// **'Reward the substitutes!'**
  String get pepTalkRewardSubstitutes;

  /// No description provided for @pepTalkEveryoneGaveBest.
  ///
  /// In en, this message translates to:
  /// **'Everyone gave their best!'**
  String get pepTalkEveryoneGaveBest;

  /// No description provided for @watchAdBoostedRecovery.
  ///
  /// In en, this message translates to:
  /// **'Watch ad: boosted recovery'**
  String get watchAdBoostedRecovery;

  /// No description provided for @watchAdBoostedEffect.
  ///
  /// In en, this message translates to:
  /// **'+15% natural recovery for the whole squad (GDD 19.3)'**
  String get watchAdBoostedEffect;

  /// No description provided for @noPepTalkDefault.
  ///
  /// In en, this message translates to:
  /// **'No pep talk — default recovery'**
  String get noPepTalkDefault;

  /// No description provided for @packsSoldFor.
  ///
  /// In en, this message translates to:
  /// **'Sold for {coins} coins'**
  String packsSoldFor(String coins);

  /// No description provided for @packsNotEnoughCoins.
  ///
  /// In en, this message translates to:
  /// **'Not enough coins for another pack'**
  String get packsNotEnoughCoins;

  /// No description provided for @liveTacticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Touchline'**
  String get liveTacticsTitle;

  /// No description provided for @liveTacticsCancelSelection.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get liveTacticsCancelSelection;

  /// No description provided for @pepTalkRecoveryConfirmation.
  ///
  /// In en, this message translates to:
  /// **'{pepTalk} (+{bonus}% recovery)'**
  String pepTalkRecoveryConfirmation(String pepTalk, int bonus);

  /// No description provided for @tacticsInPossessionTitle.
  ///
  /// In en, this message translates to:
  /// **'In Possession'**
  String get tacticsInPossessionTitle;

  /// No description provided for @tacticsInPossessionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Build-up, tempo, width and final-third approach'**
  String get tacticsInPossessionSubtitle;

  /// No description provided for @tacticsOutOfPossessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Out of Possession'**
  String get tacticsOutOfPossessionTitle;

  /// No description provided for @tacticsOutOfPossessionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Defensive line, pressing, tackling and the offside trap'**
  String get tacticsOutOfPossessionSubtitle;

  /// No description provided for @tacticsTransitionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Transitions'**
  String get tacticsTransitionsTitle;

  /// No description provided for @tacticsTransitionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Counter-press, counter-attacking and rest defence'**
  String get tacticsTransitionsSubtitle;

  /// No description provided for @tacticsSectionDefault.
  ///
  /// In en, this message translates to:
  /// **'Default setup'**
  String get tacticsSectionDefault;

  /// No description provided for @tacticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tactics'**
  String get tacticsLabel;

  /// No description provided for @tacticsBuildUp.
  ///
  /// In en, this message translates to:
  /// **'Build-up'**
  String get tacticsBuildUp;

  /// No description provided for @tacticsTempo.
  ///
  /// In en, this message translates to:
  /// **'Tempo'**
  String get tacticsTempo;

  /// No description provided for @tacticsWidth.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get tacticsWidth;

  /// No description provided for @tacticsFinalThird.
  ///
  /// In en, this message translates to:
  /// **'Final third'**
  String get tacticsFinalThird;

  /// No description provided for @tacticsEstPossession.
  ///
  /// In en, this message translates to:
  /// **'Est. possession: {share}%'**
  String tacticsEstPossession(Object share);

  /// No description provided for @buildUpPlayOut.
  ///
  /// In en, this message translates to:
  /// **'Play Out from the Back'**
  String get buildUpPlayOut;

  /// No description provided for @buildUpMixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed Build-Up'**
  String get buildUpMixed;

  /// No description provided for @buildUpLongBall.
  ///
  /// In en, this message translates to:
  /// **'Long Ball'**
  String get buildUpLongBall;

  /// No description provided for @tempoSlow.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get tempoSlow;

  /// No description provided for @tempoStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get tempoStandard;

  /// No description provided for @tempoFast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get tempoFast;

  /// No description provided for @widthNarrow.
  ///
  /// In en, this message translates to:
  /// **'Narrow'**
  String get widthNarrow;

  /// No description provided for @widthStandardWidth.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get widthStandardWidth;

  /// No description provided for @widthWide.
  ///
  /// In en, this message translates to:
  /// **'Wide'**
  String get widthWide;

  /// No description provided for @finalThirdWorkBall.
  ///
  /// In en, this message translates to:
  /// **'Work Ball into Box'**
  String get finalThirdWorkBall;

  /// No description provided for @finalThirdBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get finalThirdBalanced;

  /// No description provided for @finalThirdEarlyCrosses.
  ///
  /// In en, this message translates to:
  /// **'Early Crosses'**
  String get finalThirdEarlyCrosses;

  /// No description provided for @finalThirdShootOnSight.
  ///
  /// In en, this message translates to:
  /// **'Shoot on Sight'**
  String get finalThirdShootOnSight;

  /// No description provided for @tacticsDefensiveLine.
  ///
  /// In en, this message translates to:
  /// **'Defensive line'**
  String get tacticsDefensiveLine;

  /// No description provided for @tacticsPressing.
  ///
  /// In en, this message translates to:
  /// **'Pressing'**
  String get tacticsPressing;

  /// No description provided for @tacticsTackling.
  ///
  /// In en, this message translates to:
  /// **'Tackling'**
  String get tacticsTackling;

  /// No description provided for @tacticsOffsideTrap.
  ///
  /// In en, this message translates to:
  /// **'Offside trap'**
  String get tacticsOffsideTrap;

  /// No description provided for @lineDeep.
  ///
  /// In en, this message translates to:
  /// **'Deep'**
  String get lineDeep;

  /// No description provided for @lineStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get lineStandard;

  /// No description provided for @lineHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get lineHigh;

  /// No description provided for @pressLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get pressLow;

  /// No description provided for @pressMid.
  ///
  /// In en, this message translates to:
  /// **'Mid'**
  String get pressMid;

  /// No description provided for @pressHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get pressHigh;

  /// No description provided for @tackleClean.
  ///
  /// In en, this message translates to:
  /// **'Clean'**
  String get tackleClean;

  /// No description provided for @tackleBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get tackleBalanced;

  /// No description provided for @tackleAggressive.
  ///
  /// In en, this message translates to:
  /// **'Aggressive'**
  String get tackleAggressive;

  /// No description provided for @trapOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get trapOn;

  /// No description provided for @trapOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get trapOff;

  /// No description provided for @trapDeepWarning.
  ///
  /// In en, this message translates to:
  /// **'No benefit with a deep line — pure risk. Raise the line or turn the trap off.'**
  String get trapDeepWarning;

  /// No description provided for @tacticsCounterPress.
  ///
  /// In en, this message translates to:
  /// **'Counter-press'**
  String get tacticsCounterPress;

  /// No description provided for @tacticsAttackOnRecovery.
  ///
  /// In en, this message translates to:
  /// **'Attack on recovery'**
  String get tacticsAttackOnRecovery;

  /// No description provided for @tacticsRestDefence.
  ///
  /// In en, this message translates to:
  /// **'Rest defence'**
  String get tacticsRestDefence;

  /// No description provided for @cpRetreat.
  ///
  /// In en, this message translates to:
  /// **'Retreat to Shape'**
  String get cpRetreat;

  /// No description provided for @cpBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get cpBalanced;

  /// No description provided for @cpImmediate.
  ///
  /// In en, this message translates to:
  /// **'Immediate Counter-Press'**
  String get cpImmediate;

  /// No description provided for @arPatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get arPatient;

  /// No description provided for @arBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get arBalanced;

  /// No description provided for @arFast.
  ///
  /// In en, this message translates to:
  /// **'Fast Counter'**
  String get arFast;

  /// No description provided for @rdConservative.
  ///
  /// In en, this message translates to:
  /// **'Conservative · 4 back'**
  String get rdConservative;

  /// No description provided for @rdStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard · 3 back'**
  String get rdStandard;

  /// No description provided for @rdAggressive.
  ///
  /// In en, this message translates to:
  /// **'Aggressive · 2 back'**
  String get rdAggressive;

  /// No description provided for @restDefenceHint.
  ///
  /// In en, this message translates to:
  /// **'More players back means cover but fewer joining attacks.'**
  String get restDefenceHint;

  /// No description provided for @injuryCommentaryKnock.
  ///
  /// In en, this message translates to:
  /// **'{player} picks up a knock and can\'t continue.'**
  String injuryCommentaryKnock(Object player);

  /// No description provided for @injuryCommentaryMuscle.
  ///
  /// In en, this message translates to:
  /// **'{player} pulls up with a muscle injury — his day is done.'**
  String injuryCommentaryMuscle(Object player);

  /// No description provided for @injuryCommentarySerious.
  ///
  /// In en, this message translates to:
  /// **'{player} suffers a serious injury. That doesn\'t look good.'**
  String injuryCommentarySerious(Object player);

  /// No description provided for @injuryCommentaryPlaysShort.
  ///
  /// In en, this message translates to:
  /// **' They have no replacement and play a man short.'**
  String get injuryCommentaryPlaysShort;

  /// No description provided for @statInjuries.
  ///
  /// In en, this message translates to:
  /// **'Injuries'**
  String get statInjuries;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
