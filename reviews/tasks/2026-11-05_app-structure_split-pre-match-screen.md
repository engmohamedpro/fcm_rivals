# App structure: split the pre-match screen by phase

- Feature: app-structure
- Type: Refactor
- Priority: Minor
- Created: 2026-11-05
- Status: DONE
- Completed on: 2026-11-06

## Context
One of ten follow-ups carved out of `2026-11-04_app-structure_remaining-oversized-files` (set to SPLIT 2026-11-05 per the README §1 one-file-per-task rule). The README's ~800-line split threshold (README.md:72-74) is contradicted by `lib/features/match/pre_match_screen.dart` (1,187 lines on 2026-11-05). Split it following the proven `fcm_widgets.dart` barrel pattern so consumer imports never churn.

## Investigation & Evidence
- Investigation: `pre_match_screen.dart` measured 1,179 lines at task creation (2026-11-04), 1,187 on 2026-11-05; the analysis family and the tactics/pep-talk/bottom-bar family share one file (anchors at creation: analysis family :204-772, tactics/pep-talk/bottom-bar family :773+).
- Root cause / technical justification: per-phase UI families live inside the screen file; the god-files review split only its two in-scope targets.
- Affected files/components: `lib/features/match/pre_match_screen.dart`
- Evidence: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` lists the file on main.
- Expected benefit / necessity: makes the README convention real; measurable target — every resulting file ≤800 lines.
- Dependencies / side effects: widget move only; screen behaviour and the live match flow must stay identical.

## Reproduction Steps
Not applicable.

## Task
- [x] Split the pre-match screen by phase | Where: `lib/features/match/pre_match_screen.dart` (1,187 lines on 2026-11-05; anchors above) | Expected: `pre_match_analysis.dart` (opponent header, forecast, strength, mirror bar, top players) and `pre_match_phases.dart` (tactics phase, pep-talk phase/tiles, bottom bar); `pre_match_screen_test.dart` and the live match flow green with zero test edits.

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated; full `flutter test` suite passes
- [x] EN/AR localization complete and RTL verified where applicable (N/A — verbatim widget move; no text, directionality or layout code changed)
- [x] No performance or application-size regression (widget move only, no behaviour change)
- [x] Every resulting file ≤800 lines (excluding generated `*.g.dart`)
- [x] `pre_match_screen_test.dart` and the live match flow suites green with zero test edits

## Developer Notes
- Split landed 2026-11-06. New `lib/features/match/pre_match_analysis.dart`
  (584 lines) carries the analysis family: `AnalysisPhase` (was private
  `_AnalysisPhase`) with `_OpponentHeader`, `_ForecastCard`,
  `_OutcomeStat`, `_StrengthCard`, `_MirrorBar` and `_TopPlayersCard`.
  New `lib/features/match/pre_match_phases.dart` (437 lines) carries the
  phases family: `TacticsPhase` + `_squadFor`, `PepTalkPhase` +
  `_PepTalkTile`, and `BottomBar`. All moved VERBATIM — no logic,
  signature, callback or text changes.
- Dart privacy is per-library, so the three phase widgets the screen's
  `AnimatedSwitcher` instantiates across file boundaries had to become
  public (`_AnalysisPhase`→`AnalysisPhase`, `_TacticsPhase`→`TacticsPhase`,
  `_PepTalkPhase`→`PepTalkPhase`, `_BottomBar`→`BottomBar`; all four
  names verified unused elsewhere in lib/ and test/ — no collision).
  Inner helpers stayed private. The Context's barrel pattern is not
  applicable here: unlike `live_match_views.dart`, nothing imports this
  family set for its widgets — consumers (`routes.dart`,
  `match_session.dart`, `season_screen.dart`, `season_store.dart`)
  import only `PreMatchScreen`/`PreMatchTacticSelection`, which stay in
  `pre_match_screen.dart` unchanged, so the screen file imports the two
  siblings directly and consumer imports still never churn.
- `pre_match_screen.dart` (193 lines) keeps the flow shell:
  `PreMatchScreen` + `_PreMatchScreenState` + `PreMatchTacticSelection`,
  the phase `AnimatedSwitcher` and the back/kick-off wiring — identical
  behaviour, identical public API.
- Verification: `wc -l` → pre_match_screen.dart 193,
  pre_match_analysis.dart 584, pre_match_phases.dart 437 (all ≤800);
  `flutter analyze` → No issues found!; targeted suites `flutter test
  test/features/match/pre_match_screen_test.dart
  test/features/match/live_match_ux_test.dart` → 24/24 passed.
- Final suite summary line: `flutter test` → `05:26 +709: All tests
  passed!` — 709/709, the same test count as before the split (709 at
  `4ea2416`), i.e. ZERO test edits, exactly as the task requires.

## Reviewer Verification
<Reviewer records verification date, tested commit hash, checks performed, results, and remaining limitations. Do not add personal names.>

## Links
- Depends on: None
- Follows: `2026-11-04_app-structure_remaining-oversized-files`
- Follow-up: None

## Amendments
<Reviewer-owned, append-only. Add dated entries correcting the task's target or mechanism; never rewrite the original task text.>
