---
id: T-0023
title: Split the match report models from commentary construction
priority: medium
status: done
attempts: 1
depends_on: []
created: 2026-11-05
completed: 2026-11-06
# migrated from: reviews/tasks/2026-11-05_app-structure_split-commentary.md
---

# T-0023: Split the match report models from commentary construction

## Goal
Split match_report.dart so the commentary kinds/lines and their construction live in commentary.dart, with every resulting file at most 800 lines and zero test edits.

## Context
One of ten follow-ups carved out of `2026-11-04_app-structure_remaining-oversized-files` (set to SPLIT 2026-11-05 per the README §1 one-file-per-task rule). The README's ~800-line split threshold (README.md:72-74) is contradicted by `lib/features/match/match_report.dart` (1,026 lines on 2026-11-05). Split it following the proven `fcm_widgets.dart` barrel pattern so consumer imports never churn.

## Investigation & Evidence
- Investigation: `match_report.dart` measured 1,004 lines at task creation (2026-11-04), 1,026 on 2026-11-05; commentary kinds/lines and their building share the file with the stats/rating models (anchors at creation: `CommentaryKind`:17, `CommentaryLine`:44, `TeamMatchStats`:75, `PlayerMatchRating`:358).
- Root cause / technical justification: commentary construction lives with the report data models; the god-files review split only its two in-scope targets.
- Affected files/components: `lib/features/match/match_report.dart`
- Evidence: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` lists the file on main.
- Expected benefit / necessity: makes the README convention real; measurable target — every resulting file ≤800 lines.
- Dependencies / side effects: report models are derived from the same event records as the commentary; the move must not change derived values; report tests are the regression net.

## Requirements
- [x] Split the match report models from commentary construction | Where: `lib/features/match/match_report.dart` (1,026 lines on 2026-11-05; anchors above) | Expected: commentary kinds/lines and their building move to `commentary.dart`; stats/rating models stay; `pass_completion_stats_test.dart` and report tests green with zero test edits.

## Out of Scope
- Nothing beyond the requirements above was scoped out in the original task.

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated; full `flutter test` suite passes
- [x] EN/AR localization complete and RTL verified where applicable (N/A — pure Dart code move, no UI/l10n surface touched)
- [x] No performance or application-size regression (verbatim code move, no logic or dependency changes)
- [x] Every resulting file ≤800 lines (excluding generated `*.g.dart`)
- [x] `pass_completion_stats_test.dart` and the report suites green with zero test edits

## How to Verify
Run the board's standard gates:

```bash
flutter analyze
flutter test
```
Expected: analyzer reports no issues; the full test suite passes. Per-task checks are quoted in Requirements and Developer Notes.

---

## Developer Notes
- Split landed 2026-11-06. New `lib/features/match/commentary.dart` (355
  lines) carries the commentary data model — `CommentaryKind`,
  `CommentaryLine` — and its construction (`generateCommentary`), moved
  VERBATIM from `match_report.dart` (no logic, signature or text
  changes; its only dependency is `match_event.dart`, which supplies
  `MatchEvent`/`MatchSide`/`ShotOutcome`/`ChanceQuality`).
- `match_report.dart` (690 lines) keeps the stats/rating families
  (`TeamMatchStats`, `_momentumPressure`, `computeMomentum`,
  `computeMomentumSeries`, `computeStats`, `MatchStatsReport`,
  `PlayerMatchRating`, `_ratingWeights`, `computePlayerRatings`) and
  re-exports `commentary.dart` following the `fcm_widgets.dart` barrel
  pattern — all 13 consumers (4 lib files incl. `commentary_ticker.dart`
  and `match_simulator.dart`, 9 test files) import `match_report.dart`
  unchanged; zero import churn.
- Verification: `wc -l` → match_report.dart 690, commentary.dart 355
  (both ≤800); `flutter analyze` → No issues found!; targeted suites
  `flutter test test/features/match/pass_completion_stats_test.dart
  test/features/match/commentary_ticker_test.dart
  test/features/match/live_match_ux_test.dart
  test/features/match/match_engine_test.dart` → 56/56 passed.
- Final suite summary line: `flutter test` → `05:22 +709: All tests
  passed!` — 709/709, the same test count as before the split (709 at
  `bc84ea6`), i.e. ZERO test edits, exactly as the task requires.

## Review Log
### 2026-11-06 — board migration
- Migrated from `reviews/` to the `tasks/` board as `T-0023` (was `reviews/tasks/2026-11-05_app-structure_split-commentary.md`, status DONE).
- Awaiting independent verification on the new board.

## Historical Links
- Depends on: None
- Follows: `2026-11-04_app-structure_remaining-oversized-files`
- Follow-up: None

### Review 2026-11-06, attempt 1: PASS
- Ran on main `3f4b86c` (Flutter 3.47.9 stable, fresh clone): `flutter analyze` -> `No issues found!`; `flutter test` -> `+709: All tests passed!` (full suite, zero failures).
- Tactics sweep baseline: 44/44 pinned rows PASS on BOTH pools (`flutter test tool/tactics_tuning_sweep.dart` and `--dart-define=SWEEP_SEEDS_SUITE=true`).
- Determinism harness `flutter test tool/simulation_report_test.dart` green.
- Static: `match_report.dart` 690 / `commentary.dart` 355 lines, both <= 800 as claimed; implementation commit `34a5fed` touches only the two source files + the task file; suite count 709 unchanged = zero test edits.
- All acceptance criteria verified against real behaviour; archived per the reviewer workflow.
