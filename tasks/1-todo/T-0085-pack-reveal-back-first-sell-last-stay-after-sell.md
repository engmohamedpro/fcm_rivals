---
id: T-0085
title: Rework the pack reveal actions - BACK first, SELL last, stay after selling
priority: high
status: needs-review
attempts: 1
depends_on: [T-0084]
created: 2026-11-09
completed:
---

# T-0085: Rework the pack reveal actions - BACK first, SELL last, stay after selling

## Goal
The pack reveal's action bar reads as the owner wants it (decision 2026-11-09): a BACK button at the START of the row replacing KEEP PLAYER, SELL at the END of the row, and after selling the user stays on the reveal so they can OPEN ANOTHER or go back — no forced pop.

## Context
- The action bar lives in `lib/features/packs/pack_opening_screen.dart:726-782`: today's Row is `[SELL (if _canSell)] [KEEP PLAYER | NEXT PLAYER i/n]` — SELL first on the left, the resolver second.
- Current behavior to change: on the LAST card both KEEP PLAYER and SELL end by popping (`_next()` at ~305 pops when `_index == players.length - 1`; `_sell()` at ~190-207 sells then calls `_next()`). The owner wants the last card to keep the screen after a sale.
- `_canSell` (~187): SELL exists only when the caller wired `onSell` and the card has an owned id — preview draws (key men) have no SELL; in that case the row holds a single full-width button.
- The chain capsule (OPEN ANOTHER) renders below the row on the last card only (`_showChain`, ~225) — it stays exactly where it is; T-0084 fixes its count.
- After a sale `_liveBalance` is refreshed (~198) so the capsule's affordability is already fresh — keep that.
- Labels in this file are hardcoded English by existing convention ('SELL', 'KEEP PLAYER', 'NEXT PLAYER  i/n') — keep that style for the new 'BACK' label.
- Tests to update: `test/features/packs/pack_opening_screen_test.dart` — 'SELL sells the revealed player and moves on' (~191), 'KEEP advances without selling' (~215), 'no onSell callback — SELL is hidden, KEEP works alone' (~236).

## Requirements
1. Last card: replace KEEP PLAYER with a `BACK` button positioned at the START of the row (it keeps the card — already owned — and pops the reveal without chaining, exactly today's KEEP PLAYER pop semantics).
2. SELL moves to the END of the row on every card (last and earlier). Earlier cards keep `NEXT PLAYER i/n` in the START position (same advance behavior); after selling an earlier card the flow still advances to the next player as today.
3. After a successful SELL on the LAST card, do NOT pop: stay on the reveal. The sold card's SELL control becomes disabled or visibly marked sold (no second sale attempt for the same card), while BACK and OPEN ANOTHER remain available so the user can open another or go back. A failed sale still stays on the card with SELL enabled (current error behavior).
4. Row layout rules: when SELL is absent (preview draws) the single BACK (last card) or NEXT PLAYER (earlier card) button fills the row; with both present, both are Expanded with the existing 10px gap. Start/End must follow the text direction (RTL mirrors automatically via Row order).
5. Update the three existing tests above to the new layout and add:
   - a test that BACK (last card) pops the reveal without calling `onSell` and without chaining;
   - a test that SELL on the last card sells, stays on screen (no pop), disables SELL for that card, and the chain capsule is still tappable;
   - an Arabic RTL test asserting the button order (BACK/NEXT PLAYER at the start, SELL at the end) mirrors correctly.

## Out of Scope
- The chain capsule's data and count (T-0084), the reveal timeline/animations, the handoff line.
- Localizing the action labels to ARB keys (the screen is hardcoded EN by convention today) — a separate l10n task can sweep this file later.
- Multi-select sell, sell-all, or any new sale economics.

## Acceptance Criteria
- [ ] On the last card the row reads BACK (start) then SELL (end); on earlier cards NEXT PLAYER i/n (start) then SELL (end); preview draws show the single full-width button.
- [ ] BACK pops the reveal without selling and without chaining; earlier-card NEXT PLAYER still advances.
- [ ] Selling on the last card keeps the screen open: no pop, the card's SELL is disabled/marked sold (no double-sell), and OPEN ANOTHER plus BACK remain usable.
- [ ] Selling an earlier card still advances to the next player (screen stays as today).
- [ ] The button order holds in RTL (Arabic test) and LTR.
- [ ] Updated + new tests green; `flutter analyze` zero warnings; `flutter test test/features/packs/` green; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/packs/pack_opening_screen_test.dart
# Expected: all pass — updated SELL/KEEP tests plus the new BACK, stay-after-sell and RTL order tests

flutter test test/features/packs/
# Expected: whole packs suite green

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

**Summary of changes:** the reveal's action row is reworked to the owner's 2026-11-09 decision. The resolver now sits at the START of the row — `NEXT PLAYER i/n` on earlier cards, a new `BACK` button on the last card (same pop-without-chaining semantics KEEP PLAYER had) — and SELL moved to the END on every card. Selling the LAST card no longer pops: the screen stays so the user can OPEN ANOTHER or go BACK, and the sold card's steel button flips to a disabled `SOLD` mark (no coin value, no second sale); selling an earlier card still advances as today, and a failed sale still re-enables SELL.

1. `lib/features/packs/pack_opening_screen.dart` — state gains `_sold` (a `Set<int>` of sold card indexes; cards are immutable by index) and the `_soldCard` getter. `_sell()` captures `isLastCard` before the await, and on success either advances (`_next()`, earlier cards, unchanged) or records the sale and stays (last card). New `_back()` handler pops without chaining. The row swaps order: resolver `Expanded` first, 10px gap, SELL `Expanded` last; SELL's label/coinValue/onPressed now respect the sold mark. Labels stay hardcoded EN per the file's convention. The chain capsule, its placement below the row, `_liveBalance` refresh after a sale, and the timeline/animations are untouched.
2. `test/features/packs/pack_opening_screen_test.dart` — the three named tests updated to the new layout (earlier-card SELL advances and lands on `BACK`; `NEXT PLAYER` advances without selling; preview draw shows the single full-width `BACK`), two legendary-flow assertions updated (`BACK` replaces `KEEP PLAYER`), plus three new tests: **BACK pops** the reveal as a route (no result — no chaining) without calling `onSell` while a chain capsule is offered; **SELL on the last card stays** — screen present, `sellCalls` exactly 1 after re-tapping the `SOLD` mark, coin value gone, `OPEN ANOTHER` + `BACK` still offered, then BACK still pops; **RTL order** — under `Directionality.rtl` the resolver's right edge sits right of SELL's left edge on both an earlier card (`NEXT PLAYER`) and the last (`BACK`), proving Row order mirrors with the text direction.
3. `test/features/packs/packs_screen_test.dart` — one reference updated: the store regression test's closing tap now hits `BACK` (the last card's resolver) instead of `KEEP PLAYER`; the flow it verifies (reveal pops, store stays alive) is unchanged.

**Files changed:** `lib/features/packs/pack_opening_screen.dart`, `test/features/packs/pack_opening_screen_test.dart`, `test/features/packs/packs_screen_test.dart`, this task file.

**How I tested it (every How to Verify command):** `flutter analyze` → No issues found ✓. `flutter test test/features/packs/pack_opening_screen_test.dart` → **14/14 green** (updated + new) ✓. `flutter test test/features/packs/` → **105/105 green** ✓. Full `flutter test --concurrency=1` → **950/950 green**, no REGEN_SNAPSHOT ✓ — after fixing one latent flake the first full run exposed in the T-0084 regression tests (see concerns): their shared helper pumped a fixed ~10.7s, but `randomProvider` is an UNSEEDED Random, so a drawn GK can run the 13s legendary or 20s premium timeline — on such draws the action bar was not live yet, the OPEN ANOTHER tap missed (hit-test warning), and no purchase happened. The helper now pumps UNTIL the action bar is live (keep-fade opacity 1, bounded 30s ≫ the 20s premium timeline); the T-0084 pair then passed 5 consecutive runs (each an unseeded, different draw) before the full-suite rerun.

**Concerns / assumptions:**
- The last-card stay uses `_sold` keyed by card index rather than owned id — equivalent here (one row per index), and index survives any future multi-draw reordering better than ownedId lookups would.
- `BACK` uses `arrow_back_rounded` where KEEP used `check_rounded` — a deliberate affordance change matching the new label; the task names the label, not the icon, and a back arrow reads truer to "leave with the card kept".
- The earlier-card SELL path still calls `_next()` AFTER the sale completes — same as today's `_sell` → `_next` order, so the advance timing users know is unchanged.
- The SOLD mark reuses the steel style at 0.55 opacity (FcmButton's disabled state) — visually distinct from the priced SELL without introducing a new style token; no new design-system surface.
- Environment note: this session started on a fresh sandbox (Flutter SDK re-provisioned at the project's pinned stable 3.47.9); all gates were re-run from scratch on it, not carried over from the previous session.
- The unseeded-draw flake above was MY latent bug in the T-0084 tests (shipped green by luck in that session's runs), not a T-0085 regression — T-0085 just perturbed the draw sequence enough to surface it. The fix is in the tests only; no production change was involved.

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
