---
id: T-0053
title: Add the injury data model and seeded risk engine
priority: critical
status: todo
attempts: 0
depends_on: [T-0052]
created: 2026-11-07
completed:
---

# T-0053: Add the injury data model and seeded risk engine

## Goal
Create the injury system's contract layer: a pure, seeded, unit-testable injury-risk model (the performance role stamina used to play now becomes injury risk, per the owner's 2026-11-07 decision), the injury record model (kind + matches-out severity), and the database schema v4 columns — no match-engine wiring, no UI yet.

## Context (evidence, main `3614c4a`)
- Injuries do not exist anywhere today: the GDD has zero injury mentions, and the Medical Centre facility is an explicit forward hook — `lib/features/facilities/facilities.dart:16-19` ("injuries themselves are forecast-only today — the level persists") with `injuryRiskAt(level) = 0.6 * level` percentage points (`:107-134`, locked by `test/features/facilities/facilities_test.dart:60,78`). This task defines the model that hook finally feeds.
- The stamina system this builds on: `lib/features/match/stamina.dart` — `StaminaConfig` (drain/recovery/thresholds), `staminaDrainForMinute`, `recoverStamina`. The risk model must live next to it as a sibling pure module `lib/features/match/injury.dart` (pure Dart, no Flutter imports, server-port ready per README).
- Starter stamina after the T-0052 decoupling lands ~70 for full-match players (see the `StaminaConfig` doc comment in `stamina.dart:19-28`); congested spells push regulars into the 40s-50s. Risk must be ≈ 0 at full stamina and rise steeply below the exhausted band — fatigue moves from the results table to the treatment table.
- Persistence targets: `OwnedPlayers` (`lib/core/database/app_database.dart:78-98`, `staminaPercent` at `:93`) and the AI players table (search `AIPlayers` in the same file). Schema version is v3 today; this task ships v4 with a Drift migration (pattern: existing `onUpgrade` steps in `app_database.dart`) and regenerated `app_database.g.dart` via build_runner.
- Severity scale for the owner's game loop: a knock (misses 1 match), a muscle injury (2-3), a serious injury (4-6). Weights must make the expected recovery short — the season is 38 double round-robin rounds and squads are 23 men.
- The engine integration (per-minute rolls, `MatchEventType.injury`, forced substitutions) is T-0054; persistence behaviours and Medical Centre wiring are T-0055; UI/l10n is T-0056. This task only ships models + pure math + schema.

## Requirements
1. `lib/features/match/injury.dart` with `InjuryConfig` (all tunables in one class, the `StaminaConfig` pattern): per-minute base risk at full stamina, the fatigue-risk threshold (default 70), the risk slope/ramp below it (documented shape, e.g. quadratic, bounded by a documented max per-minute risk), a position-risk multiplier reusing `StaminaConfig.positionWorkload` semantics, a per-level Medical Centre reduction (consuming the 0.6pp/level hook as multiplicative protection), and a per-match cap guard constant.
2. Pure seeded functions (no RNG state inside — take a `MatchRandom`/seed parameter, the engine decides when to roll): `injuryChanceForMinute(...)` returning the per-minute probability for one player, and `rollInjury(...)` returning an `PlayerInjury` (kind from a 3-value enum knock/muscle/serious, `matchesOut` per the weights in Context) or null.
3. `PlayerInjury` data class + `InjuryKind` enum in `injury.dart`, display-name keys designed for EN/AR (no user-facing strings in this layer; kind → l10n key mapping documented in a doc comment).
4. DB schema v4: nullable `injuryMatchesRemaining` (int, default 0) + `injuryKind` (text, nullable) on `OwnedPlayers` AND the AI players table; migration tested (fresh install + v3→v4 upgrade preserving existing rows byte-for-byte); build_runner regenerated.
5. GDD: add §11.7 "Injury System" spec (risk inputs, threshold, severity table, Medical Centre effect, recovery = matches missed) and adjust the §3.5 Medical Centre line to point at it.
6. Unit tests: risk ≈ 0 at stamina 100; strictly increasing as stamina falls below the threshold (monotonic grid over 100→0); the Medical Centre level strictly reduces risk at every level 0-5; `rollInjury` determinism per seed and distribution sanity over ≥ 50,000 seeded draws (kind shares and mean matchesOut printed and band-locked in the test); migration tests green.

## Out of Scope
- Any match-engine call site (no per-minute roll in the loop yet — T-0054).
- Store behaviours: applying injuries post-match, decrementing on rounds, squad gating (T-0055).
- Any UI, badge, banner or l10n string (T-0056).
- Changing drain/recovery values or any T-0052 deliverable.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Injury unit tests green with the distribution bands printed and locked; migration tests green; full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified where applicable (no user-facing strings expected in this layer)
- [ ] No performance or application-size regression (schema v4 + pure functions only)
- [ ] Schema v4 with both tables carrying the injury columns; v3→v4 upgrade test green
- [ ] GDD §11.7 exists and the Medical Centre docs reference it
- [ ] `flutter test tool/simulation_report_test.dart` determinism PASS

## How to Verify
```bash
flutter analyze
flutter test test/features/match/stamina_test.dart test/features/match/injury_test.dart
flutter test test/core/database/
flutter test
```
Expected: analyzer clean; injury risk/severity/distribution tests green with printed shares; database suite green including the v3→v4 migration; full suite green.

## Side-effect risk (low)
Schema migration touches every store that opens the DB — the store integration suites are the guard. The risk constants are pre-balance placeholders (GDD rule 14); the calibration gate for real rates is T-0054's engine calibration group, so no tuning in this task.

## Developer Notes

## Review Log
