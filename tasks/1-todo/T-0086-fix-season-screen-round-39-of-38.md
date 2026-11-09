---
id: T-0086
title: Fix the season screen showing Round 39 of 38
priority: high
status: todo
attempts: 0
depends_on: []
created: 2026-11-09
completed:
---

# T-0086: Fix the season screen showing Round 39 of 38

## Goal
The season screen's progress line never shows a round beyond the season's total: after the final round is played it reads `Round 38 of 38` (today it reads `Round 39 of 38`), and at season start it reads `Round 1 of 38` (today `Round 0 of 38`).

## Context
- Owner report 2026-11-09: when the season finishes the season screen shows "round 39 of 38".
- The label is at `lib/features/season/season_screen.dart:378`:
  `'Round ${summary.roundsPlayed + (next != null ? 0 : 1)} of ${summary.roundsTotal}'`
  The conditional is inverted: `roundsPlayed` counts the user's COMPLETED rounds (`season_store.dart:195-215`, `userRounds`), `next` is the user's next unplayed fixture (`getNextFixture`, `season_store.dart` ~223, null when all are played). With all 38 played and the season not yet completed (`isCompleted` false until the user completes it), the `+1` branch fires: 38 + 1 = 39. At season start the other side shows: 0 played, next exists → `Round 0 of 38`.
- The fix intent: mid-season the label shows the round IN PROGRESS — the next fixture's round, matching the screen's own `Next fixture · round ${next.round}` line (`season_screen.dart:435`); when every fixture is played but the season is not completed, it shows `Round ${roundsTotal} of ${roundsTotal}`. One clean expression: `'Round ${next?.round ?? summary.roundsTotal} of ${summary.roundsTotal}'`.
- `roundsTotal` comes from `engine.config.roundsPerSeason()` (38 in the current config) — keep the expression generic over `roundsTotal`.
- The completed-season state (`isCompleted`) already swaps the line to `Final position: ...` (`season_screen.dart:376-377`) — unchanged.
- The label is hardcoded English by the file's existing convention; keep that style.
- Test harness: `test/features/season/season_screen_review_test.dart` — real-DB harness (drift/native, `seasonStore.getSeasonSummary` pattern at ~185); season/fixture seeding helpers also exist in `test/features/season/season_store_test.dart`.

## Requirements
1. `lib/features/season/season_screen.dart:378` — replace the expression so that:
   - a next fixture exists → the label shows `Round ${next.round} of ${roundsTotal}` (the upcoming round, aligned with the 'Next fixture' line);
   - no next fixture and season not completed → `Round ${roundsTotal} of ${roundsTotal}` (never `roundsTotal + 1`);
   - the displayed round is never greater than `roundsTotal` in any state.
2. No other behavior on the season screen changes: the progress bar (`roundsPlayed / roundsTotal`, ~305-307), the completed-season `Final position` line, and fixture lists stay as they are.
3. Add regression tests in `test/features/season/season_screen_review_test.dart` covering the four states of that line:
   - fresh season, nothing played → `Round 1 of 38`;
   - mid-season (some rounds played, a next fixture exists) → `Round ${next round} of 38`;
   - all 38 user fixtures played, season NOT yet completed → `Round 38 of 38` (the reported bug — must not read 39);
   - completed season → the `Final position: ...` line still shows instead of a round label.

## Out of Scope
- Changing `roundsPerSeason`, the fixture generator, or any engine/store logic — this is a display fix only.
- Localizing the label (the screen is hardcoded EN by convention today).
- The other season-screen texts, layout, or the completed-season flow.

## Acceptance Criteria
- [ ] After the last round is played (before completing the season) the screen shows `Round 38 of 38`, never `Round 39 of 38`.
- [ ] At season start the screen shows `Round 1 of 38`, never `Round 0 of 38`; mid-season it shows the upcoming round.
- [ ] The displayed round never exceeds `roundsTotal` in any state.
- [ ] The completed-season line (`Final position: ...`) and the progress bar behave exactly as before.
- [ ] The four state regression tests exist and are green; `flutter analyze` zero warnings; `flutter test test/features/season/` green; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/season/season_screen_review_test.dart
# Expected: all pass, including the four new round-label state tests

flutter test test/features/season/
# Expected: whole season suite green

flutter test
# Expected: full suite green, no REGEN_SNAPSHOT
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
