---
id: T-0053
title: Add the injury data model and seeded risk engine
priority: critical
status: needs-review
attempts: 1
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
- **Summary of changes:** The injury contract layer (GDD 11.7), nothing wired anywhere. `lib/features/match/injury.dart` (pure Dart, no Flutter imports): `InjuryConfig` with every tunable — base per-minute risk 0.0002 at full stamina, fatigue threshold 70 with a documented quadratic ramp (slope 14, `t = (70 − stamina)/70`) bounded by `maxRiskPerMinute` 0.0035, position multipliers mirroring the `StaminaConfig.positionWorkload` semantics, Medical Centre −0.6%/level multiplicative (consumes the 0.6pp/level hook), per-match cap 2, severity weights knock 0.55 / muscle 0.35 / serious 0.10 → E[matchesOut] = 1.925; pure functions `injuryChanceForMinute` and `rollInjury` — no RNG state inside, the engine passes a `double Function()` draw (MatchRandom's `nextDouble` tear-off fits; the engine decides when to roll, keeping the GDD-12.5 draw budget); `PlayerInjury` + `InjuryKind` with the kind→l10n-key mapping documented (`injuryKindKnock`/`injuryKindMuscle`/`injuryKindSerious`, strings land with T-0056). Schema **v12**: nullable `injuryMatchesRemaining` (default 0) + nullable `injuryKind` on BOTH `OwnedPlayers` and `AiPlayers`, four `addColumn` migration steps, `app_database.g.dart` regenerated via build_runner.
- **Deviations from the task evidence (recorded, none change the contract):** (1) the task says "schema v3 today; ships v4" — the live schema is **v11**; shipped v12 with the same column contract. (2) The referenced "§3.5 Medical Centre line" does not exist in the GDD (no §3.5 and no campus/medical section — that spec lives only in code comments citing stale GDD numbers); Requirement 5 is satisfied by §11.7 carrying the Medical Centre effect plus the §11.2 stamina line now pointing at §11.7. (3) `pubspec.lock` re-recorded: the committed lock pinned drift 2.35.3, which is unresolvable on the shipped Dart 3.13.7 toolchain — every `pub get` silently re-resolves to 2.31.0 (the `^2.20.0` constraint holds); the lock now records the resolvable truth, `sqlite3` was added as a dev dependency for the migration test (already a transitive dep — no new code in the tree), and two scoped `// ignore: experimental_member_use` comments neutralize drift 2.31's annotation on the PRE-EXISTING `TableMigration` steps (behavior unchanged) so the zero-warnings AC holds under the resolvable version.
- **Files changed:** `lib/features/match/injury.dart` (new); `lib/core/database/app_database.dart` (columns, v12, migration, 2 scoped ignores); `lib/core/database/app_database.g.dart` (regenerated); `pubspec.yaml` (+sqlite3 dev dep); `pubspec.lock` (re-resolved, see deviation 3); `docs/fcm_rivals_GDD_SRS.md` (§11.7 + §11.2 pointer); `test/features/match/injury_test.dart` (new); `test/core/database/schema_v12_migration_test.dart` (new); `test/features/season/schema_v10_migration_test.dart` + `schema_v11_migration_test.dart` (fixtures made faithful to a real pre-v12 install — see concern 2).
- **How I tested it:** `flutter analyze` → No issues found. Targeted run (injury + stamina + database suites) → 25/25 green: risk ≈ 0 at stamina 100 (exact base × workload), flat at/above 70 and strictly increasing below (grid 100→0), quadratic ratio asserted analytically, per-minute cap hit exactly (0.0002 × 15 × 1.18 → 0.0035), Medical Centre strictly reducing at every level 0-5 across four stamina points, position ordering cm > st > gk, `rollInjury` deterministic per seed with a 1-draw miss budget, distribution over 50,000 seeded draws printed and band-locked (knock ~0.55 / muscle ~0.35 / serious ~0.10 / mean matchesOut ~1.93, bands ~13σ wide), fresh-install v12 test and the v11→v12 upgrade test preserving every pre-existing row byte-for-byte (raw sqlite3 snapshot before/after) with AI rows carrying injuries through the same columns. Full `flutter test` + `flutter test tool/simulation_report_test.dart` → see the scoreboard line below.
- **Scoreboard (final):** `flutter analyze` → No issues found. Full `flutter test` → **736 passed / 0 failed, ALL GREEN**. `flutter test tool/simulation_report_test.dart` → deterministic replay PASS. Migration files 13/13 (injury + stamina + all three database/schema suites). The first full run surfaced 3 fixture failures, all the same mechanism: the v10/v11 migration fixtures dropped only the tables their OWN steps touched, leaving `owned_players`/`ai_players` at CURRENT shape — my v12 `addColumn`s then hit duplicate columns (and one stale `schemaVersion == 11` assertion). Fixed by presenting those tables at their real pre-v12 shape inside the fixtures and updating the version assertion (the v10 fixture's fresh-schema test now also asserts the injury columns exist) — no production code touched for this.
- **Concerns / assumptions:** (1) the risk constants are pre-balance placeholders (GDD rule 14) — the real-rate calibration gate is T-0054's engine calibration group; expected per-match injury volume at shipped constants ≈ 0.2/team/match in the exhausted band (T-0054 will tune with the owner). (2) The two pre-existing season migration fixtures were updated to simulate a real pre-v12 install (they previously rewound only the tables their own steps touched — a latent unfaithfulness my v12 step exposed); their assertions about v10/v11 behavior are unchanged. (3) No UI/l10n strings by design (T-0056); size impact = one pure module + four nullable columns.

## Review Log
