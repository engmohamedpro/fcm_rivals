---
id: T-0114
title: Live match — fold 'League · Round N' into a micro-caption and drop the live AppBar (reclaim vertical space)
priority: medium
status: todo
attempts: 0
depends_on: []
created: 2026-11-10
completed:
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
- [ ] Live screen has no AppBar; 'League · Round N' renders as the header micro-caption; null title renders no caption.
- [ ] The reclaimed height demonstrably reaches the content column (measured number in Developer Notes).
- [ ] `flutter analyze` zero warnings; full `flutter test` green.

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
<!-- Developer agent fills this in before moving the file to 2-needs-review. -->

- **Summary of changes:**
- **Files changed:**
- **How I tested it:**
- **Concerns / assumptions:**


## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
