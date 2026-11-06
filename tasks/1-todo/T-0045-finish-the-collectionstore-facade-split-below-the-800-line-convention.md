---
id: T-0045
title: Finish the CollectionStore facade split below the 800-line convention
priority: medium
status: todo
attempts: 0
depends_on: []
created: 2026-11-06
completed:
---

# T-0045: Finish the CollectionStore facade split below the 800-line convention

## Goal
Bring `lib/features/collection/collection_store.dart` (854 lines) below the ~800-line convention with one more verbatim part-file extraction, closing the last covered file on the T-0021 gate.

## Context
Correction follow-up of archived T-0034 ("Finish the CollectionStore facade split below the 900-line budget", landed at 854 ≤ 900) — the 800 convention (README.md:72-74) now requires the remaining 54 lines to move. Measured on main `b2c0a27` (2026-11-06): the facade is a single `CollectionStore` class (:43) composed over `part` files `collection_store_dataset.dart` (:40) and `collection_store_internals.dart` (:41). Remaining method families:
- Match-result family: `applyMatchResult` :703-~815 (≈112 lines) — the cohesive extraction candidate; verbatim move to a new part file.
- Everything else stays: club lifecycle `createClub` :126, pack flow `openPack`/`buyPack`/`getStoreOffers` :198-368, collection `getCollection` :369, sell/merge `sellPlayers` :415 / `mergeDuplicates` :491, upgrades `buyUpgrade` :594, delegations :816-854 (≈742 lines after extraction).
Same pattern as T-0034: verbatim part-file extraction, no behaviour change, schema unchanged.

## Requirements
1. Create part file `collection_store_match.dart` holding the `applyMatchResult` family verbatim, add the `part` directive; the facade lands ≤800 lines. No behaviour change, schema unchanged — store/facilities/economy suites green with zero test edits.
2. Every resulting file ≤800 lines; `flutter analyze` clean; full `flutter test` green.

## Out of Scope
- Any further store splitting (club/pack/sell families stay in the facade), renaming the facade, or changing the Drift schema.
- Changing any threshold or band to make the check pass.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes with zero test edits
- [ ] EN/AR localization complete and RTL verified where applicable
- [ ] No performance or application-size regression
- [ ] Facade `collection_store.dart` ≤800 lines; new part file ≤800 lines
- [ ] `README.md` architecture table row for the collection stores updated for the new part file

## How to Verify
```bash
wc -l lib/features/collection/collection_store.dart lib/features/collection/collection_store_match.dart
flutter analyze
flutter test test/features/collection/ test/features/economy/ test/core/database/
flutter test
```
Expected: facade ≤800 lines; analyzer clean; collection/economy/database suites and full suite green with zero test edits.

---

## Developer Notes

## Review Log
