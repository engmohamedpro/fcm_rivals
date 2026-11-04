# Tactics: possession modifier applied twice
- Feature: tactics
- Type: Bug
- Priority: Major
- Reviewer: Coach Hady
- Created: 2026-11-04
- Status: OPEN
- Completed by: -
- Completed on: -

## Context
`style.modifiers.possession` is applied twice: inside the per-segment possession ratio (support × m, raised to the power 1.6) and again in `computeTotals` support accumulation. A 1.08 tikiTaka multiplier therefore behaves as 1.08^3.2 ≈ 1.27 in odds terms. Measured possession at even strength: 59.4% (tikiTaka) vs 44.9% (longBall) — a wider spread than any real league season. The comment at `lib/features/match/tactics.dart:10-20` shows the 36–52% win-rate tuning was done around this compounding, so the fix must remove the hidden double-apply while preserving current behaviour exactly.

## Tasks
- [ ] Task 1: Remove the second application — keep the segment-level one, drop the multiplication in `computeTotals` | Where: `lib/features/match/match_engine.dart:1579` (remove × `style.modifiers.possession`), keep `:645-650` | Expected: single application of the modifier; code-inspection note in Developer Notes confirming the removal.
- [ ] Task 2: Retune the multipliers to preserve each style's identity exactly: new = old² (same effective odds ratio: old^3.2 → (old²)^1.6) — possession 1.06 → 1.12, tikiTaka 1.08 → 1.17, directPlay 0.94 → 0.88, counterAttack 0.88 → 0.77, gegenpressing 1.03 → 1.06, highPress 1.03 → 1.06, wingPlay 0.98 → 0.96, longBall 0.90 → 0.81, lowBlock 0.88 → 0.77 (use the exact squared values from the enum) | Where: `lib/features/match/tactics.dart:22-130` | Expected: per-style measured possession matches pre-change values within ±2 points; style-matrix win rates stay in the 36–52% band (`test/balance/match_engine_balance_test.dart`).
- [ ] Task 3: Make the tactics UI honest: update the displayed per-style possession effects to reflect the single-application model, and refresh the stale compounding comment | Where: tactics presentation layer + `lib/features/match/tactics.dart:10-20` | Expected: displayed numbers match the simulated effect within ±2 points; EN/AR strings updated through the localization files (no hardcoded text), RTL verified.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] Style-matrix balance test green with win rates in 36–52%
- [ ] Per-style measured possession within ±2 points of pre-change values in a ≥2,000-match seeded run

## Developer Notes
<Implementation notes, rejected points with reason.>

## Reviewer Verification
<Filled by reviewer before setting CLOSED.>
