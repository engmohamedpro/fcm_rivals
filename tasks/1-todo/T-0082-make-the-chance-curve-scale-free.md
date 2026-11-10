---
id: T-0082
title: Make the chance-creation curve scale-free so big upgrade edges stop producing stomps
priority: high
status: blocked
attempts: 1
depends_on: [T-0073]
created: 2026-11-09
completed:
---

# T-0082: Make the chance-creation curve scale-free so big upgrade edges stop producing stomps

## Goal
A +50% upgrade edge wins at most 0.88 of matches in BOTH directions (no more 0.950/0.970 stomps at 22 shots), while every existing balance band and the strength-gap ladder stay intact — the engine's strength response becomes dimensionless so the infinite upgrade ladder (T-0070) can grow forever without distorting match outcomes.

## Context
- T-0073's gate measured and locked the violation (seeds 0..999): a +50% lifted side wins 0.950 (away-lift) / 0.970 (home-lift) with 4.09 goals and 22.2 shots a match. The lock lives in `test/balance/upgrade_ladder_balance_test.dart` (`CEILING VIOLATION LOCKED` test, asserted 0.92–0.98) and the raw tables are in T-0073's Developer Notes.
- Root cause: the chance-creation logistic consumes the ABSOLUTE attack-minus-defence edge — `attackEdge = attTotals.attack - defTotals.defence` (`lib/features/match/match_engine_simulation.dart:132`) fed to `edgeFactor = 1/(1+exp(-steepness*(edge-mid)))` with `chanceSigmoidMid = 4.76`, `chanceSigmoidSteepness = 0.0714` (`lib/features/match/match_event.dart:208-209`). The pair was calibrated on the 0–99 attribute domain where a +20 edge is near-saturation; a +50% lift grows the edge to ~36 points (~2.6× the calibration ceiling), so the logistic saturates at ~0.90 and chance creation approaches its cap.
- Because `upgradedValue` grows linearly forever (T-0070), ANY absolute-edge calibration re-breaks as the ladder climbs (+75%, +100%…). The fix must be scale-free.
- Design decision (dated 2026-11-09, planner — follow T-0072's review protocol of documenting deviations): NORMALIZE the edge before the logistic — edge as a fraction of the sides' average strength, dimensionless by construction. Equal percentage growth then cancels exactly: the symmetric bands become structurally neutral instead of drift-dependent (today symmetric +50% sits at home win 0.518, only 0.002 under the 0.52 ceiling), and a +50% favourite over a fixed-base underdog sees a bounded response.
- Rejected alternatives (do NOT implement): (a) rescaling only mid/steepness to push saturation past +50% — moves every strength-gap rung and re-breaks at +75%; (b) capping the effective edge at ~20 points — a clamp that breaks monotonicity between +40% and +50% and hides the growth instead of measuring it.
- T-0052 precedent (fatigue decoupling re-anchor, 2026-11-07) shows the pattern: change the edge semantics, re-anchor the constants so base-strength behaviour is preserved, regenerate the engine snapshot deliberately with the reason recorded.

## Requirements
1. `lib/features/match/match_engine_simulation.dart` — chance creation: feed the logistic a dimensionless edge: `attackEdge / ((attTotals.attack + defTotals.defence) / 2)` (edge as a share of the sides' average strength). Expected: symmetric growth (both sides +N%) leaves the normalized edge unchanged; a one-sided lift produces a bounded, monotonic response.
2. `lib/features/match/match_event.dart` — re-anchor `chanceSigmoidMid` and `chanceSigmoidSteepness` to the new dimensionless domain so base-strength behaviour is preserved: the strength-gap ladder's calibrated rungs (gaps 4/8/12/16/20 in `test/balance/match_engine_balance_test.dart:201-238`) must stay inside their existing bands with NO band edit.
3. `test/balance/upgrade_ladder_balance_test.dart` — replace the `CEILING VIOLATION LOCKED` test (0.92–0.98) with the spec assertion: +50% win rate ≤ 0.88 for BOTH directions — B = away lifted (measured 0.950 pre-fix) AND A = home lifted (measured 0.970 pre-fix; add the home-lift rung, it exists today only as a doc-comment cross-check). Keep monotonicity (+10 < +25 < +50), keep the moderate-rung ≤ 0.88 assertions, re-lock the measured drift bands from the first post-fix run, and update the library doc comment.
4. If, after the chance layer is normalized, the +50% combined goals still leave the 1.4–5.2 band or either side alone exceeds 5.2, apply the same normalization to the goal-rate layer's shooter-minus-keeper edge (`goalBase`/`goalScale`, `lib/features/match/match_event.dart`) in this task — same mechanism, one outcome.
5. Regenerate `test/features/match/engine_snapshot.json` deliberately (`REGEN_SNAPSHOT=1 flutter test test/features/match/engine_snapshot_test.dart`) and record in Developer Notes why the snapshot change is expected (constant re-anchor changes seeded match output).

## Out of Scope
- Editing any existing band in `test/balance/` other than the T-0073 violation-lock replacement in Requirement 3 — the ladder, even-strength, chemistry and economy bands are the contract.
- Economy tuning, pack odds, upgrade costs or merge value (T-0071/T-0075/T-0076 territory).
- The AI-ahead mirror (a division-target-lifted AI club vs a base user squad) — same math as the user-ahead direction, covered by the two-direction assertions in Requirement 3; no separate mechanism.
- Any UI, l10n or save-format change.

## Acceptance Criteria
- [ ] User-ahead sweep, BOTH directions, seeds 0..999: +50% win rate ≤ 0.88 and still above the +25% rate; combined goals in 1.4–5.2 with neither side alone above 5.2.
- [ ] Symmetric sweep: win 0.42–0.52, draw 0.22–0.32, combined goals 1.4–5.2 at N ∈ {0, 10, 25, 50}; the +50% home-win drift is no larger than today's 0.518.
- [ ] The full existing balance suite passes with zero band edits — `git diff` shows the only test/balance change is the violation-lock replacement in `upgrade_ladder_balance_test.dart`.
- [ ] The engine snapshot is regenerated deliberately and the snapshot test passes with `REGEN_SNAPSHOT` unset afterwards.
- [ ] `flutter analyze` zero warnings; `flutter test` full suite green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/balance/upgrade_ladder_balance_test.dart
# Expected: all green; printed tables show +50% win rate <= 0.88 in BOTH
# the away-lift and home-lift rows, monotonic across +10/+25/+50

flutter test test/balance/
# Expected: all green, existing bands untouched

flutter test
# Expected: full suite green with REGEN_SNAPSHOT unset
```

---

## Developer Notes

## Review Log

## Developer Notes

### Attempt 1 — BLOCKED: the two-direction 0.88 spec is over-constrained against the existing ladder bands; what I measured and what is needed

**Status: BLOCKED. No production code shipped — every experiment was reverted (`git checkout` on the five touched files; analyze 0, test/balance/ 95/95 green on the reverted tree). The T-0073 violation lock and all bands are untouched.**

**What I implemented and measured (all reverted):** the full scale-free design from the Requirements — normalized chance edge (edge / average of the two totals), re-anchored sigmoid constants, knee-curve soft saturation, normalized goal-rate shooter-vs-keeper edge (engine + forecast mirror), normalized on-target edge, home-advantage de-compounding (goalkeeping factor removal, pocket-share squad-basing + flat home bonus), underdog chance floor. Measured with a 300-800 match probe harness per configuration (the real MatchEngine, seeded, mirroring both balance suites' generators), ~15 configurations in total.

**Evidence table (best configurations, seeds deterministic, n=300, CI ±2.8%):**
- Baseline (T-0073 lock): +50% away-lift 0.950 / home-lift 0.977.
- Full normalization, sigmoid m=0.16 s=4.0 + goal/on-target normalized + gk home-factor removed + pocket de-compounded: **away-lift 0.877 (spec MET) / home-lift 0.953 (spec MISSED)**.
- + underdog clamp floor 0.11 (replacing 0.05): away 0.887 / home 0.940.
- + edge defactor (home advantage divided out of the edge): away 0.890 / home 0.940 — but gap-0 falls to 0.373 (band 0.42–0.52 broken).
- Knee-curve (steep below 0.20 edge, gentle cruise above): away 0.910 / home 0.963 — top compression does not move win rates because the favourite's chanceP is already under the cap; the match is decided by the underdog's collapse, not the favourite's ceiling.

**Why it is blocked (the exact over-constraint, measured from both sides):**
1. TOP: the normalized axis puts +50% (0.46) only 0.18 above the gap-20 rung (0.28). One response curve must read ~0.5 at even strength (0.06), keep gap-20's win ≥ 0.72 AND cap +50% at 0.88 — the gap-20 band floor and the +50% ceiling demand a win rate that is nearly FLAT across 0.28→0.46 while STEEP across 0.06→0.28. A knee curve does exactly this and still lands home-lift at 0.94, because of (2).
2. BOTTOM: the underdog at +50% reads an edge of −0.47 → chance factor 0.04–0.08 → chanceP pinned at the 0.05–0.11 clamp floor on ~30% of pockets. Its 0.33 goals/match cannot reach the ~0.8 needed for the favourite to lose 12% of matches without raising the floor so far that even-strength draw/goal bands break (measured: chanceBase 0.03 → away WORSE at 0.893 because the favourite gains the same floor; speculativeShotChance 0.45 → goal explosion 5.1 per side at +50%, 3.9 combined at even strength, band ceiling broken).
3. DIRECTION: home advantage (1.07) compounds asymmetrically — the lifted HOME side reads edge 0.46 vs the lifted AWAY side's 0.33 (1.07 × 1.5 into the attack), plus 1.07 sits in the turnover supportRatio for the home side. Dividing it out of the edge fixes symmetry but removes even-strength home advantage from the chance layer → gap-0 0.373, band broken (measured twice, with different accompanying changes).

**What is needed to unblock (a design decision, not a constant):** an underdog income layer DECOUPLED from the attack-minus-defence edge — e.g. edge-independent set-piece income (corners/penalties scale with territory, not strength) or a pocket-count floor for the defending side — plus a decision on where home advantage should live (pocket share vs totals vs a flat win-probability nudge). Any of these reshapes bands the task forbids me from editing, so the owner/planner must re-spec with new bands. The near-miss configuration (away 0.877/home 0.953) is fully documented above and reproducible for that re-spec: sigmoid m=0.16 s=4.0 over the normalized edge, goalDiffScale 0.20/normalized-unit, onTargetBase 0.326 + onTargetScale 0.18/normalized-edge, goalkeeping without homeFactor, pocket share from squad support × flat 1.07.

**Files changed (final state): NONE in lib/ or test/ — all experiments reverted and verified (analyze 0, test/balance/ 95/95). Only this task file changed.**
