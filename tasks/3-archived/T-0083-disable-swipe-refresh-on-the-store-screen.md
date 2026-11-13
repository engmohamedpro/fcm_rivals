---
id: T-0083
title: Disable swipe-to-refresh on the store screen
priority: medium
status: done
attempts: 1
depends_on: []
created: 2026-11-09
completed: 2026-11-09
---

# T-0083: Disable swipe-to-refresh on the store screen

## Goal
The store screen no longer refreshes on pull-down: the `RefreshIndicator` gesture is removed so a swipe can never invalidate the pack/offer providers mid-browse (owner decision 2026-11-09). Everything else on the screen behaves exactly as today.

## Context
- The store screen is `lib/features/packs/packs_screen.dart`. The whole body is wrapped in a `RefreshIndicator` at lines 48–54: `onRefresh` invalidates `availablePacksProvider` and `storeOffersProvider`.
- Refresh is still reachable without the gesture: the error panel at `packs_screen.dart:86` invalidates `availablePacksProvider` on tap, and providers also refresh on screen re-entry, so removing the wrapper loses nothing.
- Test harness to extend: `test/features/packs/packs_screen_test.dart` (pumps the screen with `collectionStoreProvider.overrideWith((ref) => store)` over a real test DB — see its `CLAIM` test at ~272 for the pattern).

## Requirements
1. `lib/features/packs/packs_screen.dart` — remove the `RefreshIndicator` wrapper (lines 48–54) so the child tree (`offers.when(...)`) becomes the direct body. Do NOT change any other behavior: grid, sections, odds sheet, CLAIM/BUY flows, error panel stay as they are.
2. Add one widget test in `test/features/packs/packs_screen_test.dart`: pump the store screen and assert `find.byType(RefreshIndicator)` finds nothing, and the store grid still renders (existing assertions pattern).

## Out of Scope
- Adding any replacement refresh mechanism (button, banner, polling).
- Changing the error/loading states or any other screen.
- Touching `availablePacksProvider` / `storeOffersProvider` logic.

## Acceptance Criteria
- [x] Pulling down on the store screen does nothing (no `RefreshIndicator` in the tree — asserted by the new test).
- [x] The store screen renders and behaves exactly as before otherwise (grid, odds sheet, CLAIM, BUY, error tap-to-retry all unchanged).
- [x] New `RefreshIndicator`-absence test added and green.
- [x] `flutter analyze` zero warnings; `flutter test test/features/packs/` green; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/packs/packs_screen_test.dart
# Expected: all pass, including the new no-RefreshIndicator test

flutter test
# Expected: full suite green, no REGEN_SNAPSHOT
```

---
<!-- Everything below this line is filled in by agents, never by the task author. -->

## Developer Notes
<!-- Developer agent fills this in before moving the file to 2-needs-review. -->

- **Summary of changes:**
- **Files changed:**
- **How I tested it:**
- **Concerns / assumptions:**


### Attempt 1 — implementation

**Summary of changes:** the `RefreshIndicator` wrapper is gone from the store screen's build — the `offers.when(...)` tree is now the direct body, with a comment recording the owner decision and the two remaining refresh paths (the error panel's tap-to-retry and the providers' natural refresh on screen re-entry). No other behavior changed: grid, sections, odds sheet, CLAIM/BUY flows and the error/loading states are untouched.

1. `lib/features/packs/packs_screen.dart` — removed the wrapper (color/backgroundColor/onRefresh invalidate block); re-indented the child tree and removed the wrapper's now-extra closing paren; `dart format` clean.
2. `test/features/packs/packs_screen_test.dart` — one new test: pumps the store on the real-DB harness, asserts `find.byType(RefreshIndicator)` findsNothing, and re-asserts the store renders as before (the 22 starter-pack stack badges — `FREE ×2` ×7, `FREE ×4` ×2 — and the 12 section icon buttons), matching the file's existing assertion pattern.

**Files changed:** `lib/features/packs/packs_screen.dart`, `test/features/packs/packs_screen_test.dart`, this task file.

**How I tested it (every How to Verify command):** `flutter analyze` → No issues found ✓. `flutter test test/features/packs/packs_screen_test.dart` → all green including the new T-0083 test ✓. `flutter test test/features/packs/` → **102/102 green** ✓. Full `flutter test --concurrency=1` → green, no REGEN_SNAPSHOT ✓ (result recorded in the submit commit).

**Concerns / assumptions:**
- Refresh remains reachable exactly as the task documents: the error panel's tap still invalidates `storeOffersProvider`/`availablePacksProvider`, and providers re-compute on screen re-entry — so no replacement mechanism was added (out of scope respected).
- `grep RefreshIndicator lib/features/packs/packs_screen.dart` → no matches after the change; no other screen was touched.

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->

### Review 2026-11-09, attempt 1: PASS
- Ran every How to Verify command on HEAD 11804b8 (implementation commit e772db2): `flutter analyze` → No issues found; `flutter test test/features/packs/packs_screen_test.dart` → 16/16 green (15 prior + the new T-0083 test); `flutter test test/features/packs/` → 102/102 green; full `flutter test` → 947/947 green, `REGEN_SNAPSHOT` unset. All counts match the Developer Notes exactly (946 + 1 = 947).
- Diff audit (e772db2): three files — `packs_screen.dart` (the `RefreshIndicator` wrapper removal; the large line count is re-indentation of the unchanged child tree, verified hunk by hunk), `packs_screen_test.dart` (+21, the new test), this task file. Both error panels keep their tap-to-retry invalidations, the StoreGrid/CLAIM/BUY wiring is identical apart from indentation — Out of Scope respected.
- AC-1 verified by test run: `find.byType(RefreshIndicator)` findsNothing on the real-DB harness; a grep of `lib/` confirms the only remaining mention anywhere is a comment (see note below), so a pull-down can no longer invalidate any provider — it only produces the platform's default overscroll glow, which is inert.
- AC-2 verified: the new test re-asserts the store renders exactly as before (the 22 starter-pack stack badges `FREE ×2` ×7 and `FREE ×4` ×2, the 12 section icon buttons), and the production diff changes no other behavior.
- One recorded nit, no criterion impact: `packs_store_widgets.dart:78` still carries the stale phrase "the RefreshIndicator still has its scrollable" in the comment explaining the grid's `SingleChildScrollView` + `AlwaysScrollableScrollPhysics`. The physics themselves are harmless without the indicator (default overscroll, no invalidation) and changing them was correctly left out of this task's scope; the one-line comment refresh can ride along with the next task that touches that file — not worth reopening this one.
