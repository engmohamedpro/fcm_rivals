---
id: T-0070
title: Make each upgrade level add one percent to all stats without caps
priority: high
status: needs-review
attempts: 1
depends_on: []
created: 2026-11-09
completed:
---

# T-0070: Make each upgrade level add one percent to all stats without caps

## Goal
Upgrade level N adds +N% to the player's overall and all four attributes (a +3 Salah shows 103% of his base stats), upgrade levels are unlimited, and upgraded values may exceed 99 — replacing today's two random attribute points per level with the level-5 and 99 caps.

## Context
- Owner spec (2026-11-09): merging stays as-is (base + base → +1, +1 + base → +2, further merges additive), but the benefit becomes "+N% for all this player stats, +1 gives 1%, +2 gives 2% and so on" — explicitly because the game must be infinite. Integer points capped at 99 cannot grow forever; a percentage can.
- What exists today and changes here: `UpgradeEngine` (`lib/features/upgrades/upgrade_engine.dart`) allocates 2 random weighted points per level (`pointsPerLevel`, `allocateAttributeGain`) under `maxUpgradeLevel = 5` (a placeholder pre-balance value); `PlayerCard.overall`/`attribute()` add stored points capped at 99 (`lib/features/squad/squad_engine.dart:53-58`); the four `upgraded*` DB columns accumulate the random points (`lib/features/collection/collection_store.dart:494-570`, `app_database.dart:91`, mirror in `squad_store.dart:204`).
- What stays untouched: the merge progression formula (`mergedLevel = target + duplicate + 1` — satisfies the owner's examples), merging being free, the duplicate being consumed (`status: 'merged'`), the +N card badge, `sellPriceOfUpgraded` (+10% economic value per level, works at any level).
- The new formula, one source of truth: `upgradedValue(base, level) = base + (base * level / 100).round()` — linear, not compounding (+3 is ×1.03, not ×1.01³). Examples: base ATT 90 → +1: 91, +2: 92, +11: 100, +20: 108; base 60 → +3: 62.
- Existing saves get a one-time deterministic rebalance: `upgradeLevel` becomes the only source of truth; the old random stored points are ignored (a +3 card's stats may shift by a point or two — accepted, owner-driven redesign).
- UI is safe above 99 (verified): `ratingColor` thresholds (`lib/core/ui/fcm_widgets_helpers.dart:15`), `CardClass.fromOverall` (`lib/core/ui/fcm_style.dart:118`), `FcmStatBar` fill clamps at 1.0 (`lib/core/ui/fcm_chip.dart:163`).

## Requirements
1. Add the shared pure helper `int upgradedValue(int baseValue, int upgradeLevel)` to `lib/core/domain/players.dart` (pure Dart, no Flutter imports) — `baseValue + (baseValue * upgradeLevel / 100).round()`, negative levels clamped to 0. Both `PlayerCard` and the AI ladder (T-0072) must use this one function.
2. `PlayerCard` (`lib/features/squad/squad_engine.dart`): remove the four `upgraded*` fields; `overall` and `attribute()` return `upgradedValue(base, upgradeLevel)` with **no 99 cap**. Fix every construction site (grep `upgradedAttack:` — `collection_store.dart` ~402, `squad_store.dart` ~204, and tests).
3. `UpgradeEngine`: delete `allocateAttributeGain`, `pointsPerLevel` and the `maxUpgradeLevel` cap check from `canMerge`; `merge()` returns only the new level; `MergeResult` drops `attributeGain` (`lib/features/collection/collection_results.dart:83`). `mergeDuplicates` loses its `random` parameter (update callers `collection_collection_screen.dart:400` and `lib/features/simulation/economy_simulator.dart:441`) and the `Maximum upgrade level reached` error path (`collection_store.dart:523-527`).
4. DB: keep the `upgraded_*` columns (no migration); new merges stop writing accumulated points (write 0), and nothing reads them for gameplay math. Mark them legacy in a comment on the table definition (`app_database.dart`).
5. Detail sheet (`lib/features/collection/player_detail_sheet.dart:265-285`): each `FcmStatBar` bonus becomes the derived gain `upgradedValue(base.valueOf(attr), level) − base.valueOf(attr)`. The pack-reveal and card `stats` overrides keep receiving the effective values.
6. Update GDD 8.2 (`docs/fcm_rivals_GDD_SRS.md:470-476`): +N% to overall and all attributes per level, unlimited levels — dated owner decision 2026-11-09, replacing "+1 Overall + 1 random attribute".
7. Rewrite `test/features/upgrades/upgrade_engine_test.dart` deterministically: merged-level progression cases (base+base→+1, +1+base→+2, +2++1→+4); `upgradedValue` examples above including >99; the collection store merge test merges past level 5 (5+base→6, no error) and consumes the duplicate; a rebalance test — an owned row with old-style random points reads stats derived from its level only.

## Out of Scope
- Removing the coin-purchase upgrade path (T-0071).
- The AI division ladder using the same math (T-0072) and the balance gate (T-0073).
- Pack drop rates / economy retuning — duplicates become more valuable as the only upgrade currency; that is measured, not tuned, here.
- The `upgradeFacility` campus path — unrelated (buildings, not players).

## Acceptance Criteria
- [ ] A +N owned card's overall and all four attributes equal `upgradedValue(base, N)` exactly, with values above 99 rendering correctly on the card and detail sheet.
- [ ] Merging works at any level (no cap error anywhere) and stays free; the duplicate is consumed; the +N badge shows the true level.
- [ ] No gameplay code reads the `upgraded_*` columns; new merges write 0; existing saves load with level-derived stats.
- [ ] GDD 8.2 reflects the new math with the dated owner decision.
- [ ] `flutter analyze` zero warnings; `flutter test` full suite green; `test/features/match/` and `test/balance/` pass without `REGEN_SNAPSHOT`.

## How to Verify
```bash
flutter analyze
flutter test test/features/upgrades/ test/features/collection/   # new deterministic suites green
flutter test                                                     # full suite, zero drift
flutter run   # manual: merge two Salah copies twice -> +2 card, each stat +2% of base, badge +2
```
Expected: analyze clean, suites green; a merged card's stats match the percentage formula exactly (90 ATT +2 → 92).

---

## Developer Notes

- **Summary of changes:** `upgradedValue(baseValue, level)` added to `lib/core/domain/players.dart` as the single source of truth — `base + (base × level / 100).round()`, negative levels clamped, no 99 cap. `PlayerCard` lost its four `upgraded*` fields: `overall` and `attribute()` now derive purely from `upgradeLevel`. `UpgradeEngine` rewritten: `allocateAttributeGain`, `pointsPerLevel`, the `maxUpgradeLevel` cap and the `position`/`random` parameters are gone — `merge()` returns only the new level, `canMerge` is always true by level, everything deterministic. `mergeDuplicates`/`buyUpgrade` lost their `random` parameter and the `Maximum upgrade level reached` path; both write `upgradeLevel` and ZERO the legacy `upgraded_*` columns (kept for save compatibility, marked legacy in the table comment). `MergeResult`/`MergeOutcome` dropped `attributeGain`; the merge snackbar shows "+N% stats". Detail-sheet bonuses are now derived (effective − base). The screen's upgrade-cost gate (null at max level) became unconditional — levels are unlimited. GDD 8.2 rewritten with the dated owner decision.
- **Files changed:** `lib/core/domain/players.dart`, `lib/features/squad/squad_engine.dart`, `lib/features/upgrades/upgrade_engine.dart`, `lib/features/collection/{collection_store,squad_store,collection_results,collection_collection_screen,player_detail_sheet}.dart`, `lib/features/simulation/economy_simulator.dart`, `lib/core/database/app_database.dart` (comment only), `docs/fcm_rivals_GDD_SRS.md` (8.2), tests: `upgrade_engine_test.dart` (rewritten), `collection_store_test.dart`, `squad_engine_test.dart`, `ad_economy_test.dart`, `tasks/…T-0070….md`.
- **How I tested it:** `flutter analyze` → No issues found. `flutter test test/features/upgrades/` → 13/13 (progression incl. past the old cap, `upgradedValue` examples 90→91/92/100/108, 60@+3→62, no-99-cap, half-up rounding, negative clamp). `flutter test test/features/collection/collection_store_test.dart` → 24/24 including two new tests: merging a +5 with a base copy → +6 with no error and the duplicate consumed (and legacy columns zeroed), and a rebalance test where an old-style row (+3 level, 5 random ATT points) reads stats derived from the level alone. Squad + ads suites green. Zero-drift: snapshot 1/1 and balance 86/86 with `REGEN_SNAPSHOT` unset. Full `flutter test` → **880/880 green** (was 877; +3 net new tests: past-cap merge, rebalance, upgradedValue suite growth net of removed allocation tests).
- **Concerns / assumptions:** (1) `economy_simulator`'s duplicate-merge loop no longer skips "capped" pairs — every duplicate pair is now mergeable, so sim economies merge slightly more; that is the intended new rule and T-0073 measures it. (2) The `upgradeCostOf` economy curve still prices by level — at very high levels coins get expensive but that is T-0071/T-0073 territory, untouched here. (3) Old saves: a +3 card's stats may shift by a point or two (random points → +3% of base), accepted per the task. (4) `canMerge` kept as an always-true method rather than deleted, because the simulator loop and store call it — deleting it would churn callers for no benefit; documented as "store still guards same-player/owned-state".

## Review Log
