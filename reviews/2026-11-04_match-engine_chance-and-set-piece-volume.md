# Shot profile: big chances, corners, offsides, FK volume, SoT rate
- Feature: match-engine
- Type: Design
- Priority: Major
- Reviewer: Coach Hady
- Created: 2026-11-04
- Status: OPEN
- Completed by: -
- Completed on: -

## Context
Aggregate scorelines look right, but the underlying shot profile is unrecognizable vs real football (2,000-match seeded sim at HEAD ceedb00): big chances 0.72/team at 18.6% conversion (real 1.5–2.0 at ~38%), corners 4.9/match (real 9–10.5), offsides 6.2 (real 4–4.5), direct free-kick shots 1.0/team (real 0.2–0.3), shots on target 42% (real 34–36%) with conversion 11.9% compensating. Players read the shot map and stats screen, not just the score.

## Tasks
- [ ] Task 1: Strengthen the big-chance layer: share 0.15 → 0.28, `qualityOnTargetBonus` 0.18 → 0.28, `qualityGoalFactor` 1.25 → 1.50 | Where: `lib/features/match/match_engine.dart:966`, `:996`, `:1015` | Expected: 1.3–1.9 big chances/team at 30–45% conversion; assert both bands in the calibration test; total goals stay 2.4–2.9.
- [ ] Task 2: Raise corner volume: `cornerFromBlock` 0.55 → 0.62, `cornerFromCross` 0.16 → 0.35, and add a new `cornerFromSave` ≈ 0.30 config field with a roll after saved shots | Where: `lib/features/match/match_engine.dart:218-219` (config), `:762` (cross roll), `:1082` (block roll), saved-shot branch near `:1055` | Expected: 8–11 total corners/match; update the corner band at `test/features/match/engine_calibration_test.dart:184-194` from 3.5–6.5 to 8–11 (the reference comment at :17 already says ~9–10).
- [ ] Task 3: Reduce offsides: `offsideChance` 0.10 → 0.07 | Where: `lib/features/match/match_engine.dart:217` (config), roll at `:688` | Expected: 3.5–5.5 offsides/match; add a calibration assertion (none exists today).
- [ ] Task 4: Cut direct free-kick shot volume: final-third gate 0.35 → 0.12 | Where: `lib/features/match/match_engine.dart:861` | Expected: ≤ 0.5 direct FK shots/team; FK conversion unchanged (measured 7.8%, real 6–10% — already fine).
- [ ] Task 5: Fix the SoT rate: `onTargetScale` 0.30 → 0.25 with `goalBase` 0.19 → 0.21 to hold conversion in band | Where: `lib/features/match/match_engine.dart:210-211` | Expected: SoT share 33–39% (tighten the band at `test/features/match/engine_calibration_test.dart:180-181` from 0.34–0.48); overall conversion 10–13%; xG/shot 0.09–0.12 (add assertion).
- [ ] Task 6: Full-profile re-verification after Tasks 1–5, landed together with the penalty review `2026-11-04_match-engine_penalty-model` | Where: `test/features/match/engine_calibration_test.dart` | Expected: goals/match 2.4–2.9; 6+ goal share ≤ 4.5% (if above, trim `chanceMax` 0.45 → 0.43 at `lib/features/match/match_engine.dart:203`); favourite-win ladder within ±3 points of today's measured values; Developer Notes include the full shot-profile table from a ≥2,000-match seeded run.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] Shot-profile table (shots, SoT%, conversion, big chances + conversion, corners, offsides, FK shots, xG/shot) from a ≥2,000-match seeded run attached in Developer Notes
- [ ] All calibration bands updated to the new targets and green on CI

## Developer Notes
<Implementation notes, rejected points with reason.>

## Reviewer Verification
<Filled by reviewer before setting CLOSED.>
