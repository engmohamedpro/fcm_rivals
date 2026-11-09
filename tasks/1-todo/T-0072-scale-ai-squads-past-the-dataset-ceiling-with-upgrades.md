---
id: T-0072
title: Scale AI squads past the dataset ceiling with upgrade levels
priority: high
status: todo
attempts: 0
depends_on: [T-0070]
created: 2026-11-09
completed:
---

# T-0072: Scale AI squads past the dataset ceiling with upgrade levels

## Goal
The division ladder never flattens: when a division's target overall exceeds what the player pool can supply, AI squads are lifted to the target with the same +N% upgrade math the user's cards use — so divisions stay harder forever (top players, then players with +).

## Context
- Owner spec (2026-11-09): "the divisions ladder up keeps being more difficult... teams get top players then teams get players with + so that it is infinite divisions". GDD 9.1 already declares "no predefined final division".
- Today the ladder stalls: `targetAverageOverall(division) = 54 + (division − 1) × 3` (`lib/features/season/season_engine.dart:73`, unbounded), but the real-player pool bands ±3 and widens until it can only take each position's best available (`_PoolTracker.take`), and the synthetic fallback clamps at `(target + spread).clamp(35, 94)` (`_generatePlayer`). Division 16 targets 99; beyond it every squad is just "the elite leftovers" and stops growing.
- The fix uses T-0070's shared `upgradedValue(base, level)` — AI players get the same percentage lift as user cards, keeping one progression curve for both sides.
- Persistence is unchanged: `loadOpponent` (`season_store_opponent.dart`) reads the four attribute columns from `aiPlayers`; effective (lifted) values are written there directly — no schema change, no upgrade-level column.
- Determinism: the lift derives from the already-seeded squad (same seed → same squad → same lift); no new RNG draws.

## Requirements
1. In `generateAiClubs` (`season_engine.dart:214-262`): after each club's squad is built (real or synthetic), compute the squad's average base overall; when it is below the division `target`, give the whole club a uniform upgrade level `N = ceil((target / avg − 1) × 100)` (0 when avg ≥ target, guard avg > 0) and set every player's four attributes to `upgradedValue(attr, N)`. Per-club N: clubs with weaker bases get a bigger lift, every club lands on the target — consistent with today's band-around-target intent.
2. `AiPlayerDefinition` (`lib/features/season/season_ai_models.dart`) may carry the club's `upgradeLevel` as an optional debug field (not persisted, no UI).
3. Low divisions are byte-identical to today: at `target ≤ achievable base` the lift is 0 and generation is untouched (division 1 stays 54-band).
4. Update GDD 9.6 (`docs/fcm_rivals_GDD_SRS.md` "Difficulty Scaling"): beyond the dataset ceiling, difficulty scales through AI upgrade levels using the shared player-upgrade math — dated owner decision 2026-11-09.
5. Tests (extend the season engine/generation tests): division 1 squads unchanged (zero drift — the existing seeded generation tests pass untouched); division 20 (target 111) — every generated club's average effective overall is ≥ target − 1 with attributes > 99 present; the synthetic fallback path also lifts (a 94-clamped squad reaches the target); same seed twice → identical squads and lifts; a thin/test dataset (no pool) still produces a full legal XI at high targets.

## Out of Scope
- Showing +N badges on opponent players (pre-match screens show ratings only today; a display task can follow if wanted).
- Changing the division target curve (stays 54 + 3×(division−1)) or promotion/relegation.
- Match-engine behavior with >99 values — measured in T-0073.
- Persisting AI upgrade levels or lifting already-persisted historical squads (only newly generated divisions lift; existing saves keep their squads as generated).

## Acceptance Criteria
- [ ] At high divisions every AI club's average effective overall meets the division target (±1), via the shared `upgradedValue` helper — attributes above 99 flow into matches.
- [ ] Division 1 (and every division whose target the pool supplies) generates exactly today's squads — seeded generation tests and the engine snapshot pass with no `REGEN_SNAPSHOT`.
- [ ] Generation stays deterministic per seed, works with no dataset (synthetic path), and never crashes on empty/deg pools.
- [ ] GDD 9.6 documents the upgrade-level scaling with the dated owner decision.
- [ ] `flutter analyze` zero warnings; `flutter test` full suite green.

## How to Verify
```bash
flutter analyze
flutter test test/features/season/                    # generation + lift tests green
flutter test test/features/match/engine_snapshot_test.dart   # zero drift, no REGEN
flutter test
dart run   # optional: headless season sim at division 20 -> opponents average ~111
```
Expected: analyze clean, suites green; high-division opponents carry lifted (>99) attributes and low divisions are unchanged.

---

## Developer Notes

## Review Log
