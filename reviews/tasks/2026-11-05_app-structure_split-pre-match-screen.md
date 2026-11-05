# App structure: split the pre-match screen by phase

- Feature: app-structure
- Type: Refactor
- Priority: Minor
- Created: 2026-11-05
- Status: OPEN
- Completed on: -

## Context
One of ten follow-ups carved out of `2026-11-04_app-structure_remaining-oversized-files` (set to SPLIT 2026-11-05 per the README §1 one-file-per-task rule). The README's ~800-line split threshold (README.md:72-74) is contradicted by `lib/features/match/pre_match_screen.dart` (1,187 lines on 2026-11-05). Split it following the proven `fcm_widgets.dart` barrel pattern so consumer imports never churn.

## Investigation & Evidence
- Investigation: `pre_match_screen.dart` measured 1,179 lines at task creation (2026-11-04), 1,187 on 2026-11-05; the analysis family and the tactics/pep-talk/bottom-bar family share one file (anchors at creation: analysis family :204-772, tactics/pep-talk/bottom-bar family :773+).
- Root cause / technical justification: per-phase UI families live inside the screen file; the god-files review split only its two in-scope targets.
- Affected files/components: `lib/features/match/pre_match_screen.dart`
- Evidence: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` lists the file on main.
- Expected benefit / necessity: makes the README convention real; measurable target — every resulting file ≤800 lines.
- Dependencies / side effects: widget move only; screen behaviour and the live match flow must stay identical.

## Reproduction Steps
Not applicable.

## Task
- [ ] Split the pre-match screen by phase | Where: `lib/features/match/pre_match_screen.dart` (1,187 lines on 2026-11-05; anchors above) | Expected: `pre_match_analysis.dart` (opponent header, forecast, strength, mirror bar, top players) and `pre_match_phases.dart` (tactics phase, pep-talk phase/tiles, bottom bar); `pre_match_screen_test.dart` and the live match flow green with zero test edits.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified where applicable
- [ ] No performance or application-size regression
- [ ] Every resulting file ≤800 lines (excluding generated `*.g.dart`)
- [ ] `pre_match_screen_test.dart` and the live match flow suites green with zero test edits

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
