# Match flow: flat goal timing, soft discipline
- Feature: match-engine
- Type: Design
- Priority: Major
- Reviewer: Coach Hady
- Created: 2026-11-04
- Status: OPEN
- Completed by: -
- Completed on: -

## Context
Matches never open up late and discipline is too soft (2,000-match seeded sim): goals in minutes 76–90+stoppage are 16.3% of all goals (real 20–22%) while minutes 1–15 carry 17.8% (real 10–14%); yellows 1.9/match (real 3.5–4.5), reds 0.19/match (real 0.10–0.15). Late-game drama — the most engaging part of football — is missing, which also weakens the value of substitutions and game management.

## Tasks
- [ ] Task 1: Open up the late game: urgency 0.04 → 0.06 per goal, cap 0.12 → 0.18, start 60' → 55'; add a bounded defensive-fatigue term so tired defences concede more (defence effectiveness × (0.92 + 0.08 × avgStamina/100)) | Where: `lib/features/match/match_engine.dart:776-780` (`_urgencyBoost`), `:1540-1590` (computeTotals) | Expected: 76–90+ goal share 19–25%; minutes 1–15 ≤ 16%; total goals stay 2.4–2.9.
- [ ] Task 2: Calibrate cards: `yellowCardChance` 0.10 → 0.19, `straightRedChance` 0.004 → 0.002 | Where: `lib/features/match/match_engine.dart:215-216` | Expected: yellows 3.0–4.8/match, reds 0.05–0.18/match; reds stay rare in mismatch sims.
- [ ] Task 3: Optional design (no rejection if skipped): bounded latent pressure — a ~1.15 chance multiplier for 2–3 minutes after corners and blocked shots, decaying, so chances cluster the way they do in real matches | Where: `lib/features/match/match_engine.dart:700-760` (chance creation) | Expected: if implemented, goals/match stays 2.4–2.9 and the Task 1 timing bands still hold; if skipped, note the decision in Developer Notes.
- [ ] Task 4: Lock with assertions: six 15-minute goal buckets (1-15, 16-30, 31-45+, 46-60, 61-75, 76-90+) plus the card bands from Task 2 | Where: `test/features/match/engine_calibration_test.dart` | Expected: new assertions green; the existing favourite-win ladder is unchanged within ±3 points.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] Goal-timing distribution from a ≥2,000-match seeded run printed in test output or Developer Notes
- [ ] Yellows 3.0–4.8 and reds 0.05–0.18 per match asserted

## Developer Notes
<Implementation notes, rejected points with reason.>

## Reviewer Verification
<Filled by reviewer before setting CLOSED.>
