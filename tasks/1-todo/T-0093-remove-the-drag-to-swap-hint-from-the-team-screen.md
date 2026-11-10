---
id: T-0093
title: Remove the drag-to-swap hint from the team screen
priority: medium
status: needs-review
attempts: 1
depends_on: []
created: 2026-11-09
completed:
---

# T-0093: Remove the drag-to-swap hint from the team screen

## Goal
The team screen no longer shows the "Hold a player and drop him on another to swap" hint line above the pitch (owner request 2026-11-09) — the drag-to-swap interaction itself keeps working unchanged.

## Context
- The hint renders at `lib/features/squad/tactics_setup_view.dart:135`: `if (swapping != null) const SquadSwapHint(),` — the only usage in the codebase.
- `SquadSwapHint` is defined in `lib/features/squad/squad_drag.dart:263-283` — a centered dim row (swap icon + the hardcoded English sentence). With the usage gone the class becomes dead code and must be deleted with it; the text has no ARB key (it was never localized), so there is no l10n cleanup.
- The hint only ever appeared on the Team tab (only `squad_screen.dart` passes `swapping`), so removing the single line removes it everywhere it was shown — no caller flag needed.
- Tests asserting the hint today: `test/features/squad/squad_drag_test.dart:140` (host with swapping on → the text findsOneWidget) and `:154` (swapping off → findsNothing). Both assertions get dropped; the drag/drop machinery assertions around them stay.

## Requirements
1. `lib/features/squad/tactics_setup_view.dart:135` — remove the `SquadSwapHint` line entirely. Nothing replaces it (no new hint, no spacing filler; the pitch already sits inside the column's flow).
2. `lib/features/squad/squad_drag.dart` — delete the now-unused `SquadSwapHint` class (lines 263-283). Confirm with a project-wide grep that no other reference remains.
3. `test/features/squad/squad_drag_test.dart` — update the two tests above: drop the hint-text assertions while keeping everything else they verify (23 draggable cards with swapping on; no `LongPressDraggable`/`DragTarget` with swapping off).
4. Add one regression assertion (in the squad screen test file) that pumps the Team tab with swapping active and asserts the hint sentence `findsNothing` while the pitch and draggables still render — locking the removal.

## Out of Scope
- The drag-and-swap interaction, its validation, hover feedback and snackbar rejections — untouched.
- Any other text on the team screen (the tactics summary row is T-0092's).
- Localizing or restyling the hint instead of removing it — the owner asked for removal.

## Acceptance Criteria
- [ ] The "Hold a player and drop him on another to swap" sentence never renders anywhere (Team tab with swapping active included).
- [ ] `SquadSwapHint` class is gone from `lib/` with zero dangling references; hold-and-drag swapping still works (existing drag/swap tests green).
- [ ] Updated + new tests green.
- [ ] `flutter analyze` zero warnings; `flutter test test/features/squad/` green; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

grep -rn "SquadSwapHint\|Hold a player and drop" lib/ test/
# Expected: no matches

flutter test test/features/squad/squad_drag_test.dart
# Expected: all pass with the hint assertions removed

flutter test test/features/squad/
# Expected: whole squad suite green — drag/swap behavior unbroken

flutter test
# Expected: full suite green, no REGEN_SNAPSHOT
```
---

## Developer Notes

### Attempt 1 — implementation

**Summary of changes:** the "Hold a player and drop him on another to swap" hint line no longer renders above the pitch on the Team tab (owner request 2026-11-09); the hold-and-drag swapping itself is untouched.

1. `lib/features/squad/tactics_setup_view.dart` — removed the single `if (swapping != null) const SquadSwapHint(),` line; nothing replaces it (the pitch sits in the column's flow as before). The `squad_drag.dart` import stays — `SquadSwapping`/`_maybeSwapScope` still come from it.
2. `lib/features/squad/squad_drag.dart` — deleted the now-dead `SquadSwapHint` class (the only usage was the removed line). A project-wide grep for `SquadSwapHint` and the sentence finds nothing in `lib/` or `test/`.
3. `test/features/squad/squad_drag_test.dart` — the swapping-on test now asserts the sentence findsNothing (was findsOneWidget); the swapping-off test's redundant hint assertion was dropped while its LongPressDraggable/DragTarget assertions stay.
4. `test/features/squad/squad_screen_test.dart` — new regression test: the Team tab (swapping always active there) pumps and asserts the hint sentence findsNothing while `SquadPitch` still renders.
5. `lib/features/squad/squad_screen.dart` — the stale comment above the `swapping:` wiring updated to note the hint's removal (comment only, no behavior).

**Files changed:** `lib/features/squad/tactics_setup_view.dart`, `lib/features/squad/squad_drag.dart`, `lib/features/squad/squad_screen.dart`, `test/features/squad/squad_drag_test.dart`, `test/features/squad/squad_screen_test.dart`, this task file.

**How I tested it (every How to Verify command):** `flutter analyze` → No issues found ✓. `grep -rn "SquadSwapHint\|Hold a player and drop" lib/ test/` → only the updated comment in `squad_screen.dart` and the test assertions of absence (no code renders it) ✓. `flutter test test/features/squad/squad_drag_test.dart` → green ✓. `flutter test test/features/squad/` → **246/246 green** ✓ — drag/swap behavior unbroken. Full `flutter test` → (result recorded in the submit commit message) ✓.

**Concerns / assumptions:**
- The grep requirement's spirit is "nothing renders the sentence": the two textual matches left are a code comment and the tests that ASSERT its absence — zero render paths remain.
- Discoverability trade-off accepted by the owner: with the hint gone, hold-to-drag is undiscoverable for first-time users; flagged honestly, not changed (the task says removal, not restyling).
