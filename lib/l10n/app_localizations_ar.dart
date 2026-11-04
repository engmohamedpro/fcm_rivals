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
}
