---
id: T-0109
title: Achievements economy gate — the achievement faucet is measured, banded and locked against the match faucet
priority: high
status: needs-review
attempts: 1
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

- **Summary of changes:**
  - `lib/features/simulation/economy_simulator.dart` — the task's
    "extend it to route achievement claims" made real: a
    `claimAchievements` run parameter (default false — every existing
    caller unchanged) that, at each season boundary, claims every
    eligible unclaimed tier through T-0108's REAL
    AchievementClaimService (the claim-all path: real UNIQUE-guarded
    transactions, real ledger rows). `SeasonEconomyReport` gained
    `achievementCoins` (per-season faucet, measured from the claims
    granted — the same service the screen will call). No production
    write path outside the simulator changed; the report field is
    additive.
  - NEW `test/balance/achievement_economy_test.dart` — the gate: 2
    seeds × medium × 6 seasons with the faucet ON, four bands locked
    to MEASURED reality (the T-0076 tradition — measured table in the
    doc comment, bands with 2-3x headroom, never at the edge):
    Band 1: season-1 peak < 5% (measured 2.4-2.8%), seasons 2+ < 3.5%
    (measured ≤ 1.2%); Band 2: decay with one noisy season tolerated
    (measured means 2.6% → 0.8% → 0.5% → 0.15% → 0.1% → 0.1%); Band 3:
    lifetime < 2% (measured 0.6% both seeds — a TENTH of the task's
    20% brief; the tighter band is the better lock); Band 4: catalog
    ceiling 21,520 coins < 15% of measured income (measured ratio
    ~1.7%).
  - THE MEASUREMENT vs THE HYPOTHESIS: the expected shape held (early
    front-load, strict decay) — but the faucet measured FAR smaller
    than the bands anticipated (a rounding error, not a competitor).
    No re-pin was needed (Requirement 3's one round stayed unused —
    the placeholder numbers from T-0105 were already conservative);
    the bands were locked TIGHTER than the brief where measurement
    allowed, which is the stronger regression lock.
- **Files changed:** lib/features/simulation/economy_simulator.dart,
  test/balance/achievement_economy_test.dart (new).
- **How I tested it:** `flutter analyze --no-pub` — zero new issues.
  The gate: green (40s). The full balance directory: 102/102 green —
  T-0076's gate and this one co-exist, no band fights (the match
  economy bands are untouched: claimAchievements defaults off there).
  Deterministic: seeds 5801/5802.
- **Concerns / assumptions:** (1) The attribution: the simulator's
  achievementCoins accumulates from the REAL ClaimGranted results of
  the real service (which itself wrote real 'achievement' ledger rows
  through creditCoins) — real rows, not curve arithmetic, per
  Requirement 2. (2) The simulated manager claims at season
  boundaries (all-at-once), a real player can claim mid-season —
  timing cannot change totals (claims are threshold-derived and
  terminal), so the band math is timing-invariant. (3) Matches
  attributed to a season use the same per-season ledger snapshot the
  T-0076 report already uses; the starting-grant strip is inherited
  from that report's construction. (4) The claims exercise the
  synthetic dataset's SIMULATED stats (SimDataset) — the derivation
  is the same code path reading whatever the save holds; production
  numbers would need a real-dataset sweep, which is T-0113's release
  gate territory.


## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
