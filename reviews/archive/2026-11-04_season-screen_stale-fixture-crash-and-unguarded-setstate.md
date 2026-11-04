# Season screen: stale-fixture crash path and unguarded setState after awaits
- Feature: season-screen
- Type: Bug
- Priority: Major
- Reviewer: Kareem
- Created: 2026-11-04
- Status: CLOSED
- Completed by: Kareem
- Completed on: 2026-11-04

## Context
`_playNextFixture` force-unwraps `getNextFixture()` with `!`, so any staleness between `nextFixtureProvider` and the store (a commit landing between rebuild and tap, or a provider invalidated mid-run) crashes with a null assertion instead of showing a message. `_run` and `_playNextFixture` also call `setState` after `await` with no `mounted` guard on the success path, and `_maybeCompleteSeason` runs with no `_busy` guard so it can be double-triggered.

## Tasks
- [x] Task 1: Handle a null fixture in `_playNextFixture` instead of unwrapping | Where: `lib/features/season/season_screen.dart:62` (`(await store.getNextFixture())!`) | Expected: null is handled gracefully — refresh `nextFixtureProvider` and show "No fixture ready — pull to refresh" style feedback (or silently return with provider invalidation); a unit/widget test simulating a stale provider (next shown, store returns null) passes without a null-check crash.
- [x] Task 2: Guard `setState` after every `await` in `_run` and `_playNextFixture` | Where: `lib/features/season/season_screen.dart:38` (success path, after `await action(...)`), `:40` (catch), `:91` (after navigation awaits), `:109` (catch) | Expected: all four become `if (mounted) setState(...)`; `flutter analyze` clean; existing season flow tests still green.
- [x] Task 3: Run `_maybeCompleteSeason` under the `_busy` guard | Where: `lib/features/season/season_screen.dart:213-222` (no `_busy` check, unlike `_run` at `:30` and `_playNextFixture` at `:58`) and `:494` (call site) | Expected: `_maybeCompleteSeason` early-returns while `_busy` is true and the "Complete season" button shows a loading state while it runs (match `_run`'s pattern); a double-tap test proves `completeSeason` executes exactly once.

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated
- [ ] EN/AR localized, RTL verified (tracked app-wide by the localization review — see Developer Notes)
- [x] No performance regression
- [x] No unguarded `!` on nullable store results in season_screen.dart
- [x] No `setState` after `await` without a `mounted` guard in season_screen.dart

## Developer Notes
- Task 1: `_playNextFixture` now handles a null fixture gracefully — it
  refreshes `nextFixtureProvider`/`seasonSummaryProvider`/`standingsProvider`,
  clears any stale error and returns. The null `!` unwrap is gone; the pre-match
  route still surfaces `loadPreMatchData`'s "No fixture to play" through its
  error scaffold with a BACK button (verified by test).
- Task 2: all four post-await `setState` calls (`_run` success + catch,
  `_playNextFixture` catch) are `if (mounted)`-guarded.
- Task 3: `_maybeCompleteSeason` runs under the `_busy` gate (early return +
  try/finally reset) and the "Complete season" button now shows the loading
  state via `FcmButton.loading` — the same pattern `_run` uses.
- Tests: new `test/features/season/season_screen_review_test.dart` — (1) the
  stale-fixture tap: the whole season is quick-simmed via the store's own
  `simulateRemainingFixtures` BEFORE the screen is pumped, then the stale Play
  tap walks the fixed flow (error scaffold → BACK) with no crash; (2) a
  double-tap on Complete season proving exactly ONE completed row lands in
  the seasons table. Existing season suites (live match flow, store,
  major findings) re-run green.
- Test-design note: the first draft drove the quick-sim inside
  `tester.runAsync` AFTER pumping the shell and hung (380 fixtures of engine
  work inside one runAsync window starves the tester). Moving the simulation
  before `pumpWidget` keeps the test at ~3s and isolates exactly the
  staleness condition.
- EN/AR AC item: same note as the match-screen review — the localization
  review tracks the app-wide ARB migration; no new hardcoded strings were
  introduced by these fixes.

## Reviewer Verification
Verified by Coach Hady on 2026-11-04 (re-review ran the full suite the
developer skipped):
- Task 1 ✔: `grep "getNextFixture())!" season_screen.dart` → 0 hits; the
  null path (season_screen.dart:67-79) invalidates
  nextFixture/seasonSummary/standings providers and clears the error —
  the review allowed "silently return with provider invalidation", which
  is what landed. Stale-fixture widget test green (the tap walks the
  pre-match error scaffold → BACK with no crash, ~3s runtime).
- Task 2 ✔: all four post-await `setState` sites guarded — `_run`
  success (:48) and catch (:64-67); `_playNextFixture` catch (:64);
  the `!mounted` early returns at :81/:104.
- Task 3 ✔: `_maybeCompleteSeason` early-returns on `_busy` (:235-236),
  resets in `finally` (:253), and the button carries `loading: _busy`
  (:522). Double-tap test proves exactly ONE completed season row.
- AC ✔: analyzer clean repo-wide; this feature's suites (review tests,
  live match flow, store tests, major findings) all green in the full
  run. No perf impact (guard flags only).
- Perf/size: no regressions; the loading state on Complete season is a
  UX improvement.
