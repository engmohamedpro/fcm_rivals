---
id: T-0077
title: Hide the app bar on the Team tab only
priority: high
status: needs-review
attempts: 1
depends_on: []
created: 2026-11-09
completed:
---

# T-0077: Hide the app bar on the Team tab only

## Goal
The game shell's AppBar is hidden while the Team tab is active and shown on every other tab — with an animated transition, correct status-bar insets and no layout jump (owner decision 2026-11-09).

## Context
- The shell lives in `lib/main.dart`: `_GameShellBodyState.build` (lines ~241-292) — a `Scaffold` whose `AppBar` (toolbarHeight 52, `_AppBarChrome`, `FcmGoldSeam` bottom, `FcmWordmark` title, actions: `_LanguageToggle`, debug-only `_TestCoinButton`, `_CoinBalance`) is currently rendered on ALL tabs. Tabs: 0 Season, 1 Team (`SquadScreen`), 2 Collection, 3 Campus, 4 Store (the `_page` switch, lines ~232-238).
- The Team tab needs the vertical space: the squad pitch + control card are the tallest tab content. Hiding the app bar there frees ~57px (52 toolbar + 5 seam).
- Consequence the owner accepts by asking for this: while the Team tab is active the coin balance and language toggle are not visible (they live in the app bar). They return on the other four tabs. Do NOT relocate them into the squad screen.
- The body cross-fades via `AnimatedSwitcher` (200ms) — the app bar change must not be a hard jump; animate it.
- Shell tests to extend: `test/core/ui/shell_directionality_test.dart` (has a `pumpShell` helper that pumps the real `GameShell` and asserts no overflow in LTR/RTL) and `test/core/ui/fcm_bottom_nav_test.dart` (nav interaction pattern).

## Requirements
1. `lib/main.dart` — when `_index == 1` the Scaffold renders NO app bar (Team tab only); every other index renders the current app bar unchanged (wordmark, actions, seam, chrome, elevation).
2. The hide/show transition is animated (e.g. an animated height/slide of the chrome, or an equivalent mechanism the implementer chooses) — no instant jump, no flicker, matching the body's 200ms cross-fade feel.
3. Status-bar insets: with the app bar hidden, the Team tab's content must not sit under the status bar and must not gain a white gap; with it shown, other tabs look exactly as today. The bottom nav (`FcmBottomNav`) and the gold seam on other tabs are untouched.
4. `extendBodyBehindAppBar` / `MediaQuery` padding behavior stays correct in both LTR and RTL.
5. Tests (extend `test/core/ui/shell_directionality_test.dart` or add `test/core/ui/game_shell_appbar_test.dart` following its `pumpShell` pattern): (a) default Season tab shows an AppBar; (b) tapping the Team tab hides it; (c) tapping Season again restores it; (d) run the hidden/shown cycle in RTL too; (e) no overflow exceptions in any state.

## Out of Scope
- Moving the coin balance / language toggle / dev coin button anywhere else.
- Changing the bottom nav, the squad screen's own layout, or any other tab's content.
- Hiding the app bar on any other tab, or making the hide permanent.

## Acceptance Criteria
- [ ] Team tab (index 1) shows no AppBar; Season/Collection/Campus/Store show it exactly as today.
- [ ] The transition is animated — no hard layout jump when switching tabs.
- [ ] No status-bar overlap or dead gap on the Team tab in LTR and RTL; `flutter analyze` zero warnings.
- [ ] New widget tests cover hidden (Team), shown (default), restored (switch back), in both text directions, with no overflow errors.
- [ ] Full `flutter test` green; no performance regression in tab switching (the only-selected-tab-is-built behavior from ff05b44 is preserved).

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/core/ui/shell_directionality_test.dart test/core/ui/fcm_bottom_nav_test.dart
# Expected: all pass, including the new appbar hide/show cases in LTR + RTL

flutter test
# Expected: full suite green, no REGEN_SNAPSHOT
```
