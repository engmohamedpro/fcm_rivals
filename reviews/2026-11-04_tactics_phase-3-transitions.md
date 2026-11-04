# Tactics Phase 3 — Transitions Instructions
- Feature: tactics
- Type: Design
- Priority: Major
- Reviewer: Coach Hady
- Created: 2026-11-04
- Status: OPEN
- Completed by: -
- Completed on: -

## Context
Third and final custom-tactics group (execute after `2026-11-04_tactics_phase-2-out-of-possession`). Gameplay impact: what happens in the moments after losing and winning the ball — counter-press, counter-attacking, and how many players stay back while attacking (rest defence). This is the phase most football games skip, and it is where the removed Gegenpressing and Counter Attack styles now live. It closes the system: possession dials (phase 1), defensive shape (phase 2) and transition behaviour (phase 3) together rebuild every legacy style as a combination.

## Tasks
- [ ] Task 1: Add the Transitions data model | Where: `lib/features/match/tactics.dart` (`TransitionTactics` from phase 0) | Expected: three instruction fields with Balanced defaults producing identity modifiers: `counterPress` (Retreat to Shape / Balanced / Immediate Counter-Press), `attackOnRecovery` (Patient / Balanced / Fast Counter), `restDefence` (Conservative — 4 back / Standard — 3 back / Aggressive — 2 back). Anchor values (GDD rule 14 placeholders, tuned by Task 4):
  - Immediate Counter-Press: defence 1.05, chance 1.06, stamina 1.28 · Retreat to Shape: defence 1.03, chance 0.95, stamina 0.92
  - Fast Counter: own possession 0.85, chance 1.10, shotQuality 1.03 (softer than the legacy 0.77/1.15 because it now stacks with phase-1 dials) · Patient: own possession 1.05, chance 0.94
  - Conservative rest defence: conceded-chance ×0.90, own chance ×0.95 · Aggressive: conceded-chance ×1.10, own chance ×1.05
  Visible `effectSummary` per option (GDD 10.3).
- [ ] Task 2: Engine wiring | Where: `lib/features/match/match_engine.dart:655-669` (possession), `:773` (chance), conversion path (phase-1 `shotQuality` hook), `:1332-1334` (stamina) | Expected: the three instructions compose into the same bundle sites as phases 1–2, possession applied once. Rest defence is a split modifier — defence up, own attack down — reflecting that players held back do not join attacks. Fast Counter's chance bonus must not stack with itself on consecutive recovered balls (single application per possession change).
- [ ] Task 3: Transitions tab UI | Where: `lib/features/match/pre_match_screen.dart`, `lib/features/match/live_tactics_screen.dart` | Expected: segmented controls for the three instructions with visible effect summaries; the rest-defence control explains the trade-off in one line (cover vs numbers forward). EN/AR, RTL verified, in-match changes via `ChangeTacticsCommand`.
- [ ] Task 4: Balance verification — including the full gegenpress rebuild | Where: `test/balance/match_engine_balance_test.dart` (extend the harness) | Expected: 10,000 seeded sims per case, even strength vs default tactics. (a) Single-instruction extremes: win rate 46–54%. (b) The extreme combo Immediate Counter-Press + High press + High line + Aggressive rest defence (the full gegenpress rebuild) lands ≤ 58% AND its stamina bill is real: average team stamina at 75' measurably below baseline and goals conceded after 75' ≥ 15% above baseline — the style must win by pressing, not for free. (c) Fast Counter + Deep line + Low press (park-the-bus counter): win rate 40–58%, measured possession share within 30–42%. (d) Global anchors unchanged: goals 2.6–2.9, conversion 10–11%, draws 22–30%.
- [ ] Task 5: Cross-phase interaction sweep | Where: `test/balance/match_engine_balance_test.dart` | Expected: with all three groups live, run the seeded 10k harness over the corner cases of the combined instruction space (all-Standard, all-extreme-attack, all-extreme-defence, and the two rebuilds from Task 4). No configuration exceeds 58% win rate vs default at even strength; no configuration drops total goals outside 2.4–3.1. This sweep is the regression net for every future tuning change.
- [ ] Task 6: GDD documentation | Where: `docs/fcm_rivals_GDD_SRS.md` (section 10.2) | Expected: the Transitions group documented with options, anchors and the gegenpress-rebuild balance bands; the legacy mapping table from phase 0 is confirmed complete — every removed style reproducible as a combination.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] Every option's effect summary visible in the UI (GDD 10.3)
- [ ] Gegenpress rebuild ≤ 58% win rate with measurable stamina/late-goal cost; cross-phase sweep green (10k seeded sims)

## Developer Notes
<Implementation notes, rejected points with reason.>

## Reviewer Verification
<Filled by reviewer before setting CLOSED.>
