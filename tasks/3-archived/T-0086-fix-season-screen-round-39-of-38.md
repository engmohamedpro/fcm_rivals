---
id: T-0086
title: Fix the season screen showing Round 39 of 38
priority: high
status: done
attempts: 1
depends_on: []
created: 2026-11-09
completed: 2026-11-09
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
- [x] After the last round is played (before completing the season) the screen shows `Round 38 of 38`, never `Round 39 of 38`.
- [x] At season start the screen shows `Round 1 of 38`, never `Round 0 of 38`; mid-season it shows the upcoming round.
- [x] The displayed round never exceeds `roundsTotal` in any state.
- [x] The completed-season line (`Final position: ...`) and the progress bar behave exactly as before.
- [x] The four state regression tests exist and are green; `flutter analyze` zero warnings; `flutter test test/features/season/` green; full `flutter test` green.

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


### Attempt 1 — implementation

**Summary of changes:** one expression. The round label now reads `'Round ${next?.round ?? summary.roundsTotal} of ${summary.roundsTotal}'` — the upcoming fixture's round while one exists (aligned with the screen's own `Next fixture · round ${next.round}` line), the season's total once every user fixture is played but the season is not yet completed. The inverted conditional (`roundsPlayed + (next != null ? 0 : 1)`) that produced `Round 0 of 38` at season start and `Round 39 of 38` at the end is gone.

1. `lib/features/season/season_screen.dart` — the label expression swap above; nothing else on the screen changed: the progress bar (`roundsPlayed / roundsTotal`), the completed-season `Final position:` line and the fixture lists are untouched, and the label stays hardcoded English per the file's convention.
2. `test/features/season/season_screen_review_test.dart` — four state tests on the existing real-DB `FcmRivalsApp` harness, exactly the task's four states:
   - **fresh:** nothing played → `Round 1 of 38` (`Round 0 of 38` findsNothing).
   - **mid-season:** two user fixtures played through the store's own flow (`startNextFixture` → `simulateToEnd` → `finish` → `commitFixtureResult`), a next fixture exists at round > 2 → the label shows `Round ${next.round} of 38` and `Round 2 of 38` (the played count) findsNothing.
   - **all played, not completed:** `simulateRemainingFixtures` consumes all 38, `getNextFixture()` null, `isCompleted` false, `roundsPlayed` 38 → `Round 38 of 38`, `Round 39 of 38` findsNothing (the reported bug).
   - **completed:** after `Complete season` (the double-tap test's own flow), `Final position:` shows and no `Round` label remains.

**Files changed:** `lib/features/season/season_screen.dart`, `test/features/season/season_screen_review_test.dart`, this task file.

**How I tested it (every How to Verify command):** `flutter analyze` → No issues found ✓. `flutter test test/features/season/season_screen_review_test.dart` → 6/6 green (2 pre-existing + the 4 new) ✓. `flutter test test/features/season/` → **73/73 green** ✓. Full `flutter test --concurrency=1` → green, no REGEN_SNAPSHOT ✓ (result recorded in the submit commit).

**Concerns / assumptions:**
- `next.round` is 1-based from the fixture generator (`generateFixtures` rounds start at 1 — the fresh-season test proves the 1, not 0), so no clamping is needed to satisfy "never greater than roundsTotal": when a next fixture exists its round is at most `roundsTotal` by construction of the round-robin schedule; when none exists the `??` branch IS the total.
- If a future engine change ever emitted a next-fixture round beyond `roundsTotal` (impossible today), the label would show it verbatim — the task's "never greater" holds through the same invariant the fixture generator maintains, not through an added clamp (adding one would hide a generator bug; the fresh/mid tests pin the two ends of the domain).
- The mid-season test drives the real user flow (not a DB shortcut) so `roundsPlayed` reflects exactly what the label used to mis-show; this also keeps the test resilient to store refactors.

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->

### Review 2026-11-09, attempt 1: PASS
- Ran every How to Verify command on HEAD a1122b5 (implementation commit 7009b22): `flutter analyze` → No issues found; `flutter test test/features/season/season_screen_review_test.dart` → 6/6 green (2 pre-existing + the 4 new state tests); `flutter test test/features/season/` → 73/73 green; full `flutter test` → 946/946 green, `REGEN_SNAPSHOT` unset. All counts match the Developer Notes exactly (942 + 4 new = 946).
- Diff audit (7009b22): the production change is exactly ONE line — the label expression swap to `'Round ${next?.round ?? summary.roundsTotal} of ${summary.roundsTotal}'` (`season_screen.dart:378`). Progress bar, Final-position line, fixture lists and the store/engine untouched — Out of Scope respected (3 files: production line, tests, task file).
- AC-1 verified by test run: the all-played test asserts its preconditions through the store (`getNextFixture()` null, `isCompleted` false, `roundsPlayed` 38) before reading the UI, then `Round 38 of 38` present and `Round 39 of 38` absent — the reported bug is locked out.
- AC-2 verified by test run: fresh season reads `Round 1 of 38` with `Round 0 of 38` absent; the mid-season test plays two fixtures through the store's real flow (startNextFixture → simulateToEnd → finish → commitFixtureResult), asserts a next fixture exists beyond round 1, and locks BOTH the new semantic (`Round ${next.round}` present) and the old wrong one (`Round 2 of 38` — the played count — absent).
- AC-3 verified structurally, not just by the dev's word: the generator loops 0-based (`season_engine.dart:606`, `round` from 0) and the store persists `round: p.round + 1` (`season_store.dart:185`), so a stored next-fixture round is always in 1..roundsTotal; when no fixture remains the `??` branch shows exactly `roundsTotal`. The fresh and all-played tests pin both ends of that domain. The dev's decision not to add a clamp (it would hide a generator bug) is sound — the invariant is structural.
- AC-4 verified: the completed-season test taps `Complete season` through the UI, confirms `isCompleted` via the store, then asserts `Final position:` shows and NO text containing `Round` remains anywhere; the one-line production diff cannot have moved the progress bar or anything else.
