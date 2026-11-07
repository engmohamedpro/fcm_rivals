---
id: T-0041
title: Split packs_screen.dart into shell, store grid family and price widgets
priority: medium
status: needs-review
attempts: 1
depends_on: []
created: 2026-11-06
completed:
---

# T-0041: Split packs_screen.dart into shell, store grid family and price widgets

## Goal
Bring `lib/features/packs/packs_screen.dart` (901 lines) under the ~800-line convention by extracting the store-grid widget family and the price widgets, with identical screen behaviour.

## Context
Measured on main `b2c0a27` (2026-11-06): `packs_screen.dart` = 901 lines. Top-level map:
- Screen shell + state: `PacksScreen` :31, `_PacksScreenState` :38-469, chain models `_ChainTarget` :470, `_ChainReveal` :485 (≈470 lines).
- Store grid family: `_StoreGrid` :501, `_ScopeSection` :580, `_StorePackCell` :708 (≈295 lines).
- Price/button family: `_PricePlate` :796, `_ViewPlayersButton` :873 (≈106 lines).
The private underscore widgets become library-private in their new files or are exposed through a narrow barrel; screen behaviour and widget tree must stay identical.

## Requirements
1. Split into: `packs_store_widgets.dart` (grid family) and `pack_price_widgets.dart` (price plate + view-players button); `packs_screen.dart` keeps the shell, state and chain models. Pure verbatim relocation, no behaviour change.
2. Every resulting file ≤800 lines; `flutter analyze` clean; full `flutter test` green with zero test edits.

## Out of Scope
- Any change to pricing display logic, chain-reveal behaviour or the pack flow itself.
- Splitting any other packs file (T-0040 owns `pack_effects.dart`).

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes with zero test edits
- [ ] EN/AR localization complete and RTL verified where applicable
- [ ] No performance or application-size regression
- [ ] Every resulting file ≤800 lines
- [ ] `README.md` architecture table row for the packs UI family updated for the new module files

## How to Verify
```bash
wc -l lib/features/packs/packs_screen.dart lib/features/packs/packs_store_widgets.dart lib/features/packs/pack_price_widgets.dart
flutter analyze
flutter test test/features/packs/
flutter test
```
Expected: every listed file ≤800 lines; analyzer clean; packs suite and full suite green with zero test edits.

---

## Developer Notes
- **Summary of changes:** Split `packs_screen.dart` (901 lines) verbatim into three files — `packs_screen.dart` (491: the `PacksScreen` shell, `_PacksScreenState`, and the `_ChainTarget`/`_ChainReveal` chain models), `packs_store_widgets.dart` (314: `_StoreGrid`, `_ScopeSection`, `_StorePackCell` plus the `_scopeKey` helper they exclusively use) and `pack_price_widgets.dart` (126: `_PricePlate`, `_ViewPlayersButton`). Relocation by a one-time line-slice script kept outside the repo with a multiset verifier proving every original code/doc line relocated exactly once; the only new content is per-file library docs and import lines. Three visibility renames were forced by Dart library privacy (same pattern as T-0039/T-0040): `_StoreGrid`→`StoreGrid` (used by the shell), `_PricePlate`→`PricePlate` and `_ViewPlayersButton`→`ViewPlayersButton` (used across the store/price file boundary); `_ScopeSection`, `_StorePackCell`, `_ChainTarget`, `_ChainReveal` and `_scopeKey` each stay library-private to their own file. `packs_screen.dart`'s import set was adjusted accordingly: the `pack_effects.dart` import moved out with the cell that used it, and `packs_store_widgets.dart` came in.
- **Files changed:** `lib/features/packs/packs_screen.dart`, `lib/features/packs/packs_store_widgets.dart` (new), `lib/features/packs/pack_price_widgets.dart` (new), `README.md` (the "Pack visual effects" row became "Pack UI" and now also names the two new store module files).
- **How I tested it:** Baseline on the unmodified tree (byte-identical `lib/` to the one that passed the full suite `+709: All tests passed!` exit 0 at `ffcbec8`; the only later commit touches `tasks/`): `flutter analyze` No issues found + `flutter test test/features/packs/` 47/47 passed exit 0. After the split, the first analyze surfaced 5 findings, all fixed in the split script and re-verified: (1) two `undefined_getter` errors — `PackTier.accent`/`.stars` live on the `extension PackTierColor` in `pack_engine.dart`, so the new store file's `show` clause must name the extension (`show PackTier, PackTierColor`), and (2) three `use_key_in_widget_constructors` infos on the now-public widgets — fixed by adding an optional `super.key` parameter to the three renamed constructors (behaviour-neutral: never passed by call sites). Final gates: the `wc -l` gate lists 491/314/126, all ≤800; `flutter analyze` No issues found; `flutter test test/features/packs/` 47/47 passed exit 0; full `flutter test` → `+709: All tests passed!` exit 0 (~5m20s) — identical test count to the baseline, zero test edits.
- **Concerns / assumptions:** (1) The `super.key` additions are the one delta beyond pure relocation+renames — forced by the AC's "zero analyzer warnings" together with the Flutter lint on public widget constructors; no call site passes a key, so behaviour is unchanged. (2) The full-suite baseline was not re-run pre-split (tree byte-identical to the `ffcbec8` run on this machine), so the post-split run against the same suite count is the meaningful comparison. (3) `PackTierColor` appearing unused in `packs_screen.dart`'s `show` clause is pre-existing (it names the extension the file body uses implicitly); left verbatim. None blocking.

## Review Log
