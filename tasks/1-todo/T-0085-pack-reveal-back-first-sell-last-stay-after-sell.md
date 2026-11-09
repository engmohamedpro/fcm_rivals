---
id: T-0085
title: Rework the pack reveal actions - BACK first, SELL last, stay after selling
priority: high
status: todo
attempts: 0
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

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
