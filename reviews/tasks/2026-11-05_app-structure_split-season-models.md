# App structure: move the season data classes out of SeasonStore

- Feature: app-structure
- Type: Refactor
- Priority: Minor
- Created: 2026-11-05
- Status: OPEN
- Completed on: -

## Context
One of ten follow-ups carved out of `2026-11-04_app-structure_remaining-oversized-files` (set to SPLIT 2026-11-05 per the README §1 one-file-per-task rule). The README's ~800-line split threshold (README.md:72-74) is contradicted by `lib/features/season/season_store.dart` (1,257 lines on 2026-11-05). Split it following the proven `fcm_widgets.dart` barrel pattern so consumer imports never churn.

## Investigation & Evidence
- Investigation: `season_store.dart` measured 1,263 lines at task creation (2026-11-04), 1,257 on 2026-11-05; data classes share the file with the store lifecycle/logic (anchors at creation: `SeasonSummary`:38, `NextFixture`:65, `SeasonCompletion`:84, `AiOpponentSquad`:110).
- Root cause / technical justification: season result/summary data classes live inside the store file; the god-files review split only its two in-scope targets.
- Affected files/components: `lib/features/season/season_store.dart`
- Evidence: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` lists the file on main.
- Expected benefit / necessity: makes the README convention real; measurable target — every resulting file ≤800 lines.
- Dependencies / side effects: data-class move only; the season suites and the simulation harness (which drives the real stores) are the regression net.

## Reproduction Steps
Not applicable.

## Task
- [ ] Move the season data classes out of SeasonStore | Where: `lib/features/season/season_store.dart` (1,257 lines on 2026-11-05; anchors above) | Expected: `season_models.dart` holds the data classes; `SeasonStore` keeps lifecycle/logic only; season suites and simulation harness green with zero test edits.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified where applicable
- [ ] No performance or application-size regression
- [ ] Every resulting file ≤800 lines (excluding generated `*.g.dart`)
- [ ] Season suites and `flutter test tool/simulation_report_test.dart` green with zero test edits, determinism PASS

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
