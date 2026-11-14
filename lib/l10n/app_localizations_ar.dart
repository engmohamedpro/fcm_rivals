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
  String get crestShapeLabel => 'الشكل';

  @override
  String get crestPrimaryLabel => 'اللون الأساسي';

  @override
  String get crestSecondaryLabel => 'اللون الثانوي';

  @override
  String get crestIconLabel => 'الرمز';

  @override
  String get crestPatternLabel => 'النقش';

  @override
  String get starterFormationSection => 'التشكيلة الأولى';

  @override
  String get startManaging => 'ابدأ الإدارة';

  @override
  String get start => 'ابدأ';

  @override
  String get fieldRequired => 'مطلوب';

  @override
  String get clubNameHintField => 'الاسم على الشعار';

  @override
  String get managerNameHintField => 'الاسم الذي يناديك به المعلق';

  @override
  String packsSoldFor(String coins) {
    return 'تم البيع مقابل $coins عملة';
  }

  @override
  String get packsNotEnoughCoins => 'لا توجد عملات كافية لحزمة أخرى';

  @override
  String get packsNewCard => 'جديد';

  @override
  String get revealBack => 'رجوع';

  @override
  String get revealSell => 'بيع';

  @override
  String get revealUpgrade => 'ترقية';

  @override
  String get liveTacticsTitle => 'خط التماس';

  @override
  String get liveTacticsCancelSelection => 'إلغاء التحديد';

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
  String get tacticsPresetBalanced => 'متوازن';

  @override
  String get tacticsPresetPossession => 'استحواذ';

  @override
  String get tacticsPresetParkTheBus => 'مركن دفاعي';

  @override
  String get tacticsPresetGegenpress => 'ضغط عالي';

  @override
  String get tacticsPresetCounterAttack => 'هجوم مرتد';

  @override
  String get tacticsPresetAllOutAttack => 'هجوم شامل';

  @override
  String get tacticsPresetBalancedHint => 'إعدادات محايدة على كل المحاور.';

  @override
  String get tacticsPresetPossessionHint =>
      'لعب من الخلف، إيقاع هادئ، صبر، وإدخال الكرة تدريجيًا.';

  @override
  String get tacticsPresetParkTheBusHint =>
      'بلوك منخفض، ضغط خفيف، تراجع وتماسك.';

  @override
  String get tacticsPresetGegenpressHint =>
      'خط مرتفع، ضغط فوري عند فقدان الكرة، شراسة.';

  @override
  String get tacticsPresetCounterAttackHint =>
      'بلوك منخفض نسبيًا، مرتدات سريعة عند استعادة الكرة.';

  @override
  String get tacticsPresetAllOutAttackHint =>
      'الكل للأمام، خط مرتفع، وتحمل المخاطر.';

  @override
  String get tacticsPresetWingPlay => 'لعب الأطراف';

  @override
  String get tacticsPresetWingPlayHint =>
      'انتشار عريض وعرضيات مبكرة داخل المنطقة.';

  @override
  String get seasonLeadersTitle => 'نجوم الموسم';

  @override
  String get seasonLeadersGoals => 'الأهداف';

  @override
  String get seasonLeadersAssists => 'الصناعة';

  @override
  String get seasonLeadersRating => 'متوسط التقييم';

  @override
  String get seasonLeadersCleanSheets => 'الشباك النظيفة';

  @override
  String prematchTablePosition(String position) {
    return '$position في جدول الترتيب';
  }

  @override
  String prematchPositionsVersus(String user, String opponent) {
    return '$user ضد $opponent';
  }

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
  String get packRarityRare => 'نادر';

  @override
  String get packRarityEpic => 'ملحمي';

  @override
  String get packRarityLegendary => 'أسطوري';

  @override
  String get packRarityPremium => 'نخبة';

  @override
  String get packRarityIcon => 'الأيقونات';

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

  @override
  String get achCareerTitle => 'المسيرة';

  @override
  String get achCareerSubtitle => 'سنوات على خط التماس';

  @override
  String get achAttackTitle => 'الهجوم';

  @override
  String get achAttackSubtitle => 'الأهداف تكسب المباريات';

  @override
  String get achDefenceTitle => 'الدفاع';

  @override
  String get achDefenceSubtitle => 'حصن منيع في الخلف';

  @override
  String get achSilverwareTitle => 'البطولات';

  @override
  String get achSilverwareSubtitle => 'ألقاب وترقيات';

  @override
  String get achSquadTitle => 'القائمة';

  @override
  String get achSquadSubtitle => 'مجموعتك التي تبنيها';

  @override
  String get achPacksTitle => 'العبوات';

  @override
  String get achPacksSubtitle => 'تمزيق أغلفة السوق';

  @override
  String get achEconomyTitle => 'الاقتصاد';

  @override
  String get achEconomySubtitle => 'دفتر العملات';

  @override
  String get achLoyaltyTitle => 'الوفاء';

  @override
  String get achLoyaltySubtitle => 'موسمًا بعد موسم';

  @override
  String get achMastermindTitle => 'العقل المدبر';

  @override
  String get achMastermindSubtitle => 'المدرب المفكر';

  @override
  String get achCareerMatches => 'مباريات أشرفت عليها';

  @override
  String get achCareerMatchesDesc =>
      'كل مباراة أدرتها منذ صافرة البداية الأولى.';

  @override
  String get achCareerWins => 'الانتصارات';

  @override
  String get achCareerWinsDesc => 'المباريات التي كسبتها عبر مسيرتك.';

  @override
  String get achCareerWinStreak => 'سلسلة الانتصارات';

  @override
  String get achCareerWinStreakDesc => 'أطول سلسلة انتصارات متتالية حققتها.';

  @override
  String get achCareerUnbeatenStreak => 'سلسلة بلا هزائم';

  @override
  String get achCareerUnbeatenStreakDesc =>
      'انتصارات وتعادلات دون أن تتذوق طعم الخسارة.';

  @override
  String get achAttackGoals => 'الأهداف المسجلة';

  @override
  String get achAttackGoalsDesc => 'كل هدف سجله نادلك في مرمى الخصوم.';

  @override
  String get achAttackGoalsSingleMatch => 'مهرجان أهداف';

  @override
  String get achAttackGoalsSingleMatchDesc =>
      'أكبر عدد من الأهداف سجلها نادلك في مباراة واحدة.';

  @override
  String get achDefenceCleanSheets => 'الشباك النظيفة';

  @override
  String get achDefenceCleanSheetsDesc => 'مباريات أُغلقت فيها شباكك بالضبات.';

  @override
  String get achDefenceShutoutStreak => 'سلسلة نظيفة';

  @override
  String get achDefenceShutoutStreakDesc =>
      'مباريات متتالية بقيت فيها الشباك بعيدة عن الخطر.';

  @override
  String get achSilverwareTitles => 'البطل';

  @override
  String get achSilverwareTitlesDesc =>
      'بطولات الدوري التي رفعتها، في أي مستوى.';

  @override
  String get achSilverwarePromotions => 'الترقيات';

  @override
  String get achSilverwarePromotionsDesc => 'مواسم أنهيتها بتسلق درجة أعلى.';

  @override
  String get achSquadCardsOwned => 'الكروت المملوكة';

  @override
  String get achSquadCardsOwnedDesc => 'اللاعبون الذين يملكهم نادلك الآن.';

  @override
  String get achSquadLegendaries => 'قائمة أسطورية';

  @override
  String get achSquadLegendariesDesc =>
      'كروت أسطورية (تقييم 80 فأعلى) تملكها في وقت واحد.';

  @override
  String get achSquadEpics => 'قائمة ملحمية';

  @override
  String get achSquadEpicsDesc =>
      'كروت ملحمية (تقييم 70–79) تملكها في وقت واحد.';

  @override
  String get achSquadUpgrades => 'عمليات الدمج';

  @override
  String get achSquadUpgradesDesc => 'المكررات التي دمجتها في كروت أقوى.';

  @override
  String get achSquadHighestUpgrade => 'التحفة';

  @override
  String get achSquadHighestUpgradeDesc =>
      'أعلى مستوى ترقية وصل إليه كارت واحد.';

  @override
  String get achPacksOpened => 'عبوات فتحتها';

  @override
  String get achPacksOpenedDesc => 'كل عبوة مزقت غلافها، مهما كان مصدرها.';

  @override
  String get achPacksPurchased => 'عبوات اشتريتها';

  @override
  String get achPacksPurchasedDesc =>
      'عبوات اقتنيتها بعملات كسبتها بعرق الجبين.';

  @override
  String get achPacksRewarded => 'مكافآت حصلت عليها';

  @override
  String get achPacksRewardedDesc => 'عبوات منحتها إياك مكافآت نهاية الموسم.';

  @override
  String get achEconomyLifetimeEarned => 'إجمالي الدخل';

  @override
  String get achEconomyLifetimeEarnedDesc =>
      'كل عملة دخل بها النادي على الإطلاق.';

  @override
  String get achEconomyPackSpend => 'إنفاق السوق';

  @override
  String get achEconomyPackSpendDesc => 'العملات التي أنفقتها على سوق العبوات.';

  @override
  String get achEconomyUpgradeSpend => 'إنفاق التطوير';

  @override
  String get achEconomyUpgradeSpendDesc =>
      'العملات التي ضخختها في الترقيات والمرافق.';

  @override
  String get achLoyaltySeasons => 'مواسم أكملتها';

  @override
  String get achLoyaltySeasonsDesc => 'مواسم كاملة أوصلتها لصافرة النهاية.';

  @override
  String get achMastermindTacticsChanged => 'قرارات التماس';

  @override
  String get achMastermindTacticsChangedDesc =>
      'التعليمات التكتيكية التي غيرتها من على خط التماس.';

  @override
  String get achMilestoneFirstWin => 'أول انتصار';

  @override
  String get achMilestoneFirstWinDesc => 'الانتصار الذي بدأ منه كل شيء.';

  @override
  String get achMilestoneFirstTitle => 'أول بطولة';

  @override
  String get achMilestoneFirstTitleDesc => 'ارفع أول درع دوري لنادلك.';

  @override
  String get achMilestoneFirstLegendary => 'التوقيع الذهبي';

  @override
  String get achMilestoneFirstLegendaryDesc => 'امتلك أول كارت أسطوري لك.';

  @override
  String get achMilestoneFirstEpic => 'نخبة متفوقة';

  @override
  String get achMilestoneFirstEpicDesc => 'امتلك أول كارت ملحمي لك.';

  @override
  String get achMilestoneFirstLegendaryPull => 'السحبة الذهبية';

  @override
  String get achMilestoneFirstLegendaryPullDesc =>
      'اسحب كارتًا أسطوريًا من عبوة.';

  @override
  String get achMilestoneFirstMillion => 'مدرب المليونير';

  @override
  String get achMilestoneFirstMillionDesc => 'اربح مليون عملة في مسيرتك.';

  @override
  String get achMilestoneFirstSeason => 'الماراثون';

  @override
  String get achMilestoneFirstSeasonDesc => 'أكمل أول موسم كامل لك.';

  @override
  String get achTitleCareerWins1 => 'الفائز';

  @override
  String get achTitleCareerWins2 => 'فائز بطبعه';

  @override
  String get achTitleUnbeaten1 => 'لا يُقهر';

  @override
  String get achTitleUnbeaten2 => 'مدرب الحصن';

  @override
  String get achTitleGoals1 => 'القناص';

  @override
  String get achTitleGoals2 => 'آلة الأهداف';

  @override
  String get achTitleCleanSheets1 => 'السد العالي';

  @override
  String get achTitleCleanSheets2 => 'مقفل الشباك';

  @override
  String get achTitleTitles1 => 'البطل';

  @override
  String get achTitleTitles2 => 'باني الإمبراطورية';

  @override
  String get achTitleLegendaries1 => 'الغلاكتيكو';

  @override
  String get achTitleLegendaries2 => 'قائمة الأساطير';

  @override
  String get achTitlePacks1 => 'مغير الأسواق';

  @override
  String get achTitleCoins1 => 'الصراف';

  @override
  String get achTitleSeasons1 => 'المدرب المخلص';

  @override
  String get achTitleMastermind1 => 'الخطيط';

  @override
  String achievementDivisionChampion(int division) {
    return 'بطل الدرجة $division';
  }

  @override
  String get achCareerDraws => 'قسمة الغنائم';

  @override
  String get achCareerDrawsDesc => 'المباريات التي انتهت بالتعادل.';

  @override
  String get achCareerLosses => 'دروس قاسية';

  @override
  String get achCareerLossesDesc => 'الهزائم التي صنعت المدرب الذي أصبحته.';

  @override
  String get achDefenceGoalsAgainst => 'الأهداف المستقبلة';

  @override
  String get achDefenceGoalsAgainstDesc =>
      'كل هدف دخل شباكك — الكفة المقابلة للشباك النظيفة.';

  @override
  String get achDefenceScoredFirst => 'الضربة الأولى';

  @override
  String get achDefenceScoredFirstDesc =>
      'مباريات سجل فيها نادلك هدف المبادرة.';

  @override
  String get achCareerAwayMatches => 'الجمهور المسافر';

  @override
  String get achCareerAwayMatchesDesc =>
      'مباريات أدرتها على أرض الخصم وسط جمهوره.';

  @override
  String get achEconomyPlayerSales => 'بيع في السوق';

  @override
  String get achEconomyPlayerSalesDesc => 'لاعبون بِعوا بالسعر المناسب.';

  @override
  String get achLoyaltyRelegations => 'رباطة الجأش';

  @override
  String get achLoyaltyRelegationsDesc => 'هبوط ذقته ولم تغادر على إثره.';

  @override
  String get achPacksStartingPacks => 'من الصفر';

  @override
  String get achPacksStartingPacksDesc =>
      'عبوات البداية التي شيّدت أول تشكيلة.';

  @override
  String get achCareerHomeMatches => 'الحصن الداخلي';

  @override
  String get achCareerHomeMatchesDesc => 'مباريات أدرتها أمام جمهورك.';

  @override
  String get achTitlePacks2 => 'أمير الأسواق';

  @override
  String get achTitleCoins2 => 'التاجر الكبير';

  @override
  String get achTitleSeasons2 => 'أسطول النادي';

  @override
  String get achTitleMastermind2 => 'البروفيسور';

  @override
  String get navAchievements => 'الإنجازات';

  @override
  String get achHubTitle => 'غرفة الكؤوس';

  @override
  String achHubSubtitle(int claimed, int total) {
    return '$claimed من $total درجات مُستحقة';
  }

  @override
  String get achClaimedLabel => 'مُستحق';

  @override
  String get achClaimAction => 'استحق';

  @override
  String get teamOpenCollection => 'المجموعة كاملة';

  @override
  String achClaimedRungs(int count) {
    return '$count مُستحقة';
  }

  @override
  String get navProfile => 'الملف الشخصي';

  @override
  String get profileUnsetName => 'المدرب الجديد';

  @override
  String get profileUnsetClub => 'نادٍ جديد';

  @override
  String profileJoined(int year, int month, int day) {
    return 'هنا منذ $year-$month-$day';
  }

  @override
  String get profileStatMatches => 'المباريات';

  @override
  String get profileStatWinRate => 'نسبة الفوز';

  @override
  String get profileStatWins => 'فوز';

  @override
  String get profileStatDraws => 'تعادل';

  @override
  String get profileStatLosses => 'خسارة';

  @override
  String get profileStatGoalsFor => 'أهداف له';

  @override
  String get profileStatGoalsAgainst => 'أهداف عليه';

  @override
  String get profileStatCleanSheets => 'شباك نظيفة';

  @override
  String get profileStatWinStreak => 'أطول سلسلة فوز';

  @override
  String get profileStatUnbeaten => 'أطول سلسلة بلا هزيمة';

  @override
  String get profileNoMatches => 'تبدأ الآن';

  @override
  String get profileFounded => 'التأسيس';

  @override
  String get profileHeadlineSeasons => 'مواسم';

  @override
  String get profileHeadlineTrophies => 'ألقاب';

  @override
  String get profileStatsSectionTitle => 'السجل المهني';

  @override
  String get profileSilverwareTitle => 'الألقاب والكؤوس';

  @override
  String profilePercent(num value) {
    return '$value٪';
  }

  @override
  String profileTitlesCount(int count) {
    return '$count بطولة';
  }

  @override
  String get profileNoTitles => 'خزانة الألقاب تنتظر';

  @override
  String profileDivisionPlate(int division, int count) {
    return 'الدرجة $division ×$count';
  }

  @override
  String get profileSeasonHistory => 'سجل المواسم';

  @override
  String get profileNoSeasons => 'مسيرتك تبدأ الآن';

  @override
  String profileSeasonTitle(int ordinal, int division) {
    return 'الموسم $ordinal · الدرجة $division';
  }

  @override
  String profileFinalPosition(int position) {
    return 'أنهيت في المركز $position';
  }

  @override
  String get profileOutcomePromoted => 'صعد';

  @override
  String get profileOutcomeRelegated => 'هبط';

  @override
  String get profileOutcomeStayed => 'بقي';

  @override
  String get campusBannerTitle => 'حرم النادي';

  @override
  String get campusBannerSubtitle => 'تعزيزات دائمة — كل مستوى أغلى من سابقه.';

  @override
  String campusTeamBoost(String value) {
    return 'قوة الفريق $value';
  }

  @override
  String get campusNoBoosts => 'لا تعزيزات بعد';

  @override
  String get badgeCabinetTitle => 'خزانة الشارات';

  @override
  String get titlesGalleryTitle => 'الألقاب';

  @override
  String get titleEquipAction => 'ارتدِ';

  @override
  String get titleUnequipAction => 'مُرتدى';

  @override
  String titleSourceAchievement(String achievement, int threshold) {
    return 'يُكتسب عند $achievement بدرجة $threshold';
  }

  @override
  String titleSourceDivision(int division) {
    return 'أنهِ الأول في الدرجة $division';
  }

  @override
  String get streakTitle => 'الجوائز اليومية';

  @override
  String streakClaimAction(int coins) {
    return 'استلم $coins عملة';
  }

  @override
  String get streakClaimedToday => 'تم استلام اليوم';

  @override
  String streakDayCount(int day) {
    return 'اليوم $day';
  }

  @override
  String streakTomorrowPays(int coins) {
    return 'غدًا: $coins عملة';
  }

  @override
  String get streakResetWarning => 'لو فاتك يوم يبدأ العد من اليوم الأول';

  @override
  String get streakBrokenNotice => 'انقطعت السلسلة — رجوع لليوم الأول';

  @override
  String get streakWeeklyBonus => 'كل سابع يوم فيه مكافأة إضافية';

  @override
  String streakCoinsUnit(int coins) {
    return '$coins عملة';
  }
}
