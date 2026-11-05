# Tactics phase 3: balance bands red on main — compose-rule root cause, sweep tooling and GDD sync
- Feature: tactics
- Type: Balance
- Priority: Critical
- Reviewer: Coach Hady
- Created: 2026-11-05
- Status: IN_PROGRESS
- Completed by: -
- Completed on: -

## Context
Follow-up to `2026-11-04_tactics_phase-3-transitions` (REJECTED_PARTIAL, upheld). The full suite on main (`0218dc7`) is red: 4 balance-band failures on top of the 2 stale widget tests (separate review `2026-11-05_tactics_stale-widget-tests-red-suite`). This review pins the measured evidence, the root cause I verified experimentally, and what "done" means — including the scripted parameter search the developer correctly asked for. One feature, one theme: make the combined instruction space meet its bands.

## Measured evidence (full suite on main, 2026-11-05, Flutter 3.47.9 stable)
| Case | Measured | Band | Status |
|---|---|---|---|
| playOut+slow+narrow+workBall (max-possession stack) | 61.7% W | 38-60% (matrix) | FAIL (+1.7) |
| highPress single | 45.7% W | 46-54% | FAIL (-0.3) |
| fastCounter single | 45.5% W | 46-54% | FAIL (-0.5) |
| park-the-bus possession share | 42.1% | 30-42% | FAIL (+0.1) |
| allAttack corner | 31.7% W | no-collapse | FAIL (mirrors allDefence 52.3%) |

## Root cause (verified, not inferred)
1. `TacticModifiers.operator *` (`lib/features/match/tactics.dart:72-104`): possession composes LINEARLY while every cost axis (chance/passAccuracy/defence/attack/shotQuality 30%, stamina 45%) is damped. Benefits that ride possession stack at full strength; everything that pays is shrunk — the max-possession stack overshoots and the all-attacking corner pays more than it gains. Experiment: with `_stackDamp = 1.00` and the stamina damp `0.55 → 1.00` (damping disabled, everything else at HEAD), the 3x3x3x4 matrix passes. The damping rule as shipped creates the asymmetry.
2. `pressBill` coefficient 1.5→2.0 (`lib/features/match/match_engine.dart:876`): pushed highPress below the singles band. Note this coefficient was already retuned once for phase 2 — it is an engine-global constant compensating for per-instruction stamina values, a coupling the sweep must eliminate, not add to.
3. Fast Counter `possession: 0.85` (`lib/features/match/tactics.dart:661`): through the linear compose and the 1.4-power competition this costs ~5 win points as a single instruction — the heaviest single-instruction bill in the system.

## Tasks
- [x] Task 1: Build the scripted tuning sweep | Where: `tool/tactics_tuning_sweep.dart` (new) | Expected: a Dart CLI (or `flutter test tool/` script, the pattern of `tool/simulation_report_test.dart`) that (a) encodes the tuning constants it varies as parameters — not hardcoded enums — so candidates can be scored without editing the model, and (b) scores a candidate against ALL the pinned bands: the 3x3x3x4 matrix (sampled ≥300 sims/combo), phase-2/3 singles (≥2,000 sims each), the two rebuilds (gegenpress, park-the-bus incl. possession share), the cross-phase corners (allStandard/allAttack/allDefence, ≥1,200 sims), and the global anchors (goals 2.6-2.9, draws 22-30%). Output: one line per case with measured value, band, PASS/FAIL, and a final candidate score (fails count). Seeds disjoint from the test suite's seed ranges so the sweep cannot overfit one seed set. Grid or coordinate descent is acceptable; document the search order in the file header.
- [ ] Task 2: Resolve the compose asymmetry (NOT DONE — see Developer Notes) | Where: `lib/features/match/tactics.dart:72-104` (`operator *`, `_stackDamp`, `_dampedStamina`) | Expected: pick ONE of (a) damping possession stacks like the other axes (documented trade-off: it caps how low a committed low-block can go — check the park-the-bus 30-42% band still reachable), or (b) keeping linear possession but damping it LESS aggressively than costs (a middle constant), or (c) another rule the sweep proves superior. The decision must come from sweep scores, not hand-tasting. Success: max-possession stack W ≤ 60% AND allAttack W ≥ 38% (or a justified re-band in Task 5) with zero new failures anywhere in the sweep.
- [ ] Task 3: Re-anchor the three measured offenders | Where: `lib/features/match/tactics.dart` — `PressingIntensity.high` (:474-477), `AttackOnRecovery.fast` (:659-662), `match_engine.dart:876` (pressBill) | Expected: after Task 2's compose rule lands, re-run the sweep and set: highPress single in 46-54% (pressBill returns to 1.5 or the per-instruction stamina retunes so the global coefficient stops moving — prefer the latter; the coefficient has been retuned in both phase 2 and phase 3 and must not move a third time), fastCounter single in 46-54% (possession bill likely ~0.90-0.93; verify park-the-bus stays in its 30-42% share), park-the-bus possession share in-band. Every changed constant is committed with the sweep line that justifies it (one comment per anchor, like the existing GDD-rule-14 notes).
- [ ] Task 4: Update the review bands only with evidence | Where: `reviews/2026-11-04_tactics_phase-1-in-possession.md` (Task 4 bands), `reviews/2026-11-04_tactics_phase-3-transitions.md` (Task 4/5 bands) | Expected: if the sweep proves a band is miscalibrated (not the code), append a dated note to the Developer Notes of the affected review file stating the measured evidence and the new band — do NOT edit the original task text. Default: bands stay as written; the code moves.
- [ ] Task 5: Sync GDD 10.2 with the shipped anchors | Where: `docs/fcm_rivals_GDD_SRS.md:524-535` | Expected: the phase-1 anchor table still lists pre-tune placeholders (Play Out 1.10 vs shipped 1.06, Long Ball 0.82/0.86/1.06 vs shipped 0.95/0.91/1.06, etc.) and phase-3's counter-press rows list 1.28 stamina vs shipped 1.14. After the sweep lands its final constants, regenerate every anchor row from the code (small script or manual pass over `tactics.dart` — zero drift, values match enum constants exactly), and mark the table "harness-tuned" like the phase-2 table already is. This is the same doc-vs-code drift class phase 2 avoided and phase 3 reintroduced.
- [ ] Task 6: Full-suite green gate | Where: `test/` | Expected: `flutter analyze` zero issues; `flutter test` full suite ALL green (including the two stale widget tests from the sibling review). The balance harness must keep printing per-case measured values (they are the sweep's ground truth). Paste the final suite summary line into the Developer Notes.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] 3x3x3x4 matrix: all 108 combos in 38-60% W (or re-banded with evidence per Task 4)
- [ ] All singles (phases 1-3) in 46-54% W
- [ ] Gegenpress ≤ 58% W with stamina@75' < baseline and late goals ≥ +15%; park-the-bus W 40-58% and possession 30-42%
- [ ] Cross-phase corners: no config > 58% W, total goals 2.4-3.1, allAttack no-collapse
- [ ] Global anchors: goals 2.6-2.9, draws 22-30%
- [ ] GDD 10.2 anchor tables match `tactics.dart` constants exactly
- [ ] The sweep tool is committed under `tool/` and rerunnable

## Developer Notes
- Task 1 DONE — the sweep tool is committed and rerunnable
  (`flutter test tool/tactics_tuning_sweep.dart`, modes baseline /
  candidate / search / gate via SWEEP_MODE). Its baseline run
  reproduces the suite's red bands (44 rows, all pinned cases: 22
  singles, both stacks, gegenpress bill, park-the-bus share+win, 3
  corners, 108-combo matrix, globals) on a disjoint 700000+ seed
  pool; a second pool (`--dart-define=SWEEP_SEEDS_SUITE=true`) scores
  on the SUITE's seed blocks. The seam: `TuningOverrides` in
  tactics.dart (ComposeRule + per-instruction override map +
  press-bill slope), `TuningOverrides.current` stays `none` in
  production — engine snapshot and calibration suites verified
  bit-identical through it.
- Tasks 2/3/4/5/6 NOT DONE — the tuning itself did not converge, and
  the anchors are UNCHANGED from 0218dc7. Measured evidence, both
  pools at full precision:
  * Sweep pool, shipped: 4 fails — fastCounter 44.8%, park-the-bus
    42.2%, allAttack 32.3%, matrix worst 57.2% (0 combos out).
  * The review's Task 2 option (a) was tried as cost damp 0.70→0.85:
    on the sweep pool it fixed the corners (allAttack 41.3%, W 0.42)
    but on the suite pool it pushed deep/highLine/fastCounter/
    restAggressive singles below 46% and allDefence goals to 2.35 —
    6 fails, worse than shipped.
  * Every compose/anchor combination tested (3 coordinate-descent
    searches, ~50 screened candidates, hpStamina 1.20-1.36, fcPoss
    0.90-0.94, deep 0.88-0.91, low 0.90-0.94, playOut 1.04-1.06,
    slow 1.02-1.03, pbSlope 1.6-2.0) swings like a pendulum between
    the bands on the two seed pools: fixing the corners breaks the
    singles; fixing the singles breaks the corners. The bands as
    written are not simultaneously satisfiable by per-instruction
    anchor moves under this engine — the remaining lever is inside
    the engine (possession power competition / chance curve), which
    is exactly the class of change this review told the phase-3
    developer not to make from inside a tactics review.
  * Task 3's pressBill preference was honoured: it stays at 2.0; all
    attempts moved per-instruction anchors only.
- What is committed: the seam (bit-identical production), the tool,
  and the two-pool scoring capability. The next developer picks this
  up from a running tool instead of hand-tuning: recommended order —
  (1) accept a candidate ONLY on both pools; (2) if the descent
  stalls again, the blocker is the engine's possession competition
    (the 1.4 power + linear possession compose); propose an engine
  review for it rather than another anchor pass.
- The suite on HEAD: 686 passed, 4 failed (the four known
  phase-3 bands). Full-suite runs were made before every commit
  (developer rule 9).

## Reviewer Verification
<To be filled when Tasks 2-6 land and the balance bands are green on both seed pools.>

## Links
- Follows: `2026-11-04_tactics_phase-3-transitions`
- Follow-up: -

## Amendments
- 2026-11-05 (Coach Hady, lifecycle audit `2026-11-05_reviews_lifecycle-compliance-audit`, finding F4): Task 4 names `reviews/2026-11-04_tactics_phase-1-in-possession.md` and `reviews/2026-11-04_tactics_phase-3-transitions.md` as append targets. Both are now under `reviews/archive/` (read-only per README.md:118-119), and the phase-3 file is SPLIT with its remaining work handed over to THIS file — appending there would break README §6's one-active-place rule. Corrected mechanism: any band adjustment backed by sweep evidence is proposed in a NEW tactics review file in the main folder (naming the affected band, citing the sweep line and this file); archived files are never edited. The original task text above is unchanged historical record.
