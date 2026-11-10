---
id: T-0116
title: Goal announcement moment — a screen-level "GOAL!" flash the user cannot miss (banner burst + score pulse + audio timing)
priority: high
status: todo
attempts: 0
depends_on: [T-0115]
created: 2026-11-10
completed:
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
- [ ] A goal visibly announces at screen scale: banner with wordmark + scorer + new score, scoreboard pulse, ~1.6s, non-blocking.
- [ ] No banner for non-goal events; no overlap with the half-time/recovery cards; no input blocking; controller disposed.
- [ ] `flutter analyze` zero warnings; full `flutter test` green.

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
<!-- Developer agent fills this in before moving the file to 2-needs-review. -->

- **Summary of changes:**
- **Files changed:**
- **How I tested it:**
- **Concerns / assumptions:**


## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
