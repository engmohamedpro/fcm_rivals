---
id: T-0077
title: Hide the app bar on the Team tab only
priority: high
status: todo
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
- [x] The transition is animated — no hard layout jump when switching tabs.
- [ ] No status-bar overlap or dead gap on the Team tab in LTR and RTL; `flutter analyze` zero warnings.
- [x] New widget tests cover hidden (Team), shown (default), restored (switch back), in both text directions, with no overflow errors.
- [x] Full `flutter test` green; no performance regression in tab switching (the only-selected-tab-is-built behavior from ff05b44 is preserved).

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/core/ui/shell_directionality_test.dart test/core/ui/fcm_bottom_nav_test.dart
# Expected: all pass, including the new appbar hide/show cases in LTR + RTL

flutter test
# Expected: full suite green, no REGEN_SNAPSHOT
```

---

## Review Log

### Review 2026-11-09, attempt 1: FAIL
- File note: this task was authored without the Developer Notes / Review Log sections (older planning format); the developer's implementation summary lives in commit 4cf83bb's message. The Review Log section is added by this review per the reviewer workflow.
- Ran with the shell code exactly at 4cf83bb (review commits touch task files + the evidence probe only), fresh Flutter 3.47.9 / Dart 3.13.7: `flutter analyze` — No issues found on the committed code (the only 2 warnings were the reviewer's own probe import, fixed before commit); `flutter test test/core/ui/shell_directionality_test.dart test/core/ui/fcm_bottom_nav_test.dart test/core/ui/game_shell_appbar_test.dart` — 9/9 green; full `flutter test` — 927/927 green (926 committed + the reviewer's evidence probe `test/core/ui/review_t0077_statusbar_probe_test.dart`).

**Failures:**
1. AC-1 / Requirement 1 — "every other index renders the current app bar unchanged": REGRESSION on EVERY tab on any device with a status bar.
   - Evidence (pre/post, `git worktree` at 4cf83bb^ vs HEAD): with a 40px top inset, pre-T-0077 the shell's AppBar lays out at 97px (40 inset + 52 toolbar + 5 seam — it absorbs the inset) and the body starts at y=97. At HEAD the same inset measures: app-bar slot 57, body top 57. Root cause: `_CollapsibleAppBar._expandedHeight = bar.preferredSize.height` (57) — `AppBar.preferredSize` EXCLUDES the top inset — and the `OverflowBox(maxHeight: _expandedHeight)` clamps the real AppBar to 57, so on a device the toolbar (which sits below a 40px internal top padding) is clipped to ~17 visible pixels; the wordmark, language toggle and coin balance render under the clock/notch. The developer's calibration "measured the original shell via stash: 57, not 62" was measured in a ZERO-padding test environment — 57 is the zero-padding height; the device height is 97.
2. AC-3 / Requirement 3 — "with the app bar hidden, the Team tab's content must not sit under the status bar": OVERLAP confirmed.
   - Evidence (probe committed with this review): with a 40px top inset, after settling on Team the body's top edge is y=0.0 — content renders directly under the status bar. In Flutter 3.47.9 the Scaffold's `contentTop` is the app bar's LAID-OUT height (`_ScaffoldLayout`: `appBarHeight = layoutChild(_ScaffoldSlot.appBar, fullWidthConstraints).height; contentTop = appBarHeight`) — the app bar gets LOOSE height constraints, nothing absorbs the inset when the slot collapses to 0 (SquadScreen and FcmBackdrop have no SafeArea), so the code comment "the Scaffold lays the body out from the status-bar inset down" does not match 3.47.9 behavior.
3. Requirement 5 / test honesty: the second committed test is NAMED "Team tab content starts below the status-bar inset, not under it and not with a dead gap" but asserts only the bottom nav's docking — the body's top edge is never measured and the whole suite runs with zero view padding, so the inset path is never exercised. All 4 committed tests pass while the shipped behavior is broken on devices.

**Passed:** AC-2 (transition is animated — verified in the 3.47.9 SDK source that the app bar slot gets LOOSE height constraints, so the TweenAnimationBuilder genuinely drives the layout height and the body follows it), AC-4 (hidden/shown/restored covered in both text directions, no overflow exceptions), AC-5 (full suite green 927/927; the only-selected-tab-is-built behavior is unchanged — the AnimatedSwitcher body is untouched), and the analyze half of AC-3. Out of scope respected (only `lib/main.dart`, the new test and the task file).

**What to do (one coherent fix, then resubmit):**
1. Make the wrapper inset-aware: expanded height = `MediaQuery.paddingOf(context).top + bar.preferredSize.height`; collapsed height = the inset itself. The animation then collapses only the toolbar+seam (57px) — exactly the space the owner wanted freed: Team body top = inset (no overlap, no dead gap), every other tab = inset + 57, layout identical to pre-T-0077 on devices and unchanged in zero-padding tests.
2. Raise the `OverflowBox` maxHeight to the inset-aware expanded height so the real AppBar is never clamped below its natural height. Whether the residual inset-high slot paints a slim chrome strip or is clipped empty on Team is an implementation choice — both satisfy the criterion.
3. Extend `game_shell_appbar_test.dart`: inject a nonzero top `FakeViewPadding` (e.g. 40px) and ASSERT the settled body top — Team == 40, Season == 40 + 57 — in both text directions. That is the invariant the current second test claims in its name but never checks.
4. Re-verify: `flutter analyze`; `flutter test test/core/ui/`; full `flutter test`; and run the committed probe — its PROBE verdict line must print "content starts below the inset (OK)".
