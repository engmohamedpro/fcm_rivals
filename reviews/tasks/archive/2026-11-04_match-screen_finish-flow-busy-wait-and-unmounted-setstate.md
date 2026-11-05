# Match finish flow: busy-wait polling and unmounted setState
- Feature: match-screen
- Type: Bug
- Priority: Critical
- Reviewer: Kareem
- Created: 2026-11-04
- Status: CLOSED
- Completed by: Kareem
- Completed on: 2026-11-04

## Context
`_finishMatch` parks the full-time persistence behind a 50 ms `Future.delayed` polling loop while the recovery card is up, and every `setState` after an `await` in the same method runs without a `mounted` guard. The recovery card also writes its choice field without any tap feedback and dismisses to "no pep talk" on any background tap, silently discarding the ad-boost option.

## Tasks
- [x] Task 1: Replace the 50 ms polling loop in `_finishMatch` with a `Completer<_RecoveryChoice>` resolved by the card's tap handlers | Where: `lib/features/match/match_screen.dart:342-345` (loop), `:397/:447/:461/:466` (tap sites writing `_postMatchChoice`) | Expected: no `Future.delayed` polling anywhere in the file; the choice resolves the completer exactly once (guard double-tap with a `bool _choiceMade`); recovery card state machine (shown → answered) has a widget test covering "tap pep talk → finish() called with that talk" and "tap ad boost → adBoostedRecovery: true".
- [x] Task 2: Guard every `setState` that follows an `await` in `_finishMatch` with `mounted` | Where: `lib/features/match/match_screen.dart:364` (after `session.finish` + `onFullTime`) and `:374` (catch path) | Expected: `flutter analyze` clean; the two calls become `if (mounted) setState(...)`; a widget test that pops the screen mid-finish (pump `MatchScreen`, drive to full time, immediately pop before `onFullTime` completes) passes without "setState() called after dispose()".
- [x] Task 3: Make the recovery card's background tap not silently discard the boosted option | Where: `lib/features/match/match_screen.dart:396-398` (`GestureDetector onTap → _RecoveryChoice.none()`) | Expected: background tap requires a second tap to confirm skip (first tap shows a "Tap again to skip" hint on the dim layer) OR the dim layer becomes non-interactive and only the explicit "No pep talk" button skips; add a tap-ripple/pressed state on `_RecoveryOption` rows (currently plain `FcmPressable` scale only on tap-down is fine — verify it is applied); widget test for the chosen behaviour.

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated
- [ ] EN/AR localized, RTL verified (tracked app-wide by the localization review — see Developer Notes)
- [x] No performance regression
- [x] No `Future.delayed` polling loop remains in match_screen.dart
- [x] No `setState` after `await` without a `mounted` guard in match_screen.dart
- [x] Match report + reward flow behaviour unchanged (recovery choice semantics identical)

## Developer Notes
- Task 1: `_finishMatch` now awaits a `Completer<_RecoveryChoice>` resolved by
  `_answerRecovery()`; the `bool _choiceMade` guard makes the first tap win
  (double-tap test proves the first option is committed). `dispose()` errors
  the pending completer (guarded by `isCompleted`) so a torn-down screen never
  parks the finish forever. The 50 ms `Future.delayed` loop is gone — the file
  has no `Future.delayed` at all now.
- Task 2: both post-await `setState` calls in `_finishMatch` (success and
  catch) are `if (mounted)`-guarded; the `ref.invalidate` trio moved inside
  the same guard. Widget test disposes the screen mid-finish with the card
  still up — no setState-after-dispose, and the completer error path leaves
  the default recovery in place.
- Task 3: chose the confirm-first-skip pattern — the first scrim tap arms a
  gold hint ("Tap outside again to skip without a pep talk"), the second
  confirms; the explicit "No pep talk" button still skips in one tap.
  `_RecoveryOption` rows already render through `FcmPressable` (scale 0.98
  tap-down feedback) — verified, unchanged.
- Tests: 4 new widget tests in `../../../test/features/match/match_screen_test.dart`
  (pep-talk commit-once + report status line, ad-boost after a deterministic
  defeat — probed seed 3 / opponent 95 —, scrim double-tap skip, dispose
  mid-finish). `sessionDb` provider override added to the pumped scopes so the
  club lookups reuse the test's database instead of opening a second drift
  instance. The remaining drift "multiple databases" warning pre-exists on
  main (verified via git stash) and comes from the older full-time test, not
  from this change.
- Note (EN/AR AC item): the recovery card strings remain hardcoded English
  like the rest of the match feature — the localization review
  `2026-11-04_localization_missing-ar-layer-and-rtl-unsafe-layout` tracks the
  app-wide ARB migration; nothing in this fix added new hardcoded strings
  beyond moving existing ones into the new hint.

## Reviewer Verification
Verified by Coach Hady on 2026-11-04 (re-review ran the full suite the
developer skipped):
- Task 1 ✔: `grep Future.delayed lib/features/match/match_screen.dart` → 0
  hits; `Completer<_RecoveryChoice>` awaited at `_finishMatch`
  (match_screen.dart:358), `_answerRecovery` guards double-taps with
  `_choiceMade` (:406-408); `dispose()` errors the pending completer only
  when `!isCompleted` (:184-199). Widget tests: pep-talk commit-once
  (test line 401), ad-boost after defeat (line 448) — both green in the
  full-suite run.
- Task 2 ✔: both post-await `setState` calls guarded
  (success :393-402 with `ref.invalidate` inside the guard, catch :445);
  dispose-mid-finish test (line 534) green — no setState-after-dispose.
- Task 3 ✔: confirm-first-skip implemented — first scrim tap arms the
  gold hint (literal at :516, arm/disarm in `_confirmSkipOnScrim`
  :530-537); scrim double-tap test (line 488) green; `_RecoveryOption`
  rows render through `FcmPressable`.
- AC ✔ except EN/AR (explicitly deferred to the localization track —
  correct call, tracked there). Full `flutter test` suite: this feature's
  6 tests all pass.
- Follow-up filed: the armed hint is still an English literal
  (`tapAgainToSkip` ARB key exists unused) → covered by
  `2026-11-04_localization_skip-hint-rtl-test-and-phase2-tracking.md`.
- Perf: the 50ms polling loop removal is a strict win (zero timers while
  the card is up vs. 20 wakeups/sec before). No size delta.
