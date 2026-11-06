---
id: T-0039
title: Split tactics.dart into modifier math, phase families and team config
priority: medium
status: done
attempts: 1
depends_on: []
created: 2026-11-06
completed: 2026-11-06
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
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated; full `flutter test` suite passes with zero test edits
- [x] EN/AR localization complete and RTL verified where applicable
- [x] No performance or application-size regression
- [x] Every resulting file ≤800 lines; `tactics.dart` barrel keeps consumer imports stable
- [x] `README.md` architecture table row for the tactics family updated for the new module files
- [x] `flutter test tool/simulation_report_test.dart` determinism PASS

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
- **Summary of changes:** Split `tactics.dart` (1,201 lines) verbatim into five family libraries — `tactic_modifiers.dart` (282: `TacticModifiers`, `InstructionOption`, `ComposeRule`, `TuningOverrides`, `TunedInstruction`), `in_possession_tactics.dart` (227: the four in-possession enums + `InPossessionTactics`), `out_of_possession_tactics.dart` (219: `DefensiveLine`, `PressingIntensity`, `TacklingAggression`, `OffsideTrapToggles`, `OutOfPossessionTactics`), `transition_tactics.dart` (157: `CounterPress`, `AttackOnRecovery`, `RestDefence`, `TransitionTactics`) and `team_tactics.dart` (348: `TeamTactics`, `tacticsFromDbPayload`, `Mentality` + scale helpers, `LiveMatchAction`, `ActionModifiers`, `MatchPepTalk`, the pep-talk catalogs) — with `tactics.dart` kept as a 27-line barrel so all 37 existing consumer imports (lib/tool/test) work unchanged. Relocation was done by a one-time line-slice script kept outside the repo with a multiset verifier proving every original code/doc line relocated exactly once; the only new content is per-file library docs and import/export lines. One forced API delta: the JSON helper `InPossessionTactics._enumOr` became public `InPossessionTactics.enumOr` (11 occurrences) — Dart library privacy forbids calling an underscore-private static across separate libraries, and this is the minimal change preserving bit-identical behaviour. Also updated the stale README Tactics row (it still claimed "10 playing styles", removed since T-0015) to name the new module files.
- **Files changed:** `lib/features/match/tactics.dart` (now barrel), `lib/features/match/tactic_modifiers.dart` (new), `lib/features/match/in_possession_tactics.dart` (new), `lib/features/match/out_of_possession_tactics.dart` (new), `lib/features/match/transition_tactics.dart` (new), `lib/features/match/team_tactics.dart` (new), `README.md` (Tactics row).
- **How I tested it:** Toolchain freshly installed in this sandbox at the exact README pin (Flutter 3.47.9 stable / Dart 3.13.7). Baseline on the unmodified tree first: `flutter pub get` + `flutter analyze` (No issues found) + `flutter test` → `+709: All tests passed!` exit 0 (~5m35s). After the split: the `wc -l` gate lists all six files ≤800 (max 348); `flutter analyze` → No issues found; tactics-dependent smoke (`match_engine`, `engine_snapshot`, `engine_calibration`, `squad_view`) 53/53 passed; full `flutter test` → `+709: All tests passed!` exit 0 — identical test count to baseline, zero test edits; `flutter test tool/simulation_report_test.dart` → `+1: All tests passed!` with `REPORT_WRITTEN: simulation_report.md` (determinism gate PASS).
- **Concerns / assumptions:** (1) The `_enumOr` → `enumOr` visibility change is the only touch on a declaration name; no test or call site outside the five split files references it. (2) The sandbox toolchain is newly installed; to rule out environment noise the full suite was run twice on the same machine (pre-split baseline and post-split) with identical +709 results. (3) No Drift codegen involved (`tactics.dart` has no schema parts), so no `build_runner` run was needed. None blocking.

## Review Log

### Review 2026-11-06, attempt 1: PASS
- Independent verbatim-relocation check (multiset of all lines, original `db17520:lib/features/match/tactics.dart` vs. the six HEAD files): the only lines present in the original but not the new set are the 11 `_enumOr` lines; the only executable lines present in the new set but not the original are the same 11 renamed to `enumOr`. Everything else is imports/exports/`library;`/doc comments. Confirms the developer's declared single API delta; all 11 `enumOr` occurrences stay inside the split files, none outside.
- Ran: `wc -l` on all six files → 27/282/227/219/157/348, all ≤800.
- Ran: `flutter analyze` (Flutter 3.47.9 stable / Dart 3.13.7, README pin) → No issues found.
- Ran: `flutter test` → `+709: All tests passed!`, exit 0 — identical count to the archived baseline, and `git diff db17520..HEAD -- test/ tool/` is empty, so zero test edits confirmed.
- Ran: `flutter test tool/simulation_report_test.dart` → `+1: All tests passed!`, `REPORT_WRITTEN: simulation_report.md` — determinism PASS.
- Scope: `git diff --stat db17520..HEAD` shows only the six lib files + README Tactics row + this task file; no consumer edits, so the barrel kept all import paths stable. README Tactics row correctly replaced the stale "10 playing styles" text.
- Notes: EN/AR l10n untouched (no localization file in the diff; multiset proves no string literal changed), so the localization criterion is met vacuously.
