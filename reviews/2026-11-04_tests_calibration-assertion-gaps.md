# Calibration suite: sample size, regression safety net, docs drift
- Feature: tests
- Type: Test
- Priority: Major
- Reviewer: Coach Hady
- Created: 2026-11-04
- Status: OPEN
- Completed by: -
- Completed on: -

## Context
The calibration suite runs only 400 matches, its reference comments contradict its own assertions (comment at :17 says "corners per match ~9-10" while the assertion at :184-194 accepts 3.5–6.5; comment at :16 says "yellows ~4" with no assertion at all), and README.md:30 claims "five categories, 3-player tier draws" while the engine has three categories and one player per pack. Per-metric assertions are being added by the four engine/match-report reviews dated 2026-11-04; this file covers the suite-level gaps that let all of those drift go unnoticed.

## Tasks
- [ ] Task 1: Raise the sample size from 400 to ≥2,000 for share/distribution metrics (pure Dart simulation — seconds, not minutes) | Where: `test/features/match/engine_calibration_test.dart:147` | Expected: share-metric bands can tighten by ~±2 points given the larger sample; total suite runtime stays under 30s in CI.
- [ ] Task 2: Add a metric-snapshot regression harness: fixed seed set, dump a full metric table (goals/match, shots, SoT%, conversion, big chances + conversion, penalties + conversion, corners, offsides, cards, six 15-minute goal buckets, pass completion, xG/shot, per-style possession, favourite-win ladder) and compare against a committed snapshot with per-metric tolerances | Where: `test/features/match/` or `tool/` (new) | Expected: any engine change that moves a metric beyond its tolerance fails CI; snapshot regeneration is an explicit, documented step (command in the test header); snapshot file committed.
- [ ] Task 3: Sync the docs with reality: README pack-engine claims, calibration reference comments, and the engine header profile | Where: `README.md:30`, `test/features/match/engine_calibration_test.dart:11-19`, `lib/features/match/match_engine.dart:8-16` | Expected: comments and assertions agree; the engine header numbers match the post-fix measured profile from the ≥2,000-match run; the README table matches the engine (three categories, one player per pack).

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] CI green with the enlarged suite; suite runtime < 30s
- [ ] Snapshot file committed with documented regeneration step
- [ ] No contradictions between reference comments, assertions, README and engine header

## Developer Notes
<Implementation notes, rejected points with reason.>

## Reviewer Verification
<Filled by reviewer before setting CLOSED.>
