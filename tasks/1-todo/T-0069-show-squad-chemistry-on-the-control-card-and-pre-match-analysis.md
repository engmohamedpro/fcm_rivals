---
id: T-0069
title: Show squad chemistry on the control card and pre-match analysis
priority: medium
status: todo
attempts: 0
depends_on: [T-0067]
created: 2026-11-09
completed:
---

# T-0069: Show squad chemistry on the control card and pre-match analysis

## Goal
The chemistry percentage is visible where the squad is built and before every match: a CHEMISTRY row on the Team tab's control card and a chemistry line in the pre-match analysis, fully localized EN/AR.

## Context
- The calculation comes from T-0067: `chemistryPercentOf(Iterable<String?> nationalities)` in `lib/features/match/chemistry.dart` — the UI never recomputes the formula, it only calls this one function on the XI's nationalities.
- Display surfaces: the control card (`_ControlCard` in `lib/features/squad/tactics_setup_view.dart`, around lines 202-330 — already takes `teamRating` and renders the TACTICS / MENTALITY / TEAM RATING rows; `TacticsSetupView` has the `xi` map in scope to compute the value) and the pre-match analysis (`lib/features/match/pre_match_analysis.dart:523-532`, where the ATTACK / SUPPORT / DEFENCE / goalkeeping comparison rows render from the forecast's `userTotals`/`opponentTotals`; the forecast input carries both squads' `MatchPlayer`s, which have `nationality` after T-0067).
- l10n house rules (lessons from T-0064/T-0065): every new key goes into BOTH `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb` AND the three hand-maintained classes `app_localizations.dart` / `app_localizations_en.dart` / `app_localizations_ar.dart`, in gen-l10n canonical formatting; the ARB key sets must stay 1:1.
- GDD 10.3 house principle: gameplay effects must be visible — chemistry is exactly such an effect.

## Requirements
1. `_ControlCard` gains a `chemistryPercent` parameter (int, default 0); `TacticsSetupView` computes it as `chemistryPercentOf([for (var slot = 0; slot < 11; slot++) xi[slot]?.base.nationality])` and renders a CHEMISTRY row in the same style as TEAM RATING, value `'+$n%'` (a 0% renders `+0%` in the dim style used for neutral values; n ≥ 1 renders in the value colour of the TEAM RATING row).
2. Pre-match analysis: one chemistry comparison line for the user and opponent XIs (both computed from their starting elevens via `chemistryPercentOf`), placed with the other comparison rows (`pre_match_analysis.dart` around lines 523-532), format `+N%` per side like the totals rows.
3. l10n: add `teamChemistry` — EN `Chemistry`, AR `الكيمياء` — to `app_en.arb`, `app_ar.arb` and the three `app_localizations*.dart` classes (canonical gen-l10n formatting). Use it for both surfaces' labels (`semanticsLabel` included where the row has one).
4. Widget tests: (a) the control card shows `+4%` for an XI containing 2 Egypt + 4 Brazil + 5 distinct nationalities, and `+0%` for an all-distinct XI; (b) the pre-match analysis renders the chemistry line for both sides; (c) an Arabic (RTL) pump shows `الكيمياء` and the same percentage.

## Out of Scope
- Changing the chemistry formula or where the engine applies it (T-0067).
- Per-player chemistry indicators on the cards/pitch (possible follow-up).
- Localizing the control card's remaining fixed labels (TACTICS, TEAM RATING, Auto Pick) — separate concern, unchanged from T-0064's scope decision.
- Live-match chemistry display (the pre-match and Team tab surfaces are enough for this slice).

## Acceptance Criteria
- [ ] The Team tab control card shows the XI's chemistry as `+N%` and updates after swaps/Auto Pick (it derives from the same `xi` the pitch renders).
- [ ] Pre-match analysis shows the chemistry line for both teams, EN and AR.
- [ ] The seven mentality keys and all pre-existing keys are untouched; the ARB key sets stay 1:1 (EN ↔ AR).
- [ ] New tests (a)-(c) pass; `flutter analyze` reports zero warnings; `flutter test` full suite green with `test/features/match/` + `test/balance/` passing without `REGEN_SNAPSHOT`.

## How to Verify
```bash
flutter analyze
flutter test test/features/squad/                      # control-card chemistry tests green
flutter test test/features/match/pre_match_screen_test.dart   # analysis line green
flutter test                                          # full suite green, zero drift
flutter run   # manual: Team tab → control card shows CHEMISTRY +N%; pre-match shows both sides
```
Expected: analyze clean, suites green; manually the control card reads CHEMISTRY with the XI's percentage and the pre-match analysis compares both teams' chemistry.

---

## Developer Notes

## Review Log
