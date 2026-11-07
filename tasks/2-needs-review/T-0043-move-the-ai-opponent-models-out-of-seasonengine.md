---
id: T-0043
title: Move the AI opponent models out of SeasonEngine
priority: medium
status: needs-review
attempts: 1
depends_on: []
created: 2026-11-06
completed:
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
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes with zero test edits
- [ ] EN/AR localization complete and RTL verified where applicable
- [ ] No performance or application-size regression
- [ ] Every resulting file ≤800 lines
- [ ] `README.md` architecture table row for the season engine updated for the new module file
- [ ] `flutter test tool/simulation_report_test.dart` determinism PASS

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
