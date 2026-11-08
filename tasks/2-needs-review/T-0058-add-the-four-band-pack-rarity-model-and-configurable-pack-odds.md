---
id: T-0058
title: Add the four-band pack rarity model and configurable pack odds
priority: high
status: needs-review
attempts: 1
depends_on: []
created: 2026-11-08
completed:
---

# T-0058: Add the four-band pack rarity model and configurable pack odds

## Goal
Give the pack system its own four-band rarity partition (RARE < 70, EPIC 70-79, LEGENDARY 80-89, PREMIUM 90+) plus a single configurable odds class (per-pack rarity tables, MV exponent, pity placeholder) — the contract the two-stage draw (T-0059) and the calibration gate (T-0060) build on. Configuration only in this task: no engine behavior change yet.

## Context
- Owner spec 2026-11-08: rarity is derived **from OVR** (never manually assigned) in four bands; pack kinds stay three (`PackTier`, `lib/features/packs/pack_engine.dart:33-55`) with per-pack rarity probability tables: RARE pack 75/20/5/0, EPIC pack 40/50/10/0, LEGENDARY pack 0/55/43/2 (RARE/EPIC/LEGENDARY/PREMIUM). Premium is exclusive to Legendary packs (the rare/epic tables carry 0).
- **Measured on the real dataset** (analysis 2026-11-08, `assets/data/players_v1.json`, 20,876 rows, shipped T-0046 curve — boundaries OVR 70 = €4.42M, 80 = €25M, 90 = €87.06M): curve-based pools RARE 18,295 (87.64%) / EPIC 2,088 (10.00%) / LEGENDARY 464 (2.22%) / PREMIUM 29 (0.139%). The live seeded generator adds ±2.0 quality noise, so the noise-inclusive counts differ slightly: 31 premium (T-0049's measure) and 493 gold (T-0047's) → legendary 80-89 ≈ 462. Tests must print and band-lock, not assert single values.
- **Do NOT add a 4th `CardRarity` value** (T-0049 rejected it and test-locked `CardRarity.values.length == 3`; premium rendering stays `CardClass` from T-0049). The pack layer's PREMIUM band is a probability partition only.
- **Color conflict, decided:** the spec's table says PREMIUM = "Platinum/Diamond"; the shipped, owner-approved T-0049 identity is crimson red (intensity 2.5). Keep red — do not touch `CardClass`'s palette. The spec's intensity 2.5 already matches.
- Bind the pack PREMIUM threshold to the card-rendering threshold exactly like T-0047 bound the gold band (`PackEngine.legendaryOverall` pattern, `lib/features/packs/pack_engine.dart:190-206`): one constant, or a test asserting `PackRarity.premiumThreshold == CardClass.premiumOverallThreshold` — the band and the red card can never drift apart.
- Where: new file `lib/features/packs/pack_rarity.dart` (pure Dart, the `injury.dart` pattern) so `pack_engine.dart` (~525 lines) stays under the 800-line convention when T-0059 wires it.

## Requirements
1. `lib/features/packs/pack_rarity.dart`: `PackRarity` enum (`rare/epic/legendary/premium`) with `fromOverall(int overall)` partitioning on configurable thresholds (defaults 70/80/90); doc comment states the owner rule (rarity from OVR, auto-derived) and the measured MV boundaries (€4.42M / €25M / €87.06M under the shipped curve — derived, never hardcoded into logic).
2. `PackOddsConfig` in the same file, the `InjuryConfig` pattern — every knob in one class: the four OVR thresholds; the per-`PackTier` rarity probability tables (the owner's matrix above); `marketValueExponent` (default 1.5); a documented nullable pity/guaranteed-rarity placeholder field (**unused in this task** — no behavior, GDD rule 14 pre-balance). Assert every table's probabilities sum to 1.0 within 1e-9 and every value ∈ [0, 1].
3. `weightFor({required int marketValueEur, required int poolMinMarketValueEur, required double exponent})` pure helper implementing the owner formula `(poolMinMv / mv)^exponent` with safe guards: mv ≤ 0 or below 1 clamps to 1 before dividing; poolMinMv ≤ 0 clamps to 1; result never NaN/Infinity/negative. Document the guard behavior.
4. Dataset partition test (new `test/features/packs/pack_rarity_test.dart`): loads `players_v1.json`, derives each player's OVR through the shipped generator (the same `baseStats.overall` packs will see, noise included), prints the four pool sizes and shares, and band-locks them: premium ∈ [20, 45] rows, gold (legendary + premium) ∈ [460, 520], legendary 80-89 = gold − premium, epic and rare within ±5% of the curve-based counts (2,088 / 18,295).
5. Boundary unit tests: OVR 69→rare, 70→epic, 79→epic, 80→legendary, 89→legendary, 90→premium (exact edges); a consistency test binding the premium threshold to `CardClass.premiumOverallThreshold` (90) and the legendary threshold to the gold rule (80).
6. Config plumbing only: `PackTier` gains NO new value; `PackEngine` gains NO behavior change in this task (T-0059 wires the draw). No probabilities hardcoded outside `PackOddsConfig`.

## Out of Scope
- The two-stage draw itself, `oddsFor`/`expectedPackValue`/`packPriceFor` changes, any test re-anchor of shipped odds (T-0059).
- The simulation/transparency tool and EV calibration bands (T-0060).
- Changing `CardRarity`, `CardClass`, pack colors, stars or prices (T-0049/T-0047 shipped values).

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] New `pack_rarity_test.dart` green with the pool sizes printed and band-locked; full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified where applicable (no user-facing strings expected in this layer)
- [ ] No performance or application-size regression (one pure module + config)
- [ ] Every probability table sums to exactly 1 (asserted by test) and premium weight is 0 for the rare and epic packs
- [ ] Premium pack threshold and `CardClass.premiumOverallThreshold` are bound (test-locked)
- [ ] Zero probabilities hardcoded outside `PackOddsConfig` (grep clean)

## How to Verify
```bash
flutter analyze
flutter test test/features/packs/pack_rarity_test.dart
grep -rn "0.75\|0.55\|0.43\|0.02" lib/features/packs/pack_engine.dart   # expect: no odds literals
flutter test
```
Expected: analyzer clean; the partition test prints the four pool sizes and passes inside the bands; no odds literals in the engine; full suite green.

---
<!-- Everything below this line is filled in by agents, never by the task author. -->

## Developer Notes

- **Summary of changes:** New pure-Dart module `lib/features/packs/pack_rarity.dart` (the `injury.dart` pattern — no Flutter imports, no RNG): `PackRarity` enum with `fromOverall` partitioning on the configurable 70/80/90 cuts; `PackOddsConfig` holding every knob (band cuts, the owner's per-tier rarity matrix as named-record tables, `marketValueExponent` 1.5, nullable `pityGuaranteedRarityPulls` placeholder documented as unused); `weightFor` implementing `(poolMinMv / mv)^exponent` with the documented clamps. Doc comments carry the owner rule (rarity from OVR, auto-derived) and the measured MV boundaries (€4.42M / €25M / €87.06M) as documentation only — no logic hardcodes them. No engine behavior change, no new `PackTier`, no `CardRarity` change (Req 6).
- **Files changed:** `lib/features/packs/pack_rarity.dart` (new, ~190 lines); `test/features/packs/pack_rarity_test.dart` (new, 12 tests).
- **How I tested it:** `flutter analyze` — No issues found. `flutter test test/features/packs/pack_rarity_test.dart` — 12/12. Dataset partition through the REAL import pipeline (`PlayerDatabase.importDatasetFromJson` → `BaseStatsGenerator` seeded per player id, the same `baseStats.overall` packs see), printed and band-locked: **rare 18,292 (87.62%) | epic 2,074 (9.93%) | legendary 479 (2.29%) | premium 31 (0.148%) | gold 510** — premium 31 reproduces T-0049's measure, gold 510 inside T-0047's [460, 520], epic/rare within ±5% of the curve-based 2,088/18,295, and the four pools sum to 20,876 (partition, no overlap). Boundaries 69/70/79/80/89/90 exact; premium threshold bound to `CardClass.premiumOverallThreshold` and legendary to `PackEngine.legendaryOverall` by test; every table sums to 1 ±1e-9 with weights in [0,1] (`validate()` throws in release too — the const constructor can only assert constant expressions, so table sanity lives in `validate()` and is test-locked); premium weight 0 for rare/epic packs; pity placeholder null-locked; `weightFor` guards proven finite/NaN-free on degenerate inputs. Full `flutter test` — **796 passed** (14 more than T-0055's 784).
- **Concerns / assumptions:** (1) The How-to-Verify grep on `pack_engine.dart` hits ONE pre-existing literal — `tierBoundaries = const [0.15, 0.55]` (line 212) — the shipped MV-tier boundary constant from the economy work, not a rarity-odds literal; the rarity matrix lives only in `PackOddsConfig`. T-0059's draw rewiring should fold that constant into the config class when it touches the stage split. (2) Record field access in `const` initializers is not a constant expression in this Dart version, so the constructor asserts only band ordering; `validate()` (which throws `ArgumentError`) is the table guard in both debug and release — tests lock it. (3) The `pityGuaranteedRarityPulls` field is deliberately inert; T-0059/T-0060 own its semantics — wiring anything before the economy calibration would be GDD rule 14 violation.

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
