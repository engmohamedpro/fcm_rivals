---
id: T-0118
title: Pre-match tactics phase — the true matchday duplicate of the Team screen, with fitness-aware auto-pick
priority: high
status: todo
attempts: 0
depends_on: [T-0117]
created: 2026-11-10
completed:
---

# T-0118: Pre-match tactics phase — the true matchday duplicate of the Team screen, with fitness-aware auto-pick

## Goal
The pre-match tactics phase becomes EXACTLY what the owner described: a duplicate of the Team screen — same formation, same tactics controls, same bench and reserves — where every difference serves matchday: changes are match-only (never persisted — already true), stamina and injuries are VISIBLE, and the auto-pick builds the fittest legal XI (injured and suspended players excluded from BOTH the starting XI and the bench, slots filled by best-stamina-then-best-overall per position).

## Context
- Owner decision (2026-11-10): "when user press play match in the set up for match it shows duplicate of the Team screen exactly with the same formation and bench reserves and every thing but the difference is changes user made is not permanent and show stamina and injuries and red cards also auto pick here remove injured players and red cards from starting and bench players and auto pick is also according to best stamina then best overall for each position."
- What exists vs what's missing (verified in code):
  - The shared surface `TacticsSetupView` is ALREADY rendered in the pre-match phase (`pre_match_phases.dart:105-115`) with `showStamina: true, showStats: false, showReserves: true` — the "duplicate of the Team screen" is 80% there structurally. Match-only persistence is ALREADY correct (GDD 10.4, `pre_match_tactics_selection.dart`: overrides never written back).
  - MISSING #1 — an auto-pick action: the Team tab has `onAutoPick` wired (`squad_screen.dart` `_autoPick`); the pre-match phase's `TacticsSetupView` call passes NO `onAutoPick` — the matchday user cannot re-pick their XI at all. This task adds it (match-only: re-assigns the projected XI/bench in memory, saves nothing).
  - MISSING #2 — the auto-pick POLICY: the engine's `autoPick` (`squad_engine.dart:281`) excludes injured players (good — that half of "remove injured from starting and bench" already holds) but ranks by SLOT RATING ONLY — stamina never enters. The owner's new ranking: for each position slot, the best candidate is chosen by stamina FIRST, then overall. Exact semantics to implement (fixed here so the developer doesn't guess): among eligible (non-injured) players for a slot, rank by `(staminaPercent, slotRating)` — stamina bucketed into bands of 10 (94 and 86 both count as "90s") so a 2-point stamina edge doesn't outweigh a 15-point quality gap within the same band, then slot rating decides inside a band. Bench ordering follows the same rule (fittest-and-best first). Document the banding decision in code; it is the one calibration this task owns.
  - MISSING #3 — RED CARDS: no suspension state exists in the data model today (verified: the engine emits card events, the report counts them, nothing persists a post-match ban). "Remove red-carded players from starting and bench" therefore has NOTHING to remove YET. Implement the EXCLUSION HOOK, not the state: the matchday auto-pick's eligibility filter takes a `suspendedPlayerIds` set (default empty — behaviour unchanged today), so the day a suspension system lands it plugs in without re-opening this logic. State this plainly in Developer Notes; do NOT fake a red-card column (inventing persistence the owner didn't spec is how save-corrupting migrations happen).
- The injured-starter session guard (`match_session.dart:239-278`) stays as the final kick-off safety net (it re-replaces injured starters if the user MANUALLY picked one) — the pre-match auto-pick makes that guard rarely fire, manual picks keep it honest. Note: the session guard replaces with "best available" — leave its policy as-is this task; flag the stamina-ranking mismatch in Developer Notes for a follow-up if the owner wants the manual-path replacement aligned.

## Requirements
1. `lib/features/squad/squad_engine.dart` — the matchday pick policy as a parameterized variant of the ONE engine (per T-0117's split, no method duplication): eligibility excludes injured players AND the `suspendedPlayerIds` set (empty default); XI slot ranking = stamina band (10s) then slot rating; bench/reserve ordering = same key. The Team tab's merit-only policy (T-0117) and this policy coexist behind the explicit parameter.
2. `lib/features/match/pre_match_phases.dart` — wire `onAutoPick` into the tactics phase's `TacticsSetupView` (match-only re-projection: same in-memory `_squadFor` path the phase already uses for formation switches — the pick updates the phase state, `onKickOff` still hands the selection, nothing persists).
3. The projected XI/bench/reserves the phase shows ALREADY reflect the new policy wherever they are (re)built: the initial projection when entering the phase AND the auto-pick button both produce the fitness-aware team, so the user sees the team that will actually kick off (injured players visibly parked in reserves with their injury badges — the duplicate screen's "show stamina and injuries" difference, live).
4. Tests (`test/features/match/pre_match_screen_test.dart` + a new `matchday_autopick_test.dart` for the engine policy): policy ranking fixtures — a 92-stamina 78-overall player beats a 96-stamina 72-overall in the SAME band by rating; a 100-stamina 75-overall beats a 61-stamina 85-overall by band; injured players excluded from XI AND bench (bench assertion is the owner's explicit ask); `suspendedPlayerIds` excluded (empty default = unchanged); Team tab's merit policy regression (T-0117's tests stay green); the pre-match UI exposes the auto-pick action and re-projects match-only (pump the phase, tap, assert the XI changed and no store write happened — in-memory db assertion).
5. `MatchSession` untouched functionally: the kick-off guard still catches manual injured picks (existing tests green). The report/injury pipeline untouched.

## Out of Scope
- Building the red-card/suspension persistence system (data-model + post-match ban writes) — explicitly NOT in this task; the hook exists, the state doesn't. Recommend a dedicated task when the owner confirms the feature.
- Live in-match substitution auto-suggestions (different surface).
- The bench ORDER the live match's AI substitutions consume (downstream of this ordering — verify no test breaks, do not redesign).
- The Team tab's surfaces (T-0117, this task's prerequisite).

## Acceptance Criteria
- [ ] Pre-match tactics phase = the Team-screen duplicate with matchday differences: fitness visible, changes match-only, auto-pick present and fitness-aware.
- [ ] The engine policy locked by banding fixtures both directions + injured/suspended exclusions (bench included); the merit policy's tests stay green.
- [ ] The suspension gap stated plainly in Developer Notes (hook shipped, state absent); `flutter analyze` zero warnings; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/match/pre_match_screen_test.dart test/features/match/matchday_autopick_test.dart test/features/squad/
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
