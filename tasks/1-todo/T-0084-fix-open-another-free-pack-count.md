---
id: T-0084
title: Fix the OPEN ANOTHER free-pack count showing one extra
priority: high
status: todo
attempts: 0
depends_on: []
created: 2026-11-09
completed:
---

# T-0084: Fix the OPEN ANOTHER free-pack count showing one extra

## Goal
The `FREE ×N` count on the reveal screen's OPEN ANOTHER capsule shows the real number of owned packs of that shelf slot after the current open — today it shows one extra, and with the last owned pack it even offers a free open that then fails.

## Context
- Owner report 2026-11-09: after opening a pack, the OPEN ANOTHER button's free-pack count is +1 versus the real number.
- Root cause (verified in code): `_chainInfoFor` (`lib/features/packs/packs_screen.dart:280-292`) computes `ownedCount` from `ref.read(availablePacksProvider).valueOrNull` synchronously, but it is invoked from `_reveal` right after `_open` already did `store.openPack(...)` (line 126) and `ref.invalidate(availablePacksProvider)` (line 127). `availablePacksProvider` is a `FutureProvider` (`lib/app/providers.dart:167`); after `invalidate` a synchronous `.read().valueOrNull` returns the PREVIOUS cached list, which still contains the just-consumed pack → count = real + 1. The same stale read exists in `_openAnotherInChain` (`packs_screen.dart:197-205`): its owned-pack lookup can pick the already-consumed pack, then `store.openPack` throws (the row no longer exists) and the chain dies with an error SnackBar.
- Display path: `PackChainInfo.ownedCount` → `ChainButton` renders `'FREE ×$ownedCount'` (`lib/features/packs/pack_opening_widgets.dart:154`); `isFree` (`lib/features/packs/pack_opening_screen.dart:90`) is `ownedCount > 0`, so a stale +1 also flips the capsule to a false FREE.
- Fresh data is available two ways: await the provider's next computation (`await ref.read(availablePacksProvider.future)` — after invalidate it completes with the fresh list) or query the store/DB directly for currently available packs of the slot.
- Test harness: `test/features/packs/packs_screen_test.dart` — CLAIM test at ~272 already drives claim → reveal with `collectionStoreProvider.overrideWith((ref) => store)` over a real test DB; seed multiple owned packs of one slot there.

## Requirements
1. `lib/features/packs/packs_screen.dart` — the `PackChainInfo` passed to every reveal (both the first reveal from `_open` and chained reveals from `_openAnotherInChain`) must be computed from data that already reflects the just-completed open: `ownedCount`, `isFree`, price path and balance must match the DB state at push time.
2. `_openAnotherInChain`'s owned-pack selection must never return a pack that was already consumed: if it reads a pack list, that list must be fresh (post-open). With zero owned packs remaining it must take the buy path exactly as today (price check, then `store.buyPack`).
3. No behavior changes elsewhere: chain visuals, handoff animation, sell wiring and the YES/NO-free purchase model stay as they are.
4. Add regression tests in `test/features/packs/packs_screen_test.dart` (real-DB harness):
   - Seed 2 owned packs of the same shelf slot, claim/open one → the reveal's chain capsule shows `FREE ×1` (not `FREE ×2`).
   - Seed exactly 1 owned pack, open it → the capsule does NOT offer a free open (no `FREE` label; the price path shows) and tapping OPEN ANOTHER buys (or reports shortfall) instead of erroring.

## Out of Scope
- Reordering or restyling the reveal action buttons (T-0085 owns that).
- The pack engine, prices, drop rates, or anything in the store DB schema.
- Any change to `availablePacksProvider`'s definition or caching strategy in `lib/app/providers.dart`.

## Acceptance Criteria
- [ ] After opening a pack, the OPEN ANOTHER capsule's owned count equals the real number of owned packs of that slot (2 owned → open → `FREE ×1`; 1 owned → open → price path, not FREE).
- [ ] Chained reveals (OPEN ANOTHER → next reveal) also show the correct post-open count, not a stale one.
- [ ] With zero owned packs left, tapping OPEN ANOTHER never attempts to open a consumed pack id (no error SnackBar from a stale read; it buys or reports shortfall).
- [ ] The two regression tests above exist and are green.
- [ ] `flutter analyze` zero warnings; `flutter test test/features/packs/` green; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/packs/packs_screen_test.dart
# Expected: all pass, including the two new count regression tests

flutter test test/features/packs/
# Expected: whole packs suite green (chain/reveal tests unbroken)

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
