---
id: T-0102
title: Show team vs team and the top player of each side in the analysis phase
priority: high
status: done
attempts: 1
depends_on: []
created: 2026-11-09
completed: 2026-11-10
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
- [x] The header reads home club (start) VS away club (end) in both fixture orientations; the user's club is visually distinct; the fixture label, form pips and positions comparison are unchanged.
- [x] The top section shows exactly two cards — the best player of each team, in the header's side order — using the real card face; it hides when a side has no players.
- [x] 'TOP PLAYERS' no longer exists; EN and AR render; RTL mirrors both rows without overflow.
- [x] `flutter analyze` zero warnings; pre-match tests green with the new cases; match suite green; full `flutter test` green, no REGEN_SNAPSHOT.

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


### Attempt 1 — implementation

**Summary of changes:** the analysis phase now reads as the real fixture — a team-vs-team header (HOME club at the start, AWAY at the end, the user's side gold-accented) and a TOP PLAYER section holding exactly two cards, the best player of each side.

1. `lib/features/match/pre_match_analysis.dart` — `_OpponentHeader` reworked: the fixture-label row and HOME/AWAY pill stay; the single opponent panel became one `[HOME chip] VS [AWAY chip]` row where `userAtHome` decides the order and the user's chip carries the gold accent (thicker border + glow) — new compact `_TeamChip` widget (initials circle, name, table position, symmetric stack). Below it the form pips and the positions comparison survive as one centered row (`12th vs 5th` + pips — the same data, restated). No hardcoded left/right anywhere: Row order mirrors with the text direction.
2. `_TopPlayersCard` — the opponent's three-card row became exactly two: the user's best (`_bestOfSquad` over `userSquad.values`, the producer's own `(attack + support + defence) / 3` formula computed from `card.attribute`, no `PreMatchData` contract change) and the opponent's best (`opponentKeyMen.first`), ordered like the header (home side's best first). Heading reads 'TOP PLAYER'. Either side empty → the whole section hides (the medical room's conditional pattern). Card width splits over two columns instead of three.
3. `test/features/match/pre_match_screen_test.dart` — the 'opponent only' test became the T-0102 header test (both club names, VS, both table positions, form pips intact, start-side dx order for `userAtHome: true`); a new away-fixture test pumps `userAtHome: false` in the ARABIC locale asserting the mirrored pump renders both sides with no overflow and the opponent's best is the first card; the three-card assertions became two-card with the seeded best players ('ST Finisher' score 82 home-first, 'Omar Gamal'); every 'TOP PLAYERS' marker became 'TOP PLAYER' (with one line still asserting the plural findsNothing).

**Files changed:** `lib/features/match/pre_match_analysis.dart`, `test/features/match/pre_match_screen_test.dart`, `test/features/season/season_live_match_flow_test.dart` (the stale 'TOP PLAYERS' scroll marker), this task file.

**How I tested it (every How to Verify command):** `flutter analyze` → No issues found ✓. `flutter test test/features/match/pre_match_screen_test.dart test/features/match/injury_ui_test.dart` → **19/19 green** ✓ (the injury fixture compiles untouched). The first full run caught one more stale 'TOP PLAYERS' marker in `season_live_match_flow_test.dart`'s scroll-to-card step — updated to 'TOP PLAYER' (1/1 green after). Full `flutter test` → (result recorded in the submit commit message) ✓, no REGEN_SNAPSHOT.

**Concerns / assumptions:**
- The '12th vs 5th' positions line is the same two ordinals the old panel showed per-side, now side-by-side in one row — data unchanged, presentation only.
- The section heading stays hardcoded EN ('TOP PLAYER') per this file's own convention (as the task's context notes) — the club names are data and mirror in RTL.
- The user's best uses the key-men formula on EFFECTIVE (post-upgrade) attributes via `card.attribute`, matching how the squad's strength is computed elsewhere; `overall` on the card face is `card.overall` (post-upgrade too).

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->

### Review 1 — 2026-11-10 — PASS

**Ran (Flutter 3.47.9 / Dart 3.13.7, current main):**
- `flutter analyze` → No issues found! ✓
- `flutter test test/features/match/pre_match_screen_test.dart test/features/match/injury_ui_test.dart` → **19/19 green** ✓ (the injury fixture compiles untouched — no `PreMatchData` contract change)
- `flutter test test/features/season/season_live_match_flow_test.dart` → **1/1 green** ✓ (the updated 'TOP PLAYER' scroll marker)
- Full `flutter test` → **1004/1004, "All tests passed!"** on the re-run ✓ (includes the whole match suite). The first run failed exactly one test — the known intermittent audio flake at `packs_screen_test.dart:801`, owned by the pending T-0103 and unrelated to this change's area; the identical suite passed cleanly on the immediate re-run.
- Diff scope check (commit 787bb21): 4 files — `pre_match_analysis.dart`, the two test files (requirement 4's cases + the stale season live-flow marker), and this task file. All inside scope; `PreMatchData`, the key-men producer and its sort untouched ✓.
- Verified against the code: the header is one `[HOME chip] VS [AWAY chip]` row with `userAtHome` deciding the order and the user's chip gold-accented, no hardcoded left/right (Row order mirrors with text direction); the fixture label, form pips and positions comparison survive below ✓. The top section: the user's best via `_bestOfSquad` using the producer's exact formula — `((attack + support + defence) / 3).round()` on `card.attribute(...)` (effective post-upgrade attributes), identical to `SeasonStore._overallOf` / `_userMatchPlayer`, first-max tie-break — and the opponent's best as `opponentKeyMen.first`; `sides` ordered home-first like the header; `if (userBest == null || opponentBest == null) return const SizedBox()` hides the whole section on an empty side; heading 'TOP PLAYER' ✓. The away-fixture Arabic-locale test pins the mirrored pump with no overflow ✓.

All four criteria met; every verify command run by the reviewer.
