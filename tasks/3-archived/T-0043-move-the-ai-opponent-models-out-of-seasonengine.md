---
id: T-0043
title: Move the AI opponent models out of SeasonEngine
priority: medium
status: done
attempts: 1
depends_on: []
created: 2026-11-06
completed: 2026-11-06
---

# T-0043: Move the AI opponent models out of SeasonEngine

## Goal
Bring `lib/features/season/season_engine.dart` (846 lines) under the ~800-line convention by moving the AI opponent model family into its own pure-Dart file, with zero behaviour change.

## Context
Measured on main `b2c0a27` (2026-11-06): `season_engine.dart` = 846 lines. Top-level map:
- AI opponent models: `AiPoolPlayer` :146, `AiClubDefinition` :172, `AiPlayerDefinition` :206, `AiSquadPlayer` :233 (≈112 lines) — plain data classes with no engine logic.
- Engine core that stays: `SeasonConfig` :18, `FixturePairing` :258, `StandingEntry` :275, `SeasonOutcome` :306, `SeasonEngine` :309-793, `_PoolTracker` :794 (≈734 lines after extraction).
`season_models.dart` (102 lines) already holds the season data classes from T-0030; the AI family gets its own file to keep that file small too. Pure Dart, no UI dependencies (GDD §36 rule).

## Requirements
1. Create `season_ai_models.dart` holding `AiPoolPlayer`, `AiClubDefinition`, `AiPlayerDefinition`, `AiSquadPlayer` verbatim; `season_engine.dart` imports it and keeps everything else. Pure relocation, no behaviour change, schema unchanged.
2. Every resulting file ≤800 lines; `flutter analyze` clean; full `flutter test` green with zero test edits; `flutter test tool/simulation_report_test.dart` determinism PASS.

## Out of Scope
- Any change to AI generation odds, difficulty scaling (GDD §9) or fixture/standings math.
- Splitting `season_store.dart`, `season_screen.dart` (T-0044 owns that) or `season_models.dart` beyond imports.

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated; full `flutter test` suite passes with zero test edits
- [x] EN/AR localization complete and RTL verified where applicable
- [x] No performance or application-size regression
- [x] Every resulting file ≤800 lines
- [x] `README.md` architecture table row for the season engine updated for the new module file
- [x] `flutter test tool/simulation_report_test.dart` determinism PASS

## How to Verify
```bash
wc -l lib/features/season/season_engine.dart lib/features/season/season_ai_models.dart
flutter analyze
flutter test test/features/season/ test/features/simulation/
flutter test
flutter test tool/simulation_report_test.dart
```
Expected: every listed file ≤800 lines; analyzer clean; season/simulation suites and full suite green with zero test edits; determinism PASS.

---

## Developer Notes
- **Summary of changes:** Moved the AI opponent model family — `AiPoolPlayer`, `AiClubDefinition`, `AiPlayerDefinition`, `AiSquadPlayer` with their docs, original lines 141-255 — verbatim into a new pure-Dart `season_ai_models.dart` (127 lines), and rewrote `season_engine.dart` (846 → 733 lines) to keep everything else. Relocation by a one-time line-slice script kept outside the repo with a multiset verifier proving every original code/doc line lands exactly once; the only new content is the models-file header and two plumbing lines in the engine. **Zero code renames or edits** — the engine's generation/lineup/pool-tracker code references these classes unchanged.
- **The export decision (flag for the reviewer):** `season_engine.dart` both imports and re-exports `season_ai_models.dart`. The import is required (the engine constructs these objects throughout); the export is required because `season_store.dart`, `season_store_opponent.dart` and `test/features/season/season_engine_test.dart` obtain the AI classes through their `season_engine.dart` import — without the export, consumer imports would break and test edits would be needed, violating the zero-test-edit requirement. This matches the established repo pattern (`season_store.dart` already exports `season_models.dart`; `tactics.dart` exports its five tactic files).
- **Files changed:** `lib/features/season/season_engine.dart` (now 733 lines, imports + re-exports the models), `lib/features/season/season_ai_models.dart` (new, 127 lines), `README.md` (Season Engine architecture row now names `season_ai_models.dart` and the re-export).
- **How I tested it:** Baseline on the unmodified tree: `flutter analyze` No issues found + the combined focused run `flutter test test/features/season/ test/features/simulation/ tool/simulation_report_test.dart` → `+72: All tests passed!` exit 0, with the determinism run writing its report (`REPORT_WRITTEN: simulation_report.md`). After the split: the `wc -l` gate lists 733/127, both ≤800; `flutter analyze` No issues found (the models file needs only `Position` via `players.dart show Position` and `TeamTactics`/`Mentality` via `../match/tactics.dart` — verified by symbol grep before writing the header); the same combined focused run → `+72: All tests passed!` exit 0 (identical count, determinism PASS included, zero test edits); full `flutter test` → `+709: All tests passed!` exit 0 (~5m23s) — identical test count to the baseline, zero test edits.
- **Concerns / assumptions:** The task text says only "season_engine.dart imports it"; the added re-export goes one step further than the letter of the requirement but is the minimal change that keeps consumer imports (including the test file) stable — dropping it would force edits in `season_store.dart`/`season_store_opponent.dart`/the test. No other judgment calls. None blocking.

## Review Log

### Review 2026-11-06, attempt 1: PASS
- Independent verbatim-relocation check (multiset of all lines, original `7665cb0:lib/features/season/season_engine.dart` vs. the HEAD engine + `season_ai_models.dart`): ONLY-IN-ORIGINAL IS EMPTY — every line of the original 846-line engine relocated verbatim, independently confirming the zero-renames claim. Only-in-new = the models-file header (doc + `library;` + the two `show`-narrowed imports) and the engine's declared plumbing (`import 'season_ai_models.dart';` + `export 'season_ai_models.dart';`) plus blanks.
- The flagged re-export decision is accepted: verified that `season_store.dart`, `season_store_opponent.dart` and `test/features/season/season_engine_test.dart` obtain the AI classes through their `season_engine.dart` import, so dropping the export would force test/consumer edits; the re-export matches the existing repo pattern (`season_store.dart` → `season_models.dart`, `tactics.dart` barrel).
- Ran: `wc -l` → engine 733 / models 127, both ≤800 (T-0044/T-0045 verified not to touch these two files, so HEAD measurement is valid for this task's gate).
- Ran: `flutter analyze` (Flutter 3.47.9 stable / Dart 3.13.7, README pin) → No issues found.
- Ran: `flutter test test/features/season/ test/features/simulation/` → `+71: All tests passed!`.
- Ran: `flutter test tool/simulation_report_test.dart` → `+1: All tests passed!`, `REPORT_WRITTEN: simulation_report.md` — determinism PASS.
- Ran: `flutter test` → `+709: All tests passed!`, exit 0 — identical count to the archived baseline; the T-0043 diff (`7665cb0..c1e4e53`) touches no `test/` or `tool/` file, so zero test edits confirmed.
- Scope: only the two season lib files + README + this task file changed. README Season Engine row correctly names `season_ai_models.dart` and the re-export.
- Notes: no localization strings in the diff and the multiset proves no string literal changed, so the EN/AR criterion is met vacuously; models file is pure Dart per the GDD §36 rule (only `Position` and `TeamTactics`/`Mentality` imports, both domain-layer).
