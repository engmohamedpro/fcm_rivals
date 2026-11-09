---
id: T-0097
title: Add the CrestSpec model, renderer and clubs database column
priority: high
status: todo
attempts: 0
depends_on: []
created: 2026-11-09
completed:
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
- [ ] `CrestSpec` serializes and round-trips through JSON; `legacy(i)` reproduces today's palette colour for every i in 0..5; the resolver prefers the `crest` column and falls back to `crestIndex`.
- [ ] `FcmCrest` renders any valid spec at 28px and 96px without overflow or clipped icon, direction-agnostic (no visual difference LTR vs RTL).
- [ ] Schema 13 migrates from 12 without data loss (existing club rows keep working); a club created with a spec round-trips through the DB.
- [ ] A legacy club's momentum bar tint is byte-for-byte the colour it uses today; a spec club's bar uses `spec.primaryColor`.
- [ ] `flutter analyze` zero warnings; new tests green; full `flutter test` green, no REGEN_SNAPSHOT.

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

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
