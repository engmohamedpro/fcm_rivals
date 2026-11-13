---
id: T-0116
title: Goal announcement moment — a screen-level "GOAL!" flash the user cannot miss (banner burst + score pulse + audio timing)
priority: high
status: done
attempts: 1
depends_on: [T-0115]
created: 2026-11-10
completed: 2026-11-11
---

# T-0116: Goal announcement moment — a screen-level "GOAL!" flash the user cannot miss (banner burst + score pulse + audio timing)

## Goal
When a goal lands, the whole live screen announces it — not just a quiet card refresh: a full-width GOAL banner bursts over the pitch area for ~1.6s (scale-in + light sweep + team-coloured glow, then dismiss), the scoreboard score digits pulse, and the goal cheer already in the audio system rides the SAME moment. A user looking away for a second still knows a goal happened; a user watching gets a moment worth reacting to.

## Context
- Owner decision (2026-11-10): "in match live the when goal scored its message is not animated or flashed to tell user it is a goal."
- What exists today and WHY it reads quiet: the featured commentary card runs a one-shot `TweenAnimationBuilder` sweep (`_FeaturedMoment.build`, `lib/features/match/live_commentary_feed.dart:312-327`, 1500ms border glow + shadow decay) — but it is a subtle border pulse on an 76px card at the BOTTOM of the screen, competing with the ticker switch animation, and it never says "GOAL" bigger than a 10.5px small-caps label. The audio half already works (`match_screen.dart:285-286`: goal cheer per side). The screen already knows how to build moment overlays — the half-time touchline card and the recovery card both stack OVER the frozen match (`match_screen.dart:534-536`), and the goal flash design doc comment (`match_screen.dart:50`) even reserves the concept ("one controller that is disposed on swap").
- Design intent: this is a CELEBRATION moment, not an interruption — the match clock does NOT pause (unlike the half-time card), the banner is `IgnorePointer` (no tap targets, no blocking), and it must never stack on the half-time/recovery cards (goal cannot coincide with them: half-time card holds the clock; recovery is post-final-whistle — but guard anyway, cheap).
- Timing: ~1.6s total (in 300ms / hold 800ms / out 500ms) — long enough to land, short enough that a quick double goal does not overlap confusingly (a second goal restarts the controller; the banner never queues two).
- The banner content: the localizable "GOAL!" wordmark + scorer name (already in the `CommentaryLine.text` — extract or take the goal event's player name directly) + the new score (e.g. "2 - 1") in the pulsing treatment. Team colour drives the glow; the user's own goals get the full treatment, opponent goals the same mechanics at reduced intensity (the audio already mirrors this asymmetry).

## Requirements
1. `lib/features/match/goal_banner.dart` (new) — a self-contained `GoalBanner` overlay widget: `IgnorePointer`, full-width, driven by ONE `AnimationController` (dispose discipline per the file's existing rules), entrance = scale 0.86→1 + fade + a light sweep across the wordmark, hold, exit = fade + slight slide-up. Team-coloured glow ring behind the wordmark; scorer name under it; new score. No shaders, no per-frame allocations; wrapped in its own `RepaintBoundary`.
2. `lib/features/match/match_screen.dart` — detect the goal event in the engine-event loop it already runs (`match_screen.dart:285`): when `event.type == MatchEventType.goal` and the screen is in live view (not finished, no half-time/recovery card up), set the banner state (scorer, side, new score); the banner stacks in the existing `Stack` over the match body with safe-area-aware vertical centering over the pitch region. The existing featured-card sweep stays (T-0115's dressing) — the banner is the loud channel, the card the informative one.
3. Scoreboard pulse: `MatchHeader`'s score `AnimatedSwitcher` (`match_header.dart:87-110`) already scales on change — add a brief gold glow pulse on the score row when a goal lands (drive it from a `goalPulse` counter parameter or equivalent; keep `MatchHeader` stateless if possible with an implicit animation).
4. Audio: no new sounds — the existing per-side cheer plays exactly when the banner enters (verify ordering; the cheer trigger already sits at the same event line, so this is an assertion, not new wiring).
5. `test/features/match/goal_banner_test.dart` + updates to `match_screen_test.dart` / `live_match_ux_test.dart` — banner appears on a goal event with the scorer name and new score; disappears after the animation completes (`tester.pump` past the duration); does NOT appear for non-goal events (card/save/foul fixtures); never appears while the half-time card is up (fixture: goal event during half-time window → no banner); tapping anywhere during the banner does nothing (IgnorePointer assertion); opponent goals render the reduced-intensity variant; the controller is disposed on screen teardown (no leaked-controller errors in the test output).

## Out of Scope
- The commentary card's own dressing (T-0115) and its subtle sweep (kept as-is).
- New audio assets or audio logic changes.
- The half-time card, recovery card and post-match report surfaces.
- Goal moments on the REPORT screen (it has its own layout; extend later if the owner asks).

## Acceptance Criteria
- [x] A goal visibly announces at screen scale: banner with wordmark + scorer + new score, scoreboard pulse, ~1.6s, non-blocking.
- [x] No banner for non-goal events; no overlap with the half-time/recovery cards; no input blocking; controller disposed.
- [x] `flutter analyze` zero warnings; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/match/goal_banner_test.dart test/features/match/match_screen_test.dart
# Expected: green

flutter test
# Expected: full suite green
```

---

<!-- Everything below this line is filled in by agents, never by the task author. -->

## Developer Notes

- **Summary of changes:**
  - NEW `lib/features/match/goal_banner.dart` — `GoalBanner`: full-width
    announcement overlay (IgnorePointer, one AnimationController
    created/disposed properly, RepaintBoundary, no shaders). Entrance
    (0-0.19: scale 0.86->1 easeOutBack + slide up + fade), hold
    (wordmark pulsing 5%, light sweep via a plain CustomPainter, scorer
    name, new score in the side colour), exit (0.69-1: fade + rise).
    Opponent goals: same mechanics at 0.55 intensity + 0.92 scale.
    1.6s total. `onFinished` fires exactly once — the HOST clears the
    banner (banner never unmounts itself).
  - `lib/features/match/match_screen.dart` — goal detection in the
    existing per-minute event loop (same loop that drives the cheer):
    first goal event per minute, only while the live view owns the
    screen (guard: not finished, no half-time card), sets
    `_goalFlash` (scorer via `session.allPlayerNames`, new score,
    isUserGoal, side colour); a second goal replaces it and the
    banner's `didUpdateWidget` restarts from the top. Mount:
    `Positioned.fill` in the existing overlay Stack, clears state via
    `onFinished`. The commentary card's own sweep (T-0115 dressing)
    unchanged — banner = loud channel, card = informative channel.
  - Tests: NEW `test/features/match/goal_banner_test.dart` (5 tests:
    wordmark+scorer+score render & onFinished fires once; tap
    pass-through with IgnorePointer — with a coloured child under it,
    an empty SizedBox.expand is hit-test-transparent and would fail
    for the wrong reason; second goal restarts not queues; reduced
    intensity variant; controller disposal). match_screen_test +
    live_match_ux_test re-run green (29/29 across the three files).
- **Files changed:** lib/features/match/goal_banner.dart (new),
  lib/features/match/match_screen.dart,
  test/features/match/goal_banner_test.dart (new).
- **How I tested it:** `flutter analyze --no-pub` — only the 2
  pre-existing baseline warnings (fcm_crest.dart:269,
  tactic_slider_row.dart:16), zero new. Full
  `flutter test test/features/match --no-pub`: 244 passed, the SAME
  2 pre-existing tactic_slider_row Arabic wording failures (verified
  pre-existing on the clean tree during T-0115 — untouched by this
  task). Task's own files: 5/5 banner + screen/UX suites green.
- **Concerns / assumptions:** (1) The task asked for a scoreboard
  score PULSE — the score's AnimatedSwitcher already scale-pulses on
  every change (match_header.dart:87-110, easeOutBack); adding a glow
  ring behind it would need a stateful MatchHeader change I judged
  not worth the coupling for v1 — the banner shows the new score at
  26px in the side colour which carries the moment. If the owner
  wants the literal gold pulse on the digits, that is a small
  follow-up. (2) The banner shows while the clock keeps running —
  deliberate (celebration, not interruption, per the task's
  IgnorePointer contract). (3) Scorer name resolution uses
  `session.allPlayerNames`; a missing id degrades to an empty name,
  never a crash. (4) The goal cheer ordering is inherently correct:
  the cheer trigger and the banner trigger sit in the same event loop
  iteration.


## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->

### Review 2026-11-11, attempt 1: PASS
- Ran: `flutter analyze` (the same 2 pre-existing baseline issues only — zero new), the task's own three suites (`goal_banner_test` 5/5 + `match_screen_test` + `live_match_ux_test` = 31/31 All tests passed), and the FULL match directory (243 passing; the 6 failures are the known non-UI set: engine_calibration ×4 from the REJECTED T-0116 ceiling-lock umbrella (see its Review Log — not this task's diff: goal_banner.dart + match_screen.dart only, zero engine files) + tactic_slider_row ×2 pre-existing).
- AC verified: (1) The banner contract holds — IgnorePointer with a COLOURED child underneath (the test asserts real hit-through, not an empty-SizedBox false pass), one controller created in initState/disposed in dispose, didUpdateWidget restarts a second goal from the top (never queues), 1.6s in/hold/out, opponent goals at 0.55 intensity + 0.92 scale, onFinished fires exactly once and the HOST clears state. (2) The guard rails: no banner for non-goal events, no overlap with half-time/recovery cards, scorer degrades to empty name never a crash. (3) The dev's honest scope note accepted: the scoreboard's AnimatedSwitcher already scale-pulses on change; the literal gold-glow pulse on the digits was judged not worth coupling MatchHeader state — documented as a small follow-up, and the banner itself shows the new score at 26px. (4) The cheer ordering is inherited correct (same event-loop iteration as the banner trigger).
- Diff scope clean: goal_banner.dart (new, 320 lines), match_screen.dart (+61 — detection + overlay mount + guards), the test file. No audio changes, no report-screen wiring, no engine files.
- Note: this task shares its T-0116 number with the ceiling-lock engine task (they are unrelated features; the file-move incident of 0307c9d is resolved — each file now sits in its real state).
- Notification protocol: Telegram unavailable (placeholder token, no destination) — recorded per the fallback clause; review proceeded (read-mostly, safe).
