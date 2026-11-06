---
id: T-0043
title: Move the AI opponent models out of SeasonEngine
priority: medium
status: todo
attempts: 0
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

## Review Log
