---
id: T-0106
title: Achievements DB layer — claims table with UNIQUE idempotency + equipped-title setting (schema v14)
priority: high
status: needs-review
attempts: 1
depends_on: [T-0105]
created: 2026-11-10
completed:
---

# T-0106: Achievements DB layer — claims table with UNIQUE idempotency + equipped-title setting (schema v14)

## Goal
Claiming an achievement tier is atomic, idempotent and crash-safe at the DATABASE level: a UNIQUE constraint makes double-claims (double taps, back-navigation replays, process kill + retry) structurally impossible, and the user's equipped title persists — the data foundation T-0108's claim pipeline and T-0114's profile showcase stand on.

## Context
- The repo's economy invariant (FR-016, `lib/core/database/coin_ops.dart`): every coin movement is a relative, guarded, ledgered SQL statement inside one transaction. Pack opening already survived the "cannot be re-rolled by back-navigation or double taps" requirement using DB-level guarantees — claims get the same treatment: the DB, not the UI flow, is the idempotency owner.
- `AppDatabase` is at `schemaVersion = 13` (`lib/core/database/app_database.dart:311`) with a step-wise `MigrationStrategy`. Schema v12 (injury columns) is the most recent column-addition precedent; v5's `TableMigration` rebuild is the table-rebuild precedent. This task adds v14: one new table + one nullable column — the safest possible migration shape.
- Tier keys: a claim identifies (clubId, achievementId, tierKey) where tierKey is the tier's THRESHOLD value as a canonical string (e.g. `'16'`), not the tier index — thresholds are the stable identity across catalog re-ordering; indexes shift when a developer inserts a tier, thresholds do not.
- The equipped title lives on `UserSettings` (single-row table, `lib/core/database/app_database.dart:279`) as a nullable text column holding a `TitleDefinition.id` from T-0105's registry. NULL = no title equipped. FK-less by design like the rest of the schema (text ids, validated in the domain layer — T-0114 validates and falls back gracefully on unknown ids, e.g. a catalog entry renamed between versions).

## Requirements
1. `lib/core/database/app_database.dart` — new `AchievementClaims` table: `id` autoIncrement, `clubId`, `achievementId` text, `tierKey` text, `rewardCoins` int (the amount actually paid, recorded for audit), `titleGranted` text nullable, `claimedAt` dateTime. UNIQUE constraint on (`clubId`, `achievementId`, `tierKey`) — drift's `customConstraint` or a unique index; whichever the schema DSL supports cleanly.
2. Same file — `UserSettings.equippedTitle` nullable text column; `schemaVersion` 13 → 14; migration step `if (from < 14)` creating the table and adding the column (both additive — no rebuild).
3. `lib/features/achievements/achievement_claims_repository.dart` — thin repository over the table: `claimsForClub(int clubId)` (typed rows), `hasClaim(clubId, achievementId, tierKey)`, `insertClaim(...)` — NO coin logic here (that is T-0108's transaction), `getEquippedTitle()` / `setEquippedTitle(String? titleId)` on the settings row (upsert following however the existing settings writes are done).
4. `test/features/achievements/claims_repository_test.dart` — in-memory `NativeDatabase.memory()` suite: insert + read round-trip; the idempotency lock (inserting the same (club, achievement, tierKey) twice throws/ignores per the constraint's documented behavior — assert the exact behavior you implement); different clubs claim the same tier independently; equipped title set → get → set null round-trip.
5. Migration test following the repo's existing migration-test pattern (find the v12/v13 precedent under `test/`): a database written at v13 with pre-existing rows (clubs, settings, match results) upgrades to v14 without data loss, and a fresh v14 create works. If no programmatic v13 fixture helper exists, construct one with drift's schema utilities the way the repo already does — do NOT hand-wave this requirement away; a save-eating migration is the worst failure this feature could ship.

## Out of Scope
- The claim transaction itself (coins + claim in one transaction) — T-0108.
- Progress derivation, providers, UI.
- Any catalog content change (T-0105 owns the catalog).

## Acceptance Criteria
- [ ] UNIQUE(clubId, achievementId, tierKey) enforced at the DB level — the test proves a duplicate insert cannot land.
- [ ] v13 → v14 migration preserves every pre-existing row; fresh installs create v14 cleanly.
- [ ] `flutter analyze` zero warnings; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/achievements/
# Expected: green

flutter test
# Expected: full suite green (the schema bump must not break any existing db test)
```

---

<!-- Everything below this line is filled in by agents, never by the task author. -->

## Developer Notes

- **Summary of changes:**
  - `lib/core/database/app_database.dart` — schema 13 → 14: new
    `AchievementClaims` table (clubId, achievementId, tierKey as the
    THRESHOLD canonical string — stable identity across catalog
    re-ordering, rewardCoins audit, titleGranted nullable, claimedAt)
    with drift's `uniqueKeys` override: UNIQUE(clubId, achievementId,
    tierKey) — the DB-level double-claim refusal. `UserSettings
    .equippedTitle` nullable text. Migration step `if (from < 14)`
    creates the table + adds the column, BOTH existence-guarded on
    PRAGMA table_info exactly like the v13 crest precedent — a
    discovered necessity: the season fixtures rewind SOME tables to
    old shapes while others stay current-shape, and SQLite has no
    ADD COLUMN IF NOT EXISTS. build_runner regenerated
    app_database.g.dart (drift 2.31).
  - NEW `lib/features/achievements/achievement_claims_repository.dart`
    — the thin read/write layer: claimsForClub (newest first),
    hasClaim (advisory — the constraint is the law), insertClaim (raw,
    throws on duplicates: drift surfaces the SQLite UNIQUE violation;
    T-0108 will call it INSIDE its coin transaction), and the
    equipped-title settings upsert following the user_settings_store's
    exact insert-then-update pattern (row id 1, surgical column write
    — a title change never clobbers matchSpeed).
  - Tests: NEW `claims_repository_test.dart` (6: round-trip newest-
    first, THE IDEMPOTENCY LOCK — duplicate triple insert throws with
    'UNIQUE constraint failed' in the message and the table holds
    exactly one row, per-club independence, same-club different-tier,
    equipped-title insert-path/update-path/null-clear round-trip on a
    fresh DB, coexistence with a pre-existing settings row) + NEW
    `schema_v14_migration_test.dart` (fresh v14 with the UNIQUE key
    live from minute one; v13→v14 hand-crafted raw-sqlite fixture
    with club/settings/ledger rows upgrading byte-for-byte, snapshot
    before/after, new writes landing beside the preserved rows).
  - Updated the older schema tests to the bump, each with the reason
    in place: v12 test's fresh-install pin 13→14 (its own comment
    tradition), v12's v11 fixture gained the faithful user_settings
    table + row (v11 installs have had it since v8 — the v14 ALTER
    found the gap), v10 test's pin 13→14.
- **Files changed:** lib/core/database/app_database.dart,
  lib/core/database/app_database.g.dart (generated),
  lib/features/achievements/achievement_claims_repository.dart (new),
  test/features/achievements/claims_repository_test.dart (new),
  test/core/database/schema_v14_migration_test.dart (new),
  test/core/database/schema_v12_migration_test.dart,
  test/features/season/schema_v10_migration_test.dart.
- **How I tested it:** `flutter analyze --no-pub` — zero new issues
  (1 pre-existing baseline warning fcm_crest.dart:269). Task files:
  achievements + core/database 29/29 green (catalog 15 + repository 6
  + v14 migration 2 + v12 2 + coin_ops 4). Schema-fixture files
  (season v10/v11) 15/15 green. DB-heavy sweep (collection+season+
  core): 220 pass, the ONLY failure the pre-existing
  season_live_match_flow (stash-verified on the clean tree in earlier
  sessions — untouched by this task: no engine/match-code change).
  match+squad sweep: 497 pass with the same pre-existing
  tactic_slider_row (2) + squad_view T-0064 family + the same season
  flow — all verified pre-existing before this epic started.
- **Concerns / assumptions:** (1) Drift's UNIQUE violation surfaces
  as a generic Exception whose toString carries 'UNIQUE constraint
  failed' — the test pins THAT string (the stable cross-version
  surface); T-0108's pipeline should catch broadly and let the
  transaction semantics decide, not string-match. (2) The v14 step's
  existence guards make a partial-shape database (fixture or future
  bug) upgrade safely instead of crashing — deliberate defensive
  mirroring of the v13 precedent, not fixture-pandering: a real v13
  database never has the table, a real fresh install runs onCreate.
  (3) claimedAt stores second precision (drift's integer DateTime
  mode) — tests aligned to second boundaries; sub-second ordering
  within one second falls to the id AUTOINCREMENT.


## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
