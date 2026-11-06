# App structure: finish the CollectionStore facade split below the 900-line budget

- Feature: app-structure
- Type: Refactor
- Priority: Minor
- Created: 2026-11-06
- Status: OPEN
- Completed on: -

## Context
Correction follow-up of `2026-11-05_app-structure_split-collection-results-catalog` (SPLIT 2026-11-06: the results/catalog extraction verified good, but its acceptance criterion "the CollectionStore facade ≤900 lines" is unmet — the facade still measures 1,049 lines; additionally that task's full-suite summary was never pasted). This task finishes the split to the agreed budget and closes the verification gap.

## Investigation & Evidence
- Investigation: `collection_results.dart` (144 lines) and `pack_catalog.dart` (77 lines) landed, shrinking the facade 1,244 → 1,049 (measured 2026-11-06; the developer's notes report 1,051 at the task commit) — still 149 lines above the ≤900 criterion; class-level extraction is exhausted (a single `CollectionStore` class remains, declared at :41).
- Root cause / technical justification: the facade still concentrates dataset-import handling and cross-store composition logic in one class; only method-family extraction remains.
- Affected files/components: `lib/features/collection/collection_store.dart`
- Evidence: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` lists the file on main at d0fbb88; the task commit's Developer Notes state the full-suite summary was not pasted before delivery.
- Expected benefit / necessity: makes the agreed ≤900 budget real; measurable target — every resulting file ≤800 lines and the facade ≤900.
- Dependencies / side effects: the facade is consumed by screens, SeasonStore and the simulator; use the proven part-file/helper-library pattern (engine split `5447a67`) with `collection_store.dart` as the importing barrel so existing imports never churn; store/facilities/economy suites are the regression net.

## Reproduction Steps
Not applicable.

## Task
- [ ] Extract cohesive CollectionStore method families below the 900-line budget and paste the full-suite run | Where: `lib/features/collection/collection_store.dart` (1,049 lines on 2026-11-06) | Expected: the facade ≤900 lines and every new file ≤800 lines (candidates: dataset import/validation family, store-composition helpers); pure relocation, no behaviour change, schema unchanged — store/facilities/economy suites green with zero test edits, and a dated full-suite `flutter test` summary line pasted in Developer Notes (expected 705+ passed / only the tracked balance bands red).

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified where applicable
- [ ] No performance or application-size regression
- [ ] Resulting files ≤800 lines; the `CollectionStore` facade ≤900 lines
- [ ] Schema unchanged; store/facilities/economy suites green with zero test edits; dated full-suite summary pasted in Developer Notes

## Developer Notes
<Implementation summary, files changed, exact test commands/results, and rejection reason/evidence if applicable. Implement this task only, create one task-specific commit, and push it before starting another task.>

## Reviewer Verification
<Reviewer records verification date, tested commit hash, checks performed, results, and remaining limitations. Do not add personal names.>

## Links
- Depends on: None
- Follows: `2026-11-05_app-structure_split-collection-results-catalog`
- Follow-up: None

## Amendments
<Reviewer-owned, append-only. Add dated entries correcting the task's target or mechanism; never rewrite the original task text.>
