---
id: T-0078
title: Remove the name and attribute boxes from the player card
priority: high
status: done
attempts: 1
depends_on: []
created: 2026-11-09
completed: 2026-11-09
---

# T-0078: Remove the name and attribute boxes from the player card

## Goal
No player card draws a box around the player name or around the attribute cells anymore — the name and the three stat columns sit directly on the card face, in every card surface of the game (owner decision 2026-11-09).

## Context
- There is ONE card design in the game: `FcmPlayerCard` (`lib/core/ui/player_card.dart`, doc: "One card design for every size — the pack reveal, the collection grid, the detail sheet, the pitch and bench"). All surfaces get the fix from one painter; `mini_card.dart` (pitch/bench chips) draws no name/attribute boxes (verified — only the card rim), so it needs nothing.
- The boxes live in `CardFacePainter.paint` (`lib/core/ui/player_card_painters.dart`):
  - Name bar: `nameBar` RRect at lines ~251-265 — a white 0.07 fill plus a rarity-coloured stroke (`g[0]`, `frameStrength`).
  - Attribute cells: the 3-cell loop at lines ~266-290 — `attributeCellPath(...)` per cell with a white 0.06 fill and a `0.2 + 0.5 * strength` stroke.
- What stays: the dark glass information panel behind name + attributes (lines ~220-246) and its top edge line — that is the readability backdrop, not a box around either element; the name/attribute TEXT positions in `player_card.dart` (name plate ~342-355, attribute row ~357-401) are untouched.
- `attributeCellPath` and `frameStrength` are defined in `lib/core/ui/card_rarity_art.dart` and used ONLY by these boxes (verify with grep before deleting). Their unit tests live at `test/core/ui/card_rarity_art_test.dart` (~lines 55-67+).
- Owner said "remove the border around" — the visible boxes are fill + stroke together, so remove BOTH per element; keeping the faint fills would keep visible boxes.

## Requirements
1. `lib/core/ui/player_card_painters.dart` — delete the name-bar fill and stroke draw calls and the whole 3-cell attribute loop (fill + stroke). No new decoration replaces them.
2. If `attributeCellPath` and/or `frameStrength` become unused in `lib/` after step 1, delete them from `lib/core/ui/card_rarity_art.dart` and their tests from `test/core/ui/card_rarity_art_test.dart`. If anything else still uses them, leave them and note it in Developer Notes.
3. Nothing else in the card changes: card rim/bezel, rarity art, glass panel, rating column, texts, foil sweep, walkout mask all render exactly as today.
4. Update `test/core/ui/player_card_test.dart` if it asserts the boxes or the primitives; keep every other assertion green.

## Out of Scope
- The card rim/bezel and the outer frame (the card still looks like a premium card — only the name and stat boxes go).
- The dark glass panel and its top edge.
- Any new attribute/name styling (shadows, spacing changes) — text rendering is untouched.
- `mini_card.dart` and the pack contents screens.

## Acceptance Criteria
- [x] `grep -rn "nameBar\|attributeCellPath" lib/` returns no matches (or only genuinely-still-used ones documented in Developer Notes).
- [x] Every surface that renders a player card (pack reveal, collection grid, detail sheet, pitch/bench reveal) shows name and attributes with no surrounding box — verified by running the app or the existing card widget tests.
- [x] `frameStrength`/`attributeCellPath` and their tests are removed if unused, and `test/core/ui/card_rarity_art_test.dart` still passes.
- [x] `flutter analyze` zero warnings; `flutter test test/core/ui/` green; full `flutter test` green with no `REGEN_SNAPSHOT`.

## How to Verify
```bash
grep -rn "nameBar\|attributeCellPath\|frameStrength" lib/
# Expected: no matches (or only documented still-used ones)

flutter analyze
# Expected: No issues found!

flutter test test/core/ui/
# Expected: card, class, rarity-art, mini-card, l10n suites all pass

flutter test
# Expected: full suite green, no REGEN_SNAPSHOT
```

---

## Review Log

### Review 2026-11-09, attempt 1: PASS
- File note: this task was authored without the Developer Notes / Review Log sections (older planning format); the developer's implementation summary lives in commit c1174ad's message. The Review Log section is added by this review per the reviewer workflow.
- Ran at af32eea (fresh Flutter 3.47.9 / Dart 3.13.7): `grep -rn "nameBar\|attributeCellPath\|frameStrength" lib/` → no matches; `flutter analyze` → No issues found; `flutter test test/core/ui/` → 47/47 green (46 committed + the T-0077 reviewer probe); full `flutter test` → 929/929 green with `REGEN_SNAPSHOT` unset (one shared run covering both tasks in review at this HEAD).
- Diff audit (c1174ad — pure deletions, 133−/2+ where the 2+ are the task-file front matter): `player_card_painters.dart` loses exactly the name-bar RRect block (fill + stroke) and the whole 3-cell `attributeCellPath` loop (fill + stroke); the shader edge, gem and brand-mark code around them is untouched, so the rim/bezel/rarity art/glass panel/rating column/texts/foil/walkout paths have zero diff lines. `card_rarity_art.dart` loses `attributeCellPath` + `frameStrength` — grep confirms zero remaining users in `lib/`. `card_rarity_art_test.dart` loses exactly the two tests of those primitives ("frame strength climbs with the rarity", "attribute cells have a different silhouette per rarity"); its other tests remain and pass. `player_card_test.dart` is untouched and green — it never asserted the boxes.
- Every surface inherits the fix from the one painter (`FcmPlayerCard` is the single card design; `mini_card` draws no name/attribute boxes by design) — covered by the existing card widget tests, all green. No out-of-scope changes.
