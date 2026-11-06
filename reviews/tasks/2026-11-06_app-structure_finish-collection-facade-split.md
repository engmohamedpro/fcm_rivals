# App structure: finish the CollectionStore facade split below the 900-line budget

- Feature: app-structure
- Type: Refactor
- Priority: Minor
- Created: 2026-11-06
- Status: DONE
- Completed on: 2026-11-06

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
- [x] Extract cohesive CollectionStore method families below the 900-line budget and paste the full-suite run | Where: `lib/features/collection/collection_store.dart` (1,049 lines on 2026-11-06) | Expected: the facade ≤900 lines and every new file ≤800 lines (candidates: dataset import/validation family, store-composition helpers); pure relocation, no behaviour change, schema unchanged — store/facilities/economy suites green with zero test edits, and a dated full-suite `flutter test` summary line pasted in Developer Notes (expected 705+ passed / only the tracked balance bands red).

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated; full `flutter test` suite passes
- [x] EN/AR localization complete and RTL verified where applicable
- [x] No performance or application-size regression
- [x] Resulting files ≤800 lines; the `CollectionStore` facade ≤900 lines
- [x] Schema unchanged; store/facilities/economy suites green with zero test edits; dated full-suite summary pasted in Developer Notes

## Developer Notes
Implemented 2026-11-06. Followed the endorsed engine-split pattern (`5447a67`) — part files with `collection_store.dart` as the importing barrel, moved blocks byte-identical (machine-asserted against the HEAD blob before writing; the facade's whole diff against HEAD is the removal of the moved blocks plus two `part` lines):

- `collection_store_dataset.dart` (NEW, 164 lines): the dataset import/validation family — `_ensureRegistry`, `importBundledDataset`, `applyDatasetUpdate` — as public-named `extension DatasetImportOps on CollectionStore` (public-named because these members are the facade's public API called by providers, the simulator and tests; bodies unchanged).
- `collection_store_internals.dart` (NEW, 56 lines): library-private internals only — `_toBasePlayer` (as private `extension _RowMapping`) and the unnamed `extension on AppDatabase` ledger append.
- `collection_store.dart`: 1,049 → **854 lines** (≤900 with margin 46).

Deviation from the task's candidate list, with evidence: the store-composition helpers (the club/squad/campus pass-through family) were extracted first but had to be RESTORED into the class. Dart extension scope does not propagate through re-imports: `squad_screen.dart`, `main.dart`, `campus_screen.dart`, `match_screen.dart` call these members via `app/providers.dart` without importing `collection_store.dart`, so extension-declared members did not resolve there (`flutter analyze`: 7 `undefined_method` errors, e.g. `getClub` at match_screen.dart:166, `saveSquad` at squad_screen.dart:166). Moving public API to extensions would have forced import edits across consumers and tests, breaking the zero-test-edits criterion; the engine precedent only ever moved private members. The budget was reached via the dataset family (151 lines) + private internals (46 lines) instead. No behaviour, schema, transaction, or localization change (relocation only); no test edits.

Exact commands and results (2026-11-06, Flutter 3.47.9 stable / Dart 3.13.7, base `517724b`):
- `flutter analyze` → `No issues found! (ran in 2.0s)` — zero analyzer warnings.
- `flutter test test/features/collection/collection_store_test.dart test/core/database/coin_ops_test.dart test/balance/economy_balance_test.dart test/features/facilities` → `+59: All tests passed!` with zero test edits.
- Full suite: `flutter test` → `+709: All tests passed!` exit 0, dated 2026-11-06 (~5m38s wall), zero failures — NO tracked balance bands red in this run.
- Line budget: facade 854 ≤ 900; new files 164 and 56 ≤ 800; `find lib … awk '$1>800'` no longer lists anything in `lib/features/collection/`.

## Reviewer Verification
<Reviewer records verification date, tested commit hash, checks performed, results, and remaining limitations. Do not add personal names.>

## Links
- Depends on: None
- Follows: `2026-11-05_app-structure_split-collection-results-catalog`
- Follow-up: None

## Amendments
<Reviewer-owned, append-only. Add dated entries correcting the task's target or mechanism; never rewrite the original task text.>
