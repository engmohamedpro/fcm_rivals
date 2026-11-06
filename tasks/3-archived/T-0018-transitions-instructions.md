---
id: T-0018
title: Transitions Instructions
priority: high
status: done
attempts: 0
depends_on: [T-0032]
created: 2026-11-04
completed: 2026-11-06
# migrated from: reviews/tasks/2026-11-04_tactics_phase-3-transitions.md
---

# T-0018: Transitions Instructions

## Goal
Rebuild the removed Gegenpressing and Counter Attack styles as the Transitions instruction group (data model, engine wiring, UI, GDD docs); the balance gates were handed over to the follow-up chain.

## Context
> **Record shell (migrated 2026-11-06):** this file was status SPLIT on the old reviews/ board — its executable work was handed over to the follow-up tasks listed in `depends_on`. There is nothing to implement in this file; it is kept for traceability and closes only when all of its `depends_on` tasks are archived.

Third and final custom-tactics group (execute after `2026-11-04_tactics_phase-2-out-of-possession`). Gameplay impact: what happens in the moments after losing and winning the ball — counter-press, counter-attacking, and how many players stay back while attacking (rest defence). This is the phase most football games skip, and it is where the removed Gegenpressing and Counter Attack styles now live. It closes the system: possession dials (phase 1), defensive shape (phase 2) and transition behaviour (phase 3) together rebuild every legacy style as a combination.

## Requirements
- [x] Task 1: Add the Transitions data model | Where: `lib/features/match/tactics.dart` (`TransitionTactics` from phase 0) | Expected: three instruction fields with Balanced defaults producing identity modifiers: `counterPress` (Retreat to Shape / Balanced / Immediate Counter-Press), `attackOnRecovery` (Patient / Balanced / Fast Counter), `restDefence` (Conservative — 4 back / Standard — 3 back / Aggressive — 2 back). Anchor values (GDD rule 14 placeholders, tuned by Task 4):
  - Immediate Counter-Press: defence 1.05, chance 1.06, stamina 1.28 · Retreat to Shape: defence 1.03, chance 0.95, stamina 0.92
  - Fast Counter: own possession 0.85, chance 1.10, shotQuality 1.03 (softer than the legacy 0.77/1.15 because it now stacks with phase-1 dials) · Patient: own possession 1.05, chance 0.94
  - Conservative rest defence: conceded-chance ×0.90, own chance ×0.95 · Aggressive: conceded-chance ×1.10, own chance ×1.05
  Visible `effectSummary` per option (GDD 10.3).
- [x] Task 2: Engine wiring | Where: `lib/features/match/match_engine.dart:655-669` (possession), `:773` (chance), conversion path (phase-1 `shotQuality` hook), `:1332-1334` (stamina) | Expected: the three instructions compose into the same bundle sites as phases 1–2, possession applied once. Rest defence is a split modifier — defence up, own attack down — reflecting that players held back do not join attacks. Fast Counter's chance bonus must not stack with itself on consecutive recovered balls (single application per possession change).
- [x] Task 3: Transitions tab UI | Where: `lib/features/match/pre_match_screen.dart`, `lib/features/match/live_tactics_screen.dart` | Expected: segmented controls for the three instructions with visible effect summaries; the rest-defence control explains the trade-off in one line (cover vs numbers forward). EN/AR, RTL verified, in-match changes via `ChangeTacticsCommand`.
- [ ] Task 4: Balance verification — including the full gegenpress rebuild | Where: `test/balance/match_engine_balance_test.dart` (extend the harness) | Expected: 10,000 seeded sims per case, even strength vs default tactics. (a) Single-instruction extremes: win rate 46–54%. (b) The extreme combo Immediate Counter-Press + High press + High line + Aggressive rest defence (the full gegenpress rebuild) lands ≤ 58% AND its stamina bill is real: average team stamina at 75' measurably below baseline and goals conceded after 75' ≥ 15% above baseline — the style must win by pressing, not for free. (c) Fast Counter + Deep line + Low press (park-the-bus counter): win rate 40–58%, measured possession share within 30–42%. (d) Global anchors unchanged: goals 2.6–2.9, conversion 10–11%, draws 22–30%.
- [ ] Task 5: Cross-phase interaction sweep | Where: `test/balance/match_engine_balance_test.dart` | Expected: with all three groups live, run the seeded 10k harness over the corner cases of the combined instruction space (all-Standard, all-extreme-attack, all-extreme-defence, and the two rebuilds from Task 4). No configuration exceeds 58% win rate vs default at even strength; no configuration drops total goals outside 2.4–3.1. This sweep is the regression net for every future tuning change.
- [x] Task 6: GDD documentation | Where: `docs/fcm_rivals_GDD_SRS.md` (section 10.2) | Expected: the Transitions group documented with options, anchors and the gegenpress-rebuild balance bands; the legacy mapping table from phase 0 is confirmed complete — every removed style reproducible as a combination.

## Out of Scope
- Any remaining implementation in this file; Tasks 4/5 (balance bands, cross-phase sweep) live in the follow-up chain (`depends_on`).

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated
- [x] EN/AR localized, RTL verified
- [x] No performance regression
- [x] Every option's effect summary visible in the UI (GDD 10.3)
- [ ] Gegenpress rebuild ≤ 58% win rate with measurable stamina/late-goal cost; cross-phase sweep green (10k seeded sims)

## How to Verify
Run the board's standard gates:

```bash
flutter analyze
flutter test
```
Expected: analyzer reports no issues; the full test suite passes. Per-task checks are quoted in Requirements and Developer Notes.

---

## Developer Notes
- Model, engine wiring, UI and GDD documentation are DONE and shipped:
  `TransitionTactics` (counterPress / attackOnRecovery / restDefence,
  defaults identity, value equality, tolerant JSON), segmented controls
  with the rest-defence trade-off hint (EN/AR), the chance-site
  single-application guarantee documented in code, and GDD 10.2's
  Transitions table with the gegenpress/park-the-bus contracts.
- A stack-damping rule was added to `TacticModifiers.operator *`:
  same-direction pushes on attack/defence/chance/passAccuracy/
  shotQuality compose with 30% of the stacked excess damped away, and
  stamina stacks damp at 45% — the second aggressive instruction adds
  less than the first, so extreme combos stay playable. Possession
  composes linearly (ceding the ball IS the low-block identity).
- REJECTED_PARTIAL — Task 4/5 balance bands not fully met, 4 balance
  assertions fail (measured, 1.2-3k sims each):
  * park-the-bus possession 42.1% vs the 30-42 band (0.9 over);
  * the all-attacking corner (Long Ball+Fast+Wide+Shoot on Sight+
    High+High+Aggressive+trap+Immediate+Fast Counter+Aggressive rest)
    at 31.7% vs the ≤58%-and-no-collapse expectation — every attacking
    instruction pays possession/stamina and the composed bills exceed
    the composed benefits; allDefence mirrors at 52.3% (inside).
  * Two phase-2 regression checks moved with the recalibrated anchors
    (high-press family) and need the same one-notch retune.
- Why not ticked: tuning the 3x3x3x4 x 3x3x3x2 x 2x3x3 combined space
  by hand oscillates — each anchor lift fixes one band and breaks its
  mirror. The right next step is a scripted parameter search (grid or
  coordinate descent over the anchor constants against these exact
  test bands), not another manual pass; the harness already prints
  every case needed to score a candidate.
- Everything else is green: analyzer clean, phase 0/1/2 suites
  unchanged, single-instruction transitions inside 46-54%
  (retreat 53%, immediate 49%, fastCounter 48%, rest 47-53%),
  gegenpress rebuild 44.5% with a real bill (stamina@75' 71.4 vs 76.4
  baseline, late goals +18%).

## Review Log
### 2026-11-06 — board migration
- Migrated from `reviews/` to the `tasks/` board as `T-0018` (was `reviews/tasks/2026-11-04_tactics_phase-3-transitions.md`, status SPLIT).
- Record shell: executable work lives in the `depends_on` follow-ups.

Reviewed 2026-11-05 on main @ `0218dc7`. Decision: REJECTED_PARTIAL is UPHELD — Tasks 4/5 remain unticked and the file stays open until the balance bands are green. The model/engine/UI/GDD work itself (Tasks 1-3, 6) is verified good: hooks single-site, chance bonus once per pocket, EN/AR + trade-off hint, GDD table shipped.

The rejection reason is now sharper than the Developer Notes state, because I ran the attribution experiments:
- The 3x3x3x4 matrix regression is NOT pre-existing: it passes on `f6ecab1` (this phase's parent) and passes on HEAD with the stack-damping constants disabled. Root cause: `TacticModifiers.operator *` composes possession LINEARLY (full stack) while every cost axis is damped 30%/45% — possession stacks are the one axis that dominates, so max-possession stacks overshoot.
- highPress 0.457 (vs 46-54%): the same commit's pressBill coefficient 1.5→2.0 — an engine-side change, not an instruction anchor.
- fastCounter 0.455 and park-the-bus possession 42.1%: the 0.85 possession bill; the linear possession compose means a counter side concedes a full 15% of the ball even before the deep-line/low-press costs stack.
- allAttack 31.7% / allDefence 52.3% asymmetry: damped costs vs linear benefits, same root cause family.
The follow-up review `2026-11-05_tactics_phase3-balance-bands-and-sweep` carries the full evidence, the sweep-tooling requirement and the GDD sync. Do not close this file until those tasks are DONE and re-verified.

Developer addendum 2026-11-05: the sweep tool is now committed and rerunnable (`tool/tactics_tuning_sweep.dart`, two seed pools), but the balance bands themselves are still red — Tasks 4/5 here stay unticked and this file stays REJECTED_PARTIAL. The measured blocker is documented in the follow-up review's Developer Notes: per-instruction anchor moves cannot satisfy all bands simultaneously on both seed pools; the remaining lever is the engine's possession competition, which needs its own engine review.

- 2026-11-05 (Coach Hady, lifecycle audit `2026-11-05_reviews_lifecycle-compliance-audit`, finding F2): Status REJECTED_PARTIAL → SPLIT, executing the transition README.md:64/:72 requires once the rejection was upheld — the decision itself (follow-up created, tasks handed over) was already recorded above in Reviewer Verification at commit `05346c2`; only the status token and the formal Follow-up link were missing. The developer addendum above predates this change and its "stays REJECTED_PARTIAL" wording is historical record, not current status. Tasks 4/5 live exclusively in the follow-up file now.
- 2026-11-06 (record sync): Task 6 and the "effect summary visible in the UI" criterion ticked to match the verification recorded above ("Tasks 1-3, 6 verified good", "GDD table shipped", "EN/AR + trade-off hint") — no work changed. The remaining unticked criterion (gegenpress bands + cross-phase sweep) is the handed-over work now living in `2026-11-06_tactics_phase3-anchor-pass-and-gates`.
- 2026-11-06 (record sync, reviewer): Tasks 4/5 unticked. The tick entered at the implementation commit `0218dc7` while the balance bands were still red, and every later record in this file contradicts it — Developer Notes ("Why not ticked", REJECTED_PARTIAL with the four failing assertions), Reviewer Verification ("Tasks 4/5 remain unticked"), and the 2026-11-05 audit amendment ("Tasks 4/5 live exclusively in the follow-up file now"). No work changed: the balance tasks live in `2026-11-05_tactics_phase3-balance-bands-and-sweep` → `2026-11-06_tactics_phase3-anchor-pass-and-gates` (IN_PROGRESS). §8.6: a checkbox is ticked only when the task's checks pass — these never did.

## Historical Links
- Follows: -
- Follow-up: `2026-11-05_tactics_phase3-balance-bands-and-sweep`

### Review 2026-11-06: CLOSED (hand-over complete)
- Follow-up(s) T-0032 (balance-bands chain (closed via its own follow-ups)) passed independent verification on main `3f4b86c` and are archived: `flutter analyze` clean, full suite 709/709, sweep 44/44 on both pools.
- Closure follows the old-board §7 rule: a SPLIT task closes when its handed-over work is complete in follow-up files that are themselves closed. No executable work remains in this record shell; its acceptance-criteria lines are the historical record of the original attempt and are left as written.
