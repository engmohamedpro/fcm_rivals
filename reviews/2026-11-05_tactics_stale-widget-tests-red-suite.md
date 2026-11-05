# Tactics: commit 0218dc7 shipped with two stale widget tests (red suite)
- Feature: tactics
- Type: Test
- Priority: Critical
- Reviewer: Coach Hady
- Created: 2026-11-05
- Status: OPEN
- Completed by: -
- Completed on: -

## Context
Re-verification of the tactics phases ran the full suite on main (`0218dc7`): 684 pass, 6 fail. Four failures are the known phase-3 balance bands (separate review), but TWO are widget-test regressions the Developer Notes do not mention: commit `0218dc7` replaced the last `_PhasePlaceholder` in `tactics_sections.dart` with real Transitions controls and never updated the two tests that assert the old UI. Main's suite is red, which blocks every future review's "tests green" acceptance criterion. Proven not pre-existing: both tests pass on the parent commit `f6ecab1`.

## Tasks
- [ ] Task 1: Fix the 'Balanced' count in the tactic-options sheet test | Where: `test/features/squad/squad_view_test.dart:277` | Expected: the count accounts for the three new Transitions segmented rows (each selected option renders a 'Balanced' chip at defaults). Measured today: 5 found, 3 expected. Update the expectation AND the comment above it to enumerate every source of the string, or scope the finder to a specific section (`find.descendant(of:)`) so the count survives future instruction rows. Verify: `flutter test test/features/squad/squad_view_test.dart` green.
- [ ] Task 2: Fix the 'Default setup' assertion in the season live-match flow test | Where: `test/features/season/season_live_match_flow_test.dart:192` | Expected: the `_PhasePlaceholder` widget (the only renderer of `tacticsSectionDefault`) no longer exists — all three sections ship real controls. Replace the stale `expect(find.text('Default setup'), findsOneWidget)` with an assertion on the real default state (e.g. the three localized section titles, or the Transitions rows' selected 'Balanced' chips). Verify: `flutter test test/features/season/season_live_match_flow_test.dart` green.
- [ ] Task 3: Never ship red again | Where: `reviews/README.md` developer rule 4 ("analyzer clean") | Expected: before any `feat(...)` commit that changes UI or engine behaviour, run the full suite (`flutter test`) — not only the new feature's tests. The two stale assertions were both in files touched by earlier tactics commits; a full-suite run before committing `0218dc7` would have caught them.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] `flutter test` full suite: only the four known phase-3 balance failures may remain red (tracked in `2026-11-05_tactics_phase3-balance-bands-and-sweep`); zero widget-test failures
- [ ] Both fixed tests assert the CURRENT UI structure (no counting tricks that re-break on the next instruction row)

## Developer Notes
<Implementation notes, rejected points with reason.>

## Reviewer Verification
<Filled by reviewer before setting CLOSED.>
