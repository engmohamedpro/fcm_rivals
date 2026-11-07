---
id: T-0048
title: Keep attribute shape position-true at every OVR tier
priority: medium
status: needs-review
attempts: 1
depends_on: [T-0046]
created: 2026-11-07
completed:
---

# T-0048: Keep attribute shape position-true at every OVR tier

## Goal
The owner's design — market value → OVR, then attributes generated from OVR + position **with ranges, not a fixed distribution** — already exists and must be preserved and locked by tests. The one real defect: the position ladder **compresses at the top of the rating scale**, so an elite striker's card flattens exactly where elite cards matter most. Fix that, then lock the whole behaviour.

## Context (evidence, main `3300692`)
- The range layer already exists (`lib/core/domain/base_stats_generator.dart:210-237`): a shared quality offset (±`qualityNoise` = 2.0, `:216`) plus independent per-attribute style noise (±`attributeNoise` = 2.5, `:226`), both triangular and bounded (`:243-244`), drawn per player from the id-seeded RNG. Two same-value same-position players get different shapes; the same player always rebuilds the same stats. **This matches the requested approach — nothing to redesign.**
- Position ladders (`positionWeights`, `:98-171`) encode ST = attack-first/defence-last, CAM support-first, CDM/CB defence-first, GK goalkeeping-towering — as designed (GDD 4.5 doc).
- **Defect — ceiling compression**: deviations are a constant `attributeSpread * (weight - anchor)` (`:227`) while attributes clamp at 99 (`clamp(1, 99)`). At OVR 84 an ST reads ATT 96 / SUP 83 / DEF 80 (spread 16); at OVR 97 (reachable after T-0046) he reads 99 / 96 / 93 (spread **6**) — a world-class striker whose defence is nearly his support. Real elite forwards keep a wide ladder (elite finishing, modest defending). The identity ordering never inverts, but it visibly flattens.
- Attribute 99 reachability after T-0046 (owner requirement "no caps for 99"): ST attack at OVR 97 computes to 109 unclamped → clamps at 99 (reachable ✓); CB defence at 97 → 108.7 → 99 ✓; GK goalkeeping → 99 ✓. The 99 clamp itself is correct and stays.
- Known design tension, recorded not hidden: `overall` (`:231`) is the pure curve value and ignores the quality offset the attributes receive — the headline OVR is the market consensus while the attributes show the player's individual shape. Both readings are defensible (FUT-style headline); the implementer must record the decision and its rationale in Developer Notes, and either way the behaviour gets locked by tests.

## Requirements
1. Preserve a position-true ladder at the top: for **every** position, across ≥ 2,000 seeded draws at OVR ≥ 95, the primary attribute (by `positionWeights`) stays strictly the largest and `primary − least ≥ 12` (currently 6 at OVR 97 for ST). Implementation is free (scale deviations up near the ceiling, soft-cap instead of hard clamp, or ceiling-aware spread) — but must stay inside `BaseStatsGenerator`/`BaseStatsConfig` and keep determinism per seed.
2. The low and mid bands must not move: re-run the T-0046 dataset band test unchanged (median, p90, 80+ share) — this task may not shift the OVR bands, only the attribute shape around them.
3. Lock the existing range behaviour with tests: across 1,000 seeds of a fixed value+position, every attribute has σ > 0 and stays within ±(`qualityNoise` + `attributeNoise`) of its expected value; orderings never invert for all 12 positions × 2,000 draws; zero-weight attributes (outfield goalkeeping, GK attack) stay exactly 0; at least one dataset player reaches attribute 99 in each of attack, defence and goalkeeping.
4. Record the OVR-vs-quality-offset decision (keep consensus OVR or fold the offset in) in Developer Notes with the trade-off; if folded in, the T-0046 band contract must still hold (re-center, don't re-band).

## Out of Scope
- The OVR curve values (T-0046), rarity thresholds/colours (T-0047), match-engine attribute usage.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] New/updated generator tests green; full `flutter test` suite passes; T-0046 band test green **unmodified**
- [ ] EN/AR localization complete and RTL verified where applicable (no UI strings expected)
- [ ] No performance or application-size regression
- [ ] Ladder-gap floor (Requirement 1) asserted by test at OVR 95+
- [ ] Range/variance/zero-weight/attribute-99 locks (Requirement 3) all asserted
- [ ] `flutter test tool/simulation_report_test.dart` determinism PASS

## How to Verify
```bash
flutter analyze
flutter test test/core/domain/ test/balance/ test/features/simulation/
flutter test tool/simulation_report_test.dart
flutter test
```
Expected: analyzer clean; all suites green; the generator tests print the measured ladder gaps at OVR tiers (84 / 95 / 99) and variance stats, and pass.

## Side-effect risk (medium)
Match engine reads these attributes: widening the elite ladder changes elite-club internal balance (attack vs defence contribution). The `test/balance/match_engine_balance_test.dart` bands are the guard — they must pass unmodified; if they fail, narrow the gap floor or soften the ceiling scaling within Requirement 1's bounds and record why.

## Developer Notes
- **Summary of changes:** The ceiling compression is fixed inside `BaseStatsGenerator`/`BaseStatsConfig`, fully deterministic. (1) **Ceiling-aware ladder**: from `eliteLadderStartOvr` (90) each position's deviations ramp up to `eliteLadderFullOvr` (95) until the pre-noise span reaches `eliteLadderGapFloor` (**18** = the required measured 12 + the two opposed noise extremes 2×2.5 + 1 integer-rounding headroom). The floor is PER POSITION (RB/LB's shipped span is only 5.4 pts vs ST's 16.2 — one global factor cannot serve both). (2) **Shift-down at the ceiling**: when the primary attribute would clamp at 99, the whole ladder moves down by the excess instead of clamping, so absolute gaps survive — the OVR-97 striker now reads 99/85/82 (was 99/96/93), measured ladder gaps at OVR 95/99: 17.9-18.1 for every position (GK 21.7 — its shipped span is already wider; shift only). (3) Below OVR 90 nothing changes: the low/mid bands are bit-identical (locked by an exact-formula test at OVR 78, below every shift threshold). The dataset reaches attribute 99 in attack, defence AND goalkeeping (printed maxima).
- **OVR-vs-quality-offset decision (requirement 4):** KEEP the consensus OVR — `overall` stays the pure curve value and the attributes carry the ±2.0/±2.5 noise. Rationale: the value↔OVR mapping is load-bearing (store pricing EV, the T-0046 band contract, save/regeneration stability via GDD 4.6 id-seeding); folding the offset into the headline would re-band every consumer of `overall` for zero gameplay gain. FUT-style headline kept; the behaviour is locked by tests either way.
- **Files changed:** `lib/core/domain/base_stats_generator.dart` (3 config fields + the ladder/shift in `generate()`); `test/core/domain/base_stats_generator_test.dart` (new T-0048 group: gap-floor at 95/97/99 × 2,000 seeds per position, printed ladder gaps at 84/95/99, exact expected formula below the ceiling, σ>0 + ±bound range locks over 1,000 seeds, per-draw extreme-order lock + exact expected ordering across 12 positions × 2,000 draws, zero-weight exact-0 lock, dataset 99s); `test/features/simulation/match_simulator_test.dart` (one directional assertion re-anchored — see concern 1).
- **How I tested it:** `flutter analyze` → No issues found. Full `flutter test` → **746 passed / 0 failed, ALL GREEN**. `flutter test tool/simulation_report_test.dart` → determinism PASS. The T-0046 dataset band test passed **unmodified**; `test/balance/match_engine_balance_test.dart` bands passed **unmodified** (the task's named guard).
- **Concerns / assumptions:** (1) The widened elite ladder legitimately re-shaped elite-match statistics: high-vs-low squads now create and score MORE (24.8 shots / 9.6 SoT / 3.1 goals vs 22.7 / 7.9 / 2.8 per match) but the conversion-per-shot ratio flipped (0.324 vs 0.356) — chance volume over per-chance purity, since elite attacks (99) now face wider-but-lower elite defences (~82). The GDD-30 directional check was re-anchored to the stable volume metrics (~15-20% measured margins instead of the old ~1%); the old per-shot premise is no longer true by design and is documented in the test. (2) Per-draw swaps between close-weight neighbours (CAM support 0.48 / attack 0.42) are the GDD-sanctioned style noise (±2.5 exceeds their 1.8-pt expected gap); "orderings never invert" is therefore locked as: ladder extremes never cross per draw (span floor 18 > noise bound 5 + rounding) + the EXPECTED profile orders exactly by weight, strictly. Per-draw strictness between close-weight neighbours would require absurd ladders (floor ≥ 31 for CAM) and is recorded as the honest reading of requirement 3. (3) No UI strings — nothing to localize.

## Review Log
