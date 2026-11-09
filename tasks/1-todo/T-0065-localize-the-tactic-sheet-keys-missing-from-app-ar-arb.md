---
id: T-0065
title: Localize the 47 tactic-sheet keys missing from app_ar.arb
priority: high
status: todo
attempts: 0
depends_on: [T-0064]
created: 2026-11-09
completed:
---

# T-0065: Localize the 47 tactic-sheet keys missing from app_ar.arb

## Goal
The tactic options sheet is fully Arabic in the Arabic locale: the nine axis labels, every step name, the final-third chips, the offside toggle and its deep-line warning, and both GDD 10.3 readouts read Arabic instead of today's English fallbacks.

## Context
- Pre-existing gap, verified during the T-0064 review (`comm` of `grep '"..."' lib/l10n/app_en.arb` vs `app_ar.arb` at `50b08ac` and at HEAD): exactly 47 keys exist in `app_en.arb` but not in `lib/l10n/app_ar.arb`. The gap predates T-0064 (47 keys missing before and after) — T-0064's task Context wrongly asserted they existed in both ARBs; the sheet's AR labels have been English all along.
- The wiring already exists: `lib/l10n/app_localizations_ar.dart` carries hand-maintained getters returning English fallback values for all 47 keys (e.g. `String get pressHigh => 'High';`). The consumers (`_SliderRow` label/pill/end labels in `lib/features/match/tactics_sections.dart`, the FinalThird `_SegmentedRow`, the offside toggle chip, the `restDefenceHint` and `tacticsEstPossession` readouts) already read through those getters — no consumer file changes are needed, only the ARB + the AR class values.
- `tacticsEstPossession` is parameterized (`"Est. possession: {share}%"` in EN) — in the AR class it is a method `String tacticsEstPossession(int share)`, not a getter.
- Reference for style: the seven `mentality*` keys added to `app_ar.arb` by T-0064 (`متوازن`, `هجومي للغاية`, …).

## Requirements
1. Add all 47 keys below to `lib/l10n/app_ar.arb` with EXACTLY these values (standard football-manager Arabic; do not re-translate):
   - Axis titles (12): `tacticsBuildUp` بناء اللعب، `tacticsTempo` الإيقاع، `tacticsWidth` العرض، `tacticsDefensiveLine` الخط الدفاعي، `tacticsPressing` الضغط، `tacticsTackling` الالتحامات، `tacticsCounterPress` الضغط المضاد، `tacticsAttackOnRecovery` الهجوم عند الاستخلاص، `tacticsRestDefence` الدفاع الوقائي، `tacticsFinalThird` الثلث الأخير، `tacticsOffsideTrap` مصيدة التسلل، `tacticsEstPossession` الاستحواذ المتوقع: {share}%
   - Build-up steps (3): `arPatient` صبور، `arBalanced` متوازن، `arFast` سريع
   - Build-up styles (3): `buildUpPlayOut` اللعب من الخلف، `buildUpMixed` مختلط، `buildUpLongBall` كرات طويلة
   - Tempo steps (3): `tempoSlow` بطيء، `tempoStandard` معتدل، `tempoFast` سريع
   - Width steps (3): `widthNarrow` ضيق، `widthStandardWidth` معتدل، `widthWide` عريض
   - Defensive-line steps (3): `lineDeep` عميق، `lineStandard` معتدل، `lineHigh` متقدم
   - Pressing steps (3): `pressLow` منخفض، `pressMid` متوسط، `pressHigh` مرتفع
   - Tackling steps (3): `tackleClean` نظيف، `tackleBalanced` متوازن، `tackleAggressive` شرس
   - Counter-press steps (3): `cpRetreat` التراجع للتنظيم، `cpBalanced` متوازن، `cpImmediate` فوري
   - Rest-defence steps (3): `rdConservative` محافظ، `rdStandard` معتاد، `rdAggressive` هجومي
   - Final-third chips (4): `finalThirdWorkBall` تمريرات داخل المنطقة، `finalThirdEarlyCrosses` عرضيات مبكرة، `finalThirdBalanced` متوازن، `finalThirdShootOnSight` التسديد عند أول فرصة
   - Offside trap (3): `trapOff` إيقاف، `trapOn` تشغيل، `trapDeepWarning` لا فائدة منها مع خط عميق — مخاطرة صرفة. ارفع الخط أو أغلق المصيدة.
   - Readout (1): `restDefenceHint` بقاء لاعبين أكثر يعني غطاءً أفضل لكن مشاركة أقل في الهجوم.
2. Update the matching getters/method in `lib/l10n/app_localizations_ar.dart` to return the same Arabic values (the class is what the app actually reads; the ARB and the class must never disagree). `tacticsEstPossession` keeps its `int share` parameter.
3. Touch NOTHING else: no consumer file (`tactics_sections.dart`, `tactics_setup_view.dart`), no EN values, no `app_localizations.dart` abstract signatures (they already exist), no engine/model/balance file.
4. Extend the existing RTL Arabic pump in `test/features/squad/squad_view_test.dart` (the `T-0064 (RTL Arabic)` test) — or add one test beside it — asserting in the Arabic locale: the pressing row's label reads الضغط, its pill reads متوسط at the default and مرتفع after a max drag, the final-third chips read تمريرات داخل المنطقة / عرضيات مبكرة / التسديد عند أول فرصة, the offside toggle reads إيقاف, and the possession readout reads الاستحواذ المتوقع.

## Out of Scope
- Any new key that does not appear in the list above (the ARB stays 1:1 with `app_en.arb` minus `@`-metadata keys).
- Localizing `effectSummary` strings (engine-generated, game-wide — separate concern, unchanged from T-0064).
- Localizing the control card's remaining fixed labels (TACTICS, TEAM RATING, Auto Pick) and the formation dropdown.
- RTL layout changes — T-0061/T-0062 already mirror the sliders.

## Acceptance Criteria
- [ ] `comm -23 <(grep -o '^  "[a-zA-Z]*"' lib/l10n/app_en.arb | sort) <(grep -o '^  "[a-zA-Z]*"' lib/l10n/app_ar.arb | sort) | wc -l` prints `0` — no EN key missing from the AR ARB.
- [ ] All 47 AR values match the table in Requirement 1 exactly (reviewer spot-checks against the task).
- [ ] The Arabic-locale widget test asserts the localized axis label, step pill, final-third chips, offside toggle and possession readout from Requirement 4; the mirrored drag still commits the same enum.
- [ ] EN behaviour unchanged: the full existing suite green (EN assertions like `find.text('Mid')` / `find.text('Off')` must not be edited away — add AR assertions, do not rewrite EN ones).
- [ ] `flutter analyze` reports zero warnings; `flutter test` full suite green; `test/features/match/` + `test/balance/` pass with `REGEN_SNAPSHOT` unset.

## How to Verify
```bash
comm -23 <(grep -o '^  "[a-zA-Z]*"' lib/l10n/app_en.arb | sort) <(grep -o '^  "[a-zA-Z]*"' lib/l10n/app_ar.arb | sort) | wc -l   # 0
flutter analyze                    # No issues found!
flutter test test/features/squad/squad_view_test.dart    # all green incl. AR assertions
flutter test                      # full suite green
flutter test test/features/match/ test/balance/          # zero-drift gates, no REGEN
```
Expected: gap count 0, analyze clean, suites green; manually (`flutter run`, Arabic locale) the whole tactic sheet — axes, pills, chips, toggle, readouts — reads Arabic.

---

## Developer Notes

## Review Log
