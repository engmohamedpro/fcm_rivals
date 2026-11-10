---
id: T-0109
title: Achievements economy gate — the achievement faucet is measured, banded and locked against the match faucet
priority: high
status: todo
attempts: 0
depends_on: [T-0108]
created: 2026-11-10
completed:
---

# T-0109: Achievements economy gate — the achievement faucet is measured, banded and locked against the match faucet

## Goal
A seeded, multi-season simulation proves the achievement coin faucet is a controlled secondary income stream — never a dominant strategy, never a runaway faucet — and locks regression bands so every future catalog/economy change re-proves it. This is the "stable to the economy" requirement made executable.

## Context
- T-0076 set the precedent this task follows exactly (`test/balance/season_reward_economy_test.dart`): run the REAL economy end to end (real `SeasonStore`/`MatchSession` saves, real pack purchases), measure, lock bands with tolerance, document deviations. The four bands it locked (per-season earned, season-reward share ≤ 40%, bounded net coins, static champion ceiling) are the model; this task adds the achievement faucet to that world.
- The structural safety (geometric ladders + flat/sublinear coins ⇒ O(log effort) lifetime income) was built in T-0105 and unit-locked there in the abstract. This gate tests it IN CONTEXT: with real progression rates, how much of a season's income do achievements actually contribute early (hook), mid and far (endgame)?
- Expected shape (hypothesis to verify, not to force): early seasons have the highest achievement share (the faucet front-loads — by design, it is the new-player coin hook), decaying season over season as geometric thresholds outpace flat rewards. If measurement contradicts this shape, STOP and report — the catalog numbers need re-pinning, not the bands.

## Requirements
1. `test/balance/achievement_economy_test.dart` — seeded sweep over the real engine stack (reuse `EconomySimulator` and the T-0076 harness pattern; extend it to route achievement claims through T-0108's real service whenever a tier becomes eligible):
   - Band 1 — share ceiling: achievement coins per season ≤ 35% of that season's total earned (measured early-season peak; if the first season exceeds it because one-time milestones legitimately front-load, pin the first season at its measured value with tolerance and apply 35% to seasons 2+ — DOCUMENT whichever you lock).
   - Band 2 — decay property: achievement share is strictly non-increasing from season 2 onward across the sweep (the geometric ladder doing its job; tolerance for one noisy season).
   - Band 3 — lifetime ceiling: cumulative achievement coins over 6 seasons ≤ 20% of cumulative total earned.
   - Band 4 — catalog static ceiling: `AchievementEconomyConfig.totalCatalogCoinCeiling` from T-0105 ≤ 15% of the 6-season match-economy income measured by the T-0076 bands (faucet of faucets: even a completionist who claims everything stays a minority income stream).
2. Ledger attribution: the sweep reads achievement income from `coinTransactions` rows with the `achievement` reason (T-0108's convention) — real rows, not curve arithmetic. If the simulator's db-close-in-finally pattern blocks post-run queries (the T-0076 deviation note), either keep the db open in the new harness or accumulate per-season tallies during the run — do not silently switch to curve math.
3. Re-pin T-0105's placeholder coin values if any band fails: the catalog config is the tuning surface (GDD rule 14), NOT the bands. One re-pin round is in scope; a second failure means STOP, status blocked, evidence in Developer Notes.
4. Pin every measured number in the test as a doc-comment table (the T-0076 tradition) so reviewers see the measured reality behind each band.

## Out of Scope
- UI, profile, nav (T-0110+).
- Any match-economy change (rewards, pack prices) — the achievement config is the ONLY tuning surface here.
- T-0082's blocked chance-curve re-spec (independent; if it lands first and shifts match income, the bands re-measure in ITS task, not here).

## Acceptance Criteria
- [ ] Four bands locked with measured values + tolerance; the sweep runs the real claim service, real rewards, real ledger.
- [ ] Achievement income attributed from real ledger rows; the attribution path documented.
- [ ] `flutter analyze` zero warnings; full `flutter test` green including the pre-existing T-0076 economy gate (both gates co-exist without band fights).

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/balance/achievement_economy_test.dart
# Expected: green, bands locked

flutter test
# Expected: full suite green
```

---

<!-- Everything below this line is filled in by agents, never by the task author. -->

## Developer Notes
<!-- Developer agent fills this in before moving the file to 2-needs-review. -->

- **Summary of changes:**
- **Files changed:**
- **How I tested it:**
- **Concerns / assumptions:**


## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
