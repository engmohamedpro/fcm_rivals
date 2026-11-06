---
id: T-0044
title: Extract the pre-match route out of season_screen.dart
priority: medium
status: todo
attempts: 0
depends_on: []
created: 2026-11-06
completed:
---

# T-0044: Extract the pre-match route out of season_screen.dart

## Goal
Bring `lib/features/season/season_screen.dart` (803 lines — 3 over the line) under the ~800-line convention by moving the `PreMatchRoute` widget family into its own file, with zero behaviour change.

## Context
Measured on main `b2c0a27` (2026-11-06): `season_screen.dart` = 803 lines. Top-level map:
- Screen shell + state: `SeasonScreen` :20, `_SeasonScreenState` :27-594, `_Hdr` :595, `_StandingRow` :615-720 (≈720 lines after extraction).
- Route family: `PreMatchRoute` :721, `PreMatchRouteState` :739-803 (≈83 lines) — a ConsumerStatefulWidget route living inside a screen file, which also cuts against the typed-routing convention (`AppRoutes` owns full-screen routes, README "Route table" row).
Extraction drops the screen to ≈720 lines. Pure relocation, no behaviour change.

## Requirements
1. Create `pre_match_route.dart` holding `PreMatchRoute` and `PreMatchRouteState` verbatim; `season_screen.dart` imports it. Pure relocation, no behaviour change.
2. Every resulting file ≤800 lines; `flutter analyze` clean; full `flutter test` green with zero test edits.

## Out of Scope
- Migrating `PreMatchRoute` into `AppRoutes` (route-table refactor) — that is a separate decision; this task only relocates verbatim.
- Splitting `_StandingRow`/standings widgets or any other file.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes with zero test edits
- [ ] EN/AR localization complete and RTL verified where applicable
- [ ] No performance or application-size regression
- [ ] Every resulting file ≤800 lines
- [ ] `README.md` architecture table row for the season UI updated for the new module file

## How to Verify
```bash
wc -l lib/features/season/season_screen.dart lib/features/season/pre_match_route.dart
flutter analyze
flutter test test/features/season/ test/features/match/pre_match_screen_test.dart
flutter test
```
Expected: every listed file ≤800 lines; analyzer clean; season and pre-match suites and full suite green with zero test edits.

---

## Developer Notes

## Review Log
