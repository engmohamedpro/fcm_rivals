---
id: T-0095
title: Stop the tactic options sheet from covering the screen
priority: medium
status: done
attempts: 1
depends_on: []
created: 2026-11-09
completed: 2026-11-10
---

# T-0095: Stop the tactic options sheet from covering the screen

## Goal
The TACTIC OPTIONS bottom sheet opens as a compact sheet instead of a near-full-screen takeover (owner request 2026-11-09): its height caps at roughly 60% of the screen, with the rest of the content scrolling inside as it already does.

## Context
- The sheet opens via `showTacticsOptionsSheet` at `lib/features/squad/tactics_setup_view.dart:354-375` (`showModalBottomSheet` with `isScrollControlled: true`) and caps itself in `_TacticsOptionsSheetState.build` at lines 424-428: `ConstrainedBox(maxHeight: MediaQuery.sizeOf(context).height * 0.85)`. At 85% it reads as a full-screen takeover.
- The content (three `TacticsGroupScaffold` instruction sections, the mentality scale slider, DONE) already scrolls inside via the `SingleChildScrollView` at line 429 — only the cap changes.
- Keep `isScrollControlled: true`: the sheet needs the scrollable content plus the stepped slider to behave correctly; the height cap is what makes it compact.
- The TACTICS button that opens it lives on the shared control card, so the sheet is the same on the Team tab and the pre-match phase — the new cap applies to both (same widget, one behavior; no caller flag).
- Tests touching the sheet today: `test/features/squad/squad_view_test.dart:301` (opens → 'TACTIC OPTIONS' findsOneWidget) and `:349` (closed → findsNothing). Both keep passing — they assert presence, not height.

## Requirements
1. `lib/features/squad/tactics_setup_view.dart:427` — lower the cap from `height * 0.85` to `height * 0.62` (a compact sheet that leaves the pitch context visible behind it). Everything else about the sheet — drag handle, title, sections, slider, DONE, immediate-apply callbacks — stays as is.
2. The sheet's content keeps scrolling internally at the new cap (already the case via the `SingleChildScrollView`); verify no control ends up needing a scroll to reach DONE on a small screen (the DONE button stays reachable inside the scroll).
3. Add one widget test in `test/features/squad/squad_view_test.dart`: open the sheet and assert its rendered height is at most ~63% of the screen height (e.g. `tester.getSize` on the sheet surface / `BottomSheet` rect vs `tester.view`), and that DONE is still reachable (scroll + tap pops the sheet).

## Out of Scope
- Any change to the sheet's content, sections, mentality slider behavior or the immediate-apply model.
- The control card (the summary row is T-0092's) or the chemistry badge (T-0094).
- Making the cap a parameter or per-caller value — one compact cap for every caller.

## Acceptance Criteria
- [x] The TACTIC OPTIONS sheet opens at most ~62% of the screen height on the Team tab and the pre-match surface alike — the pitch stays visible behind it.
- [x] All controls (sections, slider, DONE) remain reachable by scrolling inside the sheet; DONE still pops it.
- [x] The new height-cap test and the existing sheet tests green; `flutter analyze` zero warnings; `flutter test test/features/squad/` green; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/squad/squad_view_test.dart
# Expected: all pass, including the new height-cap test

flutter test test/features/squad/
# Expected: whole squad suite green (pre-match sheet usage unbroken)

flutter test
# Expected: full suite green, no REGEN_SNAPSHOT
```

---

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->

### Review 1 — 2026-11-10 — PASS

**Ran (Flutter 3.47.9 / Dart 3.13.7, current main):**
- `flutter analyze` → No issues found! ✓
- `flutter test test/features/squad/squad_view_test.dart` → **21/21 green** ✓ (includes the new 'T-0095: the tactic options sheet opens compact' test)
- `flutter test test/features/squad/` → **247/247 green** ✓ (the existing open/closed, mentality slider, axis-drag and RTL sheet tests pass unmodified)
- Full `flutter test` → **1004/1004, "All tests passed!"** on the re-run ✓. The first run failed exactly one test — the known intermittent audio flake at `packs_screen_test.dart:801` ("the sequence must reach the done mark", Expected 1.0 / Actual 0.0), which has its own pending task (T-0103, stub audioplayers channels) and is unrelated to this change's area; the identical suite passed cleanly on the immediate re-run, and the packs suite also passed 132/132 standalone this session.
- Diff scope check (commit e1f105a): 3 files — the one-line cap change `height * 0.85` → `height * 0.62` with a T-0095 comment in `tactics_setup_view.dart` (drag handle, title, sections, slider, DONE, immediate-apply callbacks, `isScrollControlled` and the internal `SingleChildScrollView` all untouched), the new height-cap test, and this task file's front matter. All inside scope; no caller flag, the one cap applies to every caller ✓.
- The new test opens the sheet through the real `showTacticsOptionsSheet` entry on an 800×1600 viewport, asserts the rendered `BottomSheet` rect ≤ 63% of the screen height (992px cap vs 1008px bound — no slack for the old 85%), then `ensureVisible(DONE)` + tap pops the sheet — pinning both AC1 and AC2 ✓.

All three criteria met; every verify command run by the reviewer.

