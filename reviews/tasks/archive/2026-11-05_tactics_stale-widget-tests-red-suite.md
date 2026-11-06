# Tactics: commit 0218dc7 shipped with two stale widget tests (red suite)
- Feature: tactics
- Type: Test
- Priority: Critical
- Reviewer: Coach Hady
- Created: 2026-11-05
- Status: CLOSED
- Completed by: Kareem
- Completed on: 2026-11-05

## Context
Re-verification of the tactics phases ran the full suite on main (`0218dc7`): 684 pass, 6 fail. Four failures are the known phase-3 balance bands (separate review), but TWO are widget-test regressions the Developer Notes do not mention: commit `0218dc7` replaced the last `_PhasePlaceholder` in `tactics_sections.dart` with real Transitions controls and never updated the two tests that assert the old UI. Main's suite is red, which blocks every future review's "tests green" acceptance criterion. Proven not pre-existing: both tests pass on the parent commit `f6ecab1`.

## Tasks
- [x] Task 1: Fix the 'Balanced' count in the tactic-options sheet test | Where: `test/features/squad/squad_view_test.dart:277` | Expected: the count accounts for the three new Transitions segmented rows (each selected option renders a 'Balanced' chip at defaults). Measured today: 5 found, 3 expected. Update the expectation AND the comment above it to enumerate every source of the string, or scope the finder to a specific section (`find.descendant(of:)`) so the count survives future instruction rows. Verify: `flutter test test/features/squad/squad_view_test.dart` green.
- [x] Task 2: Fix the 'Default setup' assertion in the season live-match flow test | Where: `test/features/season/season_live_match_flow_test.dart:192` | Expected: the `_PhasePlaceholder` widget (the only renderer of `tacticsSectionDefault`) no longer exists — all three sections ship real controls. Replace the stale `expect(find.text('Default setup'), findsOneWidget)` with an assertion on the real default state (e.g. the three localized section titles, or the Transitions rows' selected 'Balanced' chips). Verify: `flutter test test/features/season/season_live_match_flow_test.dart` green.
- [x] Task 3: Never ship red again | Where: `reviews/README.md` developer rule 4 ("analyzer clean") | Expected: before any `feat(...)` commit that changes UI or engine behaviour, run the full suite (`flutter test`) — not only the new feature's tests. The two stale assertions were both in files touched by earlier tactics commits; a full-suite run before committing `0218dc7` would have caught them.

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated
- [x] EN/AR localized, RTL verified
- [x] No performance regression
- [x] `flutter test` full suite: only the four known phase-3 balance failures may remain red (tracked in `2026-11-05_tactics_phase3-balance-bands-and-sweep`); zero widget-test failures
- [x] Both fixed tests assert the CURRENT UI structure (no counting tricks that re-break on the next instruction row)

## Developer Notes
- Task 1: both assertions are now SCOPED, not bare counts. The
  slider's 'Balanced' marker label is scoped to `FcmScaleSlider`
  (findsOneWidget); the default-chip 'Balanced' count is scoped to
  `TacticsGroupScaffold` and set to 4 with the sources enumerated in
  the comment: final-third chip (In Possession), tackling chip (Out of
  Possession), counter-press + attack-on-recovery chips (Transitions).
  Note the reviewer's premise was 3 because rest defence's default
  chip reads 'Standard · 3 back', not 'Balanced' — hence 4, not 3.
  A future instruction row can move the scoped count but can never
  touch the slider label again.
- Task 2: replaced the stale `Default setup` expectsOneWidget with
  assertions on the CURRENT structure: the three Transitions row
  labels (COUNTER-PRESS / ATTACK ON RECOVERY / REST DEFENCE — the
  segmented rows upper-case their labels) plus the rest-defence
  default chip 'Standard · 3 back', and `Default setup` now asserted
  as findsNothing (the placeholder class is gone). Structure-based,
  not count-based.
- Task 3: added developer rule 9 to `reviews/README.md`: full-suite
  run before any commit that changes UI or engine behaviour.
- Verification: `flutter analyze` zero issues; full suite on main with
  these fixes = 686 passed, 4 failed — all four are the known phase-3
  balance failures, zero widget-test failures. `tacticsSectionDefault`
  ('Default setup' / 'الإعداد الافتراضي') remains in the ARB files;
  it is now unused by any widget but harmless for localization
  lookups until the next ARB cleanup.


- Dated verification run (2026-11-05, Kareem, per
  `2026-11-05_reviews_lifecycle-compliance-audit` Task 2, executed on
  a full Flutter 3.47.9 stable environment):
  - `flutter analyze`: **No issues found** (ran in 13.0s).
  - `flutter test` full suite on HEAD `baaf21a`:
    **705 passed, 4 failed** — the four failures are exactly the
    known phase-3 balance bands tracked in
    `2026-11-05_tactics_phase3-balance-bands-and-sweep`:
    1. In Possession: the full 3x3x3x4 matrix stays inside the
       global anchors
    2. Out of Possession: single-instruction extremes 46-54%
    3. Transitions: park-the-bus counter 30-42% possession
    4. Transitions: single-instruction extremes 46-54%
  - **Zero widget-test failures** — both fixed assertions hold
    (`squad_view_test.dart` scoped `findsNWidgets(4)` inside
    `TacticsGroupScaffold`; `season_live_match_flow_test.dart`
    structure-based Transitions assertions). This satisfies this
    review's Acceptance Criterion "only the four known phase-3
    balance failures may remain red, zero widget-test failures".

## Reviewer Verification
Verified 2026-11-06 — CLOSED on a static + recorded-run basis. Implementation commits: `0d6dcae` (scoped assertions + README developer rule 9), `045650f` (dated verification run). Checks performed: (1) static, re-confirmed today on d0fbb88 — `test/features/squad/squad_view_test.dart:298` asserts `findsNWidgets(4)` scoped to `TacticsGroupScaffold` with the chip sources enumerated; `test/features/season/season_live_match_flow_test.dart:201` asserts the real Transitions structure with `Default setup` as `findsNothing` — both structure-based, so they survive future instruction rows; (2) two independent dated full-suite runs corroborate the criterion: HEAD `baaf21a` (2026-11-05, Developer Notes above) and HEAD `fd5798d` (2026-11-05, audit file addendum) — both `flutter analyze` clean and `flutter test` 705 passed / 4 failed with exactly the four tracked phase-3 balance bands, zero widget-test failures; (3) commits after `baaf21a` touch only `tool/` tuning scripts and review documentation — no widget or engine-behaviour changes (verified via git log). Limitation: this sandbox has no Flutter SDK, so the suite was not re-run here; closure rests on the two dated developer runs corroborated by static inspection — the strongest available verification per §6.A. All Acceptance Criteria met.
