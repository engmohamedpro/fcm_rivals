---
id: T-0073
title: Gate the infinite-upgrade ladder with a seeded balance sweep
priority: high
status: todo
attempts: 0
depends_on: [T-0070, T-0072]
created: 2026-11-09
completed:
---

# T-0073: Gate the infinite-upgrade ladder with a seeded balance sweep

## Goal
The percentage-upgrade system's effect on match outcomes is measured and locked by band assertions — proving the engine stays fair when both sides grow infinitely and rewarding (not absurd) when the user is ahead — before the redesign ships.

## Context
- The engine was calibrated on 0-99 attributes: the chance sigmoid and strength curves consume attack-minus-defence edges, and the balance bands live in `test/balance/match_engine_balance_test.dart` (even-strength win rate 0.42-0.52, draw rate 0.22-0.32, avg goals per team 1.4-5.2, avg shots 4-22, win-rate bands by rating gap topping at 0.72-0.88 for a 20-point gap).
- T-0070 lets upgraded values exceed 99; T-0072 lifts AI squads the same way. Symmetric growth (both teams upgraded) should keep edges — and therefore the bands — intact; that is the hypothesis this gate verifies. A user ahead of the ladder grows the edge, which must win more without producing nonsense (10-goal stomps every match).
- Calibration precedent: `test/features/match/engine_calibration_test.dart` and the balance suite's seeded batch helpers (reuse them).
- This task changes no production code. If a band fails, the numbers go into Developer Notes and tuning is filed as a separate task.

## Requirements
1. New `test/balance/upgrade_ladder_balance_test.dart` with two seeded sweeps over seeds 0..999 (identical even-strength teams, same tactics/mentality):
   - **Symmetric growth:** both teams lifted by the same N ∈ {0, 10, 25, 50} percent (T-0070's `upgradedValue`). Assert at every level: the measured side's win rate stays in 0.42-0.52, draw rate in 0.22-0.32, and both teams' avg goals stay in 1.4-5.2 — the engine must not distort as everyone grows.
   - **User ahead:** team A fixed at base, team B lifted by N ∈ {10, 25, 50}. Measure B's win rate and both sides' avg goals; assert B's win rate rises monotonically with N and stays ≤ 0.88 (the 20-point-gap ceiling — a +50% edge must not be a guaranteed win); lock the exact bands after the first measured run and record the numbers in Developer Notes.
2. Print per-level measured numbers (win rate, draw rate, avg goals, avg shots) and mirror them in this task's Developer Notes.
3. If the symmetric sweep fails a band (the engine curves distort when attributes scale together), stop and report the numbers in Developer Notes — the curve rescale is a separate tuning task, not a patch here.

## Out of Scope
- Any production-code change — measurement and locks only.
- Retuning the engine's sigmoid, the division target curve or upgrade percentages — separate task if a band fails.
- Economy effects (duplicate value, coin sink removal) — separate measurement.

## Acceptance Criteria
- [ ] Both sweeps run seeds 0..999 with the symmetric bands (win 0.42-0.52, draw 0.22-0.32, goals 1.4-5.2) asserted at N ∈ {0, 10, 25, 50}.
- [ ] The user-ahead sweep shows monotonic win-rate growth, caps at ≤ 0.88, with its measured bands locked in the test and the raw numbers recorded in Developer Notes.
- [ ] The existing balance suite passes unchanged — no pre-existing band was edited to make the new test pass.
- [ ] `flutter analyze` zero warnings; `flutter test` full suite green.

## How to Verify
```bash
flutter analyze
flutter test test/balance/upgrade_ladder_balance_test.dart   # green, prints measured tables
flutter test test/balance/                                    # existing bands unchanged, green
flutter test
```
Expected: analyze clean; the new sweep prints the measured numbers (matching Developer Notes) and all assertions pass; pre-existing balance bands untouched.

---

## Developer Notes

## Review Log
