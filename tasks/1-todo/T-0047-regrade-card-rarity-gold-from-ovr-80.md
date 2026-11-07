---
id: T-0047
title: Regrade card rarity - gold from OVR 80, legendary packs guarantee gold
priority: medium
status: todo
attempts: 0
depends_on: [T-0046]
created: 2026-11-07
completed:
---

# T-0047: Regrade card rarity — gold from OVR 80, legendary packs guarantee gold

## Goal
Card rarity must be stable per player and match the owner's rule: **every player rated 80+ shows the golden legendary colour everywhere**, and a Legendary pack can only ever produce gold cards. Today 242 players rated 80-81 show sapphire, and Legendary packs regularly produce non-gold cards — the reported "pack bug".

## Context (evidence, main `3300692`)
- `lib/core/ui/fcm_style.dart:104-109` — `CardRarity.fromOverall`: legendary at **82+**, epic 70+, rare below. Dataset audit (T-0046 numbers): 510 players (2.44%) are 80+, only 268 (1.28%) are 82+ → **242 players in the 80-81 band show sapphire instead of gold**. This is the mismatch the owner flagged ("+80 golden rare"), not a rendering fault.
- **Stability is already correct**: all five colour call sites (`pack_contents_screen.dart:155`, `pack_opening_screen.dart:221`, `pre_match_analysis.dart:537`, `player_detail_sheet.dart:20`, `pack_catalog.dart:47`) use `fromOverall(overall)`, and `overall` is deterministic from market value — the same player always shows the same colour. No origin-based instability exists today.
- `fcm_style.dart:111-116` — `CardRarity.fromTier` maps **pack origin** to colour and bypasses the rating entirely. It has zero call sites (verified by grep) — dead code from the pre-regrade era and exactly the bug waiting to be reintroduced. Delete it.
- `lib/features/packs/pack_engine.dart:188` — value bands: low < €3M, mid €3-20M, **high ≥ €20M**; the store's Legendary pack rolls into the high band most of the time, and €20M ≈ OVR 79 under the current curve → **a gold-foil pack produces sub-80, non-gold cards**. After T-0046's retune the 80-boundary value must be computed from the config (≈ €23-24M under the proposed two-segment curve), never hardcoded.

## Requirements
1. `fromOverall` legendary threshold 82 → 80 (epic stays 70+); doc comment updated.
2. Delete `CardRarity.fromTier` (zero call sites); keep `PackTier.fromName` legacy-string parsing untouched (`pack_engine.dart:47-50` — persisted save compatibility).
3. Raise the pack high-band floor from the hardcoded €20M to the value where the T-0046 curve yields OVR 80, derived from `BaseStatsConfig` at runtime (no magic number); update the band-split tests accordingly.
4. Verify `pack_catalog.dart:47` (shelves a tier only when the position pool contains that rarity) follows the new threshold automatically; add an assertion that every shelved legendary pool is non-empty for every position pool that had one before, so no store shelf silently empties.
5. Seeded pack audit test (≥ 2,000 packs per tier, fixed seeds): **100% of Legendary-pack cards ≥ 80 OVR**; overall gold share of all pulls within 1.5-3.5%; rare/epic/legendary shares printed for the report. Rarity distribution must keep the "few elite, large middle" shape (GDD 4.5 / owner rule).

## Out of Scope
- The OVR curve itself (T-0046), attribute shapes (T-0048), pack pricing/coin economy.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Threshold and band tests updated; full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified where applicable (rarity labels: check the AR layer for the RARE/EPIC/LEGENDARY strings still correct)
- [ ] No performance or application-size regression
- [ ] Zero references to `fromTier` remain; 80+ renders gold in reveal, contents, collection and pre-match surfaces
- [ ] Pack audit test: 100% of legendary-pack pulls ≥ 80 OVR, shares band-locked
- [ ] Determinism PASS (`tool/simulation_report_test.dart` unchanged bands)

## How to Verify
```bash
grep -rn "fromTier" lib/ test/   # expect: no hits
flutter analyze
flutter test test/features/packs/ test/core/ui/ test/core/domain/
flutter test
```
Expected: no `fromTier` references; analyzer clean; pack/ui/domain suites green; full suite green.

## Side-effect risk (medium)
Store shelves re-bucket: more players qualify as legendary, so legendary pools grow and mid-band pools shrink — the pack catalog's expected-value pricing may shift slightly. EconomySimulator multi-season runs must stay green unmodified; the 80-boundary move is small (~€23-24M vs €20M) but must be measured, not assumed.

## Developer Notes

## Review Log
