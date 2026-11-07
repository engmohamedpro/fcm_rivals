---
id: T-0048
title: Keep attribute shape position-true at every OVR tier
priority: medium
status: todo
attempts: 0
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

## Review Log
