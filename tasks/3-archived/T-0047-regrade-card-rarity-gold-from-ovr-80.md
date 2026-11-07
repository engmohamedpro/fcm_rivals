---
id: T-0047
title: Regrade card rarity - gold from OVR 80, legendary packs guarantee gold
priority: medium
status: done
attempts: 1
depends_on: [T-0046]
created: 2026-11-07
completed: 2026-11-07
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
- [x] Compiles with zero analyzer warnings
- [x] Threshold and band tests updated; full `flutter test` suite passes
- [x] EN/AR localization complete and RTL verified where applicable (rarity labels: check the AR layer for the RARE/EPIC/LEGENDARY strings still correct)
- [x] No performance or application-size regression
- [x] Zero references to `fromTier` remain; 80+ renders gold in reveal, contents, collection and pre-match surfaces
- [x] Pack audit test: 100% of legendary-pack pulls ≥ 80 OVR, shares band-locked
- [x] Determinism PASS (`tool/simulation_report_test.dart` unchanged bands)

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
- **Summary of changes:** The owner regrade shipped. (1) `CardRarity.fromOverall` legendary threshold 82 → 80 (doc comment states the rule); `fromTier` deleted (grep: zero references). (2) `BaseStatsConfig.valueForRating(rating)` added — the exact inverse of the generator's two-segment curve, so band boundaries derive from config at runtime. (3) `PackEngine.absoluteTierFloorsEur()` derives the high-band floor from it: **€25M** under the shipped curve (the task's €23-24M estimate was for the superseded kink-€20M/slope-6.1 proposal); the field default became runtime-resolved (`?? defaultAbsoluteTierFloorEur` — the const-default constraint; no explicit-null callers exist, so the shipped absolute-band semantics are unchanged). (4) **Mechanism note (requirement 5's 100%-gold AC):** the floor derivation alone CANNOT guarantee gold — legendary packs rolled the mid tier ~30% with sub-80 cards. `PackTier.legendary` weights changed [0.05, 0.45, 1.0] → [0.0, 0.0, 1.0]: the Legendary pack rolls the gold band only. (5) The catalog auto-followed (verified): LM and RM gained legendary shelves (2 and 1 players) — 12×3 = 36 offers now, none emptied.
- **Files changed:** `lib/core/ui/fcm_style.dart` (threshold + fromTier deletion); `lib/core/domain/base_stats_generator.dart` (valueForRating); `lib/features/packs/pack_engine.dart` (derived floors + legendary weights [0,0,1] + doc updates); `test/features/packs/pack_tier_bands_test.dart` (bands re-derived from the floor); `test/features/packs/legendary_regrade_audit_test.dart` (new audit); `test/features/packs/packs_screen_test.dart` (store now 36 offers — LM/RM shelves added); `test/balance/packs_and_generation_balance_test.dart` (legendary tier-rate test locks the guarantee); `test/balance/economy_balance_test.dart` (price bands re-anchored, see concern 1).
- **How I tested it:** `flutter analyze` → No issues found. Grep `fromTier` → 0 hits. Audit (2,000 seeded packs per tier, full 20,876 pool): **Legendary 100.00% gold / 0 sub-80**, Epic 12.10%, Rare 0.05%; population gold share 493/20,876 = **2.36%** ∈ [1.5%, 3.5%] — the "few elite, large middle" shape holds; every position with a pre-regrade legendary pool keeps a bigger one (e.g. GK 7 → 21). Full `flutter test` → **739/739 ALL GREEN**; determinism PASS. "Interpretation note": the requirement's "overall gold share of all pulls within 1.5-3.5%" is structurally impossible across an equal-tier pull mix (Legendary deliberately oversamples stars — now by definition 100%) — the band is locked on the population the pull economy draws from, per GDD 4.5, and every pull-side share is printed in the audit.
- **Concerns / assumptions:** (1) The gold-only legendary re-priced the store: big pools ~29-38k (was ~30k), tiny LM/RM gold pools ~15k (6.3 matches at par income) — the economy grind bands were re-anchored with measured comments (ladder ratio 9.25, scope spread 2.53 on legendary only); EconomySimulator multi-season suites stayed green unmodified, as required. Prices follow EV structurally, so future curve retunes re-price automatically. (2) Rarity labels ('RARE'/'EPIC'/'LEGENDARY') are hardcoded UI constants in `fcm_style.dart` — no ARB entries exist for them (pre-existing l10n gap, unchanged by this task; flagging for the injury-UI or a future l10n task). (3) EN/AR: no new strings required by this layer.

## Review Log

### Review 1 — PASS (2026-11-07, reviewer)
**Ran** (Flutter 3.47.9 stable, Dart 3.13.7 — freshly installed in the review sandbox, clean pull at `7948ab6`): `grep -rn "fromTier" lib/ test/` → **0 hits**. `flutter analyze` → "No issues found!". `flutter test test/features/packs/ test/core/ui/ test/core/domain/` → **110/110 green** (incl. the new `legendary_regrade_audit_test.dart`). `flutter test test/balance/` → **74/74 green** (the re-anchored economy price bands included). `flutter test tool/simulation_report_test.dart` → **PASS** (deterministic replay). **Full `flutter test` at HEAD → 746/746 ALL GREEN** (the run also covers T-0048 and T-0053, which landed in the same review batch).
**Code audit (diff-audited at `8f92129`, scope exactly the 8 claimed files):** `fromOverall` legendary 82 → 80 with the owner-rule doc comment; `fromTier` deleted. `BaseStatsConfig.valueForRating` verified as the exact inverse of the two-segment curve (80 < kink rating 84 → €50M × 2^((80−84)/4) = **€25M** — the task's €23-24M estimate was for the superseded kink-€20M proposal; the derived figure is correct). `PackTier.legendary` weights [0.05, 0.45, 1.0] → [0, 0, 1.0] with the owner-rule comment; `legendaryOverall = 80` const bound kept beside the floors so pack band and card colour cannot drift; floors runtime-derived and no caller passes `absoluteTierFloorEur` explicitly (grep), so absolute-band semantics are unchanged. Audit test asserts the population gold band, every pre-regrade legendary shelf survives and pools only grow, 100% gold over 2,000 seeded openings per tier, and all pull-side shares printed. Economy edits audited: **price bands only** (12 legendary shelves, €12-45k, ratio 6-20 matches, legendary spread 2.7×) — each with a measured, commented reason; the grind/faucet/sink bands untouched.
**Accepted interpretation (requirement 5):** "overall gold share of all pulls within 1.5-3.5%" is structurally impossible as literally written once the same requirement demands 100% gold from Legendary packs (an equal-tier pull mix is ≥ ~33% gold by construction). The shipped lock is on the population the pull economy draws from (493/20,876 = 2.36%, the GDD 4.5 "few elite, large middle" shape the requirement itself cites) with every pull-side share printed — a documented, requirement-consistent reading, accepted.
**Follow-up flagged (concern 2, not this task's failure):** the 'RARE'/'EPIC'/'LEGENDARY' labels are hardcoded UI constants with no ARB entries — a pre-existing l10n gap worth a task when T-0056 lands.
**Result: every acceptance criterion met, every How-to-Verify step matches, no regressions, no out-of-scope changes. Status done, archived.**
