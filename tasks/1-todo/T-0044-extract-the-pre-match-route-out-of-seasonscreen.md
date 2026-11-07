---
id: T-0044
title: Extract the pre-match route out of season_screen.dart
priority: medium
status: needs-review
attempts: 1
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
- **Summary of changes:** Extracted the pre-match route family — doc + `PreMatchRoute` + `PreMatchRouteState`, original lines 715-803 — verbatim into a new `pre_match_route.dart` (106 lines), and rewrote `season_screen.dart` (803 → 713 lines) to keep the screen shell and state. Relocation by a one-time line-slice script kept outside the repo with a multiset verifier proving every original code/doc line lands exactly once; the only new content is the route-file header and the screen's plumbing lines. **Zero code renames or edits.**
- **Import plumbing decisions (flag for the reviewer):** (1) `season_screen.dart` **re-exports** `pre_match_route.dart` (no import — the screen body never references `PreMatchRoute` directly; it kicks off the matchday build-up through `AppRoutes.preMatch(...)`). The export is required because `lib/app/routes.dart` obtains `PreMatchRoute` via `import '../features/season/season_screen.dart' show PreMatchRoute;` — without the re-export the route table breaks; with it, zero consumer edits. This matches the T-0043 pattern and keeps the AppRoutes migration (explicitly out of scope here) free to move the route later. (2) The screen's now-orphaned imports were pruned: `../match/match_forecast.dart show PreMatchData` dropped entirely, and the `../match/pre_match_screen.dart` show clause narrowed to `PreMatchTacticSelection` (the screen still hands the selection back at kick-off); `PreMatchScreen` the widget now lives only in the route file. Both prunes verified by symbol grep over the remaining screen body.
- **Files changed:** `lib/features/season/season_screen.dart` (now 713 lines, re-exports the route), `lib/features/season/pre_match_route.dart` (new, 106 lines), `README.md` (new "Season UI" architecture-table row naming both module files and the re-export — no season UI row existed before).
- **How I tested it:** Baseline on the unmodified tree: `flutter analyze` No issues found + `flutter test test/features/season/ test/features/match/pre_match_screen_test.dart` → `+63: All tests passed!` exit 0. After the extraction: the `wc -l` gate lists 713/106, both ≤800; `flutter analyze` No issues found (import pruning exact — no unused, no missing); the same focused run → `+63: All tests passed!` exit 0 (identical count, zero test edits); full `flutter test` → `+709: All tests passed!` exit 0 (~5m25s) — identical test count to the baseline, zero test edits.
- **Concerns / assumptions:** None beyond the two plumbing decisions above — both were forced by the zero-test-edit / zero-consumer-edit constraints and are documented. None blocking.

## Review Log
