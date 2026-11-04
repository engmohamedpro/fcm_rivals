# Tactics Phase 1 — In Possession Instructions
- Feature: tactics
- Type: Design
- Priority: Major
- Reviewer: Coach Hady
- Created: 2026-11-04
- Status: OPEN
- Completed by: -
- Completed on: -

## Context
First of the three custom-tactics groups replacing the removed Playing Styles (execute after `2026-11-04_tactics_phase-0-remove-playing-styles`). Gameplay impact: the player controls how his team keeps and moves the ball — build-up, tempo, width and final-third approach. Combinations rebuild the removed possession/direct/long-ball/wing styles (e.g. Play Out + Slow + Narrow ≈ old Tiki-Taka), so depth comes from mixing dials instead of picking a named style. Scope note: "attacking freedom / fluidity" is deliberately NOT included — the engine has no off-ball-movement axis to express it honestly; fake depth is worse than absent depth.

## Tasks
- [ ] Task 1: Add the In Possession data model | Where: `lib/features/match/tactics.dart` (`InPossessionTactics` from phase 0) | Expected: four instruction fields, each with a default (Standard/Balanced) producing identity modifiers: `buildUp` (Play Out from the Back / Mixed / Long Ball), `tempo` (Slow / Standard / Fast), `width` (Narrow / Standard / Wide), `finalThird` (Work Ball into Box / Balanced / Early Crosses / Shoot on Sight). Anchor values (GDD rule 14 placeholders, tuned by Task 4):
  - Play Out: possession 1.10, passAccuracy 1.05, chance 0.94 · Long Ball: possession 0.82, passAccuracy 0.86, chance 1.06, stamina 0.96
  - Slow: possession 1.06, chance 0.95, stamina 0.94 · Fast: possession 0.95, chance 1.05, passAccuracy 0.97, stamina 1.08
  - Narrow: passAccuracy 1.04, chance 0.96 · Wide: passAccuracy 0.96, chance 1.05
  - Work Ball: chance 0.92, shotQuality 1.08 · Early Crosses: chance 1.04, shotQuality 0.95, passAccuracy 0.96 · Shoot on Sight: chance 1.10, shotQuality 0.90
  Every option exposes a visible `effectSummary` (GDD 10.3), same honest-estimate format as the old possession line (estimated share, not raw multiplier).
- [ ] Task 2: Engine wiring incl. the new shot-quality hook | Where: `lib/features/match/match_engine.dart:655-669` (possession competition), `:690`, `:791` (pass accuracy), `:773` (chance creation), conversion path after `:773` | Expected: all four instructions compose multiplicatively into the bundle consumed at the existing single-application sites. Add a `shotQuality` per-side hook on the chance→goal conversion path (the engine currently only models chance frequency; Work Ball vs Shoot on Sight cannot be told apart without it). Possession modifier still applied exactly once inside the power competition. No stacking of the same modifier at two sites.
- [ ] Task 3: In Possession tab UI | Where: `lib/features/match/pre_match_screen.dart`, `lib/features/match/live_tactics_screen.dart` (phase-0 scaffold) | Expected: segmented controls for the four instructions, live effect summary under each, and an estimated-possession readout that updates as the player changes options (reuse the honest-share formula from the old `StyleModifiers.effectSummary`). In-match changes go through `ChangeTacticsCommand`. EN/AR labels, RTL verified.
- [ ] Task 4: Balance verification | Where: `test/balance/match_engine_balance_test.dart` (extend the phase-0 harness) | Expected: 10,000 seeded sims per case, even strength vs default tactics. (a) Each single instruction at its extreme: win rate 46–54%. (b) Full-stack extremes — Play Out+Slow+Narrow+Work Ball (max possession) and Long Ball+Fast+Wide+Shoot on Sight (max direct): win rate 40–58%. (c) Measured possession share for ANY combo stays within 33–65% (real-world ceilings: elite possession sides ~60–65%, low-block counter sides ~30–35%). (d) Global realism anchors unchanged: total goals 2.6–2.9/match, shot conversion 10–11%, shots per team 10–14. Report the full 3×3×3×4 instruction matrix in the test output.
- [ ] Task 5: GDD documentation | Where: `docs/fcm_rivals_GDD_SRS.md` (section 10.2 from phase 0) | Expected: the In Possession group is documented with all options, their modifier anchors, trade-offs, and the balance bands from Task 4.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] Every option's effect summary is visible in the UI (GDD 10.3)
- [ ] Balance bands hold: single extreme 46–54%, full-stack combo 40–58%, possession 33–65%, goals 2.6–2.9, conversion 10–11% (10k seeded sims)

## Developer Notes
<Implementation notes, rejected points with reason.>

## Reviewer Verification
<Filled by reviewer before setting CLOSED.>
