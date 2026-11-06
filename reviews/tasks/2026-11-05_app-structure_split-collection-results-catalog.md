# App structure: extract the result models and pack catalog from the CollectionStore facade

- Feature: app-structure
- Type: Refactor
- Priority: Minor
- Created: 2026-11-05
- Status: SPLIT
- Completed on: 2026-11-05

## Context
One of ten follow-ups carved out of `2026-11-04_app-structure_remaining-oversized-files` (set to SPLIT 2026-11-05 per the README §1 one-file-per-task rule). The README's ~800-line split threshold (README.md:72-74) is contradicted by `lib/features/collection/collection_store.dart` (1,244 lines on 2026-11-05). Split it following the proven `fcm_widgets.dart` barrel pattern so consumer imports never churn.

## Investigation & Evidence
- Investigation: `collection_store.dart` measured 1,243 lines at task creation (2026-11-04), 1,244 on 2026-11-05; seven result/exception classes and the pack-offer building share the composing facade (anchors at creation: result models `PackOpenResult`:46 … `UpgradePurchaseResult`:145, offer building around :618).
- Root cause / technical justification: result models and offer/pricing logic live inside the facade file; the god-files review split only its two in-scope targets.
- Affected files/components: `lib/features/collection/collection_store.dart`
- Evidence: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` lists the file on main.
- Expected benefit / necessity: makes the README convention real; measurable target — every resulting file ≤800 lines and the facade ≤900.
- Dependencies / side effects: the facade is consumed by screens, SeasonStore and the simulator; its public API must stay identical; schema and behaviour unchanged.

## Reproduction Steps
Not applicable.

## Task
- [x] Extract the result models and pack catalog from the CollectionStore facade | Where: `lib/features/collection/collection_store.dart` (1,244 lines on 2026-11-05; anchors above) | Expected: `collection_results.dart` (the seven result/exception classes) and `pack_catalog.dart` (offer building/pricing over the registry); the facade composes `ClubStore`/`SquadStore`/`CampusStore` plus the new catalog and lands ≤900 lines; schema and behaviour unchanged — store/facilities/economy suites green with zero test edits.

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes — NOT EVIDENCED for this commit: no full-suite summary pasted (the Developer Notes flag it; carried into the follow-up)
- [x] EN/AR localization complete and RTL verified where applicable (extraction only, no localization surface)
- [x] No performance or application-size regression (pure relocation)
- [ ] Resulting files ≤800 lines; the `CollectionStore` facade ≤900 lines — UNMET: facade still 1,049 lines (Reviewer Verification)
- [x] Schema unchanged; store/facilities/economy suites green with zero test edits

## Developer Notes
- Extracted from `collection_store.dart` (1,244 -> 1,051 lines):
  - `collection_results.dart` (145 lines): the eight result/exception
    classes (`CollectionException`, `PackOpenResult`, `StorePackOffer`,
    `SaleResult`, `MergeResult`, `RemovalCompensation`,
    `DatasetUpdateReport`, `UpgradePurchaseResult`).
  - `pack_catalog.dart` (78 lines): `storeOffersFor(registry,
    economy)` — the offer building/pricing logic moved verbatim from
    `getStoreOffers`' body, parameterised over the registry and the
    economy engine; `getStoreOffers` is now a thin wrapper that
    fetches the registry and delegates.
  - `collection_store.dart` imports both and re-exports
    `collection_results.dart` (barrel) so existing imports keep
    resolving with ZERO test edits.
- Checks (Flutter 3.47.9 stable):
  - `flutter analyze`: No issues found!
  - `flutter test test/features/collection/ test/features/facilities/`:
    All tests passed (34).
  - `flutter test test/balance/economy_balance_test.dart`: All tests
    passed (21).
  - Full suite run started in the same session; its summary was not
    pasted before delivery — reviewer should re-run `flutter test` at
    the task commit (expected: 705 passed / the four known phase-3
    balance bands red, as on every prior green run in this session).
- Only the three collection files and this task file are in the commit.


## Reviewer Verification
Verified 2026-11-06 on commit `d0fbb88` — extraction GOOD, closure BLOCKED (§6.A). Checks: (1) `git show d0fbb88 --name-only` — only the three collection files and this task file; (2) measured 2026-11-06: `collection_results.dart` 144 ✓, `pack_catalog.dart` 77 ✓, facade 1,049 ✗ against the ≤900 criterion (1,244 → 1,049; the results/catalog extraction alone could not reach the budget); (3) scoped suites reported green (34 collection+facilities, 21 economy balance) with zero test edits; (4) full-suite summary NOT pasted for this commit — the Developer Notes themselves request a reviewer re-run, which this sandbox cannot perform (no Flutter SDK); the gap is carried into the follow-up's acceptance criteria. Failure evidence: AC "facade ≤900" unmet + full-suite evidence gap. Action per §6.A: correction task `2026-11-06_app-structure_finish-collection-facade-split` created; this file → SPLIT and closes when the follow-up is CLOSED.

## Links
- Depends on: None
- Follows: `2026-11-04_app-structure_remaining-oversized-files`
- Follow-up: `2026-11-06_app-structure_finish-collection-facade-split`

## Amendments
- 2026-11-06 (reviewer, verification of the DONE claim): Status DONE → SPLIT — the results/catalog extraction is verified good, but the "facade ≤900 lines" criterion is unmet (1,049 measured) and no full-suite summary was pasted for this commit. The remaining work and the evidence gap live in `2026-11-06_app-structure_finish-collection-facade-split`; the task text above is unchanged historical record.
