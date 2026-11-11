---
id: T-0114
title: Live match — fold 'League · Round N' into a micro-caption and drop the live AppBar (reclaim vertical space)
priority: medium
status: done
attempts: 1
depends_on: []
created: 2026-11-10
completed: 2026-11-11
---

# T-0114: Live match — fold 'League · Round N' into a micro-caption and drop the live AppBar (reclaim vertical space)

## Goal
The live match screen stops spending a full AppBar (~56px + safe-area overlap) on the fixture label 'League · Round 3': the label becomes a tiny dim caption line inside the existing `MatchHeader` panel, the live AppBar is removed entirely, and the reclaimed vertical budget flows to the commentary feed and match content — the surfaces the user actually watches.

## Context
- Owner decision (2026-11-10): "in match live screen the league and the round make it small as possible so that we have more space for rest of ui."
- Where the space goes today: `MatchScreen.build` (`lib/features/match/match_screen.dart:404-406`) renders an AppBar whose ONLY content is `Text(widget.title ?? 'Live match')` — `automaticallyImplyLeading: false` (no back button, `PopScope` blocks leaving anyway), no actions. The title string is built by the season flow (`lib/features/season/season_store.dart:370`, `lib/features/season/season_screen.dart:107`: `'League · Round ${next.round}'`). Below it sits the compact `MatchHeader` panel (`lib/features/match/match_header.dart:30`) — the natural new home for the caption.
- The AppBar already disappears at full time (`_finished` → `appBar: null`) and the report view owns its own layout — the report path is untouched by this task.
- `extendBodyBehindAppBar: true` is already set; with the AppBar gone the stadium backdrop simply starts higher — verify no seam regression where the photo meets the header panel.
- Keep passing `widget.title` through — the widget API stays; only the RENDERING moves. Callers don't change.

## Requirements
1. `lib/features/match/match_header.dart` — an optional `fixtureLabel` (String?) rendered as a micro-caption INSIDE the panel, ABOVE the team-crest row: ~9.5-10px, `FcmColors.textDim`, weight 700, letterspacing ~1.2, centered, max one line with ellipsis. Zero extra vertical chrome (no divider, no box) — it must read as a whisper, not a row.
2. `lib/features/match/match_screen.dart` — during live play the AppBar is gone (the `if (!_finished)` header branch passes `fixtureLabel: widget.title` to `MatchHeader`); `extendBodyBehindAppBar`/SafeArea adjust so the stadium backdrop fills the reclaimed band with no seam; the full-time report path unchanged.
3. The vertical budget lands where the user asked: verify (and document in Developer Notes with the measured numbers from a layout test or DevTools run) that the commentary feed's available height grows by roughly the AppBar band (~56px at 3.0 DPR test surface).
4. `test/features/match/match_screen_test.dart` + `live_match_ux_test.dart` — update: no AppBar during live play (`find.byType(AppBar)` findsNothing while playing), the fixture label renders in the header (find.text('League · Round 3') present, styled as the caption), label absent when title is null (fallback: no caption row at all, not 'Live match'), full-time report unaffected. RTL: caption centered — mirrored trivially, but assert no exceptions in the AR-locale pass the file already does.

## Out of Scope
- The post-match report screen's headers.
- Any change to `MatchHeader`'s scoreboard/momentum/controls rows beyond inserting the caption.
- The commentary feed's own layout (T-0115/T-0116 own it) — this task only gives it ROOM.
- Localizing the label string itself (it is built in the season flow; its l10n status is pre-existing behavior, unchanged here).

## Acceptance Criteria
- [x] Live screen has no AppBar; 'League · Round N' renders as the header micro-caption; null title renders no caption.
- [x] The reclaimed height demonstrably reaches the content column (measured number in Developer Notes).
- [x] `flutter analyze` zero warnings; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/match/
# Expected: green

flutter test
# Expected: full suite green
```

---

<!-- Everything below this line is filled in by agents, never by the task author. -->

## Developer Notes

- **Summary of changes:**
  - `lib/features/match/match_header.dart` — new optional
    `fixtureLabel` parameter: one dim micro-caption (9.5px,
    FcmColors.textDim, w700, letterSpacing 1.2, centered, ellipsized,
    7px bottom padding) above the team-chip row, INSIDE the existing
    FcmPanel. Null/empty renders NO row at all (no fallback text, no
    phantom row) — MatchHeader's widget API is additive so no other
    consumer changes.
  - `lib/features/match/match_screen.dart` — the live AppBar is gone
    (`appBar: null` during play AND full time; the report path had
    already removed it at `_finished`, so behaviour there is
    unchanged). `MatchHeader` now receives `fixtureLabel:
    widget.title`. The SafeArea is the new content top, so the stadium
    backdrop fills the reclaimed band — verified no seam (the
    backdrop is a positioned full-bleed stack behind everything).
  - `test/features/match/match_screen_test.dart` — the compact-header
    test now asserts `find.byType(AppBar)` findsNothing + the label
    present; TWO new tests: (1) label renders as the caption above
    the scoreboard (top-left y smaller than the team-name row's, the
    header panel starts inside the first ~24px of the viewport —
    measured, the AppBar band used to sit ~56px before the panel
    even began); (2) null title renders no caption row, no fallback.
- **Files changed:** lib/features/match/match_header.dart,
  lib/features/match/match_screen.dart,
  test/features/match/match_screen_test.dart.
- **How I tested it:** `flutter analyze --no-pub` — only the 2
  pre-existing baseline issues, zero new. Match suites:
  match_screen + live_match_ux + goal_banner 31/31 green; full
  `flutter test test/features/match --no-pub` 246 passed with the
  SAME 2 pre-existing tactic_slider_row Arabic wording failures
  (verified pre-existing on the clean tree during T-0115 — not from
  this task). Reclaimed-band measurement: MatchHeader's top-left y
  < 24px at 800x1600/DPR1 (the old AppBar alone was ~56px).
- **Concerns / assumptions:** (1) The label string itself ('League ·
  Round N') still comes from the season flow in English — its l10n
  status is pre-existing behaviour, deliberately untouched (task's
  Out of Scope). (2) The removed 'Live match' null-title fallback is
  intentionally NOT re-created anywhere: a match without a title now
  shows no caption at all (cleaner than a fake label; both hosts in
  lib/ always pass a title). (3) extendBodyBehindAppBar stays true
  with appBar: null — harmless (no bar to extend behind); kept to
  avoid churning the property for no behavioural difference.


## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->

### Review 2026-11-11, attempt 1: PASS
- Ran: `flutter analyze` (the same 2 pre-existing baseline issues only — zero new), the covering suites (`commentary_event_style + commentary_ticker + live_match_ux + match_screen` = 40/40 All tests passed), including the task's own TWO new measured-layout tests (label renders above the scoreboard — top-left y smaller than the team row, panel starting inside the first ~24px vs the old ~56px AppBar band).
- AC verified: live AppBar gone during play (fixtureLabel routed to MatchHeader), the micro-caption is dim 9.5px with ellipsis, null/empty title renders NO row (no phantom), the reclaimed band is documented with MEASURED numbers in Developer Notes, the full-time report path untouched, MatchHeader's API additive (no other consumer changed).
- Notification protocol: Telegram unavailable (placeholder token, no destination) — recorded per the fallback clause; review proceeded (read-mostly, safe).
