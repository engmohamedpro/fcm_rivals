---
id: T-0044
title: Extract the pre-match route out of season_screen.dart
priority: medium
status: done
attempts: 1
depends_on: []
created: 2026-11-06
completed: 2026-11-06
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
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated; full `flutter test` suite passes with zero test edits
- [x] EN/AR localization complete and RTL verified where applicable
- [x] No performance or application-size regression
- [x] Every resulting file ≤800 lines
- [x] `README.md` architecture table row for the season UI updated for the new module file

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

### Review 2026-11-06, attempt 1: PASS
- Independent verbatim-relocation check (multiset of all lines, original `c1e4e53:lib/features/season/season_screen.dart` vs. the HEAD screen + `pre_match_route.dart`): zero code lines changed. Only-in-original = exactly the original two-line wide `pre_match_screen.dart` import; only-in-new = the route-file header (doc/`library;`/imports), the screen's `export 'pre_match_route.dart';`, the screen's narrowed single-line import (`show PreMatchTacticSelection`) and the route file's wide single-line import — i.e. the declared import re-flow and nothing else.
- Verified the undeclared-by-multiset detail: the screen's `match_forecast.dart show PreMatchData` import is character-identical between the original (line 10) and the route file (line 14), so it cancels out of the multiset — it moved with the four `PreMatchData` usage lines, exactly as the developer stated ("dropped from the screen" = dropped from the screen's import set, re-homed in the route file).
- The flagged re-export decision is accepted: `lib/app/routes.dart:29` obtains `PreMatchRoute` via `import '../features/season/season_screen.dart' show PreMatchRoute;`, so the screen-body never referencing the widget is consistent with export-only plumbing; dropping the export would break the route table and force consumer edits. Matches the T-0043 pattern and keeps the AppRoutes migration (out of scope) free.
- Ran: `wc -l` → screen 713 / route 106, both ≤800.
- Ran: `flutter analyze` (Flutter 3.47.9 stable / Dart 3.13.7, README pin) → No issues found.
- Ran: `flutter test test/features/season/ test/features/match/pre_match_screen_test.dart` → `+63: All tests passed!`.
- Ran: `flutter test` → `+709: All tests passed!`, exit 0 — identical count to the archived baseline; the T-0044 diff (`c1e4e53..37c7c59`) touches no `test/` or `tool/` file, so zero test edits confirmed.
- Scope: only the two season lib files + README + this task file changed. README gained the new "Season UI" row naming both module files and the re-export (no season UI row existed before — correct per task AC).
- Notes: no localization strings in the diff and the multiset proves no string literal changed, so the EN/AR criterion is met vacuously; route-table migration of `PreMatchRoute` remains out of scope as the task text states.
