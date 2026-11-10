---
id: T-0090
title: Add back, sell and upgrade actions to the team card full view
priority: high
status: done
attempts: 2
depends_on: [T-0089]
created: 2026-11-09
completed: 2026-11-10
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
- [x] The full view shows BACK / SELL / UPGRADE in that order, localized EN + AR, RTL-safe.
- [x] SELL on an XI card: the slot is auto re-picked (11 valid slots), the price is credited, the view pops, the team screen reflects the change.
- [x] SELL on a bench/reserve card sells and pops the same way.
- [x] UPGRADE with a duplicate: merge animation plays, the card shows +1 level in place, the view stays open; the button disables when no copy remains.
- [x] No duplicate → UPGRADE disabled; BACK and tap-anywhere dismiss unchanged.
- [x] `flutter analyze` zero warnings; `flutter test test/features/squad/ test/features/collection/` green; full `flutter test` green.

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


### Attempt 1 — implementation

**Summary of changes:** tapping a team card now manages the card in place — BACK / SELL / UPGRADE on the full-card view, UPGRADE the gold primary; SELL is squad-aware (an XI card's slot is cleared and auto re-picked inside the sale's own transaction), and an upgrade re-renders the stronger card in place with the view staying open.

1. `lib/features/collection/collection_store.dart` — new `sellPlayerFromSquad(ownedId)`: an XI member's slot is re-picked from everyone-but-him BEFORE the sale, inside one transaction (the mergeDuplicates pattern; GDD 6.4 invariant); a bench/reserve card just sells. `sellPlayers` was refactored into a shared `_sellCopies` (pricing, 'sold' status, ledger, coin credit — the bonus path untouched); its squad refusal moved to a pre-transaction check, so `sellPlayers` behavior is byte-for-byte the same for the Collection tab.
2. `lib/features/squad/player_card_reveal.dart` — the reveal takes `duplicates` / `onSell` / `onUpgrade` / `onRefreshRegistered`. Once the entrance finishes, callers with actions get the bottom bar: `[BACK ghost] [SELL steel] [UPGRADE gold]` (localized revealBack/Sell/Upgrade, flex 2/3/3, busy-gated); showcase-only callers keep the TAP TO CLOSE hint. UPGRADE disables when no copy remains. `refreshCard` re-renders the levelled card in place (re-sparked burst). Buttons swallow their own taps so tap-anywhere dismiss still works outside the bar.
3. `lib/features/squad/squad_screen.dart` — `_openCardView` computes the tapped player's other copies (the T-0089 owned-count grouping) and wires the flows. `_sellFromView`: the ad selling-bonus offer → confirm dialog → `sellPlayerFromSquad` → pop the reveal → invalidate squad/collection/club → snackbar 'Sold for N coins' — byte-for-byte the Collection tab's flow. `_upgradeFromView`: `mergeDuplicates` → (reduced-motion snackbar | `showCardMergeAnimation`) → re-reads the fresh row and the remaining copies → `refreshCard` in place.
4. l10n: `revealBack`/`revealSell`/`revealUpgrade` EN (Back/Sell/Upgrade) + AR (رجوع/بيع/ترقية), regenerated.
5. Tests — store (real drift): XI sale keeps 11 valid slots none of which is the sold man, credits exactly `sellPriceOfUpgraded`, row leaves the owned collection; bench sale leaves the XI untouched; un-owned id refuses. Reveal (widget): showcase keeps TAP TO CLOSE; the bar renders BACK/SELL/UPGRADE with UPGRADE disabled when no duplicate; BACK pops; UPGRADE runs the callback, +2→+3 renders in place, view stays open and the button disables once copies run out; SELL hands the card to the caller.

**Files changed:** `lib/features/collection/collection_store.dart`, `lib/features/squad/player_card_reveal.dart`, `lib/features/squad/squad_screen.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`, `lib/l10n/app_localizations.dart`, `lib/l10n/app_localizations_ar.dart`, `lib/l10n/app_localizations_en.dart`, `test/features/collection/collection_store_test.dart`, `test/features/squad/player_card_reveal_test.dart`, this task file.

**How I tested it (every How to Verify command):** `flutter analyze` → No issues found ✓. `flutter test test/features/squad/ test/features/collection/` → **286/286 green** ✓. Full `flutter test` → (result recorded in the submit commit message) ✓.

**Concerns / assumptions:**
- The sell/upgrade dialogs are EN literals inside `squad_screen.dart`, mirroring the Collection tab's identical literals — matching the file's current convention (its snackbars are English literals too); full localization of both tabs' dialog strings is a separate sweep, not this task's Requirements.
- `sellPlayerFromSquad` re-picks from a snapshot read inside the transaction; drift serializes writes on one connection, so the re-pick + sale stay atomic — same pattern mergeDuplicates already relies on.
- No integration test drives the full screen tap-through to the dialogs (the reveal + store layers are each covered directly; the screen wiring is the same pattern the Collection screen tests already pin).

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->

### Review 1 — 2026-11-10 — FAIL (5/6 criteria met; AC2 unmet)

**Ran (Flutter 3.47.9 / Dart 3.13.7):**
- `flutter analyze` → No issues found! ✓
- `flutter test test/features/squad/ test/features/collection/` → 286/286 green ✓
- `flutter test` → 989/989, "All tests passed!" ✓
- Diff scope check (commit ab4d41f): all 11 files inside the declared scope ✓. The reveal bar (BACK ghost / SELL steel / UPGRADE gold, flex 2/3/3, busy-gated, UPGRADE disabled with no copies, showcase callers keep TAP TO CLOSE), the squad_screen wiring (ad-bonus → confirm → sale → pop → invalidate; merge → animation → in-place refresh), the l10n keys (revealBack/Sell/Upgrade EN+AR, regenerated) and the `sellPlayers` refactor (squad refusal as a pre-transaction check, same message, same skip-on-missing semantics) all verified against the code ✓.

**FAIL — AC2: "SELL on an XI card: the slot is auto re-picked (11 valid slots)…" does not hold at the boundary — `sellPlayerFromSquad` can sell a club below a full starting XI.**

- Severity: high (soft-lock risk — the club cannot play matches until it re-acquires an 11th player).
- Repro (ran as a temporary drift in-memory test, deleted afterwards):
  1. Create a club; insert exactly 11 owned rows (playerIds 1..11) with squadSlot 0..10 — a full XI, empty bench/reserves.
  2. `store.getSquad()` → XI has 11 valid slots (sanity ✓).
  3. `store.sellPlayerFromSquad(xiMember.ownedId)`.
- Expected: the sale is refused when no replacement exists — the method's own doc comment and `squad_swap.dart:14` ("the starting XI can never be left with a hole") pin the GDD 6.4 invariant.
- Got (actual output): `XI slots after the sale: 10`, `owned players after the sale: 10` — the sale completed, coins were credited, and the XI was persisted 10-strong. `saveSquad` (`lib/features/collection/squad_store.dart:56-95`) performs no XI-count validation, and `squad.autoPick` simply leaves slots unassigned when the healthy pool runs short (`lib/features/squad/squad_engine.dart:281+`, "Fewer than 23 players simply leaves later slots unassigned"; injured players are excluded from the pool, so an all-injured remainder triggers the same hole).
- Downstream: the next match then throws `'A full starting XI is required to play a match'` (`lib/features/match/match_session.dart:235-239`) — the user is locked out of matches until a new pack provides an 11th player. Pre-T-0090 this state was unreachable: `sellPlayers` refused every squad member.
- What to do: inside `sellPlayerFromSquad`'s transaction, compute the re-pick assignment FIRST and refuse when it cannot cover the XI — `if (assignment.length < Formation.startingXiSize) throw const CollectionException('Selling would leave the starting XI short')` (nothing sold, coins untouched, the transaction rolls back). Add the unit test this review ran as a permanent case: exactly-11 club, XI sale throws, XI still 11, row still owned, coins unchanged. Keep everything else as is — the happy paths and the rest of the criteria are green.
- Non-blocking note for the owner: a defense-in-depth XI-count backstop inside `saveSquad` itself (mirroring the swap rules) would close the whole class of holes and is a good candidate for its own small task.

### Attempt 2 — review 1 fix (AC2)

**Summary of changes:** `sellPlayerFromSquad` can no longer sell a club below a full starting XI — review 1's boundary case (an exactly-11 club, or an all-injured remainder) is now refused inside the sale's own transaction and rolls back completely.

1. `lib/features/collection/collection_store.dart` — inside the transaction, the re-pick assignment is computed FIRST and checked: `if (assignment.length < Formation.startingXiSize) throw const CollectionException('Selling would leave the starting XI short')` before `saveSquad`. Nothing is sold, coins are untouched and the ledger unwritten — drift rolls the whole transaction back, so the XI stays 11-strong and the row stays owned. `autoPick` fills slots in ascending order, so `length < 11` is exactly "some XI slot is uncovered". Non-XI (bench/reserve) sales are unaffected — no re-pick, no guard.
2. `test/features/collection/collection_store_test.dart` — review 1's repro made permanent: inserts exactly 11 position-matched rows straight into XI 0..10 (direct drift inserts, no packs), asserts a full XI before, expects the exact refusal message, then asserts the rollback — XI still 11, the row still owned, coins unchanged.

**Files changed:** `lib/features/collection/collection_store.dart`, `test/features/collection/collection_store_test.dart`, this task file.

**How I tested it (every How to Verify command):** `flutter analyze` → No issues found ✓. `flutter test test/features/squad/ test/features/collection/` → **291/291 green** ✓ (the 4 T-0090 store tests including the new boundary case). Full `flutter test` → (result recorded in the submit commit message) ✓.

**Concerns / assumptions:**
- The reviewer's non-blocking note (a defense-in-depth XI backstop inside `saveSquad` itself) is deliberately NOT done here — it is the owner's call as a separate task, per the review's own wording.
- The guard counts assignment length, not slot keys: safe because autoPick only ever assigns contiguous ascending slots (verified in the engine's doc comment and the test's full-XI sanity check).

### Review 2 — 2026-11-10 — PASS (resubmission)

**Ran (Flutter 3.47.9 / Dart 3.13.7):**
- `flutter analyze` (current main) → No issues found! ✓
- `flutter test test/features/squad/ test/features/collection/` (current main) → **292/292 green** ✓
- Full `flutter test` at commit 2911fec (the submission-era tree, clean worktree) → **1007/1007, "All tests passed!"** ✓ — the run's log confirms the new boundary test actually executed and passed: "T-0090 (review 1): an exactly-11 club cannot sell an XI player — the XI is never left short". (Current main additionally carries T-0100's WIP whose own gates were never run by its developer — unrelated to this task; see T-0100's log.)
- Fix verification (commit 2fd7462): every point of review 1's "what to do" is done — the re-pick assignment is computed FIRST inside the sale's own transaction and refused with `CollectionException('Selling would leave the starting XI short')` when `assignment.length < Formation.startingXiSize`, BEFORE `saveSquad`, so nothing is sold, coins are untouched and drift rolls the whole transaction back. Review 1's repro is now a permanent test asserting the refusal message and the full rollback (XI still 11, row still owned, coins unchanged). The guard's length-based check is sound: `autoPick` fills the XI before the bench and never leaves an XI slot empty while a healthy body remains, so `length < 11` is exactly "some XI slot is uncovered" (the exactly-11 club and the all-injured remainder both hit it). The deferred `saveSquad` backstop is correctly left to the owner as a separate task, per review 1's own wording. Diff stays inside scope (store + test + this file). All six criteria met.

