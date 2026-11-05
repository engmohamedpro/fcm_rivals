# App structure: split the match report models from commentary construction

- Feature: app-structure
- Type: Refactor
- Priority: Minor
- Created: 2026-11-05
- Status: OPEN
- Completed on: -

## Context
One of ten follow-ups carved out of `2026-11-04_app-structure_remaining-oversized-files` (set to SPLIT 2026-11-05 per the README §1 one-file-per-task rule). The README's ~800-line split threshold (README.md:72-74) is contradicted by `lib/features/match/match_report.dart` (1,026 lines on 2026-11-05). Split it following the proven `fcm_widgets.dart` barrel pattern so consumer imports never churn.

## Investigation & Evidence
- Investigation: `match_report.dart` measured 1,004 lines at task creation (2026-11-04), 1,026 on 2026-11-05; commentary kinds/lines and their building share the file with the stats/rating models (anchors at creation: `CommentaryKind`:17, `CommentaryLine`:44, `TeamMatchStats`:75, `PlayerMatchRating`:358).
- Root cause / technical justification: commentary construction lives with the report data models; the god-files review split only its two in-scope targets.
- Affected files/components: `lib/features/match/match_report.dart`
- Evidence: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` lists the file on main.
- Expected benefit / necessity: makes the README convention real; measurable target — every resulting file ≤800 lines.
- Dependencies / side effects: report models are derived from the same event records as the commentary; the move must not change derived values; report tests are the regression net.

## Reproduction Steps
Not applicable.

## Task
- [ ] Split the match report models from commentary construction | Where: `lib/features/match/match_report.dart` (1,026 lines on 2026-11-05; anchors above) | Expected: commentary kinds/lines and their building move to `commentary.dart`; stats/rating models stay; `pass_completion_stats_test.dart` and report tests green with zero test edits.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified where applicable
- [ ] No performance or application-size regression
- [ ] Every resulting file ≤800 lines (excluding generated `*.g.dart`)
- [ ] `pass_completion_stats_test.dart` and the report suites green with zero test edits

## Developer Notes
<Implementation summary, files changed, exact test commands/results, and rejection reason/evidence if applicable. Implement this task only, create one task-specific commit, and push it before starting another task.>

## Reviewer Verification
<Reviewer records verification date, tested commit hash, checks performed, results, and remaining limitations. Do not add personal names.>

## Links
- Depends on: None
- Follows: `2026-11-04_app-structure_remaining-oversized-files`
- Follow-up: None

## Amendments
<Reviewer-owned, append-only. Add dated entries correcting the task's target or mechanism; never rewrite the original task text.>
