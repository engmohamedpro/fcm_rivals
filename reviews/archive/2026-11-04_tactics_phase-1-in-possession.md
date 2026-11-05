# Tactics Phase 1 — In Possession Instructions
- Feature: tactics
- Type: Design
- Priority: Major
- Reviewer: Coach Hady
- Created: 2026-11-04
- Status: CLOSED
- Completed by: Kareem
- Completed on: 2026-11-05

## Context
First of the three custom-tactics groups replacing the removed Playing Styles (execute after `2026-11-04_tactics_phase-0-remove-playing-styles`). Gameplay impact: the player controls how his team keeps and moves the ball — build-up, tempo, width and final-third approach. Combinations rebuild the removed possession/direct/long-ball/wing styles (e.g. Play Out + Slow + Narrow ≈ old Tiki-Taka), so depth comes from mixing dials instead of picking a named style. Scope note: "attacking freedom / fluidity" is deliberately NOT included — the engine has no off-ball-movement axis to express it honestly; fake depth is worse than absent depth.

## Tasks
- [x] Task 1: Add the In Possession data model | Where: `lib/features/match/tactics.dart` (`InPossessionTactics` from phase 0) | Expected: four instruction fields, each with a default (Standard/Balanced) producing identity modifiers: `buildUp` (Play Out from the Back / Mixed / Long Ball), `tempo` (Slow / Standard / Fast), `width` (Narrow / Standard / Wide), `finalThird` (Work Ball into Box / Balanced / Early Crosses / Shoot on Sight). Anchor values (GDD rule 14 placeholders, tuned by Task 4):
  - Play Out: possession 1.10, passAccuracy 1.05, chance 0.94 · Long Ball: possession 0.82, passAccuracy 0.86, chance 1.06, stamina 0.96
  - Slow: possession 1.06, chance 0.95, stamina 0.94 · Fast: possession 0.95, chance 1.05, passAccuracy 0.97, stamina 1.08
  - Narrow: passAccuracy 1.04, chance 0.96 · Wide: passAccuracy 0.96, chance 1.05
  - Work Ball: chance 0.92, shotQuality 1.08 · Early Crosses: chance 1.04, shotQuality 0.95, passAccuracy 0.96 · Shoot on Sight: chance 1.10, shotQuality 0.90
  Every option exposes a visible `effectSummary` (GDD 10.3), same honest-estimate format as the old possession line (estimated share, not raw multiplier).
- [x] Task 2: Engine wiring incl. the new shot-quality hook | Where: `lib/features/match/match_engine.dart:655-669` (possession competition), `:690`, `:791` (pass accuracy), `:773` (chance creation), conversion path after `:773` | Expected: all four instructions compose multiplicatively into the bundle consumed at the existing single-application sites. Add a `shotQuality` per-side hook on the chance→goal conversion path (the engine currently only models chance frequency; Work Ball vs Shoot on Sight cannot be told apart without it). Possession modifier still applied exactly once inside the power competition. No stacking of the same modifier at two sites.
- [x] Task 3: In Possession tab UI | Where: `lib/features/match/pre_match_screen.dart`, `lib/features/match/live_tactics_screen.dart` (phase-0 scaffold) | Expected: segmented controls for the four instructions, live effect summary under each, and an estimated-possession readout that updates as the player changes options (reuse the honest-share formula from the old `StyleModifiers.effectSummary`). In-match changes go through `ChangeTacticsCommand`. EN/AR labels, RTL verified.
- [x] Task 4: Balance verification | Where: `test/balance/match_engine_balance_test.dart` (extend the phase-0 harness) | Expected: 10,000 seeded sims per case, even strength vs default tactics. (a) Each single instruction at its extreme: win rate 46–54%. (b) Full-stack extremes — Play Out+Slow+Narrow+Work Ball (max possession) and Long Ball+Fast+Wide+Shoot on Sight (max direct): win rate 40–58%. (c) Measured possession share for ANY combo stays within 33–65% (real-world ceilings: elite possession sides ~60–65%, low-block counter sides ~30–35%). (d) Global realism anchors unchanged: total goals 2.6–2.9/match, shot conversion 10–11%, shots per team 10–14. Report the full 3×3×3×4 instruction matrix in the test output.
- [x] Task 5: GDD documentation | Where: `docs/fcm_rivals_GDD_SRS.md` (section 10.2 from phase 0) | Expected: the In Possession group is documented with all options, their modifier anchors, trade-offs, and the balance bands from Task 4.

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated
- [x] EN/AR localized, RTL verified
- [x] No performance regression
- [x] Every option's effect summary is visible in the UI (GDD 10.3)
- [x] Balance bands hold: single extreme 46–54%, full-stack combo 40–58%, possession 33–65%, goals 2.6–2.9, conversion at the engine's calibrated anchor (see Developer Notes) (10k seeded sims)

## Developer Notes
- Model: `InPossessionTactics` with `buildUp`/`tempo`/`width`/`finalThird`
  enums; defaults (Mixed/Standard/Standard/Balanced) are the identity.
  Value equality, `copyWith`, tolerant JSON (unknown keys → defaults),
  and an honest `estimatedPossessionShare` (`m^1.4/(m^1.4+1)`).
- Engine: the four instructions compose multiplicatively into
  `TacticModifiers`; possession still applied exactly once inside the
  power competition; passAccuracy at the two completion sites; chance
  at the single creation site. New `shotQuality` per-side hook on the
  chance→goal conversion path (penalties exempt — set pieces are not
  built-up play). Defaults bit-identical (snapshot test unchanged).
- UI: `_InPossessionControls` segmented rows in the shared
  `TacticsGroupScaffold` (Team tab sheet, pre-match, live tactics);
  live effect summary per row plus the estimated-possession readout;
  in-match changes via `ChangeTacticsCommand`. EN/AR via ARB, RTL-safe
  (Wrap layouts, no directional paddings added).
- Balance (Task 4 anchors were placeholders, harness-tuned as the task
  instructs): the review's raw anchors overshot the bands because the
  engine's power competition amplifies possession costs and the
  shotQuality hook compounds on conversion. Tuned values, direction
  preserved: Play Out possession 1.10→1.06; Slow possession 1.06→1.03;
  Long Ball 0.82/0.86/1.06→0.95/0.91/1.03; Fast 0.95/1.05/1.08→
  0.97/1.03/1.04; Wide chance 1.05→1.03; Shoot on Sight
  1.10/0.90→1.04/0.94. Measured: singles 47–52%, full-stack 40–58%,
  max-possession stack share 57.9% (inside 33–65), full 3×3×3×4 matrix
  reported and inside 38–60%.
- Conversion anchor mismatch (flagged): the review's 10–11% band does
  not match the shipped engine, which the snapshot test locks at ~12%
  (measured 11.7% on this harness). Phase-1 defaults move nothing; the
  test pins the engine's own anchor instead of the real-world number.
- `flutter analyze` clean; 681 tests green (was 678).

## Reviewer Verification
Closure record backfilled 2026-11-05 by Coach Hady (lifecycle audit `2026-11-05_reviews_lifecycle-compliance-audit`, finding F3): this file was archived at Status DONE with an empty verification placeholder; the closure decision itself was made in commit `05346c2` ("close phases 0-2, uphold phase-3 rejection") but never written into the file. Status DONE → CLOSED per README.md:116/:63.

What was verified for that closure (static re-checks on main @ `45e23af`, 2026-11-05): `InPossessionTactics` at `lib/features/match/tactics.dart:470` with its four instruction enums (`BuildUpStyle` :381, `AttackTempo` :405, `AttackWidth` :426, `FinalThirdApproach` :439); the `shotQuality` axis and the `TuningOverrides` seam in `TacticModifiers` (`operator *` :80, seam :206 with `current = none` in production); the harness-tuned anchors the Developer Notes list (Play Out 1.06, Long Ball 0.95/0.91/1.03) are the shipped constants. Caveat, stated plainly: the `flutter test` suite was NOT re-run for this backfill — the audit sandbox has no Flutter/Dart SDK; the measured bands quoted above are the developer's execution-day runs. Two evidence-backed recalibrations were accepted, not silent band moves: the harness tuning of Task-4 placeholder anchors (the task itself instructs it) and the conversion-anchor flag (~12% locked by the snapshot test vs the review's 10-11%) — the latter is an engine-level calibration question that belongs to the engine reviews, not to this closed file.
