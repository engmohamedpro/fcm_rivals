# Penalty model: 5x real award rate, 24% conversion
- Feature: match-engine
- Type: Design
- Priority: Critical
- Reviewer: Coach Hady
- Created: 2026-11-04
- Status: CLOSED
- Completed by: Kareem
- Completed on: 2026-11-04

## Context
Penalties are awarded ~5x the real rate and converted at ~1/3 of it. Measured over 2,000 even-strength seeded simulations at HEAD ceedb00: 1.43 penalties/match at 24.1% conversion (real football: 0.25–0.30/match at 75–78%), and penalty goals already account for 12.7% of all goals. The two errors partially cancel in the aggregate goals/match figure, which is why the calibration suite never caught them.

## Tasks
- [x] Task 1: Cut the in-box foul probability from 0.07 to 0.013 | Where: `lib/features/match/match_engine.dart:798` | Expected: 0.18–0.36 penalties/match over ≥2,000 seeded even-strength matches (4-3-3 vs 4-4-2); total fouls stay in 16–24. With ~20 fouls/match this lands at ~0.26 pens/match, matching Europe's top divisions.
- [x] Task 2: Give penalties a dedicated shot path — they currently pass through the generic outcome draw where `config.blockChance` (0.28) can block them; 28% of penalties "blocked" is not football. For `ChanceQuality.penalty` skip the block layer and draw on-target ≈ 0.93, then P(goal | on-target) ≈ 0.82 modulated ±0.10 by the shooter-vs-GK edge | Where: `lib/features/match/match_engine.dart:970-1036` (block-first draw at :1030-1036; config at :208) | Expected: penalty conversion 68–84%, xG per penalty ≈ 0.76, zero `ShotOutcome.blocked` penalty events across ≥2,000 matches.
- [x] Task 3: Fix taker selection — penalties are taken by `_pickAttacker`, which draws with `_creatorWeights` (CAM 4.0 vs ST 1.6), so a CAM is ~2.5x more likely to take a penalty than a striker. Switch to `_shooterWeights` or a designated-taker flag | Where: `lib/features/match/match_engine.dart:855` (call site), `:1155-1163` (pickers) | Expected: STs take ≥45% of penalties for a 4-4-2 XI over ≥2,000 sims; taker distribution printed in the verification run.
- [x] Task 4: Lock with calibration assertions: penalties/match 0.18–0.36, conversion 0.68–0.84, penalty goals ≤ 12% of total goals | Where: `../../../test/features/match/engine_calibration_test.dart` | Expected: assertions green on CI; goals/match stays in 2.4–2.9 (this fix removes ~0.15 goals/match; the big-chance work in review `2026-11-04_match-engine_chance-and-set-piece-volume` adds roughly that back — land both before the final calibration pass).

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated
- [x] EN/AR localized, RTL verified
- [x] No performance regression
- [x] No `ShotOutcome.blocked` penalty events in a ≥2,000-match seeded run
- [x] Penalty award + shot events still render in match commentary/report (metadata intact)
- [x] Free-kick shot path (`ChanceQuality.freeKick`) unchanged here except the volume work in the set-piece review

## Developer Notes
- Measured over 2,000 even-strength seeds (4-4-2 vs 4-3-3): penalties/match 0.2785 (band 0.18-0.36), conversion 0.759 (band 0.68-0.84), blocked penalty shots 0, penalty goals 8.1% of all goals, fouls/match 19.9 (band 16-24), goals/match 2.6255 (band 2.4-2.9).
- New config knobs: `inBoxFoulChance` 0.013 (was a hardcoded 0.07), `penaltyOnTarget` 0.93, `penaltyGoalBase` 0.82, `penaltyGoalEdgeScale` 0.10 — the penalty draw is a dedicated branch in `_shoot` that skips the block layer; xG per penalty = onTarget x goalP (0.93 x ~0.76 measured).
- Taker selection switched from `_pickAttacker` (creator weights, CAM 4.0 vs ST 1.6) to `_pickShooter` (shooter weights): ST taker share now 54.0% (target >= 45%), distribution printed above in the harness run and locked via the calibration test.
- Free-kick path untouched (still `_pickAttacker`); user and AI shot paths otherwise unchanged.
- The extreme 90/10 calibration group previously failed on "avg goals under 4.4"; after this fix that test now PASSES and the group's remaining failure moved to "minnow shots > 5/team" — exactly the interplay this review predicted ("the big-chance work adds roughly that back"): the chance-and-set-piece-volume review (next in the queue) owns that assertion.

## Reviewer Verification
Verified independently on FRESH seeds (20,000-21,999, reviewer harness): 0.2660 penalties/match (band 0.18-0.36), conversion 0.750 (0.68-0.84), blocked penalty shots 0, fouls 19.9/match (16-24), goals/match 2.594 (2.4-2.9 — Task 4's no-regression requirement holds), penalty goals 7.7% of all goals (<= 12%), ST takers 54.1% (>= 45%); full taker distribution: st 288, cm 76, lm 64, cb 48, rm 36, rb 11, lb 9. Code inspection: inBoxFoulChance 0.013, penaltyOnTarget 0.93, penaltyGoalBase 0.82, penaltyGoalEdgeScale 0.10 as specified; dedicated penalty branch skips the block layer; free-kick path still uses _pickAttacker (AC met). Calibration penalty assertions and the goals-band test re-run green. All tasks and acceptance criteria verified — CLOSED.
