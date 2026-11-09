---
id: T-0091
title: Show a NEW badge only for first-time cards in the pack reveal
priority: high
status: todo
attempts: 0
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
- [ ] A drawn player the club already owned shows no badge; a first-time player shows the gold NEW badge after the flip.
- [ ] The same-player-twice-in-one-pack case flags only the first (unit-tested).
- [ ] The badge is localized EN + AR and never appears before the card flips.
- [ ] `ownedIds` sell behavior unchanged.
- [ ] `flutter analyze` zero warnings; `flutter test test/features/packs/` green; full `flutter test` green.

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

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
