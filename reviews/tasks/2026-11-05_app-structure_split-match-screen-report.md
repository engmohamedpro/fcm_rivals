# App structure: extract the report view and ratings panels out of MatchScreen

- Feature: app-structure
- Type: Refactor
- Priority: Minor
- Created: 2026-11-05
- Status: OPEN
- Completed on: -

## Context
One of ten follow-ups carved out of `2026-11-04_app-structure_remaining-oversized-files` (set to SPLIT 2026-11-05 per the README §1 one-file-per-task rule). The README's ~800-line split threshold (README.md:72-74) is contradicted by `lib/features/match/match_screen.dart` (1,296 lines on 2026-11-05). Split it following the proven `fcm_widgets.dart` barrel pattern so consumer imports never churn.

## Investigation & Evidence
- Investigation: `match_screen.dart` measured 1,296 lines at task creation (2026-11-04) and on 2026-11-05; the live-match shell shares one file with the post-match report UI (anchors at creation: `_RecoveryOption`:753, `MatchReportView`:824, `_RatingsTabs`:1136, `_RatingsPanel`:1205).
- Root cause / technical justification: the report view, ratings tabs/panels and recovery widgets live inside the screen file; the god-files review split only its two in-scope targets.
- Affected files/components: `lib/features/match/match_screen.dart`
- Evidence: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` lists the file on main.
- Expected benefit / necessity: makes the README convention real; measurable target — every resulting file ≤800 lines.
- Dependencies / side effects: widget move only; screen behaviour and widget tree must stay identical; the three named suites are the regression net.

## Reproduction Steps
Not applicable.

## Task
- [ ] Extract the report view and ratings panels out of MatchScreen | Where: `lib/features/match/match_screen.dart` (1,296 lines; anchors above) | Expected: `match_report_view.dart` owns `MatchReportView`, the ratings tabs/panels and the recovery widgets; `match_screen.dart` keeps the live-match shell; screen behaviour and widget tree identical — `match_screen_test.dart`, `live_match_ux_test.dart` and `season_live_match_flow_test.dart` green with zero test edits.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified where applicable
- [ ] No performance or application-size regression
- [ ] Every resulting file ≤800 lines (excluding generated `*.g.dart`)
- [ ] `match_screen_test.dart`, `live_match_ux_test.dart` and `season_live_match_flow_test.dart` green with zero test edits

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
