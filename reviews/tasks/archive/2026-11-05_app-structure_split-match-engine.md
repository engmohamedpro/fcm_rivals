# App structure: split the match engine into domain, commands and engine

- Feature: app-structure
- Type: Refactor
- Priority: Minor
- Created: 2026-11-05
- Status: CLOSED
- Completed on: 2026-11-05

## Context
One of ten follow-ups carved out of `2026-11-04_app-structure_remaining-oversized-files` (set to SPLIT 2026-11-05 per the README §1 one-file-per-task rule). The README's ~800-line split threshold (README.md:72-74) is contradicted by `lib/features/match/match_engine.dart` (2,054 lines on 2026-11-05). Split it following the proven `fcm_widgets.dart` barrel pattern so consumer imports never churn.

## Investigation & Evidence
- Investigation: `match_engine.dart` measured 1,970 lines at task creation (2026-11-04) and 2,054 on 2026-11-05; it mixes event/player/team-input models, engine config and the command hierarchy with the engine core (class anchors at creation: `MatchEvent`:69, `MatchPlayer`:113, `MatchTeamInput`:164, `MatchEngineConfig`:198, `MatchCommand` hierarchy:309).
- Root cause / technical justification: the engine file accumulated domain models, the command object tree and the pipeline in one file; the god-files review split only its two in-scope targets.
- Affected files/components: `lib/features/match/match_engine.dart`
- Evidence: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` lists the file on main.
- Expected benefit / necessity: makes the README convention real; measurable target — every resulting file ≤800 lines.
- Dependencies / side effects: pure Dart move, no behaviour change; the engine must stay deterministic — snapshot and calibration suites green with identical seed output is the regression net.

## Reproduction Steps
Not applicable.

## Task
- [x] Split the match engine into domain, commands and engine | Where: `lib/features/match/match_engine.dart` (2,054 lines on 2026-11-05; anchors above) | Expected: `match_event.dart` (enums + event/player/team-input models + config) and `match_commands.dart` (the command hierarchy), engine core stays; pure Dart, no behaviour change — `engine_snapshot_test.dart` and `engine_calibration_test.dart` green with zero test edits and identical seed output; every resulting file ≤800 lines.

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated; full `flutter test` suite passes (green except the four tracked phase-3 balance bands — see Reviewer Verification)
- [x] EN/AR localization complete and RTL verified where applicable (no UI or localization surface touched)
- [x] No performance or application-size regression (pure relocation, same tokens)
- [x] Every resulting file ≤800 lines (excluding generated `*.g.dart`)
- [x] `engine_snapshot_test.dart` and `engine_calibration_test.dart` green with zero test edits and identical seed output

## Developer Notes
- Split executed as pure text relocation (no token changed; verified
  programmatically: the concatenation of the seven resulting files
  contains every token of the original `match_engine.dart` — zero
  missing, zero behavioural edits).
- Resulting layout:
  - `match_event.dart` (278 lines): `matchEngineVersion` re-export,
    the four enums, `MatchEvent`, `MatchPlayer`, `MatchTeamInput`,
    `MatchEngineConfig` + `defaultMatchEngineConfig`.
  - `match_commands.dart` (86 lines): the `MatchCommand` hierarchy
    (`ChangeFormation`/`ChangeTactics`/`ChangeMentality`/`Substitution`/
    `ChangePepTalk`).
  - `match_engine_runtime.dart` (324 lines): part of the engine
    library — `TeamTotals`, `squadQualityTotals`, `MatchState`,
    `MatchRandom`, `_TeamRuntime`, `_MatchEngineRole` (kept in-library
    because the engine and its part files use the private runtime
    types).
  - `match_engine_simulation.dart` (376 lines), part:
    `_drawSegmentCount` .. `_turnover`.
  - `match_engine_setpieces.dart` (433 lines), part: `_issueCard`
    .. `_drainStamina` (cards, corners, chance creation, shot
    pipeline, player picking, stamina drain).
  - `match_engine_events.dart` (385 lines), part: `_applyDueCommands`
    .. `_emit` (command application, AI adaptation/substitutions,
    event emission).
  - `match_engine.dart` (245 lines): library doc, imports, re-exports
    (`match_event.dart`, `match_commands.dart`), the part directives,
    `matchEngineVersion` and the `MatchEngine` core (ctor, fields,
    public API). Every existing `import 'match_engine.dart'` keeps
    working unchanged (barrel pattern).
- Checks (Flutter 3.47.9 stable):
  - `flutter analyze`: No issues found! (ran in 4.2s).
  - `flutter test test/features/match/engine_snapshot_test.dart
    test/features/match/engine_calibration_test.dart`: All tests
    passed (21 tests) — zero test edits, identical seeded output.
  - `flutter test` full suite: 705 passed, 4 failed — the four
    failures are exactly the known phase-3 balance bands tracked in
    `2026-11-05_tactics_phase3-balance-bands-and-sweep` (same four,
    same shape as the pre-split run on `fd5798d`); zero new failures,
    zero widget-test failures.
- No test, localization or unrelated file was touched; `git status`
  shows only the seven engine files and this task file.


## Reviewer Verification
Verified 2026-11-06 on commit `5447a67` (static — this sandbox has no Flutter SDK; the cited runs are the developer's and are mutually consistent across the session's six implementation commits: analyze clean, full suite 705 passed / 4 failed with only the four tracked phase-3 balance bands). Checks: (1) `git show 5447a67 --name-only` — only the seven engine files and this task file; (2) measured 2026-11-06: match_engine 245, match_event 278, match_commands 86, match_engine_runtime 325, match_engine_simulation 376, match_engine_setpieces 433, match_engine_events 385 — all ≤800; (3) the two-file Expected is met and the four additional part files are the documented consequence of keeping the engine's private runtime types in-library (token-concatenation verification in Developer Notes); (4) suite caveat: the four red bands are the tracked balance failures (`2026-11-05_tactics_phase3-balance-bands-and-sweep`), not regressions of this task. Limitation: the suite was not re-run in this sandbox. CLOSED.

## Links
- Depends on: None
- Follows: `2026-11-04_app-structure_remaining-oversized-files`
- Follow-up: None

## Amendments
<Reviewer-owned, append-only. Add dated entries correcting the task's target or mechanism; never rewrite the original task text.>
