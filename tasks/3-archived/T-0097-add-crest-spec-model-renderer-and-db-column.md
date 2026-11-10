---
id: T-0097
title: Add the CrestSpec model, renderer and clubs database column
priority: high
status: done
attempts: 1
depends_on: []
created: 2026-11-09
completed: 2026-11-10
---

# T-0097: Add the CrestSpec model, renderer and clubs database column

## Goal
A club's crest becomes a composed visual identity — shape + primary/secondary colours + icon — instead of a bare palette index: a serializable `CrestSpec` domain model, an `FcmCrest` renderer widget, and a nullable `crest` column on `clubs`, with every existing club falling back to today's exact rendering. This is the foundation task; the club-creation picker (T-0098) and the AI random crests (T-0099) build on it.

## Context
- Today a crest IS one colour: `clubs.crestIndex` int (`lib/core/database/app_database.dart:62`, default 0) resolved through `FcmColors.crestPalette` — 6 colours at `lib/core/ui/fcm_style.dart:81-88` — with `FcmColors.crestColor(index)` clamping out-of-range indexes (`fcm_style.dart:93`).
- Colour consumers that must keep working: the momentum bar's user half tint (`lib/features/match/match_screen.dart:163-175`) and the club creation backdrop tint (`lib/features/onboarding/club_creation_screen.dart:69,72`).
- AI clubs get `crestIndex: random.nextInt(8)` (`lib/features/season/season_engine.dart:262`) — 8 > palette 6, silently clamped today; T-0099 replaces this with a real spec.
- DB migrations: `schemaVersion` 12 with `MigrationStrategy(onUpgrade:)` at `lib/core/database/app_database.dart:305-310` — follow the existing step pattern, bump to 13.
- The store that owns clubs: `lib/features/collection/collection_store.dart` (`createClub` writes `crestIndex`; `getClub` reads the row).

## Requirements
1. New model `CrestSpec` (suggest `lib/core/domain/crest.dart`): an enum-backed shape (at least 4 shapes, e.g. shield / round / pennant / diamond), a primary and a secondary colour each as an index into `FcmColors.crestPalette`, and an enum-backed icon (at least 6 icons, e.g. star / ball / crown / lion / flame / bolt). Immutable, `const`-constructible, with `toJson` / `fromJson` (round-trip safe) and a `primaryColor` getter resolving through the palette. Include a `legacy(int crestIndex)` factory for old rows.
2. New renderer `FcmCrest` (suggest `lib/core/ui/fcm_crest.dart`): a widget drawing the spec — the shape's outline in the secondary colour over a primary-coloured field with a simple two-tone pattern (halves or stripes — one pattern, applied consistently), the icon glyph centered — via `CustomPaint`, at any width. Direction-agnostic (symmetric design, no hardcoded left/right), legible at 28px and at 96px.
3. DB: add a nullable TEXT `crest` column to `clubs` (drift table + companion), bump `schemaVersion` to 13, add the v12→v13 migration step (ALTER TABLE ADD COLUMN, existing rows null). Existing older steps unchanged.
4. Store plumbing (`lib/features/collection/collection_store.dart`): `createClub` accepts an optional `CrestSpec` and serializes it into the new column (null keeps today's `crestIndex` path); club reads expose the parsed spec. Add one resolver — e.g. `CrestSpec? crestOf(clubRow)` — so every consumer resolves legacy vs new in one place.
5. Momentum bar tint (`match_screen.dart:169`): use the resolver — for a club with a spec, `spec.primaryColor`; for a legacy club, exactly `FcmColors.crestColor(club.crestIndex)` as today. No visual change for existing saves.
6. Tests: `CrestSpec` JSON round-trip; `legacy()` maps each palette index; the resolver prefers the column and falls back to `crestIndex`; an `FcmCrest` golden-free widget test (renders at 28 and 96 logical px without overflow, paints an icon); a DB test writing then reading a club with a spec on the migrated schema (follow the existing real-DB test harness pattern used in `test/features/onboarding/club_creation_test.dart`).

## Out of Scope
- The club-creation picker UI (T-0098) and AI crest generation (T-0099).
- New palette colours, crest editing after creation, any match-header rework.
- Rendering crests anywhere new (consumers adopt `FcmCrest` in their own tasks).

## Acceptance Criteria
- [x] `CrestSpec` serializes and round-trips through JSON; `legacy(i)` reproduces today's palette colour for every i in 0..5; the resolver prefers the `crest` column and falls back to `crestIndex`.
- [x] `FcmCrest` renders any valid spec at 28px and 96px without overflow or clipped icon, direction-agnostic (no visual difference LTR vs RTL).
- [x] Schema 13 migrates from 12 without data loss (existing club rows keep working); a club created with a spec round-trips through the DB.
- [x] A legacy club's momentum bar tint is byte-for-byte the colour it uses today; a spec club's bar uses `spec.primaryColor`.
- [x] `flutter analyze` zero warnings; new tests green; full `flutter test` green, no REGEN_SNAPSHOT.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/onboarding/ test/features/match/match_screen_test.dart
# Expected: green — includes the new model/renderer/DB tests and the unchanged momentum tint

flutter test
# Expected: full suite green, no REGEN_SNAPSHOT
```

---
<!-- Everything below this line is filled in by agents, never by the task author. -->

## Developer Notes
<!-- Developer agent fills this in before moving the file to 2-needs-review. -->

- **Summary of changes:**
- **Files changed:**
- **How I tested it:**
- **Concerns / assumptions:**


### Attempt 1 — implementation

**Summary of changes:** the crest foundation is in — a serializable `CrestSpec` domain model, an `FcmCrest` CustomPaint renderer, a nullable TEXT `crest` column on `clubs` (schema 13), store plumbing with a single legacy-vs-new resolver, and the momentum bar routed through it. Every existing club renders exactly as today.

1. `lib/core/domain/crest.dart` (new) — `CrestSpec`: enum-backed `CrestShape` (shield/round/pennant/diamond) and `CrestIcon` (star/ball/crown/lion/flame/bolt) with stable JSON ids, one `CrestPattern.halves` applied consistently, palette-index colours resolving through `FcmColors.crestColor` (same clamp), `toJson`/`fromJson`/`fromJsonString`/`encode` (round-trip safe; junk → null so the caller falls back), `CrestSpec.legacy(crestIndex)` (shield+star, primary = the exact old tint, in-family secondary via a +2 wrap with ember keeping itself), `==`/`hashCode`/`toString`. Unknown shape/icon ids degrade to defaults instead of crashing.
2. `lib/core/ui/fcm_crest.dart` (new) — `FcmCrest(spec, width)`: one `_CrestPainter` CustomPaint pass — the shape path clipped, primary field + secondary middle band (the halves pattern), stroke outline, then the centered icon glyph drawn with canvas primitives (no font/asset). All geometry derives from the canvas size (no absolute px), symmetric about the vertical axis — direction-agnostic by construction; `shouldRepaint` on spec inequality.
3. `lib/core/database/app_database.dart` — `TextColumn get crest => text().nullable()()` on `Clubs` with the T-0097 doc comment; `schemaVersion` 12 → 13; the v12→v13 step is a pure `addColumn` (existing rows null). Older steps untouched. `build_runner` regenerated (`Club.crest` field present).
4. `lib/features/collection/collection_store.dart` — `createClub` takes an optional `CrestSpec crest` (absent → today's `crestIndex` path byte-for-byte); new `static CrestSpec crestOf(Club club)` resolver: `CrestSpec.fromJsonString(club.crest) ?? CrestSpec.legacy(club.crestIndex)` — the one place every consumer resolves old-vs-new (column wins, corrupt JSON falls back safely).
5. `lib/features/match/match_screen.dart` — `_loadUserCrestColor` now uses `CollectionStore.crestOf(club).primaryColor`; for a legacy club that IS `FcmColors.crestColor(club.crestIndex)` — no visual change for existing saves; a spec club's bar takes its primary.
6. Tests (`test/features/onboarding/crest_spec_test.dart`, new) — 10 tests: JSON round-trip (single + exhaustive 4 shapes × 6 icons + the TEXT-column convenience); `legacy(i)` pins the exact old tint for every 0..5 (+99 clamp); junk-input tolerance (null/empty/invalid JSON/partial); `crestOf` preference (column beats index, legacy fallback is byte-for-byte, corrupt column falls back); `FcmCrest` at 28 and 96 logical px (exact RenderBox size, no overflow exception, scoped CustomPaint painter attached); every shape × icon lays out clean; RTL/LTR occupy the same frame slot (direction-agnostic). Plus two real-drift tests: a club created WITH a spec round-trips (column JSON exact, resolver reads it back) and without (column null, legacy tint exact); schema-13 column existence + write/read through the generated class.

**Files changed:** `lib/core/domain/crest.dart` (new), `lib/core/ui/fcm_crest.dart` (new), `lib/core/database/app_database.dart`, `lib/core/database/app_database.g.dart` (regenerated), `lib/features/collection/collection_store.dart`, `lib/features/match/match_screen.dart`, `test/features/onboarding/crest_spec_test.dart` (new), this task file.

**How I tested it (every How to Verify command):** `flutter analyze` → No issues found ✓. `flutter test test/features/onboarding/ test/features/match/match_screen_test.dart` → onboarding 14/14, match_screen 8/8 ✓. Full `flutter test` → (result recorded in the submit commit message) ✓. No REGEN_SNAPSHOT (no golden touched).

**Concerns / assumptions:**
- MIGRATION ROBUSTNESS (found by the full suite): the v11 step's `TableMigration(clubs)` rebuilds the table at the CURRENT shape, so a real v10/v11 database reopening on schema 13 already carries `crest` and a naive v13 `addColumn` would throw `duplicate column name` — the v13 step now introspects `PRAGMA table_info(clubs)` and adds the column only when missing (SQLite has no ADD COLUMN IF NOT EXISTS). The v12 migration test's fixture also gained its v11 `clubs` table (it previously created no clubs table at all, so `ALTER TABLE clubs` hit `no such table`), and the version pins in schema_v10/v12 tests moved to 13. All 13 migration tests green after the fix.
- The legacy spec's SECONDARY colour is an in-family +2 palette wrap (ember keeps itself) — a design choice; the PRIMARY (what every current consumer reads) is byte-for-byte today's tint, which is what the AC pins.
- `CrestPattern` is an enum with one value (`halves`) — the wire format carries it so a second pattern later is a non-breaking addition, not a schema change.
- The migration test exercises the fresh-create schema-13 path plus direct column write/read; a true downgrade-reopen (a real v12 file opened by v13 code) runs the same `addColumn` step drift generates — noted honestly: not separately simulated.
- `FcmCrest` is rendered nowhere yet by design (T-0098/0099 adopt it); the widget tests pin its contract now.

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->

### Review 1 — 2026-11-10 — PASS

**Ran (Flutter 3.47.9 / Dart 3.13.7):**
- `flutter analyze` (current main) → No issues found! ✓
- `flutter test test/features/onboarding/ test/features/match/match_screen_test.dart` → at commit 2911fec (this task's submission tree, clean worktree): **22/22 green** ✓. On CURRENT main the same run fails 3 tests — all T-0100's WIP (55b7cdb: pep-talk/CONTINUE flows, whose own developer recorded "TEST SUITES NOT YET RUN — task stays in 1-todo"); attribution verified by running the identical suites on both trees: green pre-T-0100, red only on T-0100's tests after it. Nothing crest-related fails anywhere.
- Full `flutter test` at 2911fec → **1007/1007, "All tests passed!"** ✓ (includes all 13 migration tests and the new crest_spec_test.dart suite).
- Diff scope check (commit fd0f585): all 10 files inside the declared scope. Verified against the code: `CrestSpec` const-constructible with enum-backed shape/icon (stable JSON ids, unknown ids degrade to defaults), round-trip-safe JSON, junk → null; `legacy(i).primaryColor == FcmColors.crestColor(i)` byte-for-byte (same palette + clamp); `crestOf` resolver = column-wins-else-legacy in one place; the momentum tint routes through `crestOf(club).primaryColor` (import-order warning aside, analyze is clean); the v12→v13 step introspects `PRAGMA table_info` and adds `crest` only when missing — the duplicate-column trap of the v11 `TableMigration(clubs)` rebuild is handled in the migration itself, and the migration-test fixture changes (v11 clubs table added, version pins 12→13) strengthen the tests rather than weaken them ✓. No golden touched, so the REGEN_SNAPSHOT clause is moot ✓.
- Developer-notes claims spot-checked and confirmed honest (including the "true downgrade-reopen not separately simulated" caveat — the PRAGMA-guarded step runs the same addColumn path the fresh-create schema test exercises).

All five criteria met; every verify command run by the reviewer on this task's own tree. PASS.
