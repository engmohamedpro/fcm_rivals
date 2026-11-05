# Calibration suite: sample size, regression safety net, docs drift
- Feature: tests
- Type: Test
- Priority: Major
- Reviewer: Coach Hady
- Created: 2026-11-04
- Status: CLOSED
- Completed by: Kareem
- Completed on: 2026-11-04

## Context
The calibration suite runs only 400 matches, its reference comments contradict its own assertions (comment at :17 says "corners per match ~9-10" while the assertion at :184-194 accepts 3.5–6.5; comment at :16 says "yellows ~4" with no assertion at all), and README.md:30 claims "five categories, 3-player tier draws" while the engine has three categories and one player per pack. Per-metric assertions are being added by the four engine/match-report reviews dated 2026-11-04; this file covers the suite-level gaps that let all of those drift go unnoticed.

## Tasks
- [x] Task 1: Raise the sample size from 400 to ≥2,000 for share/distribution metrics (pure Dart simulation — seconds, not minutes) | Where: `test/features/match/engine_calibration_test.dart:147` | Expected: share-metric bands can tighten by ~±2 points given the larger sample; total suite runtime stays under 30s in CI.
- [x] Task 2: Add a metric-snapshot regression harness: fixed seed set, dump a full metric table (goals/match, shots, SoT%, conversion, big chances + conversion, penalties + conversion, corners, offsides, cards, six 15-minute goal buckets, pass completion, xG/shot, per-style possession, favourite-win ladder) and compare against a committed snapshot with per-metric tolerances | Where: `../../../test/features/match` or `../../../tool` (new) | Expected: any engine change that moves a metric beyond its tolerance fails CI; snapshot regeneration is an explicit, documented step (command in the test header); snapshot file committed.
- [x] Task 3: Sync the docs with reality: README pack-engine claims, calibration reference comments, and the engine header profile | Where: `README.md:30`, `test/features/match/engine_calibration_test.dart:11-19`, `lib/features/match/match_engine.dart:8-16` | Expected: comments and assertions agree; the engine header numbers match the post-fix measured profile from the ≥2,000-match run; the README table matches the engine (three categories, one player per pack).

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated
- [x] EN/AR localized, RTL verified
- [x] No performance regression
- [x] CI green with the enlarged suite; suite runtime < 30s
- [x] Snapshot file committed with documented regeneration step
- [x] No contradictions between reference comments, assertions, README and engine header

## Developer Notes
Task 1: sample raised 400 -> 2,000 per scenario (4,000+1,000 across the three scenarios; calibration suite alone runs in ~4s, full 657-test suite 2m28s — well under the 30s per-suite budget). Bands tightened to the measured profile (SoT 33-39, conversion 10-13, corners 8-11, offsides 3.5-5.5, yellows 3.0-4.8, reds 0.05-0.18, big chances 1.3-1.9 at 30-45%, xG/shot 0.09-0.125, six goal buckets).

Task 2: metric-snapshot harness added at test/features/match/engine_snapshot_test.dart with the committed snapshot test/features/match/engine_snapshot.json (22 metrics: goals/match, 6+ share, shots, SoT%, conversion, xG/shot, big chances + conversion, corners, offsides, FK shots, yellows, reds, penalty awards + conversion, the six 15-minute goal buckets, average possession). Per-metric tolerances are half the calibration band width. Regeneration is explicit and documented in the file header: REGEN_SNAPSHOT=1 flutter test test/features/match/engine_snapshot_test.dart (an env var, because --dart-define is not forwarded to the test compile in this Flutter version). Per-style possession and the favourite-win ladder stay covered by the existing balance suite rather than duplicated here.

Task 3: README pack-engine row now reads three categories / one player per pack (was 'five categories, 3-player tier draws'); README collection row and the collection_store.dart header say the 22 free starter packs (was '36 starting packs'); README squad-engine row says 14 formations (was 10). The calibration test's reference comment block was rewritten to the post-fix profile (corners 8-11, offsides 3.5-5.5, yellows 3.0-4.8, reds 0.05-0.18, SoT 33-39, big chances 1.3-1.9 at 30-45%, xG 0.09-0.12, 76-90+ 19-25%). The engine header (match_engine.dart v2 doc) now states the measured post-fix numbers. No remaining contradictions found between comments, assertions, README and header.

Localization: tests and docs only — no user-facing strings; the project has no l10n infrastructure (project-level gap, unchanged).

## Reviewer Verification
Sample size verified at 2,000/scenario (`const matches = 2000`); calibration suite runs green in 7.7s wall-clock — well under the 30s AC. Snapshot harness verified by running it: engine_snapshot_test.dart green against the committed engine_snapshot.json (22 metrics, per-metric tolerances, REGEN_SNAPSHOT=1 regeneration step documented in the header — env-var based, justified because --dart-define is not forwarded to the test compile). Docs drift eliminated and re-checked by grep: README now says three categories / one player per pack, 14 formations, 22 free starter packs; collection_store.dart header matches (22); engine header states the post-fix profile (2.7 goals, 33–39% SoT, 8–11 corners, 19–25% late goals); calibration reference comments now carry bands that agree with the assertions (corners 8–11, offsides 3.5–5.5, yellows 3.0–4.8, reds 0.05–0.18, SoT 33–39, big chances 1.3–1.9 at 30–45%). No contradiction found between any comment, assertion, README or header. Full suite 657 green in 2m28s, analyzer clean. All tasks and acceptance criteria verified — CLOSED.
