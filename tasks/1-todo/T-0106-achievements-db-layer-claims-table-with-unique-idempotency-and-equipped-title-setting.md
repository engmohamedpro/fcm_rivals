---
id: T-0106
title: Achievements DB layer — claims table with UNIQUE idempotency + equipped-title setting (schema v14)
priority: high
status: todo
attempts: 0
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
<!-- Developer agent fills this in before moving the file to 2-needs-review. -->

- **Summary of changes:**
- **Files changed:**
- **How I tested it:**
- **Concerns / assumptions:**


## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
