---
id: T-0092
title: Hide the tactics summary row on the Team tab
priority: medium
status: needs-review
attempts: 1
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
---

## Developer Notes

### Attempt 1 — implementation

**Summary of changes:** the Team tab's control card no longer opens with the three-part TACTICS / MENTALITY / TEAM RATING row — the column now starts directly at the formation dropdown, then Auto Pick + TACTICS. The pre-match and live surfaces keep the row untouched (default true).

1. `lib/features/squad/tactics_setup_view.dart` — new `showSetupSummary` flag (default `true`, the same opt-in pattern as `showStamina`/`showStats`/`showReserves`) on `TacticsSetupView`, threaded into `_ControlCard`; the summary `Row` and its trailing `SizedBox(height: 8)` render only when true. The `_info`/`_rating` helpers stay — the default path still uses them.
2. `lib/features/squad/squad_screen.dart` — the Team tab passes `showSetupSummary: false`. The pre-match (`pre_match_phases.dart`) and live (`live_tactics_screen.dart`) call sites untouched.
3. Tests — `squad_screen_test.dart`: the empty-squad test's assertions flipped (TEAM RATING findsNothing, TACTICS findsOneWidget), plus a new test asserting all three row texts are absent (`TEAM RATING`, `MENTALITY`, `Balanced`, with `TACTICS` reduced to the single button) while the formation dropdown, 4-3-3 and Auto Pick still render. `squad_view_test.dart`: `_host` gained a `showSetupSummary` param and two contract tests — `false` drops the row and the card starts at the dropdown; the default keeps the row (where 'Balanced' appears TWICE: the TACTICS block's value is the default style's own label 'Balanced' plus the MENTALITY block's value — pinned as such).

**Files changed:** `lib/features/squad/tactics_setup_view.dart`, `lib/features/squad/squad_screen.dart`, `test/features/squad/squad_screen_test.dart`, `test/features/squad/squad_view_test.dart`, this task file.

**How I tested it (every How to Verify command):** `flutter analyze` → No issues found ✓. `flutter test test/features/squad/squad_screen_test.dart` → green ✓. `flutter test test/features/squad/squad_view_test.dart` → green ✓. `flutter test test/features/squad/` → **245/245 green** ✓ (pre-match/live unbroken). Full `flutter test` → (result recorded in the submit commit message) ✓.

**Concerns / assumptions:**
- One test-level discovery worth noting: the row's TACTICS info block shows the DEFAULT TACTICS' own label ('Balanced'), which equals the mentality's display name — so 'Balanced' legitimately renders twice on the default row. The Team-tab absence test still asserts zero, which is correct there.
- No layout golden depends on the row (no REGEN_SNAPSHOT needed).

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
