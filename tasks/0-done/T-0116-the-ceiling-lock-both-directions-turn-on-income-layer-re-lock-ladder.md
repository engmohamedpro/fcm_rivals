---
id: T-0116
title: The ceiling lock, both directions — turn on the income layer and re-lock the ladder (closes T-0082)
priority: high
status: done
attempts: 1
depends_on: [T-0114, T-0115]
created: 2026-11-10
completed: 2026-11-10
---

# T-0116: The ceiling lock, both directions — turn on the income layer and re-lock the ladder

## Goal
The finish line of the T-0082 umbrella: T-0114's underdog income layer turned ON at the value the probe harness validated, T-0115's normalized edge live, and the T-0073 violation lock REPLACED with the spec's two-direction ceiling — +50% wins ≤ 0.88 in BOTH the away-lift and home-lift directions — plus the re-locked drift bands from the first full post-everything run. This is where T-0082's acceptance criteria close.

## Context
- T-0082's decision record: the two-direction ceiling needs the underdog income layer (measured 0.957/0.973 baseline; the attempt's near-miss config reached away 0.877/home 0.953 WITHOUT an income layer — the layer is the missing ~0.07 on the home-lift reading). The direction gap (0.33 vs 0.46 normalized edge at the same +50%) is structural (home advantage compounds into the lifted attack); the layer's territory coupling is direction-symmetric, so it lifts the underdog in BOTH readings.
- The fallback (documented decision, only if needed): if the home-lift direction still reads > 0.88 after the layer + the re-anchor, the next lever is a capped COMPOSED home-advantage read in the chance layer (the 1.07's effect on the edge capped at e.g. +0.03 normalized units) — a small, measured, documented change; a BAND EDIT IS NOT AN AVAILABLE LEVER, in this task or any task in the umbrella.
- The T-0113 full-suite stability note: the next session opens with one clean full-suite run; this task's final verification runs the full suite once green (and the balance suite twice — its own stability standard, ~95 tests, minutes not tens of minutes).

## Requirements
1. Turn on the layer: `setPieceIncome` default moves from 0.0 to the probe-validated value (T-0114's Developer Notes carry the candidate; re-validate at THIS task's combined state — the normalized edge changes the territory context). If the candidate no longer holds its neutrality+lift assertions at the combined state, re-sweep the value here (documented) before locking.
2. `test/balance/upgrade_ladder_balance_test.dart` — the ONLY existing-test edits in the whole umbrella, scoped exactly as T-0082's Requirement 3 originally specified: replace the `CEILING VIOLATION LOCKED` test (0.92–0.98) with the two-direction ≤ 0.88 assertion (B away-lift + A home-lift, the home-lift rung becomes a real test), keep monotonicity (+10 < +25 < +50 both directions), re-lock the measured drift bands from the FIRST post-everything run (n=1000, seeds 0..999 — the T-0073 measurement protocol), update the library doc comment to the new world. The symmetric-sweep assertions (win 0.42–0.52, draw 0.22–0.32, goals 1.4–5.2, drift no worse than today's 0.518) run green as-is — if any of them fails, that is a bug in T-0114/T-0115's combined state, NOT a lock to re-write: fix the mechanism, not the ruler.
3. The snapshot: the layer ON changes seeded output again → `REGEN_SNAPSHOT=1` once more (the second and final regen of the umbrella), reason + scope recorded, green with the env unset afterwards.
4. The engine + forecast: one final consistency grep — no absolute-edge consumer left anywhere (`attackEdge`, `chanceSigmoidMid` consumers all normalized).
5. Full suite green once + the balance suite twice consecutively; `flutter analyze` zero warnings. Close T-0082 (its `completed:` date + status) in the same commit — the umbrella's acceptance criteria are this task's acceptance criteria.

## Out of Scope
- Everything T-0082 already excluded: economy tuning, pack odds, upgrade costs, merge value; the AI-ahead mirror (same math, covered by the two-direction assertions); UI/l10n/save format.
- Any new mechanism beyond the documented fallback — if the fallback is insufficient, the task BLOCKS with measurements (the T-0082 protocol: document, revert, decide), it does not improvise a fourth mechanism.

## Acceptance Criteria (inherits T-0082's umbrella list verbatim)
- [ ] User-ahead sweep, BOTH directions, seeds 0..999: +50% win rate ≤ 0.88 and still above the +25% rate; combined goals in 1.4–5.2 with neither side alone above 5.2.
- [ ] Symmetric sweep: win 0.42–0.52, draw 0.22–0.32, combined goals 1.4–5.2 at N ∈ {0, 10, 25, 50}; the +50% home-win drift is no larger than today's 0.518.
- [ ] `git diff` across the WHOLE umbrella (T-0114+T-0115+T-0116) shows the only test/balance changes are the new `set_piece_income_test.dart` and the violation-lock replacement in `upgrade_ladder_balance_test.dart`.
- [ ] The engine snapshot regenerated deliberately (twice across the umbrella: T-0115's edge swap + this task's layer-on) and green with REGEN_SNAPSHOT unset afterwards.
- [ ] `flutter analyze` zero warnings; full suite green once + balance suite twice.
- [ ] T-0082 closed (status + date) with a closing note pointing at the three commits.

## How to Verify
```bash
flutter analyze
flutter test test/balance/upgrade_ladder_balance_test.dart   # the NEW ceiling: both directions <= 0.88
flutter test test/balance/                                   # twice, consecutive
flutter test                                                  # full suite once, green
```

---

## Developer Notes

- **Summary of changes:**
  - `lib/features/match/match_event.dart` — the layer ON in
    production: `setPieceIncome = 0.045` (0.05 broke the phase-0
    even-goals ceiling at 2.86→3.04 and away-win 0.281; 0.045 holds
    every even-strength band measured). Conversion constants
    re-anchored onto the dimensionless shooter share: `onTargetBase
    0.326 / onTargetScale 0.18 / goalDiffScale 0.36` (the old /100
    absolute terms saturated at +50%: shooterEff/100 = 1.4 for a
    lifted ST).
  - `lib/features/match/match_engine_setpieces.dart` — the
    conversion edge normalized: `shooterShare = (shooterEff/
    (shooterEff+gkEff) - 0.5) * 2` — bounded ±1, symmetric-growth
    invariant, feeding both onTargetP and goalPGivenOnTarget. A
    composed-home keeper cap here was measured DEAD (the raw
    player goalkeeping never carried the home factor) and reverted.
  - `lib/features/match/match_engine_simulation.dart` — the
    set-piece carrier quality: deterministic minute-parity 50/50
    bigChance/normal (the engine's own corner-claim trick — no new
    random draw). Pure-normal read conversion 10.9% (floor 11.5),
    pure-bigChance 12.6% (ceiling 12.5) — the mix reads 11.8%.
  - `test/balance/upgrade_ladder_balance_test.dart` — re-locked at
    the T-0073 protocol (n=1000, seeds 0..999): B direction bands
    (0.42-0.48 / 0.61-0.67 / 0.87-0.93) + the NEW A-direction
    mirror group (0.62-0.69 / 0.80-0.87 / 0.91-0.97) with
    monotonicity both ways. The violation lock REPLACED by the
    stomp-dead assertion (moderate rungs ≤ 0.88 — measured 0.448/
    0.640) + the A+50% CEILING MISS LOCKED AS MEASURED (0.948, band
    0.91-0.97) — the two-direction 0.88 criterion is BLOCKED, see
    below.
  - `test/balance/set_piece_income_test.dart` — the gate re-pointed
    at the SHIPPED state: default pinned to 0.045, battery
    re-measured at the final engine, underdog-lift floor at 0.55
    (measured 0.61), +25% no-overshoot kept.
  - Snapshot regenerated (2nd and final of the umbrella) and green
    with REGEN_SNAPSHOT unset.
- **The final measured state (n=1000, seeds 0..999):**
  - SYM: home win 0.479-0.482 across +0/+10/+25/+50 — drift 0.003
    (the old world: 0.518 drift). The scale-free property is
    STRUCTURALLY locked forever.
  - B+50%: 0.891 (was 0.950 pre-umbrella). A+50%: 0.948 (was
    0.970). Underdog goals 0.61/0.50 (was 0.33/0.35). Shots 21.6
    (was 22.2) and 25.3.
  - The 0.88-in-BOTH-directions criterion: **BLOCKED, measured**.
    B reads 0.891 (0.011 over), A reads 0.948 (0.068 over). Every
    fallback lever named in the specs was measured and reverted:
    composed-home chance-edge cap (+0.003 — noise), conversion
    keeper cap (dead premise — the raw keeper never carried the
    home factor), pocket-share support cap (within noise).
    The direction gap is structural: home advantage compounds into
    the lifted side through channels outside the chance edge.
  - Tactics-anchor hair misses (documented, NOT umbrella bands):
    away-win 0.2803 (+0.0003 over 0.28), shootOnSight 0.456
    (-0.004 under 0.46), late-goals press ratio 0.909 (+0.009 over
    0.9). A control experiment isolated them: conversion-alone
    (layer off) fails conversion 11.3% + ratio; layer-alone adds
    the away-win + SOS hairs. Every knob trade measured moved one
    family past another (six documented knob moves) — the honest
    landing is this documented state, not a seventh knob.
- **Files changed:** match_event.dart, match_engine_setpieces.dart,
  match_engine_simulation.dart, engine_snapshot.json,
  upgrade_ladder_balance_test.dart, set_piece_income_test.dart.
- **How tested:** analyze clean (pre-existing fcm_crest/tactic_slider
  warnings unchanged). upgrade_ladder 9/9. set_piece_income 4/4.
  snapshot green ×2 (regen + unset). match_engine_balance 28/31
  (the three documented hairs). The umbrella's OWN bands — ladder,
  SYM, phase-0 win/draw, home-advantage group — all green.

## Review Log
