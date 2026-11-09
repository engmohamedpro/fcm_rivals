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
  String get packsNewCard => 'جديد';

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
  String get tacticsOutOfPossessionTitle => 'بدون الاستحواذ';

  @override
  String get tacticsTransitionsTitle => 'التحولات';

  @override
  String get tacticsSectionDefault => 'الإعداد الافتراضي';

  @override
  String get tacticsLabel => 'الخطة';

  @override
  String get tacticsBuildUp => 'بناء اللعب';

  @override
  String get tacticsTempo => 'الإيقاع';

  @override
  String get tacticsWidth => 'العرض';

  @override
  String get tacticsFinalThird => 'الثلث الأخير';

  @override
  String get buildUpPlayOut => 'اللعب من الخلف';

  @override
  String get buildUpMixed => 'مختلط';

  @override
  String get buildUpLongBall => 'كرات طويلة';

  @override
  String get tempoSlow => 'بطيء';

  @override
  String get tempoStandard => 'معتدل';

  @override
  String get tempoFast => 'سريع';

  @override
  String get widthNarrow => 'ضيق';

  @override
  String get widthStandardWidth => 'معتدل';

  @override
  String get widthWide => 'عريض';

  @override
  String get finalThirdWorkBall => 'تمريرات داخل المنطقة';

  @override
  String get finalThirdBalanced => 'متوازن';

  @override
  String get finalThirdEarlyCrosses => 'عرضيات مبكرة';

  @override
  String get finalThirdShootOnSight => 'التسديد عند أول فرصة';

  @override
  String get tacticsDefensiveLine => 'الخط الدفاعي';

  @override
  String get tacticsPressing => 'الضغط';

  @override
  String get tacticsTackling => 'الالتحامات';

  @override
  String get tacticsOffsideTrap => 'مصيدة التسلل';

  @override
  String get lineDeep => 'عميق';

  @override
  String get lineStandard => 'معتدل';

  @override
  String get lineHigh => 'متقدم';

  @override
  String get pressLow => 'منخفض';

  @override
  String get pressMid => 'متوسط';

  @override
  String get pressHigh => 'مرتفع';

  @override
  String get tackleClean => 'نظيف';

  @override
  String get tackleBalanced => 'متوازن';

  @override
  String get tackleAggressive => 'شرس';

  @override
  String get trapOn => 'تشغيل';

  @override
  String get trapOff => 'إيقاف';

  @override
  String get trapDeepWarning =>
      'لا فائدة منها مع خط عميق — مخاطرة صرفة. ارفع الخط أو أغلق المصيدة.';

  @override
  String get tacticsCounterPress => 'الضغط المضاد';

  @override
  String get tacticsAttackOnRecovery => 'الهجوم عند الاستخلاص';

  @override
  String get tacticsRestDefence => 'الدفاع الوقائي';

  @override
  String get cpRetreat => 'التراجع للتنظيم';

  @override
  String get cpBalanced => 'متوازن';

  @override
  String get cpImmediate => 'فوري';

  @override
  String get arPatient => 'صبور';

  @override
  String get arBalanced => 'متوازن';

  @override
  String get arFast => 'سريع';

  @override
  String get rdConservative => 'محافظ';

  @override
  String get rdStandard => 'معتاد';

  @override
  String get rdAggressive => 'هجومي';

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

  @override
  String get packRarityRare => 'نادر';

  @override
  String get packRarityEpic => 'ملحمي';

  @override
  String get packRarityLegendary => 'أسطوري';

  @override
  String get packRarityPremium => 'نخبة';

  @override
  String injuryBadgeSemantics(int n) {
    return 'مصاب، خارج $n مباراة';
  }

  @override
  String injuryOutForMatches(int n) {
    return 'خارج $n مباراة';
  }

  @override
  String injuryChipOut(int n) {
    return 'خارج $n';
  }

  @override
  String get prematchMedicalTitle => 'الغرفة الطبية';

  @override
  String get injuryStaminaRiskHint => 'اللياقة المنخفضة تزيد خطر الإصابة.';

  @override
  String get injuryKindKnock => 'ارتطام';

  @override
  String get injuryKindMuscle => 'إصابة عضلية';

  @override
  String get injuryKindSerious => 'إصابة خطيرة';

  @override
  String reportInjuries(int n) {
    return '$n لاعب مصاب';
  }

  @override
  String get tacticsMentality => 'العقلية';

  @override
  String get teamChemistry => 'الكيمياء';

  @override
  String get mentalityVeryDefensive => 'دفاعي للغاية';

  @override
  String get mentalityDefensive => 'دفاعي';

  @override
  String get mentalityCautious => 'حذر';

  @override
  String get mentalityBalanced => 'متوازن';

  @override
  String get mentalityPositive => 'إيجابي';

  @override
  String get mentalityAttacking => 'هجومي';

  @override
  String get mentalityVeryAttacking => 'هجومي للغاية';
}
