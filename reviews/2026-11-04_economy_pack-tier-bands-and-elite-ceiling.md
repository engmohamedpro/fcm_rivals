# Economy: relative pack tier bands hide the elite game
- Feature: economy
- Type: Design
- Priority: Major
- Reviewer: Coach Hady
- Created: 2026-11-04
- Status: OPEN
- Completed by: -
- Completed on: -

## Context
Pack tier bands are relative to each pool's log market-value range (`tierBoundaries [0.15, 0.55]`), so a Legendary pack drawn from a €0.4M–2.6M pool can never contain a star. Simulation over the real 20,876-player dataset: Rare packs 0% chance of any ≥€20M player, Epic 1.15%, Legendary 6.5% ≥€20M and only 1.0% ≥€50M, with E[MV] of a legendary pull ≈ €5.7M. A full XI of €50M players needs ~1,080 legendary packs (~140 seasons) — the elite game the pack UI sells is effectively unreachable. Match rewards are also nearly flat: ~2,096 coins/match at a 30% win rate vs 2,369 at 60% (Δ13%).

## Tasks
- [ ] Task 1: Replace the relative tier bands with absolute market-value bands (low < €3M, mid €3–20M, high ≥ €20M), or keep relative bands but add a per-tier absolute floor for legendary pools | Where: `lib/features/packs/pack_engine.dart:188` (`tierBoundaries`), tier weights at `:33-35` | Expected over ≥20,000 seeded openings on the full dataset: Legendary P(≥€20M) ≥ 20% and P(≥€50M) ≥ 4%; Epic 5–15% ≥€20M; Rare < 5% ≥€20M; tier-share table in Developer Notes. Dynamic pricing must be re-derived from the new expected values — legendary prices will rise; verify the margin logic still holds (`lib/features/economy/economy_engine.dart:39` comment).
- [ ] Task 2: Make the elite ceiling an explicit product decision: either communicate the soft cap in-game (expected best XI by season N) or add a floor-guaranteed elite acquisition path (scouting market / event packs with a €20M floor) | Where: `lib/features/economy/` + pack purchase UI | Expected: decision recorded with a GDD reference; if a new path is added, a 10-season economy sim shows the intended elite XI is reachable within a stated number of seasons (suggest ≤ 30 at a 60% win rate); if the product decision is a longer grind, state that explicitly in Developer Notes with the sim numbers.
- [ ] Task 3: Widen the performance-driven income spread | Where: `lib/features/economy/economy_engine.dart:41-42` (`baseMatchReward`, `matchRewardPerGoal`) | Expected: ≥ ±20% spread around par by win rate (loss pays 80–90% of par, win 120–135%); a 20-season sim table for three win-rate scenarios (30/46/60%) in Developer Notes; season economy ends balanced with no coin inflation blowup.
- [ ] Task 4: Make the upgrade display honest: the card shows +1 OVR per upgrade level (`overall = base + upgradeLevel`) but each level grants one attribute point — an ST gains E[0.66] attack ≈ +0.5 true position rating | Where: `lib/features/squad/squad_engine.dart:42`, `lib/features/upgrades/upgrade_engine.dart:53-84` | Expected: either grant 2 attribute points per level (≈ +1 true OVR for attackers) or display the upgrade level separately from OVR; matches-per-point for a €50M card at L1 stays ≥ 3; if points are doubled, re-check the upgrade cost curve so upgrades don't become the dominant strategy.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] Pack-odds regression test covering the new tier bands (≥20,000 seeded openings)
- [ ] Economy sim table (≥10 seasons × 3 win-rate scenarios) in Developer Notes
- [ ] No hardcoded currency strings; locale-aware number formatting for new UI copy

## Developer Notes
<Implementation notes, rejected points with reason.>

## Reviewer Verification
<Filled by reviewer before setting CLOSED.>
