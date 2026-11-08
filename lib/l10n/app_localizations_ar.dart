// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'FCM Rivals';

  @override
  String get navSeason => 'الموسم';

  @override
  String get navTeam => 'الفريق';

  @override
  String get navCollection => 'المجموعة';

  @override
  String get navCampus => 'الحرم';

  @override
  String get navStore => 'المتجر';

  @override
  String get createYourClub => 'أنشئ ناديك';

  @override
  String get createYourClubIntro =>
      'تبدأ بعملات و٢٢ حزمة مجانية — اثنتان لكل مركز في تشكيلتك الأولى.';

  @override
  String get clubNameLabel => 'اسم النادي';

  @override
  String get clubNameHint => 'الاسم على الشعار';

  @override
  String get managerNameLabel => 'اسم المدرب';

  @override
  String get managerNameHint => 'الاسم الذي يناديك به المعلق';

  @override
  String get chooseCrest => 'اختر شعارك';

  @override
  String get chooseFormation => 'التشكيلة الأولى';

  @override
  String get startClub => 'ابدأ النادي';

  @override
  String get startSeason => 'ابدأ موسمك الأول';

  @override
  String get playMatch => 'العب المباراة';

  @override
  String get completeSeason => 'أكمل الموسم';

  @override
  String startSeasonInDivision(int division) {
    return 'ابدأ الموسم في الدرجة $division';
  }

  @override
  String nextFixtureRound(int round) {
    return 'المباراة التالية · الجولة $round';
  }

  @override
  String get noFixtureReady => 'لا توجد مباراة جاهزة — يتم التحديث.';

  @override
  String get bestSquadSelected => 'تم اختيار أفضل تشكيلة';

  @override
  String get languageLabel => 'اللغة';

  @override
  String get languageEn => 'English';

  @override
  String get languageAr => 'العربية';

  @override
  String get languageSystem => 'النظام';

  @override
  String get matchSpeedLabel => 'سرعة عرض المباراة';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String coinCompactMillions(String value) {
    return '$value م';
  }

  @override
  String coinCompactThousands(String value) {
    return '$value ألف';
  }

  @override
  String get openPacksHint =>
      'افتح الحزم لجمع اللاعبين ثم اضغط الاختيار التلقائي.';

  @override
  String get clubCrestSection => 'شعار النادي';

  @override
  String get starterFormationSection => 'التشكيلة الأولى';

  @override
  String get starterFormationIntro =>
      'هذه تشكيلتك الأولى — يبدأ فريقك بهذه الهيئة و٢٢ حزمة مجانية تطابق مراكزها. يمكنك تغييرها في أي وقت من تبويب الفريق.';

  @override
  String get startManaging => 'ابدأ الإدارة';

  @override
  String get fieldRequired => 'مطلوب';

  @override
  String get clubNameHintField => 'الاسم على الشعار';

  @override
  String get managerNameHintField => 'الاسم الذي يناديك به المعلق';

  @override
  String get tapAgainToSkip => 'اضغط خارج البطاقة مرة أخرى للتخطي بدون حديث';

  @override
  String get postMatchRecoveryTitle => 'الاستشفاء بعد المباراة';

  @override
  String get postMatchRecoveryIntro =>
      'تركيز واحد للفريق في أيام الراحة القادمة:';

  @override
  String recoveryBonusEffect(int bonus) {
    return '+$bonus% استشفاء طبيعي';
  }

  @override
  String get pepTalkRestEveryone => 'راحة، الجميع يستحقها!';

  @override
  String get pepTalkFocusExhausted => 'التركيز على اللاعبين المنهكين!';

  @override
  String get pepTalkRewardSubstitutes => 'مكافأة بدلاء اللقاء!';

  @override
  String get pepTalkEveryoneGaveBest => 'الجميع بذل أفضل ما لديه!';

  @override
  String get watchAdBoostedRecovery => 'شاهد إعلانًا: استشفاء معزز';

  @override
  String get watchAdBoostedEffect =>
      '+15% استشفاء طبيعي لكامل الفريق (GDD 19.3)';

  @override
  String get noPepTalkDefault => 'بدون حديث — الاستشفاء الافتراضي';

  @override
  String packsSoldFor(String coins) {
    return 'تم البيع مقابل $coins عملة';
  }

  @override
  String get packsNotEnoughCoins => 'لا توجد عملات كافية لحزمة أخرى';

  @override
  String get liveTacticsTitle => 'خط التماس';

  @override
  String get liveTacticsCancelSelection => 'إلغاء التحديد';

  @override
  String pepTalkRecoveryConfirmation(String pepTalk, int bonus) {
    return '$pepTalk (+$bonus% استشفاء)';
  }

  @override
  String get tacticsInPossessionTitle => 'في الاستحواذ';

  @override
  String get tacticsInPossessionSubtitle =>
      'بناء اللعب والإيقاع والعرض وأسلوب الثلث الأخير';

  @override
  String get tacticsOutOfPossessionTitle => 'بدون الاستحواذ';

  @override
  String get tacticsOutOfPossessionSubtitle =>
      'خط الدفاع والضغط والالتحامات ومصيدة التسلل';

  @override
  String get tacticsTransitionsTitle => 'التحولات';

  @override
  String get tacticsTransitionsSubtitle =>
      'الضغط المرتد والهجمات المرتدة والدفاع الاحتياطي';

  @override
  String get tacticsSectionDefault => 'الإعداد الافتراضي';

  @override
  String get tacticsLabel => 'الخطة';

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
    return '$player يتلقى ارتطامًا ولا يستطيع الاستكمال.';
  }

  @override
  String injuryCommentaryMuscle(Object player) {
    return '$player يتوقف بإصابة عضلية — وداعًا يومه اليوم.';
  }

  @override
  String injuryCommentarySerious(Object player) {
    return '$player يتعرض لإصابة خطيرة. الوضع لا يبدو جيدًا.';
  }

  @override
  String get injuryCommentaryPlaysShort =>
      ' لا يوجد بديل عنه وسيكمل الفريق ناقصًا.';

  @override
  String get statInjuries => 'الإصابات';

  @override
  String get cardClassPremium => 'نخبة';

  @override
  String get revealBannerPremium => 'سحب النخبة!';
}
