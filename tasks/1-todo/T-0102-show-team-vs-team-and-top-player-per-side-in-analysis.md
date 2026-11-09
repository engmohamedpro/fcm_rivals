---
id: T-0102
title: Show team vs team and the top player of each side in the analysis phase
priority: high
status: todo
attempts: 0
depends_on: []
created: 2026-11-09
completed:
---

# T-0102: Show team vs team and the top player of each side in the analysis phase

## Goal
The pre-match analysis phase reads as the real fixture (owner request 2026-11-09): the header shows TEAM vs TEAM with the HOME club at the start and the AWAY club at the end, and the TOP PLAYERS section becomes the top player of EACH team — one card per side — instead of the opponent's top three.

## Context
- `lib/features/match/pre_match_analysis.dart` — `AnalysisPhase` (`:28-57`) lays out: `_OpponentHeader` (`:141-262`, opponent-centric: fixture label + HOME/AWAY pill, opponent circle with initials, form pips, positions) then `_TopPlayersCard` (`:603-667`, hardcoded EN 'TOP PLAYERS' heading + the opponent's `opponentKeyMen` top three rendered as `FcmPlayerCard`s via `_basePlayerOf`).
- `PreMatchData` (`lib/features/match/match_forecast.dart:86-134`) already carries everything needed: `userClubName`, `opponentClubName`, `userAtHome`, `userSquad` (`List<MatchPlayer>` — the user's full squad) and `opponentKeyMen` (already sorted best-first by the producer at `lib/features/season/season_store.dart:348-360`).
- The user's best player: derive from `userSquad` with the same math the key-men sort uses (`season_store.dart:381`, `(attack + support + defence) / 3` rounded) — compute it in the analysis file from `MatchPlayer` fields (`lib/features/match/match_event.dart:90-110` has name/position/attack/support/defence/goalkeeping), no `PreMatchData` contract change, so the existing test fixtures (`test/features/match/pre_match_screen_test.dart:46`, `test/features/match/injury_ui_test.dart:73`) keep compiling.
- The section heading stays hardcoded EN per this file's own convention (like today's 'TOP PLAYERS'), but the header club names are data, and RTL must mirror.
- Tests today: `test/features/match/pre_match_screen_test.dart:205,229,236,248,263` assert on 'TOP PLAYERS'; the analysis phase is pumped through the pre-match screen.

## Requirements
1. Rework `_OpponentHeader` into a team-vs-team header: one row reading [HOME club] VS [AWAY club] — the fixture's home club at the START and the away club at the END, regardless of which side the user is (`userAtHome` decides the order: user first when home, opponent first when away). Each side shows a compact identity chip (the existing initials circle style) with the club name; 'VS' sits between them in gold; the user's club is visually distinguished (gold accent) so the player always spots their side. Keep the fixture label row above it. The opponent form pips and the league-positions comparison stay as they are below.
2. Replace `_TopPlayersCard`'s three-card opponent row with exactly two cards — the top player of each side, ordered like the header (home side's best first): the user's best from `userSquad` (max by the key-men formula above) and the opponent's best (`opponentKeyMen.first`), both through the existing `_basePlayerOf` card face. Heading becomes 'TOP PLAYER' (per-side context is the header order). If either side has no players (empty squad edge), hide the section entirely, same pattern as the medical room's conditional.
3. RTL: the header row and the two cards mirror with the text direction (Row order, no hardcoded left/right); EN and AR pumps both render club names and the heading correctly.
4. Tests (update `test/features/match/pre_match_screen_test.dart`): the header shows BOTH club names with home first — once with `userAtHome: true` and once with `userAtHome: false` (assert the left/start name flips); the top section shows exactly two cards with the correct best players' names for the seeded squads; 'TOP PLAYERS' is gone; an Arabic RTL pump keeps both sides inside the screen (no overflow, mirrored order).

## Out of Scope
- The forecast card, strength bars and medical room card.
- `PreMatchData` producers or its contract (derive the user's best in the view).
- The live match header (`match_header.dart`) or any other screen.
- Changing the key-men producer or its sort.

## Acceptance Criteria
- [ ] The header reads home club (start) VS away club (end) in both fixture orientations; the user's club is visually distinct; the fixture label, form pips and positions comparison are unchanged.
- [ ] The top section shows exactly two cards — the best player of each team, in the header's side order — using the real card face; it hides when a side has no players.
- [ ] 'TOP PLAYERS' no longer exists; EN and AR render; RTL mirrors both rows without overflow.
- [ ] `flutter analyze` zero warnings; pre-match tests green with the new cases; match suite green; full `flutter test` green, no REGEN_SNAPSHOT.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/match/pre_match_screen_test.dart test/features/match/injury_ui_test.dart
# Expected: green — both fixtures compile untouched, new header/top-player cases pass

flutter test
# Expected: full suite green, no REGEN_SNAPSHOT
```

Manual: open a home fixture and an away fixture from the season screen → the analysis header always lists the home club first; the top-player row shows your best player beside the opponent's best.

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
