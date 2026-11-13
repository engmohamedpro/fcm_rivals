---
id: T-0084
title: Fix the OPEN ANOTHER free-pack count showing one extra
priority: high
status: done
attempts: 1
depends_on: []
created: 2026-11-09
completed: 2026-11-09
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
- [x] After opening a pack, the OPEN ANOTHER capsule's owned count equals the real number of owned packs of that slot (2 owned → open → `FREE ×1`; 1 owned → open → price path, not FREE).
- [x] Chained reveals (OPEN ANOTHER → next reveal) also show the correct post-open count, not a stale one.
- [x] With zero owned packs left, tapping OPEN ANOTHER never attempts to open a consumed pack id (no error SnackBar from a stale read; it buys or reports shortfall).
- [x] The two regression tests above exist and are green.
- [x] `flutter analyze` zero warnings; `flutter test test/features/packs/` green; full `flutter test` green.

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


### Attempt 1 — implementation

**Summary of changes:** the OPEN ANOTHER capsule and the chain hop now read the POST-open state. The capsule's `PackChainInfo` is computed after awaiting `availablePacksProvider`'s fresh future (post-invalidate) and the balance straight from `store.getClub()`, so `ownedCount`, `isFree` and the price path match the DB at push time; `_openAnotherInChain` awaits the same fresh list, so its owned-pack lookup can never select the just-consumed row — with zero owned packs it takes the buy path exactly as before (price check, then `store.buyPack`).

1. `lib/features/packs/packs_screen.dart` — `_chainInfoFor` is now `Future<PackChainInfo?>` taking the store: `await ref.read(availablePacksProvider.future)` (the task's first suggested fresh source — after the open's `invalidate` this completes with the fresh DB list) and `(await store.getClub())?.coins ?? 0` instead of the synchronous `valueOrNull` reads that returned the stale cached list. `_reveal` awaits it before the push (with a `context.mounted` re-check after the round-trips). `_openAnotherInChain` awaits the provider future before its owned lookup, and captures `ScaffoldMessenger`/`l10n` before the first await (the file's own `_reveal` pattern) to clear the new `use_build_context_synchronously` infos on the shortfall branch.
2. No change to `availablePacksProvider`'s definition or caching (out of scope), no change to chain visuals, handoff, sell wiring or the YES/NO purchase model, no engine/price/schema change.
3. `test/features/packs/packs_screen_test.dart` — two regression tests on the real-DB harness, plus a shared helper that opens one owned GK rare pack into its finished reveal:
   - **FREE ×1:** the starter grant gives GK exactly 2 rare packs; after opening one the capsule shows `FREE ×1` (and `FREE ×2` findsNothing — the stale read the task locks), with the DB agreeing (1 survivor).
   - **Last-pack path:** GK doctored down to 1 owned pack in the DB before the first pump (the drained-wallet test's before-pump pattern); opening it offers the price plate (`26K` for rare GK) with no FREE label anywhere, and tapping OPEN ANOTHER spends `offer.price` coins, shows NO SnackBar, and lands the chained reveal — the pre-fix code died here on a CollectionException from reopening the consumed row.

**Files changed:** `lib/features/packs/packs_screen.dart`, `test/features/packs/packs_screen_test.dart`, this task file.

**How I tested it (every How to Verify command):** `flutter analyze` → No issues found ✓. `flutter test test/features/packs/packs_screen_test.dart` → all green including the two new T-0084 tests ✓. `flutter test test/features/packs/` → **101/101 green** ✓. Full `flutter test --concurrency=1` → green, no REGEN_SNAPSHOT ✓ (result recorded in the submit commit message). One test-side iteration during development: the last-pack test first seeded the DB mutation after `bootScreen`, so the provider had already resolved with the two-pack list and the open died on the consumed row — moved the mutation before `pumpScreen` (the established before-pump doctoring pattern); production code needed no iteration.

**Concerns / assumptions:**
- `_chainInfoFor` now performs two awaited DB round-trips (provider future + getClub) per reveal push — microseconds on drift, and it only runs once per pack open, not per frame; the capsule is a push-time snapshot by design (mid-reveal sales refresh through the existing `queryBalance` callback, unchanged).
- The balance in the capsule comes from the DB rather than the (live) `clubProvider` stream — the task requires "balance must match the DB state at push time", and the stream could still be mid-emission right after the open's invalidations; the reveal's live refresh path still uses the provider.
- If the provider future rejects (DB error), `_reveal`'s caller catches nothing new — same failure surface as the pre-existing `await store.openPack` right above it (error SnackBar from `_open`/`_buy` catch blocks); behavior unchanged in kind.

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->

### Review 2026-11-09, attempt 1: PASS
- Ran every How to Verify command on HEAD 5deaa93: `flutter analyze` → No issues found; `flutter test test/features/packs/packs_screen_test.dart` → 15/15 green (13 prior + the two new T-0084 tests); `flutter test test/features/packs/` → 101/101 green; full `flutter test` → 942/942 green, `REGEN_SNAPSHOT` unset. All counts match the Developer Notes exactly.
- Diff audit (717e0e9): three files only — `packs_screen.dart` (the fix), `packs_screen_test.dart` (the two regression tests + shared helper), this task file. No provider definition/caching change, no engine/price/schema change — Out of Scope respected.
- AC-1 verified by test run: the FREE ×1 test seeds the starter's 2 GK rare packs, opens one, asserts `FREE ×1` present, `FREE ×2` absent (the stale read locked out) and the DB agreeing (1 survivor). The last-pack test doctors GK down to 1 owned pack pre-pump, opens it and asserts no `FREE` label anywhere plus the rare-GK offer price plate on the capsule.
- AC-2 verified by code-path uniformity plus integration: `PackChainInfo` is constructed in exactly one place (`packs_screen.dart:313` inside `_chainInfoFor`) and `_chainInfoFor` is called from exactly one place (`_reveal`, line 171) — the first reveal and the chain recursion both flow through the same async fresh-read path, so no second code path can produce a stale count. The last-pack test then drives the full chained hop end to end (OPEN ANOTHER → buy → open → chained reveal on stage). Note: the chained reveal's own capsule label is not directly asserted — acceptable because the shared path is proven fresh by the first test; recorded here for the record, not as a failure.
- AC-3 verified by test run: with zero owned left, tapping OPEN ANOTHER shows no SnackBar, spends exactly `offer.price` coins (asserted against `store.getClub()` before/after) and lands the chained reveal — the pre-fix code died here reopening the consumed row.
- Code-structure checks on the async rework: `context.mounted` re-check after the `_chainInfoFor` await before the push; `ScaffoldMessenger`/`l10n` captured before the first await in `_openAnotherInChain` (the file's own `_reveal` pattern) — no use-build-context-synchronously gaps, analyze clean. The balance now read from `store.getClub()` (DB truth at push time, per Requirement 1) while the reveal's live refresh still flows through `queryBalance` — consistent with the capsule's push-time snapshot design.
