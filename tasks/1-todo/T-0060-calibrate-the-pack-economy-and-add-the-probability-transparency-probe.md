---
id: T-0060
title: Calibrate the pack economy and add the probability transparency probe
priority: high
status: todo
attempts: 0
depends_on: [T-0059]
created: 2026-11-08
completed:
---

# T-0060: Calibrate the pack economy and add the probability transparency probe

## Goal
Prove with measured numbers that the new two-stage odds are economically sound — EV ladder, prices, premium reachability, selection diversity — via a large-N simulation probe and band-locked calibration tests, then write the system into GDD §5. This is the balance gate: no new mechanics, only measurement, locks and documentation.

## Context
- **Measured baseline (analysis 2026-11-08, global pool, exponent 1.5, 20,876-row dataset, margins 1.25/1.40):** EV in economic-value units RARE 4,257 / EPIC 8,396 / LEGENDARY 17,332; auto-derived prices ~5,000 / ~10,000 / ~24,000; EV ladder strictly increasing. Premium's 2% legendary-pack share adds **+3.3%** to its EV (weighted premium E[MV] ≈ €109M). Reachability: P(premium | legendary pack) = 2% → 1-in-50 packs; ≥ 1 premium within 50 legendary packs = **63.6%**, within 100 = **86.7%**. Par team income ≈ 1,858 coins/match → affordability ladder 2.7 / 5.4 / 12.9 matches per pack (the shipped ladder was ~2.2 / 7.8 / 19.4 — the new one is flatter: legendary relatively cheaper; deliberate owner direction toward the red chase).
- **Selection diversity is the one real tuning risk:** at exponent 1.5 the RARE pool (18,295 rows) becomes bottom-heavy — effective pool size N_eff = 1,288 and the cheapest 10% of the pool take **71.4%** of the probability mass (at exponent 1.0: N_eff 4,446 / 48.5%; at 2.0: 453 / 87.1%). EPIC (N_eff 1,528), LEGENDARY (396) and PREMIUM (26) are healthy. The owner's spec rule "cheap players must not become the only realistic rewards" needs a hard band so a future exponent bump cannot silently collapse diversity. The exponent stays 1.5 (owner's number) unless the measured evidence in this task's calibration says otherwise — tuning happens HERE, in config, never in the algorithm.
- Shipped economy constants (`lib/features/economy/economy_engine.dart`): `packMarginMultiplier` 1.25, `legendaryPackMarginMultiplier` 1.40, `packOddsSmoothing` 0.55 (the legacy within-band exponent — T-0059 retires its use in the pack draw; keep the field for any remaining consumers or remove it if none, recording which), `economicValueOf` sqrt curve clamped [5, 600k].
- EconomySimulator multi-season suites are the standing faucets/sinks guard — the legendary pack price drops (~36k → ~24k global), which moves season spending; the suites must stay green or the shift must be recorded and explained (not tuned away).
- GDD: §5 (5.2 categories, 5.3 tiers, 5.4 odds, 5.5 pricing) documents the CURRENT single-stage tier system — it must be rewritten for the two-stage system with the owner's tables and formula.

## Requirements
1. Simulation probe `tool/pack_probability_probe.dart` (pure Dart, runnable via `dart run`): for each `PackTier` × the global scope, opens N seeded packs (default 100,000, `--packs` flag), and prints/writes a report: rarity distribution vs theoretical (per-rarity absolute deviation + binomial 3σ bound), top-20 per-player selection shares vs theoretical, average/min/max reward MV per pack, premium appearance frequency, EV per pack in coins, and the N_eff + cheapest-decile share per rarity pool. Deterministic given `--seed`.
2. Calibration test group `pack probability` in `test/balance/` with printed, band-locked numbers: EV ladder strictly increasing (rare < epic < legendary); global price bands re-anchored with measured comments (rare ~5k, epic ~10k, legendary ~24k, ±25%); premium contributes between 1% and 8% of the legendary pack's EV; premium reachability band 1.5%-2.5% per legendary pack (the published odds); affordability bands in par matches (rare ≤ 4, epic 4-8, legendary 10-16); **diversity floor**: RARE pool N_eff ≥ 1,000 AND cheapest-decile share ≤ 75% at the shipped exponent, plus the same metrics printed for epic/legendary/premium.
3. Exponent decision recorded: run the probe at exponents 1.0 / 1.5 / 2.0, compare the diversity metrics and EV ladder, and record in Developer Notes whether 1.5 ships (expected: yes — N_eff 1,288 clears the floor) or the config default moves, with the numbers. Any move is a config change only.
4. Multi-season stability: `EconomySimulator` suites pass unmodified; if the price shift moves any season band, record the diff and the reason in Developer Notes (tune nothing in the match economy). One soak: ≥ 5 simulated seasons with the new odds, no negative balances, no unreachable progression, pack spend within the documented ladder.
5. GDD §5 rewrite: the two-stage algorithm (the exact 8 owner steps), the rarity table (OVR bands, colors — PREMIUM documented as the shipped crimson identity), the pack odds matrix, the MV-weighting formula with the exponent, safe-empty-pool fallback, premium exclusivity, the pricing model (EV × margin, floor-to-thousands) with the measured price examples, and the transparency probe as the audit tool. Reference T-0060's bands as the calibration contract.
6. `packOddsSmoothing` disposition: remove it if T-0059 leaves zero consumers (with the grep evidence), or document it as legacy-only — no dead config without a note.

## Out of Scope
- Any engine/mechanic change (T-0059 owns the draw); the algorithm must not change here even if a band suggests tuning — config values only.
- Pack prices beyond what `packPriceFor` derives automatically; match rewards; coin faucets/sinks other than recording their behavior.
- The reveal animations (T-0050/T-0051) and store UI.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] The probe runs deterministically and its report prints every required metric (rarity deltas within 3σ, per-player shares, MV stats, premium frequency, EV, N_eff)
- [ ] Calibration group green with all bands printed and locked; full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified where applicable (probe output is a dev tool — English-only acceptable; no user-facing strings expected)
- [ ] No performance or application-size regression (the probe is a tool, not shipped code)
- [ ] EV ladder, price bands, premium EV share, reachability and diversity floors all band-locked by test
- [ ] EconomySimulator multi-season suites green unmodified (or the shift recorded with numbers)
- [ ] GDD §5 documents the shipped system with the measured numbers

## How to Verify
```bash
flutter analyze
dart run tool/pack_probability_probe.dart --packs 100000 --seed 2026
flutter test test/balance/ test/features/season/
flutter test
```
Expected: analyzer clean; the probe report matches the calibration bands (rarity deltas within 3σ, legendary pack ~24k EV-priced, premium ~2%); balance/season suites green; full suite green.

---
<!-- Everything below this line is filled in by agents, never by the task author. -->

## Developer Notes

- **Summary of changes:**
- **Files changed:**
- **How I tested it:**
- **Concerns / assumptions:**

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
