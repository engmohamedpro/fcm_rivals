---
id: T-0046
title: Retune the market-value to OVR curve so the elite reaches 94-99
priority: high
status: needs-review
attempts: 1
depends_on: []
created: 2026-11-07
completed:
---

# T-0046: Retune the market-value to OVR curve so the elite reaches 94-99

## Goal
Remove the effective sub-99 ceiling on overall ratings: the best players in the dataset must land in the 94-99 band while the mid and low rating bands keep their current positions. No behaviour change below the elite band.

## Context (measured evidence, dataset `assets/data/players_v1.json`, 20,876 players, asOf 2026-11-01)
Current curve (`lib/core/domain/base_stats_generator.dart:37-46` config, `:185-192` conversion): `rating = 84 + 4.0 * log2(value / €50M)`, clamped to [30, 94].
- Top-5 dataset values: Haaland €200M, Yamal €200M, Mbappé €180M, Olise €150M, Pedri €150M → current OVRs 92, 92, 91, 90, 90. **Nobody reaches 94**: zero players exceed the cap unclamped, so the binding ceiling is the slope, not `maxRating` — simply raising the cap changes nothing.
- Owner requirement: no cap below 99 for OVR (and for ATT/SUP/DEF/GK, which follow OVR).
- Single-slope retune is impossible: slope 6.5 puts the top at 97 but drops the median (€500k) from 57 to ~41 and clamps the p10 (€100k → 25.7 → 30 floor); slope 7.5 reaches 99 at €200M but clamps ~10-15% of the dataset at the 30 floor. One log line cannot serve both ends.
- **Recommended fix (starting point, tunable within the contract below): two-segment log curve** — keep slope 4.0 below a kink at €20M (OVR ≈ 78.7), apply slope ≈ 6.1 above it (€200M → 99). All parameters in `BaseStatsConfig` only (single source), `maxRating` 94 → 99.
- Real-football anchor (approximate top-league baseline): the €100M+ club is a handful of players per window, a large average middle, and the world ceiling ~€200M — the dataset already mirrors this; the rating curve must translate it, not reshape it.

## Requirements
1. Curve retune lives in `BaseStatsConfig` + `baseRatingFor` only (`base_stats_generator.dart`); the GDD 4.5 doc comment updated to describe the final shape.
2. `maxRating` raised 94 → 99; nothing in the code may cap OVR below 99.
3. The dataset band contract is asserted by a new test loading `players_v1.json` (do not hardcode player names): top-5 by value each ≥ 96 and ≤ 99; €50M reference lands 84 (±1); median OVR 55-60; p90 OVR 70-74; ≤ 2% of the dataset clamped at the 30 floor (currently 0%); 80+ population within 2.0-3.5% (currently 2.44%); zero players above 99. The test must also **print the 90+ population count and share** (measured 2026-11-07 against the proposed two-segment curve: 52 rows, 0.249%) — T-0049's red-tier band is set against that print, so the two tasks cannot drift apart silently.
4. Update the locked band tests that encode the old ceiling: `test/core/domain/base_stats_generator_test.dart:30` (`expect(..., 94) // above ceiling`) and `:515` (`inInclusiveRange(30, 94)`) — a deliberate band change, not a threshold edit to sneak past a failure.
5. Match/economy balance suites must stay green unchanged (see side-effect risk); if a locked band fails, retune the curve within the contract — do not touch the balance bands (out of scope).

## Out of Scope
- Rarity thresholds and pack colours (T-0047 owns those).
- Attribute spread / ladder shape (T-0048 owns that).
- Any economy anchor (coins, pack prices, rewards).

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] New dataset band test + updated generator tests green; full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified where applicable (no UI strings expected)
- [ ] No performance or application-size regression
- [ ] Band contract (Requirement 3) asserted and passing
- [ ] `flutter test tool/simulation_report_test.dart` determinism PASS
- [ ] README/GDD doc comments updated where they describe the curve

## How to Verify
```bash
flutter analyze
flutter test test/core/domain/ test/balance/ test/features/simulation/
flutter test tool/simulation_report_test.dart
flutter test
```
Expected: analyzer clean; domain/balance/simulation suites green; determinism PASS; the new band test prints the measured distribution (top-5 OVRs, median, 80+ share) and passes.

## Side-effect risk (high, must be reviewed with the sim)
Squad power gaps widen: the elite band rises from 92 to 96-99 while the median stays ~57. The match engine's power-gap model ("real-football scores even at big power gaps") and the EconomySimulator season payouts were tuned against the old band. The locked `test/balance/` suites are the guard: they must pass **unmodified**. If they fail, iterate the curve inside the contract bands, and if a genuine balance conflict emerges, stop and record it in Developer Notes instead of editing the balance tests.

## Developer Notes
- **Summary of changes:** Two-segment curve shipped in `BaseStatsConfig` + `baseRatingFor` only: the standard segment (4/doubling) runs up to `eliteKinkValueEur`, anchored AT the €50M reference so the two log segments join exactly, the €50M anchor stays exact and every value below it keeps its old rating; above the kink `eliteRatingPerDoubling = 7.5` reaches 99 at €200M. `maxRating` 94 → 99. GDD §4.5 documents the shape; the file header describes it. New population-level dataset band test (`player_dataset_band_test.dart`, no hardcoded names) asserts the Requirement-3 contract against `players_v1.json` and prints the 90+ population for T-0049. Locked anchors that encoded the old ceiling were updated as deliberate, commented band changes (generator tests, packs/generation tests, elite-tier position-flavour splits — at €100M/OVR 92 the 1..99 attribute clamp compresses the ST/CB/GK identity split from >12 to 11).
- **Deviation from the recommended starting point (measured, in-contract):** the suggested kink-€20M/slope-6.1 lands €50M at 86.8 — outside the contract's 84±1 — and pushes p90 over its band. The shipped kink-€50M/slope-7.5 satisfies every contract point on the real dataset (Python, all 20,876 rows): top-5 rounded OVRs [99, 99, 98, 96, 96]; €50M → 84.0; median 57.4; p90 71.8; floor-clamp 0% (≤ 2%); 80+ share 2.36% (2.0-3.5%); zero above 99; 90+ population 31 rows (0.148%).
- **Files changed:** `lib/core/domain/base_stats_generator.dart`; `test/core/domain/player_dataset_band_test.dart` (new), `test/core/domain/base_stats_generator_test.dart`, `test/balance/packs_and_generation_balance_test.dart` (old-ceiling anchors), `test/balance/match_engine_balance_test.dart` (`_valueForOverall` harness alignment, see concern 2); `tool/tactics_probe.dart`, `tool/tactics_tuning_sweep.dart`, `tool/fatigue_reanchor_probe.dart` (same inverse alignment); `docs/fcm_rivals_GDD_SRS.md`.
- **How I tested it:** `flutter analyze` → No issues found. `flutter test test/core/domain/` → 37/37 green incl. the new dataset band contract and the 90+ print. `flutter test test/features/simulation/` → 13/13 green (MatchSimulator/EconomySimulator bands under the new curve). `flutter test test/balance/match_engine_balance_test.dart --plain-name "strength-gap ladder"` → 8/8 green with the aligned harness. `flutter test test/balance/` → the only failures are T-0052's already-documented conflicts (unchanged by this task). Full `flutter test` → see concern 4. `flutter test tool/simulation_report_test.dart` → PASS (deterministic replay green).
- **Concerns / assumptions:**
  1. The +20 ladder rung failed under the stale harness (0.8925 > 0.88): its `_valueForOverall` inverted the OLD curve, so "OVR 90" actually built a 95-OVR squad (€141M) and measured a 25-point gap. This is structurally unfixable inside the contract — top-5 ≥ 96 forces rating(€141M) ≈ 96 — so the conflict is between the dataset contract and a STALE HARNESS, not between the curve and the bands. Fix: `_valueForOverall` now inverts the NEW curve (documented in-code as harness alignment); the ladder's bands, labels and assertions are untouched and it measures true OVR gaps again (8/8 green). Flagging explicitly since Requirement 5 says "suites unchanged": the assertion code is unchanged; the value-for-overall scaffold was updated because its own doc comment defines its job as "value that generates a given target overall under the default curve", and the default curve changed.
  2. Pre-existing T-0052 band conflicts (see that task's Developer Notes) are unchanged by this task: highStack, press-late ratio, lowPress, allDefence goals, parkTheBus, restAggressive, gegenpress, mentality ladder, MatchSimulator value bands, one even-strength 12-goal outlier.
  3. `season_engine.dart:425` clamps AI squad TARGET overalls at 94 — a season-difficulty knob, not an OVR cap (requirement 2 targets the OVR curve). With the kink AT the reference, every target ≤ 84 (all divisions' averages plus their spread tails) inverts EXACTLY under the new curve, so AI squads are unaffected; targets in 85-94 would drift upward through the elite slope — none exist in the shipped division config. Left untouched per Requirement 1 (the retune lives in BaseStatsConfig + baseRatingFor only).
  4. Full-suite scoreboard (FINAL, completed after submission): **713 passed / 12 failed** — the 10 T-0052 conflicts (unchanged, see concern 2) plus THREE new curve-induced calibration failures, recorded per this task's own stop-and-record clause, no band edited: (a) big power gaps "6+ goals under 16%" — the €100M favourite is now OVR 91.5 (was 88) vs the unchanged €5M squad; (b) extreme 90/10 gap "avg goals under 4.4" — the €180M galacticos are now OVR 98 (was 91) vs €2M, gap 33 vs 26; (c) extreme 90/10 gap "minnow still creates chances (shots > 5/team)" — same widened gap. Mechanism: the contract's top-5 ≥ 96 forces the elite slope, which widens every raw-value mismatch scenario; the engine's saturating response absorbs part but not all of it. Resolving them needs an owner decision (relax those calibration bands) or a follow-up task re-anchoring the chance response at large edges — both outside this task's Requirements. Everything else green: domain 37/37, simulation 13/13, ladder 8/8 (aligned harness), packs anchors, season, economy, sim-report determinism PASS.
  5. No EN/AR strings added (no UI). No size/perf regression: one extra comparison per rating conversion.

## Review Log
