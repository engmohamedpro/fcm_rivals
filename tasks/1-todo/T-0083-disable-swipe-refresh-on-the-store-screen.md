---
id: T-0083
title: Disable swipe-to-refresh on the store screen
priority: medium
status: todo
attempts: 0
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

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
