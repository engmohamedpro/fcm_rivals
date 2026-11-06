# App structure: finish the SeasonStore split below the 800-line convention

- Feature: app-structure
- Type: Refactor
- Priority: Minor
- Created: 2026-11-06
- Status: OPEN
- Completed on: -

## Context
Correction follow-up of `2026-11-05_app-structure_split-season-models` (SPLIT 2026-11-06: implementation verified good, but its acceptance criterion "every resulting file ≤800 lines" is unmet — `season_store.dart` still measures 1,167 lines). This task finishes the split to the README's ~800-line convention (README.md:72-74).

## Investigation & Evidence
- Investigation: the data-class extraction landed (`season_models.dart`, 102 lines) but `season_store.dart` remains at 1,167 lines (measured 2026-11-06; 1,257 before the split) — class-level extraction is exhausted, the file now holds a single `SeasonStore` class (declared at :35) whose method families carry the bulk.
- Root cause / technical justification: the season store concentrates fixture resolution/play, quick simulation, standings, history and rewards logic in one class; only method-family extraction remains.
- Affected files/components: `lib/features/season/season_store.dart`
- Evidence: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` lists the file on main at d0fbb88.
- Expected benefit / necessity: makes the README convention real; measurable target — every resulting file ≤800 lines.
- Dependencies / side effects: the proven pattern is the engine split's (`5447a67`): cohesive method families moved verbatim into private part files or helper libraries with `season_store.dart` as the importing barrel, so every existing `import 'season_store.dart'` keeps resolving; season suites and the simulation harness are the regression net.

## Reproduction Steps
Not applicable.

## Task
- [ ] Extract cohesive SeasonStore method families below the 800-line budget | Where: `lib/features/season/season_store.dart` (1,167 lines on 2026-11-06) | Expected: `season_store.dart` and every new file ≤800 lines (candidates per README's module table: fixture play/quick simulation, standings/history, rewards); pure relocation, no behaviour change — season suites and `flutter test tool/simulation_report_test.dart` green with zero test edits, determinism PASS.

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
- Follows: `2026-11-05_app-structure_split-season-models`
- Follow-up: None

## Amendments
<Reviewer-owned, append-only. Add dated entries correcting the task's target or mechanism; never rewrite the original task text.>
