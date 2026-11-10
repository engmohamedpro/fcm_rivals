/// FCM Rivals — the words of the tactic sliders (EN + AR).
///
/// Each slider has a name and five descriptive bands: the text that
/// floats above the thumb says what the current number MEANS (width 5 →
/// "Very narrow", 55 → "Standard"). Value 0 is always the cautious /
/// minimum end of the instruction as the engine's anchors define it,
/// 99 the opposite end, 50 the default.
///
/// Plain Dart on purpose: the slider wording lives next to the axis
/// definitions it describes and needs no ARB regeneration to change.
library;

import 'tactic_sliders.dart';

class TacticAxisCopy {
  const TacticAxisCopy({
    required this.nameEn,
    required this.nameAr,
    required this.bandsEn,
    required this.bandsAr,
  });

  final String nameEn;
  final String nameAr;

  /// Five descriptions, from the 0 end to the 99 end.
  final List<String> bandsEn;
  final List<String> bandsAr;

  String name({required bool arabic}) => arabic ? nameAr : nameEn;

  /// What [value] (0–99) means: the band it falls in, equal fifths
  /// (0–19, 20–39, 40–59, 60–79, 80–99).
  String band(int value, {required bool arabic}) {
    final bands = arabic ? bandsAr : bandsEn;
    final i = (clampScale(value) * bands.length ~/ (kScaleMax + 1)).clamp(
      0,
      bands.length - 1,
    );
    return bands[i];
  }
}

/// Every slider's wording.
const Map<TacticAxisId, TacticAxisCopy> kTacticAxisCopy = {
  // ---- Mentality
  TacticAxisId.mentality: TacticAxisCopy(
    nameEn: 'Mentality',
    nameAr: 'العقلية',
    bandsEn: [
      'Very defensive',
      'Defensive',
      'Balanced',
      'Attacking',
      'Very attacking',
    ],
    bandsAr: ['دفاعي للغاية', 'دفاعي', 'متوازن', 'هجومي', 'هجومي للغاية'],
  ),
  // ---- In possession
  TacticAxisId.buildUp: TacticAxisCopy(
    nameEn: 'Build-Up',
    nameAr: 'بناء اللعب',
    bandsEn: [
      'Play out from the back',
      'Short and patient',
      'Mixed',
      'Direct',
      'Long ball',
    ],
    bandsAr: [
      'الخروج بالكرة من الخلف',
      'تمرير قصير وصبور',
      'متوازن',
      'لعب مباشر',
      'كرات طويلة',
    ],
  ),
  TacticAxisId.tempo: TacticAxisCopy(
    nameEn: 'Tempo',
    nameAr: 'الإيقاع',
    bandsEn: ['Very slow', 'Slow', 'Standard', 'Fast', 'Very fast'],
    bandsAr: ['بطيء جداً', 'بطيء', 'عادي', 'سريع', 'سريع جداً'],
  ),
  TacticAxisId.width: TacticAxisCopy(
    nameEn: 'Width',
    nameAr: 'العرض',
    bandsEn: ['Very narrow', 'Narrow', 'Standard', 'Wide', 'Very wide'],
    bandsAr: ['ضيق جداً', 'ضيق', 'عادي', 'عريض', 'عريض جداً'],
  ),
  TacticAxisId.shotSelection: TacticAxisCopy(
    nameEn: 'Final Third',
    nameAr: 'الثلث الأخير',
    bandsEn: [
      'Work it into the box',
      'Patient',
      'Balanced',
      'Shoot early',
      'Shoot on sight',
    ],
    bandsAr: [
      'إدخال الكرة للمنطقة',
      'صبور',
      'متوازن',
      'تسديد مبكر',
      'تسديد من أي مكان',
    ],
  ),
  TacticAxisId.crossing: TacticAxisCopy(
    nameEn: 'Crossing',
    nameAr: 'العرضيات',
    bandsEn: [
      'Keep it on the ground',
      'Rarely cross',
      'Standard',
      'Cross often',
      'Cross early',
    ],
    bandsAr: [
      'اللعب الأرضي',
      'عرضيات نادرة',
      'عادي',
      'عرضيات متكررة',
      'عرضيات مبكرة',
    ],
  ),
  // ---- Out of possession
  TacticAxisId.defensiveLine: TacticAxisCopy(
    nameEn: 'Defensive Line',
    nameAr: 'خط الدفاع',
    bandsEn: ['Very deep', 'Deep', 'Standard', 'High', 'Very high'],
    bandsAr: ['عميق جداً', 'عميق', 'عادي', 'متقدم', 'متقدم جداً'],
  ),
  TacticAxisId.pressing: TacticAxisCopy(
    nameEn: 'Pressing',
    nameAr: 'الضغط',
    bandsEn: [
      'Hardly press',
      'Low press',
      'Mid press',
      'High press',
      'Relentless press',
    ],
    bandsAr: ['بلا ضغط', 'ضغط منخفض', 'ضغط متوسط', 'ضغط عالٍ', 'ضغط شرس'],
  ),
  TacticAxisId.tackling: TacticAxisCopy(
    nameEn: 'Tackling',
    nameAr: 'التدخلات',
    bandsEn: [
      'Very clean',
      'Clean',
      'Balanced',
      'Aggressive',
      'Very aggressive',
    ],
    bandsAr: ['نظيف جداً', 'نظيف', 'متوازن', 'عدواني', 'عدواني جداً'],
  ),
  // ---- Transitions
  TacticAxisId.counterPress: TacticAxisCopy(
    nameEn: 'Counter-Press',
    nameAr: 'الضغط المعاكس',
    bandsEn: [
      'Retreat to shape',
      'Drop back',
      'Balanced',
      'Press back',
      'Instant counter-press',
    ],
    bandsAr: [
      'التراجع للتشكيل',
      'التراجع',
      'متوازن',
      'ضغط للخلف',
      'ضغط معاكس فوري',
    ],
  ),
  TacticAxisId.attackOnRecovery: TacticAxisCopy(
    nameEn: 'On Recovery',
    nameAr: 'عند الاستعادة',
    bandsEn: [
      'Very patient',
      'Patient',
      'Balanced',
      'Quick',
      'Fast counter',
    ],
    bandsAr: [
      'صبور جداً',
      'صبور',
      'متوازن',
      'سريع',
      'مرتدة سريعة',
    ],
  ),
  TacticAxisId.restDefence: TacticAxisCopy(
    nameEn: 'Rest Defence',
    nameAr: 'التأمين الدفاعي',
    bandsEn: [
      '4 stay back',
      'Cautious',
      '3 stay back',
      'Bold',
      '2 stay back',
    ],
    bandsAr: [
      '4 يبقون للدفاع',
      'حذر',
      '3 يبقون للدفاع',
      'جريء',
      '2 يبقون للدفاع',
    ],
  ),
};
