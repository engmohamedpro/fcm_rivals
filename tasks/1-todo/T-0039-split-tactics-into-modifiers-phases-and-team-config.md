---
id: T-0039
title: Split tactics.dart into modifier math, phase families and team config
priority: medium
status: todo
attempts: 0
depends_on: []
created: 2026-11-06
completed:
---

# T-0039: Split tactics.dart into modifier math, phase families and team config

## Goal
Bring `lib/features/match/tactics.dart` (1,201 lines) under the ~800-line convention by splitting it into cohesive family files behind a barrel, with zero behaviour change.

## Context
Measured on main `b2c0a27` (2026-11-06): `tactics.dart` = 1,201 lines, the largest remaining over-800 file. Top-level map (line = declaration start):
- Modifier math: `TacticModifiers` :27, `ComposeRule` :194, `TuningOverrides` :233, `TunedInstruction` extension :289 (≈275 lines) — `ComposeRule` is the root-cause-sweep subject of archived T-0032; do not alter its semantics.
- Team config / live actions: `TeamTactics` :302, `Mentality` :997, `LiveMatchAction` :1067, `ActionModifiers` :1095, `MatchPepTalk` :1114 (≈305 lines total).
- In-possession family (T-0016): `BuildUpStyle` :415, `AttackTempo` :439, `AttackWidth` :470, `FinalThirdApproach` :483, `InPossessionTactics` :523 (≈216 lines).
- Out-of-possession family (T-0017): `DefensiveLine` :631, `PressingIntensity` :650, `TacklingAggression` :687, `OffsideTrapToggles` :732, `OutOfPossessionTactics` :750 (≈209 lines).
- Transitions family (T-0018): `CounterPress` :840, `AttackOnRecovery` :859, `RestDefence` :892, `TransitionTactics` :914 (≈157 lines).
The fatigue-decoupling chain (T-0037/T-0038) is archived, so no pending balance work touches this file — sequencing precondition satisfied. Follow the proven barrel pattern (`fcm_widgets.dart`, `live_match_views.dart`): consumer imports of `tactics.dart` keep working unchanged.

## Requirements
1. Split into: `tactic_modifiers.dart` (modifier math family), `in_possession_tactics.dart`, `out_of_possession_tactics.dart`, `transition_tactics.dart`, and `team_tactics.dart` (team config + Mentality + LiveMatchAction + ActionModifiers + MatchPepTalk); `tactics.dart` remains as a barrel re-exporting every family. Pure verbatim relocation, no behaviour change.
2. Every resulting file ≤800 lines (excl. generated `*.g.dart`); `flutter analyze` clean; full `flutter test` green with zero test edits; `flutter test tool/simulation_report_test.dart` determinism PASS.

## Out of Scope
- Any change to modifier percentages, defaults, compose semantics or enum values (T-0032 root-cause work is frozen).
- Splitting any other file; editing `MatchEngine` or `engine_config` beyond import fixes.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes with zero test edits
- [ ] EN/AR localization complete and RTL verified where applicable
- [ ] No performance or application-size regression
- [ ] Every resulting file ≤800 lines; `tactics.dart` barrel keeps consumer imports stable
- [ ] `README.md` architecture table row for the tactics family updated for the new module files
- [ ] `flutter test tool/simulation_report_test.dart` determinism PASS

## How to Verify
```bash
wc -l lib/features/match/tactics.dart lib/features/match/tactic_modifiers.dart lib/features/match/team_tactics.dart lib/features/match/in_possession_tactics.dart lib/features/match/out_of_possession_tactics.dart lib/features/match/transition_tactics.dart
flutter analyze
flutter test
flutter test tool/simulation_report_test.dart
```
Expected: every listed file ≤800 lines; analyzer reports no issues; full suite green with zero test edits; determinism PASS.

---

## Developer Notes

## Review Log
