---
id: T-0057
title: Run the match-engine compatibility gate for the retuned OVR bands
priority: high
status: todo
attempts: 0
depends_on: [T-0046, T-0048, T-0052]
created: 2026-11-07
completed:
---

# T-0057: Run the match-engine compatibility gate for the retuned OVR bands

## Goal
Prove the gameplay layer is compatible with the new rating world: after T-0046/T-0048 move the elite band to 94-99 with wider elite attribute ladders, and T-0052 removes fatigue from performance, the match engine, season difficulty and economy must still produce real-football results with every balance band intact — verified by measurement, not assumption.

## Context (evidence, main `3614c4a`)
- What changes underneath the engine: elite OVRs rise from ≤ 92 to 94-99 (T-0046's two-segment curve, measured top-5 = 99/99/98/96.4/96.4); elite attribute ladders widen (T-0048: primary − least ≥ 12 at OVR ≥ 95); stamina stops scaling attributes (T-0052). Both user squads AND AI squads regenerate through the same stats curve (Season Engine "AI club + squad generation through the stats curve"), so gaps shift on both sides — but not uniformly: the user's club (median ~57 dataset) meets AI clubs drawn from the same dataset, and division difficulty scaling multiplies on top.
- The locked measurement surface: `test/balance/match_engine_balance_test.dart` strength-gap ladder (`:187-245`, relative OVR gaps) and tactics groups; `test/features/match/engine_calibration_test.dart` even-strength, big-gap (`:398`) and extreme 90/10-gap (`:442`) groups; the engine snapshot (`engine_snapshot.json`, regenerated in T-0052/T-0054 as their deltas land); EconomySimulator multi-season runs (`test/balance/economy_balance_test.dart`, promotion achievable, division 2 harder); `tool/simulation_report_test.dart` determinism.
- The open question this gate answers: do the bands survive when the ACTUAL dataset bands shift (elite squads now built from 94-99 players meet mid squads built from the unchanged median ~57)? The ladder tests use synthetic relative gaps so they should hold by construction — this gate verifies the dataset-driven paths (season AI, forecast, ratings spread) with the real distribution.
- T-0046's side-effect section already demands "balance suites green unmodified"; this task is the deliberate, recorded proof pass across the full gameplay surface (engine + season + economy together), including paths no single task owned: `match_forecast` predictions vs simulated outcomes under the new bands, and position-sensitive ratings distribution under the wider elite ladders.

## Requirements
1. Run the full verification set on the combined state and record every measured number in Developer Notes: calibration groups (even/gap/extreme), strength-gap ladder, season multi-season economy runs, sim-report determinism, engine snapshot (regenerate only if a T-0052/T-0054 regen is not already current — one regen per engine version, never per test run).
2. Forecast sanity under the new bands: for ≥ 200 seeded pairings across the value spectrum (10M-200M club anchors), `match_forecast` predicted win/draw/loss shares stay within the existing forecast-test bands, and predicted-vs-actual outcome error does not widen beyond the current test tolerance.
3. Ratings stability: position-sensitive player ratings (`match_report.dart` computePlayerRatings) keep their distribution shape under the wider elite ladders — print mean/std of ratings for elite (95+) vs mid (55-60) squads and lock a sanity band (elite ratings do not saturate; the scale's top is not permanently pinned).
4. Season difficulty integrity: promotion still achievable, division 2 measurably harder, AI clubs built from the new bands produce the difficulty ladder the README documents — EconomySimulator outputs printed with the season-by-season promotion/division table.
5. If any band fails: iterate ONLY in the engine's own tuning seams (`TuningOverrides`, season difficulty scaling config) — never by editing a balance band, the curve contract, or the attribute-ladder floors. If a genuine conflict emerges (e.g. the strength-gap saturates differently with 99-OVR squads), stop and record it in Developer Notes as a design decision for the owner.

## Out of Scope
- Any code change beyond tuning-seam constant adjustments (fixes belong in new tasks).
- Re-touching T-0046/T-0048/T-0052 deliverables (curve, ladders, decoupling) — this gate consumes them.
- Pack/economy pricing changes (T-0047 owns the pack-side compatibility).

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Full `flutter test` suite passes with all calibration/balance bands unmodified
- [ ] Measured report recorded in Developer Notes (calibration numbers, forecast error, ratings distribution, season ladder)
- [ ] EN/AR localization complete and RTL verified where applicable (no strings expected)
- [ ] No performance or application-size regression
- [ ] `flutter test tool/simulation_report_test.dart` determinism PASS
- [ ] Every band verdict explicitly stated in Developer Notes (pass / passed-after-tuning / conflict)

## How to Verify
```bash
flutter analyze
flutter test test/features/match/engine_calibration_test.dart test/balance/
flutter test tool/simulation_report_test.dart
flutter test
```
Expected: analyzer clean; calibration + balance suites green; determinism PASS; Developer Notes contains the measured table (bands, forecast error, ratings spread, season promotion table) with a verdict per band.

## Side-effect risk (medium)
This is a gate, not a build task — its main risk is discovering a conflict late in the chain (after T-0048/T-0052 both landed). Sequence it immediately after its three dependencies archive, before the packs chain continues into T-0050/T-0051 UI polish, so any engine-side surprise surfaces while the board still has room to react.

## Developer Notes

## Review Log
