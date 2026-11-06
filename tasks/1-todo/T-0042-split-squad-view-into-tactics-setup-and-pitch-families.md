---
id: T-0042
title: Split squad_view.dart into tactics setup and pitch families
priority: medium
status: todo
attempts: 0
depends_on: []
created: 2026-11-06
completed:
---

# T-0042: Split squad_view.dart into tactics setup and pitch families

## Goal
Bring `lib/features/squad/squad_view.dart` (890 lines) under the ~800-line convention by separating the tactics-setup family from the pitch family behind a barrel, with zero behaviour change.

## Context
Measured on main `b2c0a27` (2026-11-06): `squad_view.dart` = 890 lines. Top-level map:
- Tactics setup family: `TacticsSetupView` :40, `_ControlCard` :196, `_TacticsOptionsSheet` :361-534 (≈495 lines).
- Pitch family: `SquadPitch` :535, `SquadCardRow` :661, `_EmptySlot` :768, `_EmptyBenchCard` :793, `_PitchPainter` :815 (≈356 lines).
Follow the barrel pattern (`fcm_widgets.dart`) so consumer imports of `squad_view.dart` keep working unchanged.

## Requirements
1. Split into: `tactics_setup_view.dart` (setup family incl. the options sheet) and `squad_pitch_view.dart` (pitch family incl. `_PitchPainter`); `squad_view.dart` remains as a barrel re-exporting both. Pure verbatim relocation, no behaviour change.
2. Every resulting file ≤800 lines; `flutter analyze` clean; full `flutter test` green with zero test edits.

## Out of Scope
- Any change to formation logic, drag/swap behaviour or tactics option sets (custom tactics framework T-0015..T-0018 output is frozen).
- Splitting any other squad file.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes with zero test edits
- [ ] EN/AR localization complete and RTL verified where applicable
- [ ] No performance or application-size regression
- [ ] Every resulting file ≤800 lines; `squad_view.dart` barrel keeps consumer imports stable
- [ ] `README.md` architecture table row for the squad UI family updated for the new module files

## How to Verify
```bash
wc -l lib/features/squad/squad_view.dart lib/features/squad/tactics_setup_view.dart lib/features/squad/squad_pitch_view.dart
flutter analyze
flutter test test/features/squad/
flutter test
```
Expected: every listed file ≤800 lines; analyzer clean; squad suite and full suite green with zero test edits.

---

## Developer Notes

## Review Log
