# Season screen: stale-fixture crash path and unguarded setState after awaits
- Feature: season-screen
- Type: Bug
- Priority: Major
- Reviewer: Kareem
- Created: 2026-11-04
- Status: OPEN
- Completed by: -
- Completed on: -

## Context
`_playNextFixture` force-unwraps `getNextFixture()` with `!`, so any staleness between `nextFixtureProvider` and the store (a commit landing between rebuild and tap, or a provider invalidated mid-run) crashes with a null assertion instead of showing a message. `_run` and `_playNextFixture` also call `setState` after `await` with no `mounted` guard on the success path, and `_maybeCompleteSeason` runs with no `_busy` guard so it can be double-triggered.

## Tasks
- [ ] Task 1: Handle a null fixture in `_playNextFixture` instead of unwrapping | Where: `lib/features/season/season_screen.dart:62` (`(await store.getNextFixture())!`) | Expected: null is handled gracefully — refresh `nextFixtureProvider` and show "No fixture ready — pull to refresh" style feedback (or silently return with provider invalidation); a unit/widget test simulating a stale provider (next shown, store returns null) passes without a null-check crash.
- [ ] Task 2: Guard `setState` after every `await` in `_run` and `_playNextFixture` | Where: `lib/features/season/season_screen.dart:38` (success path, after `await action(...)`), `:40` (catch), `:91` (after navigation awaits), `:109` (catch) | Expected: all four become `if (mounted) setState(...)`; `flutter analyze` clean; existing season flow tests still green.
- [ ] Task 3: Run `_maybeCompleteSeason` under the `_busy` guard | Where: `lib/features/season/season_screen.dart:213-222` (no `_busy` check, unlike `_run` at `:30` and `_playNextFixture` at `:58`) and `:494` (call site) | Expected: `_maybeCompleteSeason` early-returns while `_busy` is true and the "Complete season" button shows a loading state while it runs (match `_run`'s pattern); a double-tap test proves `completeSeason` executes exactly once.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] No unguarded `!` on nullable store results in season_screen.dart
- [ ] No `setState` after `await` without a `mounted` guard in season_screen.dart

## Developer Notes
<Implementation notes, rejected points with reason.>

## Reviewer Verification
<Filled by reviewer before setting CLOSED.>
