---
id: T-0069
title: Show squad chemistry on the control card and pre-match analysis
priority: medium
status: needs-review
attempts: 2
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
- [x] The Team tab control card shows the XI's chemistry as `+N%` and updates after swaps/Auto Pick (it derives from the same `xi` the pitch renders).
- [x] Pre-match analysis shows the chemistry line for both teams, EN and AR.
- [x] The seven mentality keys and all pre-existing keys are untouched; the ARB key sets stay 1:1 (EN ↔ AR).
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

### Attempt 2 (review fix)

- **Fix — the two failing injury tests:** exactly as the reviewer directed, TEST-SIDE ONLY (no production change): `pumpLocalized` in `test/features/match/injury_ui_test.dart` now enlarges the viewport to 2400×3600 @ dpr 3 (the same pattern as `injury_surfaces_test.dart` and `detail_sheet_merge_only_test.dart`). The new CHEMISTRY row made the analysis ListView one row taller, pushing the medical-room card below the fold of the default 600×800 viewport — a lazy ListView never builds off-screen children, so `find.text` saw 0 widgets. With the taller viewport the file is **11/11 green** (was 9/11).
- **Full suite — the one remaining verification from attempt 1 — now completed and green:** full `flutter test` → **911/911** (this run includes the T-0072 attempt-2 rework that shares this tree; both tasks' changes are covered by it). `flutter analyze` → zero warnings. ARB parity was verified by the reviewer at 138/138 with `teamChemistry` in both ARBs and all three hand classes — unchanged this attempt.
- **Files changed (attempt 2):** `test/features/match/injury_ui_test.dart` (viewport in the shared helper), `tasks/…T-0069….md` (this file).
- **Reviewer's forward-looking note acknowledged (not a failure, not this task's scope):** the forecast's WIN/DRAW/LOSS Monte-Carlo does not apply chemistry while the new row displays it — documented as display-only in attempt 1's notes. Making the forecast chemistry-aware or labelling the row "applied at kick-off" belongs to a future task; the owner's board would need to file it.

## Review Log

### Review 2026-11-09, attempt 1: FAIL
Ran: `flutter analyze` (clean), `flutter test test/features/squad/ test/features/match/pre_match_screen_test.dart test/features/match/match_forecast_test.dart` (246/246), ARB key parity check (EN 138 = AR 138, `teamChemistry` present in both ARBs and all three hand classes), full `flutter test` on HEAD.

**Failures:**

1. Criterion 4 — "flutter test full suite green with test/features/match/ … passing": the full suite on HEAD fails exactly two tests, both in `test/features/match/injury_ui_test.dart`:
   - `pre-match medical room (requirement 2) the analysis lists injured players with their count (EN, LTR)` — `Expected: exactly one matching candidate / Found 0 widgets with text "Medical room"` (injury_ui_test.dart:175)
   - `pre-match medical room (requirement 2) Arabic renders the localized room (RTL)` — same, `الغرفة الطبية` (injury_ui_test.dart:199)
   - Root cause: the new CHEMISTRY row in `_StrengthCard` makes the analysis ListView one row taller, pushing the medical-room card below the fold of the injury tests' viewport — a lazily-built ListView does not build off-screen children, so `find.text` sees 0 widgets. This is the same viewport lesson recorded in T-0071's debugging notes (the 600×800 default cuts content below the action area).
   - Attribution proven by A/B: at 362148c (pre-T-0069, with T-0071 and the rarity-art commit already in) `flutter test test/features/match/injury_ui_test.dart` is 11/11 green; on HEAD the same file is 9/11 with exactly these two red. The only pre-match production delta in between is this task's chemistry row.
   - The production layout itself is fine (a ListView scrolls on a real device); the fix belongs in the tests: enlarge the injury tests' viewport (e.g. 2400×3600 @ dpr 3, as `detail_sheet_merge_only_test.dart` and `injury_surfaces_test.dart` do) or `scrollUntilVisible` the medical room before the expectations — then re-run the FULL suite (this task's own Developer Notes flagged the full run as the one remaining verification; it does not pass).
   - Note: the criterion's other clauses hold — analyze is clean, `test/balance/` passed in the full run (no failures there), and no `REGEN_SNAPSHOT` was set.

**Passed:** criteria 1–3 — the control-card CHEMISTRY row derives from the XI via `chemistryPercentOf` (`tactics_setup_view.dart:103-105`) and renders `+4%`/`+0%` per the new squad tests; the pre-match comparison row renders both sides EN and AR (`الكيمياء` + `+4%`/`+2%` asserted); ARB key sets 1:1 at 138/138 with `teamChemistry` in both ARBs and all three hand classes; zero +/- lines touch the mentality keys; scope exactly the 10 declared files.

**What to do:** fix the two injury tests' viewport/scroll (test-side only — no production change needed or wanted), then resubmit with a completed full-suite run.

**Reviewer note (not a failure, for a future task):** the forecast now DISPLAYS both sides' chemistry but the Monte-Carlo behind the WIN/DRAW/LOSS numbers does not apply it (display-only, as documented) — consider either making the forecast chemistry-aware or labelling the row "applied at kick-off" so the sheet cannot read as if the percentages already include it.
