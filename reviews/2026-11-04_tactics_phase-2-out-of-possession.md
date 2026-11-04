# Tactics Phase 2 — Out of Possession Instructions
- Feature: tactics
- Type: Design
- Priority: Major
- Reviewer: Coach Hady
- Created: 2026-11-04
- Status: OPEN
- Completed by: -
- Completed on: -

## Context
Second custom-tactics group (execute after `2026-11-04_tactics_phase-1-in-possession`). Gameplay impact: the player shapes his team's defensive behaviour — line height, pressing intensity, tackling aggression and the offside trap — and, crucially, the engine now reads BOTH teams' instructions: a high line gets punished by the opponent's long balls, a deep block concedes territory to patient build-up. That interaction is what makes tactics feel smart rather than stacked multipliers. Absorbs the removed High Press, Gegenpressing and Low Block styles.

## Tasks
- [ ] Task 1: Add the Out of Possession data model | Where: `lib/features/match/tactics.dart` (`OutOfPossessionTactics` from phase 0) | Expected: four instruction fields with Standard defaults producing identity modifiers: `defensiveLine` (Deep / Standard / High), `pressingIntensity` (Low / Mid / High), `tacklingAggression` (Clean / Balanced / Aggressive), `offsideTrap` (Off / On). Anchor values (GDD rule 14 placeholders, tuned by Task 5):
  - Deep: defence 1.08, own possession 0.95 · High: defence 0.94, own possession 1.04
  - Low press: defence 1.02, stamina 0.88, own possession 0.94 · High press: defence 1.06, chance 1.04, stamina 1.28 (anchored to the §34 gegenpress cost of 1.30)
  - Aggressive: defence 1.04, foul rate ×1.30, yellow-card rate ×1.35 · Clean: defence 0.98, foul rate ×0.75, yellow-card rate ×0.70
  - Offside trap On: conceded-chance quality ×0.94, but each beaten trap amplifies that chance's quality ×1.15 (see Task 3)
  Visible `effectSummary` per option (GDD 10.3).
- [ ] Task 2: Per-side foul and card scaling | Where: `lib/features/match/match_engine.dart:875-905` (foul emission with `config.foulOnTurnover`, `config.inBoxFoulChance`, `yellowCardChance`) | Expected: these config chances are currently engine-global; make the foul and yellow probabilities per-side, scaled by each team's `tacklingAggression`. `inBoxFoulChance` scales identically (aggressive defending concedes more penalties — this is the real cost of the option). Penalty award rate at Balanced must stay at the calibrated 0.25–0.30/match.
- [ ] Task 3: Offside trap hook and line-height interactions | Where: `lib/features/match/match_engine.dart:773` area (chance creation/conversion), phase-1 `shotQuality` hook | Expected: offside trap is a stochastic hook on conceded chances: while On, 6% of conceded chances are "beaten trap" events with quality ×1.15, the rest ×0.94 — net effect negative for the defending team's opponent but with tail risk. Line-height interaction matrix, evaluated with both teams' instructions available (the runtimes already hold both): High line vs opponent Long Ball/Fast tempo → additional defence −0.06 (balls in behind); Deep line vs opponent Play Out/Slow → opponent possession +0.04 (conceded territory).
- [ ] Task 4: Out of Possession tab UI | Where: `lib/features/match/pre_match_screen.dart`, `lib/features/match/live_tactics_screen.dart` | Expected: segmented controls + offside-trap toggle with effect summaries. The trap toggle is disabled or warns when `defensiveLine` = Deep (no benefit, pure risk — the UI must teach the trade-off). EN/AR, RTL verified, in-match changes via `ChangeTacticsCommand`.
- [ ] Task 5: Balance verification | Where: `test/balance/match_engine_balance_test.dart` (extend the harness) | Expected: 10,000 seeded sims per case, even strength vs default tactics. (a) Single-instruction extremes: win rate 46–54%; full-stack defensive extreme (Deep+Low+Clean) and (High+High+Aggressive+trap): 40–58%. (b) Realism anchors — measure the current engine's combined fouls/match at Balanced first and keep it within ±10%; that baseline should sit in the 20–28 band; Aggressive raises fouls +25–35% and yellows +30–40% vs Balanced; Clean lowers both. (c) High-press stamina drain 1.25–1.35 and visible late-match cost: goals conceded after 75' at High press ≥ 15% above baseline. (d) Global anchors unchanged: goals 2.6–2.9, conversion 10–11%, draws 22–30%.
- [ ] Task 6: GDD documentation | Where: `docs/fcm_rivals_GDD_SRS.md` (section 10.2) | Expected: the Out of Possession group documented with options, anchors, the interaction matrix and the foul/card realism bands.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] Every option's effect summary visible in the UI; offside-trap/trade-off warning present
- [ ] Foul/card rates are per-side and hit the Task-5 bands (10k seeded sims); penalty award rate 0.25–0.30/match at Balanced

## Developer Notes
<Implementation notes, rejected points with reason.>

## Reviewer Verification
<Filled by reviewer before setting CLOSED.>
