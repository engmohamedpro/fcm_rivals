---
id: T-0063
title: Add generic enum-scale helpers for ordered tactics instructions
priority: medium
status: done
attempts: 1
depends_on: []
created: 2026-11-08
completed: 2026-11-08
---

# T-0063: Add generic enum-scale helpers for ordered tactics instructions

## Goal
One tested pair of generic helpers converts any ordered instruction enum to and from its 0-100 scale position, ready for the slider UI (T-0064), with the mentality mapping behaviour unchanged.

## Context
- `mentalityFromScale` / `mentalityToScale` (`lib/features/match/team_tactics.dart`, lines 200-209) are mentality-specific: `round(value * (n - 1) / 100)` and `round(index * 100 / (n - 1))`.
- The nine ordered axes (GDD 10.2): `BuildUpStyle`, `AttackTempo`, `AttackWidth` (`lib/features/match/in_possession_tactics.dart`); `DefensiveLine`, `PressingIntensity`, `TacklingAggression` (`lib/features/match/out_of_possession_tactics.dart`); `CounterPress`, `AttackOnRecovery`, `RestDefence` (`lib/features/match/transition_tactics.dart`). Each has exactly 3 values with the default at the middle index, so every default maps to scale 50 — the slider's centre tick.
- `FinalThirdApproach` (4 categorical styles, not a spectrum) and the offside-trap bool are deliberately NOT ordered scales and must not be forced through these helpers.
- No model-level tactics test file exists today — the mentality mapping is only locked through widget tests in `test/features/squad/squad_view_test.dart`. The new unit tests go in a new `test/features/match/tactics_scale_test.dart`.
- Polarity (verified against the current enum declarations): on every one of the nine axes the scale-100 end is the aggressive/riskier step — `longBall`, `fast`, `wide`, `high`, `high`, `aggressive`, `immediate`, `fast`, `aggressive` respectively — and every default sits at the middle index. This task locks that table so a later enum reorder cannot silently flip a slider.

## Requirements
1. Add generic helpers next to the mentality pair in `lib/features/match/team_tactics.dart`: `T enumFromScale<T extends Enum>(List<T> values, int value)` and `int enumToScale<T extends Enum>(List<T> values, T value)` — identical math to the mentality pair (Dart `.round()`, half away from zero — never truncation or int division), input clamped to 0-100.
2. Refactor `mentalityFromScale` / `mentalityToScale` to delegate to them so there is a single code path with identical behaviour.
3. Unit tests in `test/features/match/tactics_scale_test.dart`: round-trip every one of the nine enums (each value against each of its scale positions); every default lands at 50; out-of-range scales (-5, 105) clamp to the first / last value.
4. Boundary cases locked with the verified numbers: 3 steps — scale 25 maps to the middle value, 75 to the last; 7 steps — scale 58 maps to `Mentality.balanced`, 59 to `Mentality.positive`.
5. Polarity guard: a test table asserts `enumFromScale(values, 100)` equals the aggressive end listed in Context for each of the nine axes — so the slider's max end is always the riskier step and a future enum reorder fails CI instead of flipping an axis silently.

## Out of Scope
- Any UI change, new instruction steps or values, engine or balance changes.
- `FinalThirdApproach` and the offside trap.

## Acceptance Criteria
- [x] The generic helpers exist with the exact math above; the mentality mapping is unchanged (existing mentality tests green, untouched).
- [x] Round-trip tests cover all nine ordered enums and prove every default maps to 50.
- [x] The boundary cases (3 steps: 25 → middle, 75 → last; 7 steps: 58 → Balanced, 59 → Positive) and the nine-axis polarity table are locked by tests.
- [x] `flutter analyze` reports zero warnings; `flutter test test/features/match/` green.

## How to Verify
```bash
flutter analyze
flutter test test/features/match/
flutter test test/features/squad/squad_view_test.dart
```
Expected: analyze clean; the match feature suite including the new `tactics_scale_test.dart` is green, and the existing mentality widget tests still pass untouched.

---

## Developer Notes

- **Summary of changes:** the generic ordered-enum scale pair lives next to the mentality mapping in `team_tactics.dart`: `T enumFromScale<T extends Enum>(List<T> values, int value)` — `round(value.clamp(0, 100) * (n-1) / 100)`, Dart `.round()` (half away from zero), never truncation — and `int enumToScale<T extends Enum>(List<T> values, T value)` — `round(index * 100 / (n-1))`. `mentalityFromScale` / `mentalityToScale` now delegate to them (one code path, behaviour identical — the squad view mentality tests pass untouched). Nothing else changed: no UI, no new steps, no engine/balance edits; `FinalThirdApproach` and the offside trap stay categorical by design.
- **Files changed:** lib/features/match/team_tactics.dart, test/features/match/tactics_scale_test.dart (new).
- **How I tested it:** `flutter analyze` — No issues found. New `test/features/match/tactics_scale_test.dart` — **6/6 passed**: (1) every value of all ten axes (the nine GDD 10.2 axes + mentality) round-trips exactly; (2) every default maps to scale 50 (the slider's centre tick); (3) out-of-range scales (−5, 105) clamp to first/last on every axis; (4) 3-step boundaries: 25 → middle, 75 → last, plus the mirrored 24 → first / 26 → middle; (5) 7-step mentality boundaries: 58 → Balanced, 59 → Positive, canonical positions 0/17/33/50/67/83/100 spot-checked at 0/50/100; (6) the polarity table: scale 100 equals the aggressive/riskier step on all nine axes (longBall, fast, wide, high, high, aggressive, immediate, fast, aggressive) and the aggressive end maps back to 100 — a future enum reorder flips a slider only by failing CI first. `flutter test test/features/match/ test/features/squad/squad_view_test.dart --concurrency=1` — **187/187 passed** (existing mentality widget tests green, untouched).
- **Concerns / assumptions:** none — pure model-layer addition; the helpers are the exact math the task specified, and the boundary numbers were verified against Dart rounding semantics in the test comments (round(0.5)=1, round(3.48)=3, round(3.54)=4).

## Review Log

### Review 2026-11-08, attempt 1: PASS
- Environment: Flutter 3.47.9 stable / Dart 3.13.7 (fresh SDK install at tag 3.47.9), 2-core container, main @ `6bb7e05`.
- Code review of `lib/features/match/team_tactics.dart` (diff `79645bf..6bb7e05`): `enumFromScale` is `(value.clamp(0, 100) * steps / 100).round()` and `enumToScale` is `(index * 100 / steps).round()` — the exact Dart `.round()` (half away from zero) math of the original mentality pair, which now delegate to them: one code path, behaviour identical by construction. `FinalThirdApproach` and the offside trap untouched — Out of Scope respected.
- Ran `flutter analyze` → `No issues found!` (zero warnings).
- Ran the verify commands inside `flutter test test/core/ui/ test/features/match/ test/features/squad/squad_view_test.dart test/balance/ test/features/season/ --concurrency=1` → **362/362 passed**, including the 6 new `tactics_scale_test.dart` tests: round-trips for every value of all ten axes; every default at scale 50; clamps (−5, 105); 3-step boundaries 25 → middle / 75 → last plus the mirrored 24/26; 7-step 58 → Balanced / 59 → Positive with the canonical 0/50/100 positions; the nine-axis polarity table (scale 100 = the aggressive end — longBall, fast, wide, high, high, aggressive, immediate, fast, aggressive — and the aggressive end maps back to 100; mentality 100 = veryAttacking). Then the full `flutter test --concurrency=1` gate → **855/855 passed**.
- Acceptance criteria, one by one: helpers with the exact math and the mentality mapping unchanged (squad-view mentality tests green, untouched) ✔; round-trips over all nine ordered enums with defaults at 50 ✔; the boundary cases and the polarity table locked by tests ✔; analyzer zero warnings and `test/features/match/` green ✔.
