---
id: T-0045
title: Finish the CollectionStore facade split below the 800-line convention
priority: medium
status: needs-review
attempts: 1
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
- **Summary of changes:** Extracted the match-result family — the `applyMatchResult` method, original lines 703-810 (108 lines; the task estimated ≈112 ending at ~815, but the delegations banner starts at 812 with a blank at 811, so the method body ends at 810) — verbatim into a new `part` file `collection_store_match.dart` (121 lines), wrapped in `extension MatchResultOps on CollectionStore` exactly like the existing `DatasetImportOps` part, and added `part 'collection_store_match.dart';` to the facade. The facade lands at **747 lines** (854 → 747). Relocation by a one-time line-slice script kept outside the repo with a multiset verifier proving every original code line lands exactly once; the only new content is the part-file header docs and the extension wrapper. **Zero code renames or edits** — part files share the facade library, so the private store state stays reachable and every existing call site (`match_session.dart:438`, the ad tests) keeps resolving with zero edits because the extension is exported through the `collection_store.dart` import.
- **Pre-existing defect found, not fixed (flag for the reviewer):** facade lines 691-702 (now 691-702 in the 747-line facade) carry scrambled, orphaned doc-comment fragments left behind by the T-0034 extraction — a cut-off "Squad assignments" doc, the "Campus facilities" banner, a cut-off "Current facility levels" doc and a stray "not come on keep their stamina untouched." fragment, now doc-attaching to nothing (after this extraction they sit directly above the delegations banner). They are comment-only: the compiler and analyzer are unaffected and the T-0034 review passed with them present. I left them untouched (this task is a pure verbatim relocation and fixing foreign content silently is out of scope) — recommend a small dedicated cleanup task.
- **Files changed:** `lib/features/collection/collection_store.dart` (now 747 lines, third `part` directive added), `lib/features/collection/collection_store_match.dart` (new, 121 lines), `README.md` (Focused stores row now names the three `part` files).
- **How I tested it:** Environment note: the sandbox was recycled mid-task, so the repo was re-cloned at `37c7c59` and Flutter 3.47.9 reinstalled before any gates ran. Baseline on the unmodified tree: `flutter pub get` exit 0, `flutter analyze` No issues found, `flutter test test/features/collection/ test/features/economy/ test/core/database/` → `+39: All tests passed!` exit 0. After the extraction: the `wc -l` gate lists 747/121, both ≤800; `flutter analyze` No issues found (part files share the facade imports — no import work needed); the same focused run → `+39: All tests passed!` exit 0 (identical count, zero test edits); full `flutter test` → `+709: All tests passed!` exit 0 (~5m31s) — identical test count to the baseline, zero test edits.
- **Concerns / assumptions:** (1) The family boundary 703-810 vs the task's ≈703-~815 estimate — verified against the actual file (blank 811, banner 812-814, delegations 816+); nothing between 811-815 moved. (2) The stale doc fragments above are pre-existing and left as-is. None blocking.

## Review Log
