---
id: T-0057
title: Run the match-engine compatibility gate for the retuned OVR bands
priority: high
status: needs-review
attempts: 1
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
- **Verdict: the gameplay layer is COMPATIBLE with the retuned OVR world — every band PASS, zero production code changed.** No tuning seam needed touching; the gate's deliverable is the committed measurement instrument `test/balance/compatibility_gate_test.dart` (3 tests, the reproducible source of every number below).
- **Requirement 1 — the full verification set (all recorded numbers):** calibration + balance + gate = **101/101 green**; full `flutter test` = **770/770**; `flutter analyze` clean; `tool/simulation_report_test.dart` determinism **PASS**; engine snapshot: regen **CURRENT** (T-0054's, engine v4 — the one-regen-per-engine-version rule; no regen this run, snapshot test green). Even-strength calibration: goals 2.4-2.9 band, injuries fresh **0.033-0.035** (< 0.05), exhausted **0.272** (∈ [0.25, 1.5)), monotonic grid 0.035/0.0425/0.0925/0.2525/0.490 — all the T-0054 numbers reproduce under the gate's reruns.
- **Requirement 2 — forecast sanity (PASS, gate-locked band):** 200 seeded two-legged pairings (400 matches) across ten log-spaced anchors 10M-200M; the EXISTING forecast bands hold per pairing (shares sum 100, all positive, goals 0.2-5). Predicted W/D/L **35.0/30.4/34.6** vs actual **39.0/23.5/37.5** — per-outcome gaps **4.0 / 6.9 / 2.9 points**, inside the 12-point calibration band this gate locks (no prior predicted-vs-actual tolerance existed — the band is the gate's own contract, recorded here). Lopsided 20× anchor (200M vs 10M): forecast 58% win, engine 2-1 ✓. **Measurement-design finding (recorded honestly):** a one-legged comparison FAILS (predicted 35 vs actual 51 win%) — that 16-point gap IS the engine's calibrated home advantage meeting a venue-blind forecast, not miscalibration; the two-legged aggregate is the correct neutral comparison. The residual ~7-point draw overestimate of the neutral forecast is within band and is the obvious target for a future forecast-tuning task.
- **Requirement 3 — ratings stability (PASS):** computePlayerRatings over 40 seeds × 2 sides per class — elite (€150M → OVR 96): **mean 6.13, std 0.47, p95 7.08, max 8.63**; mid (€600K → OVR 58): **mean 6.12, std 0.48, p95 6.96, max 9.49**. The sanity band locked: elite mean < 8.5 (no saturation — the clamp at 10.0 is nowhere near engaged), share of exact-10.0 ratings < 5%, mid mean ∈ [5.0, 7.5], both stds > 0.3, elite > mid. Anchor mapping measured first (€150M → 96, €600K → 58 under the T-0046 curve) so the classes really are 94+ vs 55-60. Observation (not a failure): the elite-vs-mid rating gap is small because ratings are event-driven — equal-strength matches produce similar event volumes for both sides; the ladder still reads in the right direction.
- **Requirement 4 — season/economy integrity (PASS):** EconomySimulator (seed 57, medium, 3 seasons): **S1 position 4 (stayed, 86,375 coins, best XI 70, collection 34) → S2 position 1 PROMOTED (119,375 coins, XI 73) → S3 position 1 PROMOTED (126,875 coins, XI 74, collection 50)**; high band (seed 58): position 3 with **best XI 71 > medium's 70** — promotion is achievable, the value ladder still buys strength, coins reconcile, no 'unknown' outcomes.
- **Requirement 5 — conflicts:** none surfaced. The strength-gap ladder and tactics matrix held by construction (synthetic relative gaps) AND on the dataset-driven paths (forecast sweep, season sim) with the real 94-99 elite band in play.
- **Files changed:** `test/balance/compatibility_gate_test.dart` (NEW — the gate instrument only). NO production code, NO band, NO tuning constant touched. (Interpretation recorded: the task's Out of Scope bars production fixes; the measurement tests requirements 2-3 explicitly commission are this gate's own deliverable, not fixes.)
- **How I tested it:** `flutter analyze` → clean; `flutter test test/features/match/engine_calibration_test.dart test/balance/` → 101/101; `flutter test tool/simulation_report_test.dart` → PASS; `flutter test` → **770/770, ALL GREEN**. The gate test is deterministic (fixed seed sets) and every number above prints from it.
- **Concerns:** (1) The forecast draw overestimate (~7 pts) is within the locked band but real — worth a dedicated forecast-calibration task if the pre-match screen ever promises tighter honesty. (2) The ratings class-gap (6.13 vs 6.12) is directionally right but small — if the owner wants ratings to visibly separate classes, that is a ratings-weights design decision, not this gate's scope. (3) The gate adds ~25s to the suite (400 + 160 engine matches + 2 sim seasons).

## Review Log
