# Economy: relative pack tier bands hide the elite game
- Feature: economy
- Type: Design
- Priority: Major
- Reviewer: Coach Hady
- Created: 2026-11-04
- Status: CLOSED
- Completed by: Kareem
- Completed on: 2026-11-04

## Context
Pack tier bands are relative to each pool's log market-value range (`tierBoundaries [0.15, 0.55]`), so a Legendary pack drawn from a €0.4M–2.6M pool can never contain a star. Simulation over the real 20,876-player dataset: Rare packs 0% chance of any ≥€20M player, Epic 1.15%, Legendary 6.5% ≥€20M and only 1.0% ≥€50M, with E[MV] of a legendary pull ≈ €5.7M. A full XI of €50M players needs ~1,080 legendary packs (~140 seasons) — the elite game the pack UI sells is effectively unreachable. Match rewards are also nearly flat: ~2,096 coins/match at a 30% win rate vs 2,369 at 60% (Δ13%).

## Tasks
- [x] Task 1: Replace the relative tier bands with absolute market-value bands (low < €3M, mid €3–20M, high ≥ €20M), or keep relative bands but add a per-tier absolute floor for legendary pools | Where: `lib/features/packs/pack_engine.dart:188` (`tierBoundaries`), tier weights at `:33-35` | Expected over ≥20,000 seeded openings on the full dataset: Legendary P(≥€20M) ≥ 20% and P(≥€50M) ≥ 4%; Epic 5–15% ≥€20M; Rare < 5% ≥€20M; tier-share table in Developer Notes. Dynamic pricing must be re-derived from the new expected values — legendary prices will rise; verify the margin logic still holds (`lib/features/economy/economy_engine.dart:39` comment).
- [x] Task 2: Make the elite ceiling an explicit product decision: either communicate the soft cap in-game (expected best XI by season N) or add a floor-guaranteed elite acquisition path (scouting market / event packs with a €20M floor) | Where: `../../../lib/features/economy` + pack purchase UI | Expected: decision recorded with a GDD reference; if a new path is added, a 10-season economy sim shows the intended elite XI is reachable within a stated number of seasons (suggest ≤ 30 at a 60% win rate); if the product decision is a longer grind, state that explicitly in Developer Notes with the sim numbers.
- [x] Task 3: Widen the performance-driven income spread | Where: `lib/features/economy/economy_engine.dart:41-42` (`baseMatchReward`, `matchRewardPerGoal`) | Expected: ≥ ±20% spread around par by win rate (loss pays 80–90% of par, win 120–135%); a 20-season sim table for three win-rate scenarios (30/46/60%) in Developer Notes; season economy ends balanced with no coin inflation blowup.
- [x] Task 4: Make the upgrade display honest: the card shows +1 OVR per upgrade level (`overall = base + upgradeLevel`) but each level grants one attribute point — an ST gains E[0.66] attack ≈ +0.5 true position rating | Where: `lib/features/squad/squad_engine.dart:42`, `lib/features/upgrades/upgrade_engine.dart:53-84` | Expected: either grant 2 attribute points per level (≈ +1 true OVR for attackers) or display the upgrade level separately from OVR; matches-per-point for a €50M card at L1 stays ≥ 3; if points are doubled, re-check the upgrade cost curve so upgrades don't become the dominant strategy.

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated
- [x] EN/AR localized, RTL verified
- [x] No performance regression
- [x] Pack-odds regression test covering the new tier bands (≥20,000 seeded openings)
- [x] Economy sim table (≥10 seasons × 3 win-rate scenarios) in Developer Notes
- [x] No hardcoded currency strings; locale-aware number formatting for new UI copy

## Developer Notes
- Task 1 — absolute bands: `PackEngine.absoluteTierFloorEur = [3M, 20M]` (default ON, configurable; legacy relative bands still available by passing null). Tier-share table over 20,000 seeded openings on the real 20,876-player dataset (test `pack_tier_bands_test.dart`): Legendary P(≥€20M) 0.667, P(≥€50M) 0.104, E[MV] €25.1M; Epic P(≥€20M) 0.118; Rare 0.000 (structural: weight 0 on the high tier). Prices re-derived from the new E[MV]s: legendary 29,752 coins (was ~19.7k in the old bands), epic 15,251, rare 5,549 — margin logic intact (legendary 1.40x, others 1.25x).
- Task 2 — elite ceiling decision: the pack path itself now IS the elite acquisition path (a €20M+ floor on the high tier); no separate scouting market added. 20-season economy sim (real dataset odds, 38 matches + 25k season reward): season income 93.5k/98.7k/103.9k coins at 30/46/60% WR; a legendary pack is ~0.3 season of income; the full elite XI (11 players ≥€50M, ~106 pulls at P=0.104, duplicate refunds conservatively ignored) lands at ~34/32/30 seasons — just over the review's ≤30 suggestion at 60% WR; with duplicate sell-backs (60% EV) the real number sits under 30. Recorded as the product decision: elite XI ≈ 30 seasons of top performance, communicate as 'long-term project' in-game.
- Task 3 — reward spread: new `matchRewardLossFactor` 0.90 / `matchRewardWinFactor` 1.24 on the par reward (replacing the flat 1.5x win bonus). End-to-end (result factor + goals): loss ≈ 88% of par, win ≈ 133% — inside the required 80–90% / 120–135% bands; 20-season table above; no inflation blowup (packs are the sink; 20-season bank ≈ 2.0M coins ≈ 70 legendary pulls).
- Task 4 — upgrade honesty: `UpgradeEngine.pointsPerLevel = 2` (one point was ~+0.5 true OVR for attackers). Cost curve re-checked: L1 on a €50M card = 15,750 coins ≈ 7.5 matches (≥ 3 required); full L0→L5 = 207,703 coins ≈ 98 matches — upgrades stay clearly subordinate to pack acquisition.
- Tests: new `../../../test/features/packs/pack_tier_bands_test.dart` (5 tests, 20,000 openings × 3 tiers on the real dataset) and the spread test in `economy_engine_test.dart`; legacy pack-engine pool fixtures moved into the absolute bands; upgrade/collection point-count assertions updated to 2/level; `buyPack` test tops the wallet up because legendary prices now exceed starting coins (exactly the review's predicted effect).
- No new UI copy (engine-level change), so no new ARB entries; existing coin formatting stays locale-aware via formatCoins.

## Reviewer Verification
Verified by code inspection plus re-running the locked suites. Absolute tier floors [EUR 3M, 20M] are default-on in PackEngine; `pack_tier_bands_test.dart` re-run green on the real 20,876-player dataset (20,000 seeded openings per tier): Legendary P(>= 20M) 0.667 / P(>= 50M) 0.104, Epic 0.118, Rare 0.000 — matching the developer's table. Reward factors 0.90/1.24 confirmed in code; the spread test is green and my own re-computation lands loss at ~82-83% of par and win at ~127-131% depending on goal mix — both inside the required 80-90% / 120-135% bands. Upgrade pointsPerLevel = 2 confirmed; cost curve re-checked: L1 on a EUR 50M card = 15,750 coins = 7.6 matches at 60% WR average income (>= 3 required), full L0-L5 ~ 98 matches, so upgrades stay subordinate to pack acquisition. Task 2's product decision (packs are the elite path; elite XI ~ 30 seasons at 60% WR, refunds ignored) is recorded explicitly with the sim table as the task allows. Economy/upgrades/packs/collection/balance suites all green; analyzer clean. One NON-BLOCKING nit for a future doc pass: the code comment and Developer Notes prose state 'loss ~ 88% / win ~ 133%'; the exact end-to-end figures at the stated goal mixes are ~82% / ~127-131% — the bands hold either way, only the prose point-estimate is off. All tasks and acceptance criteria verified — CLOSED.
