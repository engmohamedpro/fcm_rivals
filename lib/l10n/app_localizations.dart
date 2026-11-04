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
