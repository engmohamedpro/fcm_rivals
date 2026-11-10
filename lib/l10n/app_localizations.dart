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

  /// No description provided for @crestShapeLabel.
  ///
  /// In en, this message translates to:
  /// **'Shape'**
  String get crestShapeLabel;

  /// No description provided for @crestPrimaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary colour'**
  String get crestPrimaryLabel;

  /// No description provided for @crestSecondaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Secondary colour'**
  String get crestSecondaryLabel;

  /// No description provided for @crestIconLabel.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get crestIconLabel;

  /// No description provided for @crestPatternLabel.
  ///
  /// In en, this message translates to:
  /// **'Pattern'**
  String get crestPatternLabel;

  /// No description provided for @starterFormationSection.
  ///
  /// In en, this message translates to:
  /// **'STARTER FORMATION'**
  String get starterFormationSection;

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

  /// No description provided for @packsNewCard.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get packsNewCard;

  /// No description provided for @revealBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get revealBack;

  /// No description provided for @revealSell.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get revealSell;

  /// No description provided for @revealUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get revealUpgrade;

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

  /// No description provided for @tacticsInPossessionTitle.
  ///
  /// In en, this message translates to:
  /// **'In Possession'**
  String get tacticsInPossessionTitle;

  /// No description provided for @tacticsOutOfPossessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Out of Possession'**
  String get tacticsOutOfPossessionTitle;

  /// No description provided for @tacticsTransitionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Transitions'**
  String get tacticsTransitionsTitle;

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

  /// No description provided for @cardClassPremium.
  ///
  /// In en, this message translates to:
  /// **'PREMIUM'**
  String get cardClassPremium;

  /// No description provided for @packRarityRare.
  ///
  /// In en, this message translates to:
  /// **'Rare'**
  String get packRarityRare;

  /// No description provided for @packRarityEpic.
  ///
  /// In en, this message translates to:
  /// **'Epic'**
  String get packRarityEpic;

  /// No description provided for @packRarityLegendary.
  ///
  /// In en, this message translates to:
  /// **'Legendary'**
  String get packRarityLegendary;

  /// No description provided for @packRarityPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get packRarityPremium;

  /// No description provided for @injuryBadgeSemantics.
  ///
  /// In en, this message translates to:
  /// **'Injured, out for {n} matches'**
  String injuryBadgeSemantics(int n);

  /// No description provided for @injuryOutForMatches.
  ///
  /// In en, this message translates to:
  /// **'Out for {n} matches'**
  String injuryOutForMatches(int n);

  /// No description provided for @injuryChipOut.
  ///
  /// In en, this message translates to:
  /// **'OUT {n}'**
  String injuryChipOut(int n);

  /// No description provided for @prematchMedicalTitle.
  ///
  /// In en, this message translates to:
  /// **'Medical room'**
  String get prematchMedicalTitle;

  /// No description provided for @injuryStaminaRiskHint.
  ///
  /// In en, this message translates to:
  /// **'Low fitness raises injury risk.'**
  String get injuryStaminaRiskHint;

  /// No description provided for @injuryKindKnock.
  ///
  /// In en, this message translates to:
  /// **'Knock'**
  String get injuryKindKnock;

  /// No description provided for @injuryKindMuscle.
  ///
  /// In en, this message translates to:
  /// **'Muscle injury'**
  String get injuryKindMuscle;

  /// No description provided for @injuryKindSerious.
  ///
  /// In en, this message translates to:
  /// **'Serious injury'**
  String get injuryKindSerious;

  /// No description provided for @reportInjuries.
  ///
  /// In en, this message translates to:
  /// **'{n} player(s) injured'**
  String reportInjuries(int n);

  /// No description provided for @tacticsMentality.
  ///
  /// In en, this message translates to:
  /// **'Mentality'**
  String get tacticsMentality;

  /// No description provided for @teamChemistry.
  ///
  /// In en, this message translates to:
  /// **'Chemistry'**
  String get teamChemistry;

  /// No description provided for @mentalityVeryDefensive.
  ///
  /// In en, this message translates to:
  /// **'Very Defensive'**
  String get mentalityVeryDefensive;

  /// No description provided for @mentalityDefensive.
  ///
  /// In en, this message translates to:
  /// **'Defensive'**
  String get mentalityDefensive;

  /// No description provided for @mentalityCautious.
  ///
  /// In en, this message translates to:
  /// **'Cautious'**
  String get mentalityCautious;

  /// No description provided for @mentalityBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get mentalityBalanced;

  /// No description provided for @mentalityPositive.
  ///
  /// In en, this message translates to:
  /// **'Positive'**
  String get mentalityPositive;

  /// No description provided for @mentalityAttacking.
  ///
  /// In en, this message translates to:
  /// **'Attacking'**
  String get mentalityAttacking;

  /// No description provided for @mentalityVeryAttacking.
  ///
  /// In en, this message translates to:
  /// **'Very Attacking'**
  String get mentalityVeryAttacking;

  /// No description provided for @achCareerTitle.
  ///
  /// In en, this message translates to:
  /// **'Career'**
  String get achCareerTitle;

  /// No description provided for @achCareerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The touchline years'**
  String get achCareerSubtitle;

  /// No description provided for @achAttackTitle.
  ///
  /// In en, this message translates to:
  /// **'Attack'**
  String get achAttackTitle;

  /// No description provided for @achAttackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Goals win games'**
  String get achAttackSubtitle;

  /// No description provided for @achDefenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Defence'**
  String get achDefenceTitle;

  /// No description provided for @achDefenceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Solid at the back'**
  String get achDefenceSubtitle;

  /// No description provided for @achSilverwareTitle.
  ///
  /// In en, this message translates to:
  /// **'Silverware'**
  String get achSilverwareTitle;

  /// No description provided for @achSilverwareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Titles and promotions'**
  String get achSilverwareSubtitle;

  /// No description provided for @achSquadTitle.
  ///
  /// In en, this message translates to:
  /// **'Squad'**
  String get achSquadTitle;

  /// No description provided for @achSquadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The collection you build'**
  String get achSquadSubtitle;

  /// No description provided for @achPacksTitle.
  ///
  /// In en, this message translates to:
  /// **'Packs'**
  String get achPacksTitle;

  /// No description provided for @achPacksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ripping open the market'**
  String get achPacksSubtitle;

  /// No description provided for @achEconomyTitle.
  ///
  /// In en, this message translates to:
  /// **'Economy'**
  String get achEconomyTitle;

  /// No description provided for @achEconomySubtitle.
  ///
  /// In en, this message translates to:
  /// **'The coin ledger'**
  String get achEconomySubtitle;

  /// No description provided for @achCampusTitle.
  ///
  /// In en, this message translates to:
  /// **'Campus'**
  String get achCampusTitle;

  /// No description provided for @achCampusSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Built brick by brick'**
  String get achCampusSubtitle;

  /// No description provided for @achLoyaltyTitle.
  ///
  /// In en, this message translates to:
  /// **'Loyalty'**
  String get achLoyaltyTitle;

  /// No description provided for @achLoyaltySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Season after season'**
  String get achLoyaltySubtitle;

  /// No description provided for @achMastermindTitle.
  ///
  /// In en, this message translates to:
  /// **'Mastermind'**
  String get achMastermindTitle;

  /// No description provided for @achMastermindSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The thinking coach'**
  String get achMastermindSubtitle;

  /// No description provided for @achCareerMatches.
  ///
  /// In en, this message translates to:
  /// **'Matches Managed'**
  String get achCareerMatches;

  /// No description provided for @achCareerMatchesDesc.
  ///
  /// In en, this message translates to:
  /// **'Every match you have managed, from the first whistle.'**
  String get achCareerMatchesDesc;

  /// No description provided for @achCareerWins.
  ///
  /// In en, this message translates to:
  /// **'Wins'**
  String get achCareerWins;

  /// No description provided for @achCareerWinsDesc.
  ///
  /// In en, this message translates to:
  /// **'Matches won across your career.'**
  String get achCareerWinsDesc;

  /// No description provided for @achCareerWinStreak.
  ///
  /// In en, this message translates to:
  /// **'Winning Streak'**
  String get achCareerWinStreak;

  /// No description provided for @achCareerWinStreakDesc.
  ///
  /// In en, this message translates to:
  /// **'Your longest run of back-to-back victories.'**
  String get achCareerWinStreakDesc;

  /// No description provided for @achCareerUnbeatenStreak.
  ///
  /// In en, this message translates to:
  /// **'Unbeaten Run'**
  String get achCareerUnbeatenStreak;

  /// No description provided for @achCareerUnbeatenStreakDesc.
  ///
  /// In en, this message translates to:
  /// **'Wins and draws without tasting defeat.'**
  String get achCareerUnbeatenStreakDesc;

  /// No description provided for @achAttackGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals Scored'**
  String get achAttackGoals;

  /// No description provided for @achAttackGoalsDesc.
  ///
  /// In en, this message translates to:
  /// **'Every goal your club has put past a keeper.'**
  String get achAttackGoalsDesc;

  /// No description provided for @achAttackGoalsSingleMatch.
  ///
  /// In en, this message translates to:
  /// **'Goal Haul'**
  String get achAttackGoalsSingleMatch;

  /// No description provided for @achAttackGoalsSingleMatchDesc.
  ///
  /// In en, this message translates to:
  /// **'The most goals your club scored in one match.'**
  String get achAttackGoalsSingleMatchDesc;

  /// No description provided for @achDefenceCleanSheets.
  ///
  /// In en, this message translates to:
  /// **'Clean Sheets'**
  String get achDefenceCleanSheets;

  /// No description provided for @achDefenceCleanSheetsDesc.
  ///
  /// In en, this message translates to:
  /// **'Matches finished without conceding.'**
  String get achDefenceCleanSheetsDesc;

  /// No description provided for @achDefenceShutoutStreak.
  ///
  /// In en, this message translates to:
  /// **'Shutout Streak'**
  String get achDefenceShutoutStreak;

  /// No description provided for @achDefenceShutoutStreakDesc.
  ///
  /// In en, this message translates to:
  /// **'Consecutive matches keeping the nets untouched.'**
  String get achDefenceShutoutStreakDesc;

  /// No description provided for @achSilverwareTitles.
  ///
  /// In en, this message translates to:
  /// **'Champion'**
  String get achSilverwareTitles;

  /// No description provided for @achSilverwareTitlesDesc.
  ///
  /// In en, this message translates to:
  /// **'Division championships won, at any level.'**
  String get achSilverwareTitlesDesc;

  /// No description provided for @achSilverwarePromotions.
  ///
  /// In en, this message translates to:
  /// **'Promotions'**
  String get achSilverwarePromotions;

  /// No description provided for @achSilverwarePromotionsDesc.
  ///
  /// In en, this message translates to:
  /// **'Seasons finished with a climb up the ladder.'**
  String get achSilverwarePromotionsDesc;

  /// No description provided for @achSquadCardsOwned.
  ///
  /// In en, this message translates to:
  /// **'Cards Owned'**
  String get achSquadCardsOwned;

  /// No description provided for @achSquadCardsOwnedDesc.
  ///
  /// In en, this message translates to:
  /// **'The players your club holds right now.'**
  String get achSquadCardsOwnedDesc;

  /// No description provided for @achSquadLegendaries.
  ///
  /// In en, this message translates to:
  /// **'Legendary Squad'**
  String get achSquadLegendaries;

  /// No description provided for @achSquadLegendariesDesc.
  ///
  /// In en, this message translates to:
  /// **'Legendary cards (80+ overall) owned at once.'**
  String get achSquadLegendariesDesc;

  /// No description provided for @achSquadEpics.
  ///
  /// In en, this message translates to:
  /// **'Epic Squad'**
  String get achSquadEpics;

  /// No description provided for @achSquadEpicsDesc.
  ///
  /// In en, this message translates to:
  /// **'Epic cards (70–79 overall) owned at once.'**
  String get achSquadEpicsDesc;

  /// No description provided for @achSquadUpgrades.
  ///
  /// In en, this message translates to:
  /// **'Merges Completed'**
  String get achSquadUpgrades;

  /// No description provided for @achSquadUpgradesDesc.
  ///
  /// In en, this message translates to:
  /// **'Duplicates merged into stronger cards.'**
  String get achSquadUpgradesDesc;

  /// No description provided for @achSquadHighestUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Masterwork'**
  String get achSquadHighestUpgrade;

  /// No description provided for @achSquadHighestUpgradeDesc.
  ///
  /// In en, this message translates to:
  /// **'The highest upgrade level one card has reached.'**
  String get achSquadHighestUpgradeDesc;

  /// No description provided for @achPacksOpened.
  ///
  /// In en, this message translates to:
  /// **'Packs Opened'**
  String get achPacksOpened;

  /// No description provided for @achPacksOpenedDesc.
  ///
  /// In en, this message translates to:
  /// **'Every pack ripped open, whatever its source.'**
  String get achPacksOpenedDesc;

  /// No description provided for @achPacksPurchased.
  ///
  /// In en, this message translates to:
  /// **'Packs Purchased'**
  String get achPacksPurchased;

  /// No description provided for @achPacksPurchasedDesc.
  ///
  /// In en, this message translates to:
  /// **'Packs bought with hard-earned coins.'**
  String get achPacksPurchasedDesc;

  /// No description provided for @achPacksRewarded.
  ///
  /// In en, this message translates to:
  /// **'Rewards Earned'**
  String get achPacksRewarded;

  /// No description provided for @achPacksRewardedDesc.
  ///
  /// In en, this message translates to:
  /// **'Packs granted by season rewards.'**
  String get achPacksRewardedDesc;

  /// No description provided for @achEconomyLifetimeEarned.
  ///
  /// In en, this message translates to:
  /// **'Lifetime Earnings'**
  String get achEconomyLifetimeEarned;

  /// No description provided for @achEconomyLifetimeEarnedDesc.
  ///
  /// In en, this message translates to:
  /// **'Every coin the club has ever earned.'**
  String get achEconomyLifetimeEarnedDesc;

  /// No description provided for @achEconomyPackSpend.
  ///
  /// In en, this message translates to:
  /// **'Market Spending'**
  String get achEconomyPackSpend;

  /// No description provided for @achEconomyPackSpendDesc.
  ///
  /// In en, this message translates to:
  /// **'Coins spent on the pack market.'**
  String get achEconomyPackSpendDesc;

  /// No description provided for @achEconomyUpgradeSpend.
  ///
  /// In en, this message translates to:
  /// **'Investment Spending'**
  String get achEconomyUpgradeSpend;

  /// No description provided for @achEconomyUpgradeSpendDesc.
  ///
  /// In en, this message translates to:
  /// **'Coins poured into upgrades and facilities.'**
  String get achEconomyUpgradeSpendDesc;

  /// No description provided for @achCampusFacilityLevels.
  ///
  /// In en, this message translates to:
  /// **'Facility Levels'**
  String get achCampusFacilityLevels;

  /// No description provided for @achCampusFacilityLevelsDesc.
  ///
  /// In en, this message translates to:
  /// **'The sum of every level across your campus.'**
  String get achCampusFacilityLevelsDesc;

  /// No description provided for @achLoyaltySeasons.
  ///
  /// In en, this message translates to:
  /// **'Seasons Completed'**
  String get achLoyaltySeasons;

  /// No description provided for @achLoyaltySeasonsDesc.
  ///
  /// In en, this message translates to:
  /// **'Full seasons seen through to the final whistle.'**
  String get achLoyaltySeasonsDesc;

  /// No description provided for @achMastermindTacticsChanged.
  ///
  /// In en, this message translates to:
  /// **'Touchline Calls'**
  String get achMastermindTacticsChanged;

  /// No description provided for @achMastermindTacticsChangedDesc.
  ///
  /// In en, this message translates to:
  /// **'Tactical instructions changed from the dugout.'**
  String get achMastermindTacticsChangedDesc;

  /// No description provided for @achMilestoneFirstWin.
  ///
  /// In en, this message translates to:
  /// **'First Victory'**
  String get achMilestoneFirstWin;

  /// No description provided for @achMilestoneFirstWinDesc.
  ///
  /// In en, this message translates to:
  /// **'The win that started it all.'**
  String get achMilestoneFirstWinDesc;

  /// No description provided for @achMilestoneFirstTitle.
  ///
  /// In en, this message translates to:
  /// **'First Championship'**
  String get achMilestoneFirstTitle;

  /// No description provided for @achMilestoneFirstTitleDesc.
  ///
  /// In en, this message translates to:
  /// **'Lift your first division title.'**
  String get achMilestoneFirstTitleDesc;

  /// No description provided for @achMilestoneFirstLegendary.
  ///
  /// In en, this message translates to:
  /// **'The Golden Signature'**
  String get achMilestoneFirstLegendary;

  /// No description provided for @achMilestoneFirstLegendaryDesc.
  ///
  /// In en, this message translates to:
  /// **'Own your first legendary card.'**
  String get achMilestoneFirstLegendaryDesc;

  /// No description provided for @achMilestoneFirstEpic.
  ///
  /// In en, this message translates to:
  /// **'A Cut Above'**
  String get achMilestoneFirstEpic;

  /// No description provided for @achMilestoneFirstEpicDesc.
  ///
  /// In en, this message translates to:
  /// **'Own your first epic card.'**
  String get achMilestoneFirstEpicDesc;

  /// No description provided for @achMilestoneFirstLegendaryPull.
  ///
  /// In en, this message translates to:
  /// **'Golden Pull'**
  String get achMilestoneFirstLegendaryPull;

  /// No description provided for @achMilestoneFirstLegendaryPullDesc.
  ///
  /// In en, this message translates to:
  /// **'Pull a legendary card from a pack.'**
  String get achMilestoneFirstLegendaryPullDesc;

  /// No description provided for @achMilestoneFirstMillion.
  ///
  /// In en, this message translates to:
  /// **'Millionaire Manager'**
  String get achMilestoneFirstMillion;

  /// No description provided for @achMilestoneFirstMillionDesc.
  ///
  /// In en, this message translates to:
  /// **'Earn one million coins in your career.'**
  String get achMilestoneFirstMillionDesc;

  /// No description provided for @achMilestoneFirstSeason.
  ///
  /// In en, this message translates to:
  /// **'The Long Haul'**
  String get achMilestoneFirstSeason;

  /// No description provided for @achMilestoneFirstSeasonDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete your first full season.'**
  String get achMilestoneFirstSeasonDesc;

  /// No description provided for @achMilestoneFirstFacilityMax.
  ///
  /// In en, this message translates to:
  /// **'Campus Landmark'**
  String get achMilestoneFirstFacilityMax;

  /// No description provided for @achMilestoneFirstFacilityMaxDesc.
  ///
  /// In en, this message translates to:
  /// **'Take one facility to its maximum level.'**
  String get achMilestoneFirstFacilityMaxDesc;

  /// No description provided for @achTitleCareerWins1.
  ///
  /// In en, this message translates to:
  /// **'The Winner'**
  String get achTitleCareerWins1;

  /// No description provided for @achTitleCareerWins2.
  ///
  /// In en, this message translates to:
  /// **'Serial Winner'**
  String get achTitleCareerWins2;

  /// No description provided for @achTitleUnbeaten1.
  ///
  /// In en, this message translates to:
  /// **'Unbeaten'**
  String get achTitleUnbeaten1;

  /// No description provided for @achTitleUnbeaten2.
  ///
  /// In en, this message translates to:
  /// **'Fortress Manager'**
  String get achTitleUnbeaten2;

  /// No description provided for @achTitleGoals1.
  ///
  /// In en, this message translates to:
  /// **'The Marksman'**
  String get achTitleGoals1;

  /// No description provided for @achTitleGoals2.
  ///
  /// In en, this message translates to:
  /// **'Goal Machine'**
  String get achTitleGoals2;

  /// No description provided for @achTitleCleanSheets1.
  ///
  /// In en, this message translates to:
  /// **'The Wall'**
  String get achTitleCleanSheets1;

  /// No description provided for @achTitleCleanSheets2.
  ///
  /// In en, this message translates to:
  /// **'Locked Down'**
  String get achTitleCleanSheets2;

  /// No description provided for @achTitleTitles1.
  ///
  /// In en, this message translates to:
  /// **'Champion'**
  String get achTitleTitles1;

  /// No description provided for @achTitleTitles2.
  ///
  /// In en, this message translates to:
  /// **'Dynasty Builder'**
  String get achTitleTitles2;

  /// No description provided for @achTitleLegendaries1.
  ///
  /// In en, this message translates to:
  /// **'Galactico'**
  String get achTitleLegendaries1;

  /// No description provided for @achTitleLegendaries2.
  ///
  /// In en, this message translates to:
  /// **'Squad of Legends'**
  String get achTitleLegendaries2;

  /// No description provided for @achTitlePacks1.
  ///
  /// In en, this message translates to:
  /// **'Market Raider'**
  String get achTitlePacks1;

  /// No description provided for @achTitleCoins1.
  ///
  /// In en, this message translates to:
  /// **'The Banker'**
  String get achTitleCoins1;

  /// No description provided for @achTitleSeasons1.
  ///
  /// In en, this message translates to:
  /// **'Loyal Gaffer'**
  String get achTitleSeasons1;

  /// No description provided for @achTitleMastermind1.
  ///
  /// In en, this message translates to:
  /// **'The Tactician'**
  String get achTitleMastermind1;

  /// No description provided for @achievementDivisionChampion.
  ///
  /// In en, this message translates to:
  /// **'Division {division} Champion'**
  String achievementDivisionChampion(int division);

  /// No description provided for @achCareerDraws.
  ///
  /// In en, this message translates to:
  /// **'Shares of the Spoils'**
  String get achCareerDraws;

  /// No description provided for @achCareerDrawsDesc.
  ///
  /// In en, this message translates to:
  /// **'Matches that ended all square.'**
  String get achCareerDrawsDesc;

  /// No description provided for @achCareerLosses.
  ///
  /// In en, this message translates to:
  /// **'Hard Lessons'**
  String get achCareerLosses;

  /// No description provided for @achCareerLossesDesc.
  ///
  /// In en, this message translates to:
  /// **'The defeats that shaped the manager you became.'**
  String get achCareerLossesDesc;

  /// No description provided for @achDefenceGoalsAgainst.
  ///
  /// In en, this message translates to:
  /// **'Goals Conceded'**
  String get achDefenceGoalsAgainst;

  /// No description provided for @achDefenceGoalsAgainstDesc.
  ///
  /// In en, this message translates to:
  /// **'Every goal shipped at the wrong end — the counterweight of the clean sheets.'**
  String get achDefenceGoalsAgainstDesc;

  /// No description provided for @achDefenceScoredFirst.
  ///
  /// In en, this message translates to:
  /// **'First Blood'**
  String get achDefenceScoredFirst;

  /// No description provided for @achDefenceScoredFirstDesc.
  ///
  /// In en, this message translates to:
  /// **'Matches where your club struck the opening goal.'**
  String get achDefenceScoredFirstDesc;

  /// No description provided for @achCareerAwayMatches.
  ///
  /// In en, this message translates to:
  /// **'Travelling Support'**
  String get achCareerAwayMatches;

  /// No description provided for @achCareerAwayMatchesDesc.
  ///
  /// In en, this message translates to:
  /// **'Matches managed on hostile ground.'**
  String get achCareerAwayMatchesDesc;

  /// No description provided for @achEconomyPlayerSales.
  ///
  /// In en, this message translates to:
  /// **'Market Sales'**
  String get achEconomyPlayerSales;

  /// No description provided for @achEconomyPlayerSalesDesc.
  ///
  /// In en, this message translates to:
  /// **'Players moved on for the right price.'**
  String get achEconomyPlayerSalesDesc;

  /// No description provided for @achLoyaltyRelegations.
  ///
  /// In en, this message translates to:
  /// **'Weathered the Storm'**
  String get achLoyaltyRelegations;

  /// No description provided for @achLoyaltyRelegationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Relegations endured without walking away.'**
  String get achLoyaltyRelegationsDesc;

  /// No description provided for @achPacksStartingPacks.
  ///
  /// In en, this message translates to:
  /// **'From the Ground Up'**
  String get achPacksStartingPacks;

  /// No description provided for @achPacksStartingPacksDesc.
  ///
  /// In en, this message translates to:
  /// **'The starter packs that built the first squad.'**
  String get achPacksStartingPacksDesc;

  /// No description provided for @achCareerHomeMatches.
  ///
  /// In en, this message translates to:
  /// **'Home Fortress'**
  String get achCareerHomeMatches;

  /// No description provided for @achCareerHomeMatchesDesc.
  ///
  /// In en, this message translates to:
  /// **'Matches managed in front of your own crowd.'**
  String get achCareerHomeMatchesDesc;

  /// No description provided for @achCampusRecoveryLevel.
  ///
  /// In en, this message translates to:
  /// **'The Recovery Room'**
  String get achCampusRecoveryLevel;

  /// No description provided for @achCampusRecoveryLevelDesc.
  ///
  /// In en, this message translates to:
  /// **'The Recovery Centre\'s level — where tired legs come back.'**
  String get achCampusRecoveryLevelDesc;

  /// No description provided for @achTitlePacks2.
  ///
  /// In en, this message translates to:
  /// **'Market Mogul'**
  String get achTitlePacks2;

  /// No description provided for @achTitleCoins2.
  ///
  /// In en, this message translates to:
  /// **'The Magnate'**
  String get achTitleCoins2;

  /// No description provided for @achTitleSeasons2.
  ///
  /// In en, this message translates to:
  /// **'Club Legend'**
  String get achTitleSeasons2;

  /// No description provided for @achTitleMastermind2.
  ///
  /// In en, this message translates to:
  /// **'The Professor'**
  String get achTitleMastermind2;
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
