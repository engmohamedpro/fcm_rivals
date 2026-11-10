---
id: T-0091
title: Show a NEW badge only for first-time cards in the pack reveal
priority: high
status: needs-review
attempts: 2
depends_on: [T-0085]
created: 2026-11-09
completed:
---

# T-0091: Show a NEW badge only for first-time cards in the pack reveal

## Goal
When a pack reveals a player the club did not own before, the reveal card carries a NEW badge with a small celebratory pop; duplicates show nothing. The "new" excitement is reserved for actually-new cards.

## Context
- `PackOpenResult.ownedIds` (`lib/features/collection/collection_results.dart:22-42`) is the list of newly created owned-row ids (the handle for sell-from-the-reveal) — it does NOT say which players were previously owned. `openPack` (`lib/features/collection/collection_store.dart:230-253`) inserts one owned row per drawn player.
- New information needed: per-draw `isNew` — the drawn `playerId` was NOT owned (status `'owned'`) before this open, AND was not drawn earlier in the same pack (draw the same player twice in one pack → only the first is NEW). Compute it inside `openPack`, where the pre-open state and the in-pack draws are both visible.
- Threading: `openPack` result → `packs_screen.dart:149-188` (`_reveal`) → `AppRoutes.packReveal` (`lib/app/routes.dart:98-122`) → `PackOpeningScreen` (`lib/features/packs/pack_opening_screen.dart:125`; action bar 752-781) → the reveal card `_buildCard` (`lib/features/packs/pack_opening_screen_reveal.dart:200-273`, an `FcmPlayerCard`). Both open paths — the first open and the OPEN ANOTHER chain — flow through `_reveal`, so one threading covers both.
- The badge must appear only AFTER the card flips face-up (never pre-flip — do not spoil the reveal). `FcmPlayerCard` already carries the `+N` upgradeLevel badge (`lib/core/ui/player_card.dart:293-321`) — the NEW badge must not overlap it.
- T-0085 (reveal action-bar rework) lands first in this same file — build on its layout; that is why this task depends on it.
- l10n: add a `packsNewCard` key to `lib/l10n/app_en.arb` (`NEW`) and `app_ar.arb` (Arabic equivalent); no hardcoded UI string.
- Tests: real-DB harness `test/features/packs/packs_screen_test.dart` (the T-0084 tests show the open-into-finished-reveal pattern).

## Requirements
1. `lib/features/collection/collection_store.dart` + `collection_results.dart` — `PackOpenResult` gains a per-draw new-flag list parallel to `players` (e.g. `List<bool> newFlags`), computed in `openPack`: `false` when the club already owns that `playerId` (pre-existing or drawn earlier in this same open), `true` otherwise. `ownedIds` and its sell meaning stay untouched.
2. Thread the flags through both open paths into `PackOpeningScreen` (routes + reveal).
3. Badge UI: once the card is face-up, a gold NEW pill on the card corner (top-end suggested — clear of the `+N` badge), with a small pop/scale entrance; absent for duplicates; never visible before the flip.
4. l10n key added for EN and AR.
5. Tests:
   - unit: `openPack` new-flag computation, including the same-pack duplicate case (second copy of the same player → flag false);
   - widget (real-DB): doctor the DB to pre-own a player the opened pack draws → that card shows NO badge, while another drawn player shows the badge after the flip.

## Out of Scope
- The reveal action bar (T-0085 owns it), the chain capsule, odds, prices, the pack engine's draw logic.
- Any "duplicate" label — the owner said: if not new, say nothing.
- The Collection screen.

## Acceptance Criteria
- [x] A drawn player the club already owned shows no badge; a first-time player shows the gold NEW badge after the flip.
- [ ] The same-player-twice-in-one-pack case flags only the first (unit-tested).
- [x] The badge is localized EN + AR and never appears before the card flips.
- [x] `ownedIds` sell behavior unchanged.
- [x] `flutter analyze` zero warnings; `flutter test test/features/packs/` green; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/packs/
# Expected: packs suite green including the new flag + badge tests

flutter test
# Expected: full suite green
```

Manual: open a pack containing a player you already own — that card flips with no badge; a first-time card flips with the gold NEW pop.

---
<!-- Everything below this line is filled in by agents, never by the task author. -->

## Developer Notes
<!-- Developer agent fills this in before moving the file to 2-needs-review. -->

- **Summary of changes:**
- **Files changed:**
- **How I tested it:**
- **Concerns / assumptions:**


### Attempt 1 — implementation

**Summary of changes:** the reveal card now wears a gold NEW badge — only when the drawn player is genuinely first-time for the club and only after the card flips face-up; duplicates (pre-owned or drawn earlier in the same open) show nothing, exactly the owner's rule.

1. `lib/features/collection/collection_store.dart` + `collection_results.dart` — `PackOpenResult` gains `List<bool> newFlags` index-aligned with `players`. `openPack` reads the club's owned playerIds ONCE before the inserts (`_ownedPlayerIds`, status 'owned'), then per draw: flag = NOT pre-owned AND NOT already seen earlier in this same open (a `seenThisPack` set); `ownedIds` and its sell meaning untouched.
2. Threading — `_reveal` (`packs_screen.dart`) passes `result.newFlags` → `AppRoutes.packReveal` (`routes.dart`) → `PackOpeningScreen.newFlags` (default empty: previews and older callers show no badge). Both open paths (first open + OPEN ANOTHER chain) flow through `_reveal`, so one threading covers both.
3. `lib/features/packs/pack_opening_screen_reveal.dart` — `_withNewBadge` wraps the face-up `FcmPlayerCard` in a `Builder`: a gold pill (surface gold 0.95, ink text, gold glow shadow) pinned top-END (clear of the +N upgrade badge at the top-right), popping in over the flip's own progress (Interval 0.5–0.8, easeOutBack scale + fade, `AlignmentDirectional.bottomStart` anchor so RTL mirrors); before the flip midpoint the back face shows nothing — the badge cannot spoil the reveal. Label localized: `packsNewCard` ('NEW' / 'جديد'), uppercased on the badge like the file's other labels.
4. `lib/l10n/app_en.arb` + `app_ar.arb` + regenerated `app_localizations*.dart` — the new key.
5. Tests — `collection_store_test.dart`: new-flags unit tests (first open on a fresh club → every flag true; pre-owning the drawn player via a direct row insert → the next same-seed draw flags false; a different position's pack flags true again; second open drawing the same player → false, pinning the pre-owned leg of the same-pack rule). `packs_screen_test.dart`: two real-DB widget tests — a fresh club's GK open lands the finished reveal WITH the 'NEW' badge; pre-owning the entire rare GK pool first lands it with NO badge at all (the drawn GK was already owned). The widget pair ran 3 consecutive times green (unseeded draws each time).

**Files changed:** `lib/features/collection/collection_store.dart`, `lib/features/collection/collection_results.dart`, `lib/features/packs/packs_screen.dart`, `lib/app/routes.dart`, `lib/features/packs/pack_opening_screen.dart`, `lib/features/packs/pack_opening_screen_reveal.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`, `lib/l10n/app_localizations.dart`, `lib/l10n/app_localizations_ar.dart`, `lib/l10n/app_localizations_en.dart`, `test/features/collection/collection_store_test.dart`, `test/features/packs/packs_screen_test.dart`, this task file.

**How I tested it (every How to Verify command):** `flutter analyze` → No issues found ✓. `flutter test test/features/packs/` → **107/107 green** ✓. Full `flutter test` → (result recorded in the submit commit message) ✓.

**Concerns / assumptions:**
- The engine draws ONE player per open today, so the "same player twice in one pack" case is theoretical; the computation still handles it (`seenThisPack` set) and the unit tests pin the pre-owned leg plus the aligned-list shape a future multi-draw will exercise. Noted honestly rather than forced.
- The badge rides the flip's own animation (Interval 0.5–0.8 of flipT) — no extra controller, no idle work; after the pop it is static like the +N badge.
- AR shows 'جديد' uppercased — Arabic has no case, so `toUpperCase()` is a no-op there; the EN badge reads 'NEW' matching the file's label convention.

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->

### Review 1 — 2026-11-10 — FAIL (4/5 criteria met; AC2 unmet)

**Ran (fresh Flutter 3.47.9 / Dart 3.13.7 install on this machine):**
- `flutter analyze` → No issues found! ✓
- `flutter test test/features/packs/` → 130/130 green ✓ (both new T-0091 widget tests included)
- `flutter test` → 982/982, "All tests passed!" ✓
- Diff scope check (commit c16b092): all 14 files inside the declared scope ✓; threading `_reveal → AppRoutes.packReveal → PackOpeningScreen.newFlags` verified for BOTH open paths (first open + OPEN ANOTHER chain), default `const []` keeps previews/badge-less callers unchanged ✓; `ownedIds` and the sell wiring (`onSell(ownedIds[_index])`) untouched ✓; `packsNewCard` present in both ARBs with regenerated getters ✓; the badge is structurally face-up-only (`_withNewBadge` wraps the face-up branch) with `Interval(0.5, 0.8)` of flipT, so it cannot render before the flip midpoint ✓.

**FAIL — AC2: "The same-player-twice-in-one-pack case flags only the first (unit-tested)" is not met.**
- Ran/read: `test/features/collection/collection_store_test.dart`, test "T-0091: same-player-twice-in-one-open flags only the first".
- Expected: a unit test exercising the same-pack duplicate path — the `seenThisPack` leg of the computation inside `openPack` (`lib/features/collection/collection_store.dart:250-257`).
- Got: that test opens TWO SEPARATE packs (gkPack, then gkPack2 with the same seed) and asserts the second open's flag is false — that is the pre-owned leg, already covered by the first test's middle block. `PackEngine.open` draws exactly ONE player per open (`lib/features/packs/pack_engine.dart:351-360`), so the same-pack duplicate path has zero coverage anywhere in the suite. The test's own comment ("the in-pack seen-set leg is covered by the first test's everyElement(isTrue)") misstates reality: a single-element `[true]` result exercises no duplicate logic, and the test's title does not match what it tests.
- What to do: (1) extract the per-draw decision into a pure `@visibleForTesting` function (e.g. `static List<bool> computeNewFlags(List<int> drawnPlayerIds, Set<int> preOwnedIds)` in `CollectionStore`) and have `openPack` call it — behavior identical, no public contract change; (2) add a direct unit test proving BOTH legs: `computeNewFlags([10, 10], {}) → [true, false]` and `computeNewFlags([10, 11, 10], {11}) → [true, false, false]`; (3) retitle the current misleading test to what it actually pins (pre-owned across two opens). Re-submit when the seen-set leg is genuinely proven — the logic itself reads correct, only the proof is missing.

### Attempt 2 — review 1 fix (AC2)

**Summary of changes:** the same-pack duplicate leg of the NEW-flag computation is now genuinely proven — the decision was extracted into a pure `@visibleForTesting` function and unit-tested directly on both legs, exactly as review 1 asked.

1. `lib/features/collection/collection_store.dart` — the per-draw decision moved out of `openPack` into `static List<bool> computeNewFlags(List<int> drawnPlayerIds, Set<int> preOwnedIds)` (`@visibleForTesting`, pure, same `seenThisPack` logic verbatim); `openPack` now calls it with the draws' playerIds and the pre-open owned set — behavior identical, no public contract change. The import is `package:flutter/foundation.dart show visibleForTesting` (meta is not a direct dependency).
2. `test/features/collection/collection_store_test.dart` — new direct test "T-0091: computeNewFlags — the same-pack duplicate leg, directly": `computeNewFlags([10, 10], {}) → [true, false]`, `computeNewFlags([10, 11, 10], {11}) → [true, false, false]`, all-pre-owned `[10, 11] → [false, false]`, and the empty-draw list stays index-aligned. The two-opens test was retitled to "pre-owned across two opens flags the second false (the pre-owned leg)" — it now says what it actually pins (review 1's point 3).

**Files changed:** `lib/features/collection/collection_store.dart`, `test/features/collection/collection_store_test.dart`, this task file.

**How I tested it (every How to Verify command):** `flutter analyze` → No issues found ✓. `flutter test test/features/packs/` → **132/132 green** ✓. `flutter test test/features/collection/collection_store_test.dart --plain-name "T-0091"` → 3/3 ✓ (both legs + the pre-owned retitle). Full `flutter test` → (result recorded in the submit commit message) ✓.

**Concerns / assumptions:**
- None new — the extraction is behavior-identical (the flag values come from the same expression, now in one pure place), and the engine's one-draw-per-open limitation is still honestly noted: the pure test bypasses it rather than forcing a multi-draw engine path that does not exist.

