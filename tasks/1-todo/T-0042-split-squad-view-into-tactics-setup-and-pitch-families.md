---
id: T-0042
title: Split squad_view.dart into tactics setup and pitch families
priority: medium
status: needs-review
attempts: 1
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
- **Summary of changes:** Split `squad_view.dart` (890 lines) verbatim into three files — `tactics_setup_view.dart` (498: `TacticsSetupView`, `_ControlCard`, `showTacticsOptionsSheet` and `_TacticsOptionsSheet`), `squad_pitch_view.dart` (400: `SquadPitch`, `SquadCardRow`, `_dragFeedback`, `_EmptySlot`, `_EmptyBenchCard`, `_PitchPainter` and `statsOf`, the public stat-triple helper whose only callers are the pitch widgets) and `squad_view.dart` as a 19-line barrel (19) re-exporting both, so consumer imports (`live_tactics_screen`, `pre_match_phases` and the three squad test files) stay unchanged. Relocation by a one-time line-slice script kept outside the repo with a multiset verifier proving every original code/doc line relocated exactly once — the barrel keeps the original library doc verbatim, and the only new content is the two file headers (docs + imports). **Zero visibility renames**: every symbol that crosses a file boundary (`TacticsSetupView`, `showTacticsOptionsSheet`, `SquadPitch`, `SquadCardRow`, `statsOf`) is already public, and every `_`-private widget is used only inside its destination file.
- **Files changed:** `lib/features/squad/squad_view.dart` (now the barrel), `lib/features/squad/tactics_setup_view.dart` (new), `lib/features/squad/squad_pitch_view.dart` (new), `README.md` (new "Squad UI" architecture-table row naming the two new module files and the barrel).
- **How I tested it:** Baseline on the unmodified tree: `flutter analyze` No issues found + `flutter test test/features/squad/` 222/222 passed exit 0. After the split: the `wc -l` gate lists 19/498/400, all ≤800; `flutter analyze` No issues found (the import sets were derived per file from a symbol-home grep — e.g. `PlayerCard` the model lives in `squad_engine.dart`, `FcmMiniCard` exports through the `player_card.dart` barrel, `mentalityToScale`/`mentalityFromScale` come via `../match/tactics.dart` re-exporting `team_tactics.dart` — so no unused and no missing imports appeared); `flutter test test/features/squad/` 222/222 passed exit 0 with zero test edits; full `flutter test` → `+709: All tests passed!` exit 0 (~5m23s) — identical test count to the baseline, zero test edits.
- **Concerns / assumptions:** (1) `statsOf` sits between the two families in the original and the task map doesn't name it; I assigned it to the pitch file because its only callers are `SquadPitch` and `SquadCardRow`, and it stays public via the barrel — flagging the choice for the reviewer. (2) The setup file's `squad_swap.dart` import clause narrowed from `show SquadDropTarget, SquadZone` to `show SquadZone` because the setup family never uses `SquadDropTarget` (pitch-only); keeping the wider clause would also have been lint-clean. (3) The full-suite baseline was not re-run pre-split (tree byte-identical to the `b19b1c2` full-suite run on this machine), so the post-split run against the same suite count is the meaningful comparison. None blocking.

## Review Log
