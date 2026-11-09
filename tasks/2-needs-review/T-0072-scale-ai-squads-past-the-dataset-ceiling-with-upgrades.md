---
id: T-0072
title: Scale AI squads past the dataset ceiling with upgrade levels
priority: high
status: needs-review
attempts: 1
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

- **Summary of changes:** `generateAiClubs` now lifts every club onto the division target: after the squad is built (real or synthetic), `_liftToTarget(squad, target)` computes the club's average base overall, and when it is a full point or more below the target it applies a uniform level `N = ceil((target / avg − 1) × 100)` — every player's four attributes become `upgradedValue(attr, N)`, the shared T-0070 math, so AI and user progression are one curve. Weaker bases get bigger lifts; every club lands on the target. Deterministic (derives from the already-seeded squad, no new RNG). `AiPlayerDefinition` gained an optional `upgradeLevel` debug field (default 0, not persisted, no UI). Persistence untouched: lifted effective values are written into the existing `aiPlayers` attribute columns exactly as before. GDD 9.6 documents the dated owner decision.
- **Files changed:** `lib/features/season/season_engine.dart` (`_liftToTarget` + call site), `lib/features/season/season_ai_models.dart` (`upgradeLevel` field), `docs/fcm_rivals_GDD_SRS.md` (9.6), `test/features/season/season_engine_test.dart` (+5 tests), `tasks/…T-0072….md`.
- **How I tested it:** `flutter analyze` → No issues found. `test/features/season/season_engine_test.dart` → **29/29** (new: div 1 zero drift with level 0 everywhere + the near-target band still ±6; div 20 target 111 — every club's average effective overall > 110 with attributes > 99 present and level > 0; the real-pool path (buildPool caps at 94) also reaches 111 ±1; same seed twice → identical squads AND lifts; synthetic-only division 25 (target 126) and a 30-player degenerate pool at division 20 both produce full legal 18-man XIs on target). Season suite → **64/64** (all pre-existing generation tests untouched and green). Zero-drift: engine snapshot 1/1 and balance 90/90 with `REGEN_SNAPSHOT` unset. Full `flutter test` → **893/893 green**.
- **Design decisions the tests forced (documented for review):** (1) The squad average must be computed over the OUTFIELD attributes (ATT/SUP/DEF) — the same basis the generation tests use. My first draft averaged all four, which read goalkeepers' 0-ATT and outfield players' 0-GK as weakness: a division-1 synthetic XI measured 42 instead of 53.5 and got a +30% "lift" at the easiest division. (2) The dead zone is `target − avg < 1.0` on the real gap, not `level ≤ 1`: the spread variance (±3 per player, ±6 tolerated by the near-target band) leaves some clubs 0.3–0.7 under target, and `ceil` would turn that into level 1 — a needless drift for divisions the pool supplies. The task's Requirement 3 (low divisions byte-identical) wins; the 1-point floor is far below the ±1 acceptance tolerance and the div-20 gap of ~17 points dwarfs it. (3) The lift counts BASE overall (pre-lift) for the level, so a club lands at ≥ target − 1 after rounding (per-attr rounding costs at most a fraction of a point), which the div-20 test verifies directly.
- **Concerns / assumptions:** (1) Levels are uniform per club, exactly as specified — a star and a squad player get the same +N%; per-player targeting would smooth spikes but the spec says uniform. (2) Persisted historical squads (saves mid-career) keep their generated values — only newly generated divisions lift, per Out of Scope. (3) The `upgradeLevel` field is diagnostic; if a later task wants +N badges on opponents, it is already there to read. (4) >99 attributes flow into `computeTotals` and rating displays unchecked by design — T-0073 measures that balance; nothing here clamps them.

## Review Log
