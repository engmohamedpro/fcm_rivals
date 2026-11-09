---
id: T-0083
title: Disable swipe-to-refresh on the store screen
priority: medium
status: needs-review
attempts: 1
depends_on: []
created: 2026-11-09
completed:
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
- [ ] Pulling down on the store screen does nothing (no `RefreshIndicator` in the tree — asserted by the new test).
- [ ] The store screen renders and behaves exactly as before otherwise (grid, odds sheet, CLAIM, BUY, error tap-to-retry all unchanged).
- [ ] New `RefreshIndicator`-absence test added and green.
- [ ] `flutter analyze` zero warnings; `flutter test test/features/packs/` green; full `flutter test` green.

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
