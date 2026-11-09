---
id: T-0092
title: Hide the tactics summary row on the Team tab
priority: medium
status: todo
attempts: 0
depends_on: []
created: 2026-11-09
completed:
---

# T-0092: Hide the tactics summary row on the Team tab

## Goal
The Team tab's control card no longer shows the three-part summary row — TACTICS / MENTALITY / TEAM RATING — that reads "Tactics Balanced / Mentality Balanced / Team rating 77" (owner request 2026-11-09). The pre-match and live surfaces keep it.

## Context
- The row lives in `lib/features/squad/tactics_setup_view.dart:220-234`: the first `Row` inside `_ControlCard` — `_info('TACTICS', tactics.label)`, `_info(l10n.tacticsMentality.toUpperCase(), …)` and `_rating()` — closed by the `SizedBox(height: 8)` at line 235.
- `_ControlCard` is private and shared by every `TacticsSetupView` caller: `squad_screen.dart:88` (Team tab), `pre_match_phases.dart:105` and `live_tactics_screen.dart:144`. The owner asked for the Team tab only, so the change must be opt-in per caller — the same pattern as the existing `showStamina` / `showStats` / `showReserves` flags on the view.
- With the row hidden the card's column starts directly at the formation dropdown (`tactics_setup_view.dart:239`).
- Tests that assert the row today: `test/features/squad/squad_screen_test.dart:100` (`TEAM RATING` findsOneWidget on the Team tab — flips to absent) and `:102` (`find.text('TACTICS')` findsNWidgets(2) — one is this row's label, the other the TACTICS button, so it becomes 1). `test/features/squad/squad_view_test.dart:154/169` pump `TacticsSetupView` directly with defaults — those keep passing and pin the default-true behavior.
- The `mentalityDisplayName` helper and the ARB keys stay: the sheet's mentality scale still uses them.

## Requirements
1. `lib/features/squad/tactics_setup_view.dart` — add `showSetupSummary` (default `true`) to `TacticsSetupView`, thread it into `_ControlCard`, and build the summary `Row` (lines 220-234) plus the `SizedBox(height: 8)` after it only when it is true. When false the card column starts at the formation dropdown.
2. `lib/features/squad/squad_screen.dart:88` — pass `showSetupSummary: false` to the Team tab's `TacticsSetupView`. Do NOT touch the pre-match (`pre_match_phases.dart:105`) or live (`live_tactics_screen.dart:144`) call sites — they keep the default and the row.
3. Update the Team-tab assertions in `test/features/squad/squad_screen_test.dart` (the `TEAM RATING` / `TACTICS`-count lines above), and add one test that pumps the Team tab and asserts all three row texts are absent (`TEAM RATING`, the localized mentality label value 'Balanced' via `find.text`, and 'TACTICS' reduced to the single button) while the formation dropdown, Auto Pick and TACTICS button still render.
4. Add one test in `test/features/squad/squad_view_test.dart` that pumps `TacticsSetupView` with `showSetupSummary: false` and asserts the row is gone, and one with the default that asserts it still renders — pinning the opt-in contract for the other two callers.

## Out of Scope
- The pre-match and live surfaces' control cards (they keep the row).
- The formation dropdown, Auto Pick / TACTICS buttons, the tactic options sheet (T-0095 owns its height).
- Any change to how tactics / mentality / rating are computed or persisted.
- Removing the now-unused `_info` / `_rating` helpers if any caller still shows the row — they are still used by the default path; do not delete them.

## Acceptance Criteria
- [ ] On the Team tab the control card shows no TACTICS/MENTALITY/TEAM RATING row: none of the three texts render; the card reads formation dropdown then Auto Pick + TACTICS.
- [ ] The pre-match and live tactics screens still show the summary row exactly as today (default `showSetupSummary: true`).
- [ ] Updated + new tests green (Team-tab absence, view-level opt-in/opt-out contract).
- [ ] `flutter analyze` zero warnings; `flutter test test/features/squad/` green; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/squad/squad_screen_test.dart
# Expected: all pass, including the new absence test

flutter test test/features/squad/squad_view_test.dart
# Expected: all pass, including the two new showSetupSummary contract tests

flutter test test/features/squad/
# Expected: whole squad suite green (pre-match/live unbroken)

flutter test
# Expected: full suite green, no REGEN_SNAPSHOT
```
