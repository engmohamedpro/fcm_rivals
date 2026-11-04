# Match finish flow: busy-wait polling and unmounted setState
- Feature: match-screen
- Type: Bug
- Priority: Critical
- Reviewer: Kareem
- Created: 2026-11-04
- Status: OPEN
- Completed by: -
- Completed on: -

## Context
`_finishMatch` parks the full-time persistence behind a 50 ms `Future.delayed` polling loop while the recovery card is up, and every `setState` after an `await` in the same method runs without a `mounted` guard. The recovery card also writes its choice field without any tap feedback and dismisses to "no pep talk" on any background tap, silently discarding the ad-boost option.

## Tasks
- [ ] Task 1: Replace the 50 ms polling loop in `_finishMatch` with a `Completer<_RecoveryChoice>` resolved by the card's tap handlers | Where: `lib/features/match/match_screen.dart:342-345` (loop), `:397/:447/:461/:466` (tap sites writing `_postMatchChoice`) | Expected: no `Future.delayed` polling anywhere in the file; the choice resolves the completer exactly once (guard double-tap with a `bool _choiceMade`); recovery card state machine (shown → answered) has a widget test covering "tap pep talk → finish() called with that talk" and "tap ad boost → adBoostedRecovery: true".
- [ ] Task 2: Guard every `setState` that follows an `await` in `_finishMatch` with `mounted` | Where: `lib/features/match/match_screen.dart:364` (after `session.finish` + `onFullTime`) and `:374` (catch path) | Expected: `flutter analyze` clean; the two calls become `if (mounted) setState(...)`; a widget test that pops the screen mid-finish (pump `MatchScreen`, drive to full time, immediately pop before `onFullTime` completes) passes without "setState() called after dispose()".
- [ ] Task 3: Make the recovery card's background tap not silently discard the boosted option | Where: `lib/features/match/match_screen.dart:396-398` (`GestureDetector onTap → _RecoveryChoice.none()`) | Expected: background tap requires a second tap to confirm skip (first tap shows a "Tap again to skip" hint on the dim layer) OR the dim layer becomes non-interactive and only the explicit "No pep talk" button skips; add a tap-ripple/pressed state on `_RecoveryOption` rows (currently plain `FcmPressable` scale only on tap-down is fine — verify it is applied); widget test for the chosen behaviour.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] No `Future.delayed` polling loop remains in match_screen.dart
- [ ] No `setState` after `await` without a `mounted` guard in match_screen.dart
- [ ] Match report + reward flow behaviour unchanged (recovery choice semantics identical)

## Developer Notes
<Implementation notes, rejected points with reason.>

## Reviewer Verification
<Filled by reviewer before setting CLOSED.>
