# App structure: split the match engine into domain, commands and engine

- Feature: app-structure
- Type: Refactor
- Priority: Minor
- Created: 2026-11-05
- Status: OPEN
- Completed on: -

## Context
One of ten follow-ups carved out of `2026-11-04_app-structure_remaining-oversized-files` (set to SPLIT 2026-11-05 per the README §1 one-file-per-task rule). The README's ~800-line split threshold (README.md:72-74) is contradicted by `lib/features/match/match_engine.dart` (2,054 lines on 2026-11-05). Split it following the proven `fcm_widgets.dart` barrel pattern so consumer imports never churn.

## Investigation & Evidence
- Investigation: `match_engine.dart` measured 1,970 lines at task creation (2026-11-04) and 2,054 on 2026-11-05; it mixes event/player/team-input models, engine config and the command hierarchy with the engine core (class anchors at creation: `MatchEvent`:69, `MatchPlayer`:113, `MatchTeamInput`:164, `MatchEngineConfig`:198, `MatchCommand` hierarchy:309).
- Root cause / technical justification: the engine file accumulated domain models, the command object tree and the pipeline in one file; the god-files review split only its two in-scope targets.
- Affected files/components: `lib/features/match/match_engine.dart`
- Evidence: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` lists the file on main.
- Expected benefit / necessity: makes the README convention real; measurable target — every resulting file ≤800 lines.
- Dependencies / side effects: pure Dart move, no behaviour change; the engine must stay deterministic — snapshot and calibration suites green with identical seed output is the regression net.

## Reproduction Steps
Not applicable.

## Task
- [ ] Split the match engine into domain, commands and engine | Where: `lib/features/match/match_engine.dart` (2,054 lines on 2026-11-05; anchors above) | Expected: `match_event.dart` (enums + event/player/team-input models + config) and `match_commands.dart` (the command hierarchy), engine core stays; pure Dart, no behaviour change — `engine_snapshot_test.dart` and `engine_calibration_test.dart` green with zero test edits and identical seed output; every resulting file ≤800 lines.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified where applicable
- [ ] No performance or application-size regression
- [ ] Every resulting file ≤800 lines (excluding generated `*.g.dart`)
- [ ] `engine_snapshot_test.dart` and `engine_calibration_test.dart` green with zero test edits and identical seed output

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
