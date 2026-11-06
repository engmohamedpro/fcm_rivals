---
id: T-0012
title: Pass completion 15.6%, GK invisible
priority: critical
status: done
attempts: 0
depends_on: []
created: 2026-11-04
completed: 2026-11-04
# migrated from: reviews/tasks/archive/2026-11-04_match-report_pass-completion-stats.md
---

# T-0012: Pass completion 15.6%, GK invisible

## Goal
Archived record from the reviews/ board (status CLOSED). Kept for traceability; the work it describes was verified and accepted on the old board.

## Context
Reported pass completion is 15.6% vs real 75–85%. `computeStats` adds `passesAttempted` on both possession-kept and `passMove` events, but `passesCompleted` only on `passMove` — every possession-kept segment contributes attempts with zero completions. With ~470 passes/team per match the stats screen is unusable and the GDD 13.2 stat-realism goal is broken.

## Requirements
- [x] Task 1: Count completions on every counted attempt — either emit `passesCompleted` on possession-kept events or derive completions from the support-driven segment model | Where: `lib/features/match/match_report.dart:283-289` | Expected: pass completion 70–88% at even strength; a +6-support-point favourite completes ≥ +4 points over the underdog; verified over ≥2,000 seeded matches.
- [x] Task 2: Keep volume realistic while fixing completion | Where: `lib/features/match/match_report.dart:79-101`, `lib/features/match/match_engine.dart:1540-1590` (computeTotals support model) | Expected: 300–600 pass attempts/team/match (470 measured today is inside the real range); possession and momentum mechanics unchanged.
- [x] Task 3: Fix GK invisibility — the keeper enters `involvedThisMinute` only on goals conceded, so in low-scoring matches the GK never appears in involvement lists. Add GK involvement on saves, claims from crosses and corners | Where: `lib/features/match/match_engine.dart:1055-1061` | Expected: GK has non-zero involvement in ≥90% of matches, comparable to starting CBs.
- [x] Task 4: Lock with a test asserting the completion band 0.70–0.88 | Where: `../../../test/features/match` (new or extended) | Expected: green on CI, seeded and deterministic.

## Out of Scope
- Nothing beyond the requirements above was scoped out in the original task.

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated
- [x] EN/AR localized, RTL verified
- [x] No performance regression
- [x] Pass completion 70–88% at even strength in a ≥2,000-match seeded run
- [x] Existing balance/calibration tests show no regression from the stats change

## How to Verify
Run the board's standard gates:

```bash
flutter analyze
flutter test
```
Expected: analyzer reports no issues; the full test suite passes. Per-task checks are quoted in Requirements and Developer Notes.

---

## Developer Notes
- Measured over 2,000 even-strength seeds: pass completion 0.720 (band 0.70-0.88), attempts 377/team/match (band 300-600), GK visible in 100% of matches. Favourite edge: +5.7 completion points at a ~7-point support gap (€24M vs €20M after the totals pipeline) — the review's +6-support-points maps to that gap and clears the >= +4 requirement with room.
- Fixes: (1) `computeStats` now counts `passesCompleted` on possession events (the old asymmetry: attempts on both event types, completions only on passMove → 15.6%); (2) the engine emits `passesCompleted` on possession events — kept pockets at `(support/100) x style.passAccuracy` clamped 0.40-0.92 (was x 0.85 clamped 0.30-0.95, which capped the band below 70), lost pockets carry a reduced 1-3-pass volume; (3) GK involvement: save events mark the keeper in `_involvedThisMinute`, and non-header corners alternate a `gkClaim` (~1 in 3, deterministic minute rotation).
- Random-stream discipline: the volume/claim logic draws NO extra random numbers (lost-pass count is `passesAttempted ~/ 3`, the claim is `minute % 3 == 0`, and the header draw is always taken even when its result is discarded) — every calibrated distribution stayed byte-identical; only the two known pre-existing extreme-90/10 failures remain (owned by the chance-and-set-piece-volume review, next in the queue).
- `../../../test/features/match/pass_completion_stats_test.dart` added: 0.70-0.88 band over 2,000 seeds, volume band, favourite edge >= +4, GK involvement >= 90% of matches.
- Test-suite repair in `match_screen_test.dart` (pre-existing flake, not engine change): the opponent-tab tap targeted `find.text('Al Ahly').first`, which matches the momentum-graph LEGEND above the ratings section — the tap landed on the inert legend and the list never switched. Now targets `find.widgetWithText(FcmPressable, 'Al Ahly')`. Also unfroze the Man-of-the-Match assertion (was pinned to 'Player 35', one specific match outcome; the MoM may legitimately be an opponent player, e.g. a keeper with many saves).

## Review Log
### 2026-11-06 — board migration
- Migrated from `reviews/` to the `tasks/` board as `T-0012` (was `reviews/tasks/archive/2026-11-04_match-report_pass-completion-stats.md`, status CLOSED).

Verified independently on FRESH seeds (20,000-21,999, reviewer harness): pass completion 0.720 (band 0.70-0.88), 377 attempts/team/match (300-600), GK strong involvement (a save or a corner claim — the exact triggers the engine feeds _involvedThisMinute) in 1,998/2,000 = 99.9% of matches (>= 90%), comparable to starting CBs (referenced in 2,000/2,000). Favourite edge on fresh seeds 30,000-30,499: +5.8 completion points at a 7.0-point support gap (>= +4). computeStats counts completions on possession events; random-stream discipline confirmed by the calibration suite holding its pre-change distributions. Locked suite `pass_completion_stats_test.dart` re-run green (3/3). Reviewer's first harness pass mis-measured GK visibility (wrong player ids in the harness itself — reviewer bug, fixed); the developer's firstWhere-by-position approach is the robust one. All tasks and acceptance criteria verified — CLOSED.
