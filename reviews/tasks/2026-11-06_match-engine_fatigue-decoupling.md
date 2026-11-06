# Match engine: decouple the late-concession/fatigue bill from the raw pressing constant

- Feature: match-engine
- Type: Balance
- Priority: Critical
- Created: 2026-11-06
- Status: OPEN
- Completed on: -

## Context
Prerequisite follow-up of `2026-11-05_tactics_phase3-balance-bands-and-sweep` (SPLIT 2026-11-06, rejection upheld per §6.B). The combined tactics instruction space cannot meet its pinned bands on BOTH seed pools by instruction anchors alone: the gegenpress late-goals bill and the press-side singles bands pull the same axis in opposite directions under the current fatigue formula. This task makes that one-knob axis two knobs at the engine level, with production-default behaviour bit-identical.

## Investigation & Evidence
- Investigation (carried from the balance review, measured on main `0218dc7`/`baaf21a`, Flutter 3.47.9): under the fatigue formula `coldStart * (1 + 2.0(1-avg/100)t^2) * (1 + pressBill*t^2)` the gegenpress late-goals bill and the press-side singles bands (highPress/highLine/restAggressive) are ONE knob.
- Root cause / technical justification: `pressBill` (`lib/features/match/match_engine.dart:878-883`) reads the RAW `PressingIntensity.high` stamina constant, not the composed bundle — raising hpStamina above 1.30 silently kills the gegenpress late-goals bill (measured: hpStamina 1.32/1.34 → late goals DROP to 110%, matrix worst 60.9 on the suite pool), while the press-side singles demand the opposite move.
- Affected files/components: `lib/features/match/match_engine.dart` (stamina drain / pressBill site), `lib/features/match/tactics.dart` (`TuningOverrides` seam at :206, `operator *` at :79, `_dampedStamina` at :121)
- Evidence: best anchor-only candidate (cost 0.86, fcChance 1.26, hpChance 1.10, lowPoss 0.91) still fails 2/44 pinned cases on the sweep pool and 5/44 on the suite pool; every press-side lever that moves allAttack/late-goals also moves highLine/highPress/restAggressive and the matrix worst combo (both pools, full-precision runs in the balance review's Developer Notes).
- Expected benefit / necessity: the two opposing constraints become independently satisfiable, making the 44 pinned cases reachable on BOTH pools by the anchor pass (`2026-11-06_tactics_phase3-anchor-pass-and-gates`).
- Dependencies / side effects: non-default tactic behaviour changes (that is the point); production defaults (`TuningOverrides.current = none`) must keep `engine_snapshot_test.dart` and `engine_calibration_test.dart` bit-identical; the new lever must be exposed through the `TuningOverrides` seam so the sweep can score it without model edits.

## Reproduction Steps
`flutter test tool/tactics_tuning_sweep.dart` (SWEEP_MODE=baseline) on main: 4 fails on the sweep pool; `--dart-define=SWEEP_SEEDS_SUITE=true`: 5 fails — no candidate set closes both (full runs in the balance review's Developer Notes).

## Task
- [ ] Decouple the late-concession/fatigue bill from the raw pressing constant | Where: `lib/features/match/match_engine.dart:878-883` (pressBill/fatigue), `lib/features/match/tactics.dart:206-221` (TuningOverrides seam) | Expected: pick ONE mechanism the sweep proves superior — (a) a separate late-concession hook keyed to the COMPOSED stamina bundle rather than the raw pressing constant, or (b) a baseline-relative late bill — such that the gegenpress late-goals band (≥115% vs baseline) and the press-side singles bands (46-54%) are simultaneously reachable on both seed pools; production defaults bit-identical (snapshot/calibration suites unchanged).

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes (only the four tracked phase-3 balance bands may remain red until the anchor pass lands)
- [ ] EN/AR localization complete and RTL verified where applicable
- [ ] No performance or application-size regression
- [ ] `engine_snapshot_test.dart` and `engine_calibration_test.dart` green with bit-identical output at production defaults
- [ ] With the new lever exposed via `TuningOverrides`, the sweep demonstrates BOTH constraint families satisfiable on both seed pools (winning mechanism + sweep lines documented in Developer Notes); zero new fails among the 44 pinned cases at shipped constants

## Developer Notes
<Implementation summary, files changed, exact test commands/results, and rejection reason/evidence if applicable. Implement this task only, create one task-specific commit, and push it before starting another task.>

## Reviewer Verification
<Reviewer records verification date, tested commit hash, checks performed, results, and remaining limitations. Do not add personal names.>

## Links
- Depends on: None
- Follows: `2026-11-05_tactics_phase3-balance-bands-and-sweep`
- Follow-up: None

## Amendments
<Reviewer-owned, append-only. Add dated entries correcting the task's target or mechanism; never rewrite the original task text.>
