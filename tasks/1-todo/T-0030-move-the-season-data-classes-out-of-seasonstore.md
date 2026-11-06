---
id: T-0030
title: Move the season data classes out of SeasonStore
priority: medium
status: todo
attempts: 0
depends_on: [T-0036]
created: 2026-11-05
completed:
# migrated from: reviews/tasks/2026-11-05_app-structure_split-season-models.md
---

# T-0030: Move the season data classes out of SeasonStore

## Goal
Move the season data classes out of SeasonStore into season_models.dart; finishing the store below the 800-line convention lives in the follow-up task.

## Context
> **Record shell (migrated 2026-11-06):** this file was status SPLIT on the old reviews/ board — its executable work was handed over to the follow-up tasks listed in `depends_on`. There is nothing to implement in this file; it is kept for traceability and closes only when all of its `depends_on` tasks are archived.

One of ten follow-ups carved out of `2026-11-04_app-structure_remaining-oversized-files` (set to SPLIT 2026-11-05 per the README §1 one-file-per-task rule). The README's ~800-line split threshold (README.md:72-74) is contradicted by `lib/features/season/season_store.dart` (1,257 lines on 2026-11-05). Split it following the proven `fcm_widgets.dart` barrel pattern so consumer imports never churn.

## Investigation & Evidence
- Investigation: `season_store.dart` measured 1,263 lines at task creation (2026-11-04), 1,257 on 2026-11-05; data classes share the file with the store lifecycle/logic (anchors at creation: `SeasonSummary`:38, `NextFixture`:65, `SeasonCompletion`:84, `AiOpponentSquad`:110).
- Root cause / technical justification: season result/summary data classes live inside the store file; the god-files review split only its two in-scope targets.
- Affected files/components: `lib/features/season/season_store.dart`
- Evidence: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` lists the file on main.
- Expected benefit / necessity: makes the README convention real; measurable target — every resulting file ≤800 lines.
- Dependencies / side effects: data-class move only; the season suites and the simulation harness (which drives the real stores) are the regression net.

## Requirements
- [x] Move the season data classes out of SeasonStore | Where: `lib/features/season/season_store.dart` (1,257 lines on 2026-11-05; anchors above) | Expected: `season_models.dart` holds the data classes; `SeasonStore` keeps lifecycle/logic only; season suites and simulation harness green with zero test edits.

## Out of Scope
- Any remaining implementation in this file; the store-budget completion lives in `2026-11-06_app-structure_finish-season-store-split`.

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated; full `flutter test` suite passes (green except the four tracked phase-3 balance bands — see Reviewer Verification)
- [x] EN/AR localization complete and RTL verified where applicable (data-class move only, no localization surface)
- [x] No performance or application-size regression (pure relocation)
- [ ] Every resulting file ≤800 lines (excluding generated `*.g.dart`) — UNMET: `season_store.dart` still 1,167 lines (Reviewer Verification)
- [x] Season suites and `flutter test tool/simulation_report_test.dart` green with zero test edits, determinism PASS

## How to Verify
Run the board's standard gates:

```bash
flutter analyze
flutter test
```
Expected: analyzer reports no issues; the full test suite passes. Per-task checks are quoted in Requirements and Developer Notes.

---

## Developer Notes
- Extracted `season_models.dart` (103 lines) from `season_store.dart`
  (1,257 -> 1,168 lines): `SeasonException`, `SeasonSummary`,
  `NextFixture`, `SeasonCompletion`, `AiOpponentSquad` — each with its
  doc comment. Pure relocation, zero behavioural edits.
- `season_store.dart` imports and re-exports `season_models.dart`
  (barrel) so every existing `import 'season_store.dart'` (season
  screens, providers, economy simulator, tests) keeps resolving all
  model names with ZERO test edits.
- Checks (Flutter 3.47.9 stable):
  - `flutter analyze`: No issues found!
  - `flutter test test/features/season/ test/features/simulation/`:
    All tests passed (71) — season suites + simulation harness.
  - `flutter test` full suite: 705 passed, 4 failed — exactly the four
    known phase-3 balance bands (identical to the pre-change run);
    zero new failures.
- Only `season_store.dart`, the new `season_models.dart` and this task
  file are in the commit.

## Review Log
### 2026-11-06 — board migration
- Migrated from `reviews/` to the `tasks/` board as `T-0030` (was `reviews/tasks/2026-11-05_app-structure_split-season-models.md`, status SPLIT).
- Record shell: executable work lives in the `depends_on` follow-ups.

Verified 2026-11-06 on commit `52cd716` — implementation GOOD, closure BLOCKED by one acceptance criterion (§6.A: any failed AC prevents closure). Checks: (1) `git show 52cd716 --name-only` — only `season_store.dart`, `season_models.dart` and this task file; (2) measured 2026-11-06: `season_models.dart` 102 ✓ but `season_store.dart` 1,167 ✗ against the ≤800 criterion — the task moved only the data classes (~90 lines), leaving the store far above budget; (3) season+simulation suites reported green (71 tests) and the full suite 705/4 with only the tracked balance bands, zero test edits. Failure evidence: AC "Every resulting file ≤800 lines" unmet. Action per §6.A: correction task `2026-11-06_app-structure_finish-season-store-split` created (method-family extraction — class-level extraction is exhausted, the file holds a single `SeasonStore` class); this file → SPLIT and closes when the follow-up is CLOSED. Limitation: the suite was not re-run in this sandbox.

- 2026-11-06 (reviewer, verification of the DONE claim): Status DONE → SPLIT — the extraction itself is verified good, but the "every resulting file ≤800 lines" criterion is unmet (season_store.dart 1,167 measured). The remaining work lives in `2026-11-06_app-structure_finish-season-store-split`; the task text above is unchanged historical record.

## Historical Links
- Depends on: None
- Follows: `2026-11-04_app-structure_remaining-oversized-files`
- Follow-up: `2026-11-06_app-structure_finish-season-store-split`
