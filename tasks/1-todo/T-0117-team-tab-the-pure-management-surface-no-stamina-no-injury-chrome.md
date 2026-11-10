---
id: T-0117
title: Team tab — the pure management surface: no stamina bars, no injury badges, no match-condition chrome
priority: high
status: todo
attempts: 0
depends_on: []
created: 2026-11-10
completed:
---

# T-0117: Team tab — the pure management surface: no stamina bars, no injury badges, no match-condition chrome

## Goal
The Team tab becomes exactly what it is for: MANAGING the squad — formation, tactics, the starting XI, bench and reserves — free of match-day condition chrome. Stamina bars, injury badges and any suspension markers disappear from the pitch cards, the bench strip and the reserves strip; the saved setup the user builds here is their permanent identity eleven, chosen on merit, not on Friday's fitness.

## Context
- Owner decision (2026-11-10): "Team screen … is for managing the team and making the tactics and the starting 11 and bench for the user not affected by league stamina and injuries and red cards and all these things and its auto pick is not affected."
- Current state is ALREADY close: `SquadScreen` passes `showStamina: false` (`lib/features/squad/squad_screen.dart:126`) and the pitch doc comment claims "hidden in the Team tab" (`squad_pitch_view.dart:69`). BUT the hiding is cosmetic and leaky:
  - `squad_pitch_view.dart:157` and `:180/:212-213` still pass `injuryMatchesOut: card.injuryMatchesRemaining` to the card painters UNCONDITIONALLY — injury badges render on the Team tab's pitch TODAY whenever a player is injured (only the stamina BAR is gated by `showStamina`). Verify by tracing `_CardSurface`/`injury_badge.dart` rendering while implementing; the task's tests must pin the fixed behavior either way.
  - The pre-match phase shows what the MATCHDAY variant should look like (`pre_match_phases.dart:95-115`: `showStamina: true, showStats: false, showReserves: true` — "match-day fitness" comment) — that surface becomes the duplicate screen's basis in T-0118.
- IMPORTANT scoped honesty (state, not just display): the OWNER'S full intent — "not affected by league stamina and injuries" — reaches into the SELECTION ENGINE: `autoPick` currently EXCLUDES injured players from the pool entirely (`squad_engine.dart:284-291`), and `MatchSession` swaps injured starters out at kick-off (`match_session.dart:239-278`). Making the Team tab a pure merit surface means: the Team tab's auto-pick ranks EVERYONE on quality (injured or not), and the match-day exclusion moves to the pre-match/match layer (T-0118's auto-pick + the session's existing guard). This task covers the Team-tab half of that split; T-0118 covers the match-day half. The DB columns stay untouched — injuries keep existing, keep ticking down post-match (T-0055 pipeline unchanged); only WHERE they gate selection changes.
- Red cards: the engine emits `MatchEventType.card` events and the report counts them, but NO suspension/`injuryMatchesRemaining`-style persistence exists today (verified: no red-card writes outside the report). So "red cards don't affect the Team tab" is ALREADY true structurally; when a future suspension system lands, the Team tab's purity is this task's locked contract. Write the test that documents it (see Requirement 3) so the contract survives that future change.

## Requirements
1. `lib/features/squad/` — gate ALL match-condition chrome on a single explicit flag (extend the `showStamina` convention into a clearly-named `matchCondition`-style parameter or a second flag — pick ONE and document): the pitch cards, bench strip and reserves strip on the Team tab show NO stamina bars, NO injury badges, NO condition-based dimming/tinting. The pre-match and live surfaces opt IN and keep their current behaviour (pre-match currently shows stamina + injury — T-0118 refines what the match-day auto-pick does with them).
2. `SquadScreen`'s auto-pick path — the Team tab's auto-pick ranks on merit ONLY (the `slotRatingOf`/overall ladder), including currently-injured players in the pool (they are squad members; their fitness is a matchday concern). If this changes `autoPick`'s shared behaviour, split it by parameter rather than duplicating the method — the pre-match variant (T-0118) excludes them with its own ranking; ONE engine, two policies, both tested.
3. Tests (`test/features/squad/` — extend the existing suite files that cover the pitch/bench surfaces): an injured player on the Team tab renders with NO injury badge and NO dimming (badge absent per painter key/type); auto-pick on a squad containing injured players still places them (best XI on merit); the pre-match/live paths still show injury badges (regression guard that the flag didn't leak); a documented contract test: nothing in the Team-tab surface reads `injuryMatchesRemaining` for DISPLAY or SELECTION (grep-level assertion in test comments is not enough — assert behaviour with fixtures).
4. Doc comments updated where they now lie: `squad_view.dart`'s library doc ("the Team tab — every change goes straight to the club's saved setup") gains the purity contract sentence (management surface, condition-free by design, matchday fitness belongs to the pre-match duplicate).

## Out of Scope
- The pre-match duplicate screen and its auto-pick (T-0118 — the very next task).
- The match session's kick-off injured-starter replacement (`match_session.dart:239-278`) — it stays; it IS the match-day layer's guard.
- Injury healing/persistence pipeline (T-0055 owns it; untouched).
- Introducing a suspension/red-card persistence system (does not exist; out of this epic — flagged to the owner in the plan).
- Showing overall/stat rows on the Team tab (`showStats` stays false — pre-existing decision).

## Acceptance Criteria
- [ ] Team tab renders zero match-condition chrome anywhere (pitch, bench, reserves) — locked by fixture tests with an injured+fatigued squad.
- [ ] Team auto-pick is merit-only including injured players; pre-match/live display behaviour unchanged (regression guards green).
- [ ] The purity contract documented in code + the contract test named; `flutter analyze` zero warnings; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/squad/
# Expected: green

flutter test
# Expected: full suite green
```

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
