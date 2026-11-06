---
id: T-0041
title: Split packs_screen.dart into shell, store grid family and price widgets
priority: medium
status: todo
attempts: 0
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

## Review Log
