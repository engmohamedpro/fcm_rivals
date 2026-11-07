---
id: T-0046
title: Retune the market-value to OVR curve so the elite reaches 94-99
priority: high
status: todo
attempts: 0
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

## Review Log
