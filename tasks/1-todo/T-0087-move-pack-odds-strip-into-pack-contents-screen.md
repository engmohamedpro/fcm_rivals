---
id: T-0087
title: Move the pack odds strip from the store cells into the pack contents screen
priority: medium
status: todo
attempts: 0
depends_on: []
created: 2026-11-09
completed:
---

# T-0087: Move the pack odds strip from the store cells into the pack contents screen

## Goal
The store grid cells stop showing the four-band rarity odds; that information moves into the pack contents (players list) screen, which opens from each cell's info button. The store stays a clean shelf, the odds live where the player actually browses the pack's players.

## Context
- The odds strip is in the store pack cell: `lib/features/packs/packs_store_widgets.dart:314-349` — a `SizedBox(height: 16)` + `Wrap` of chips under the price plate slot (which stays). One chip per band, each an atomic `Text('${label} ${percent}%')` (RTL-safe by design, T-0059 decision). Zero-weight bands are dropped.
- Helpers to move with it: `_bandChips` (`packs_store_widgets.dart:352-364`, reads `defaultPackOddsConfig.oddsFor(tier)`) and `_rarityLabel` (`366-372`, l10n keys `packRarityRare/Epic/Legendary/Premium` already exist in `lib/l10n/app_en.arb` + `app_ar.arb`).
- Destination: `lib/features/packs/pack_contents_screen.dart` (`PackContentsScreen`, players list sorted by rating, `_FiltersBar` at line 178). It already receives `category`/`scopeValue`/`tier` — the info button opens it via `_showContents` (`lib/features/packs/packs_screen.dart:336-357`) → `AppRoutes.packContents` (`lib/app/routes.dart:126`).
- Store cells otherwise unchanged: price plate, FREE badges, CLAIM/BUY, the info button itself.
- No widget test currently asserts the chips in the grid (odds tests are engine-level: `pack_engine_test.dart`, `pack_tier_bands_test.dart`) — but check `test/features/packs/` for anything that breaks when the strip leaves the cell.

## Requirements
1. `lib/features/packs/packs_store_widgets.dart` — remove the odds strip (`SizedBox(height: 16)` + `Wrap` of band chips) from the pack cell, and move `_bandChips`/`_rarityLabel` (or their equivalents) out of this file.
2. `lib/features/packs/pack_contents_screen.dart` — show the tier's four-band odds chips as a header strip above the players list (visible on open, not buried after scroll): same atomic-Text chip pattern, zero-weight bands still dropped, localized labels in EN and AR. The sheet has room, so bump the chip font from 9 to ~11 and keep the dim-text look.
3. No other change to either screen's layout or behavior.
4. Tests (real-DB harness in `test/features/packs/packs_screen_test.dart`):
   - the store grid shows no odds text (a localized rarity label with `%` findsNothing on the grid);
   - opening a pack's contents from a cell's info button shows that tier's non-zero bands (at least the top band's `label`+`%` present).

## Out of Scope
- Changing `PackOddsConfig` values, the odds engine, or prices.
- The pack reveal screen, the chain capsule, CLAIM/BUY flows.
- Any other store layout change (that is the whole point: only the strip moves).

## Acceptance Criteria
- [ ] The store grid cells render no odds/percentage text.
- [ ] The pack contents screen shows the tier's non-zero bands with percentages above the players list, in EN and AR, RTL-safe.
- [ ] Both new widget assertions exist and pass.
- [ ] `flutter analyze` zero warnings; `flutter test test/features/packs/` green; full `flutter test` green (regenerate goldens via the documented `REGEN_SNAPSHOT` flow only if a packs visual golden exists and the cell height change is intentional — say so in the notes).

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/packs/
# Expected: whole packs suite green including the two new assertions

flutter test
# Expected: full suite green, no unintended REGEN_SNAPSHOT
```

Manual: open the store — cells show pack art + price plate only; tap a cell's players (info) button — the contents sheet lists the pack's players with the odds chips above the list.

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
