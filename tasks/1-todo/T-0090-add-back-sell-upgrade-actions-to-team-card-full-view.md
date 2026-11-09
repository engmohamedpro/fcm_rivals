---
id: T-0090
title: Add back, sell and upgrade actions to the team card full view
priority: high
status: todo
attempts: 0
depends_on: [T-0089]
created: 2026-11-09
completed:
---

# T-0090: Add back, sell and upgrade actions to the team card full view

## Goal
Tapping a card on the team screen opens the full-card view with three actions at the bottom — BACK, SELL, UPGRADE — so the user can manage a squad card without hopping to the Collection tab. UPGRADE is the primary (gold) action.

## Context
- Today tapping a team card opens `showPlayerCardReveal` (`lib/features/squad/player_card_reveal.dart:43-60`): a showcase-only full screen — full-size `FcmPlayerCard` (width `min(w*0.68, 300)`, line 127; card at 245-257), tap-anywhere dismiss (line 135), "TAP TO CLOSE" hint (190-198), no actions. Its only caller is `squad_screen.dart:111`.
- The action-bearing bottom sheet (`showPlayerDetail`, `lib/features/collection/player_detail_sheet.dart:76-99`, actions 316-341) stays Collection-only — this task puts actions on the full-card view itself, not a sheet.
- SELL guard: `CollectionStore.sellPlayers` (`lib/features/collection/collection_store.dart:414+`) REFUSES a player who is in the squad ("Player is in the squad (slot …)"). Decision: implement a squad-aware sell for this screen (clear the XI slot, auto re-pick it, then sell — one transaction), mirroring how `mergeDuplicates` already handles the merged duplicate being in the XI (`collection_store.dart:552-557`). A disabled SELL would defeat the request — most tapped cards on the team screen ARE the XI.
- Sell price and flow reuse the Collection tab's pattern: `economy.sellPriceOfUpgraded(card.base, card.upgradeLevel)` and the ad selling-bonus offer before the sale (`collection_collection_screen.dart:200-230`) — both tabs must sell identically.
- UPGRADE: `store.mergeDuplicates({targetOwnedId, duplicateOwnedId})` (`collection_store.dart:492-565`), merging with the first other copy; then `showCardMergeAnimation` (`lib/features/collection/card_merge_animation.dart:53-74`). `FcmPlayerCard` already renders the `+N` level badge (`lib/core/ui/player_card.dart:293-321`).
- Owned-copy counts on the team screen arrive with T-0089 (collectionProvider grouping) — this task reuses that plumbing; that is why it depends on T-0089.
- l10n: labels need new keys in `lib/l10n/app_en.arb` + `app_ar.arb` (BACK / SELL with price / UPGRADE); RTL-safe layout.
- Tests: `test/features/squad/player_card_reveal_test.dart` exists; extend it on the real-DB harness.

## Requirements
1. `lib/features/squad/player_card_reveal.dart` — add a bottom action bar to the reveal: `[BACK] (ghost, leading)` `[SELL (steel, compact price)]` `[UPGRADE (gold, primary)]`. UPGRADE is disabled when no other copy exists (the T-0089 count plumbing). Keep tap-anywhere-to-dismiss as the implicit back.
2. Squad-aware sell in `lib/features/collection/collection_store.dart` (new method or a flag on `sellPlayers`): if the owned player holds an XI slot — clear the slot, auto re-pick it (the `mergeDuplicates` pattern), then sell — all in one transaction. Non-squad players sell exactly as today. Unit-test in `test/features/collection/collection_store_test.dart`: selling an XI player leaves 11 valid slots filled, credits the price, removes the row.
3. SELL flow on the view: ad selling-bonus offer (when available, same as the Collection tab) → confirm → squad-aware sell → pop the reveal → invalidate squad/collection/club providers.
4. UPGRADE flow on the view: merge with the first other copy → `showCardMergeAnimation` → the full view refreshes in place to the upgraded card (`upgradeLevel + 1`) and stays open; UPGRADE disables once no copy remains.
5. After SELL the view always pops (the sold row no longer exists); after UPGRADE it stays (the card still exists, stronger).
6. Tests (real-DB harness, `test/features/squad/player_card_reveal_test.dart` + store tests): tap a card with a duplicate → UPGRADE merges (level +1, copy count −1, view stays open, button disables when copies run out); tap an XI card → SELL re-picks the slot, credits coins and pops; a no-duplicate card → UPGRADE disabled; BACK pops.

## Out of Scope
- The team-grid upgradable mark (T-0089 owns it).
- The Collection tab's sheet UX, the pack reveal action bar (T-0085 owns that), transfer market, prices and the merge engine.
- Replacing the ad selling-bonus flow or the price formula.

## Acceptance Criteria
- [ ] The full view shows BACK / SELL / UPGRADE in that order, localized EN + AR, RTL-safe.
- [ ] SELL on an XI card: the slot is auto re-picked (11 valid slots), the price is credited, the view pops, the team screen reflects the change.
- [ ] SELL on a bench/reserve card sells and pops the same way.
- [ ] UPGRADE with a duplicate: merge animation plays, the card shows +1 level in place, the view stays open; the button disables when no copy remains.
- [ ] No duplicate → UPGRADE disabled; BACK and tap-anywhere dismiss unchanged.
- [ ] `flutter analyze` zero warnings; `flutter test test/features/squad/ test/features/collection/` green; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/squad/ test/features/collection/
# Expected: both suites green including the new store + reveal tests

flutter test
# Expected: full suite green
```

Manual: tap an XI card with a duplicate — UPGRADE (gold) merges and the card levels up in place; tap a bench card — SELL credits coins and closes; BACK closes without changes.

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
