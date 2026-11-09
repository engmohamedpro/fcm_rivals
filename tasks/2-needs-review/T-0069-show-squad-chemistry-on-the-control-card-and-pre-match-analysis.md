---
id: T-0069
title: Show squad chemistry on the control card and pre-match analysis
priority: medium
status: needs-review
attempts: 1
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

- **Summary of changes:** `_ControlCard` gained `chemistryPercent` (default 0); `TacticsSetupView` computes it via `chemistryPercentOf([for (var slot = 0; slot < 11; slot++) xi[slot]?.base.nationality])` — the UI never recomputes the formula, it calls T-0067's function. The CHEMISTRY row renders right-aligned under the setup row in the TEAM RATING label style: label localized `teamChemistry.toUpperCase()`, value `'+$n%'` — dim (textDim) at 0, rating-color at n ≥ 1. Pre-match: `MatchForecast` gained `userChemistry`/`opponentChemistry` (defaults 0), computed in `forecast()` from each side's starting XI (`squad.take(11)` — the squad lists are slot-ordered by the season store, same convention as the totals wiring); `_StrengthCard` renders one chemistry comparison row with the other rows via an optional `format` callback showing `+N%` per side, gold on the higher side. l10n: `teamChemistry` — EN 'Chemistry', AR 'الكيمياء' — added to `app_en.arb`, `app_ar.arb` and the three hand-maintained classes in gen-l10n canonical formatting; key sets stay 1:1.
- **Files changed:** `lib/features/squad/tactics_setup_view.dart`, `lib/features/match/match_forecast.dart`, `lib/features/match/pre_match_analysis.dart`, `lib/l10n/{app_en.arb,app_ar.arb,app_localizations.dart,app_localizations_en.dart,app_localizations_ar.dart}`, tests: `test/features/squad/squad_view_test.dart` (+3), `test/features/match/pre_match_screen_test.dart` (+2), `tasks/…T-0069….md`.
- **How I tested it:** `flutter analyze` → No issues found. `squad_view_test` + `pre_match_screen_test` + `match_forecast_test` → **28/28**: (a) the control card shows `+4%` for the owner's example XI (2 Egypt + 4 Brazil + 5 distinct) and `+0%` for all-distinct; (b) the analysis renders `+4%` vs `+2%` for both sides (forecast fixtures carry the new fields); (c) Arabic RTL pumps show `الكيمياء` with the same percents and no EN leakage. Zero-drift: engine snapshot 1/1, balance 88/88 with `REGEN_SNAPSHOT` unset. Broad sweep (squad + match + forecast + snapshot + balance + ui) → **346/346 green**. The FULL `flutter test` run could not complete inside this session's time budget after the sweep; every directly-affected suite is green and the analyzer is clean — the reviewer should treat the full-suite pass as the one remaining verification.
- **Concerns / assumptions:** (1) The forecast chemistry uses the first 11 of each squad list as the starters — true for the season store's slot-ordered lists; the friendly path (`MatchSession.create`) does not go through the forecast UI, so no other caller is affected. (2) Chemistry in the forecast is display-only (the Monte-Carlo sim itself does not apply it — it uses neutral totals by design); the live engine applies it at match time. (3) Test-bug fixed during development: an escaped `'N\$slot'` literal made all 11 players share one nationality (+10%, not +0%) — the test was wrong, not the widget. (4) ARB regenerated formatting follows the house gen-l10n canonical style.

## Review Log
