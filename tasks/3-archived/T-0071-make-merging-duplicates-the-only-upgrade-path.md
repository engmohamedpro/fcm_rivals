---
id: T-0071
title: Make merging duplicates the only upgrade path
priority: medium
status: done
attempts: 1
depends_on: [T-0070]
created: 2026-11-09
completed: 2026-11-09
---

# T-0071: Make merging duplicates the only upgrade path

## Goal
Player cards upgrade only by combining duplicate cards — the coin-purchase upgrade path is removed end-to-end, so duplicates become the sole upgrade currency.

## Context
- Owner spec (2026-11-09): "player cards is upgraded only if player have two cards of the player" — every example is card-based. Today the detail sheet offers BOTH paths: a primary "Upgrade · N coins" button (`buyUpgrade`, `lib/features/collection/collection_store.dart` ~598, wired in `collection_collection_screen.dart:190-215` and `_upgrade` at ~336) and the Merge button when duplicates exist. `buyUpgrade` charges `economy.upgradeCostOf` (`lib/features/economy/economy_engine.dart` ~140) with an ad-powered discount (`AdEngine.discountedUpgradeCost`, `adStore.upgradeDiscountActive`).
- Removing the coin path removes an economy sink; the owner's direction is that pack duplicates (the faucet) carry that role instead. Balance impact is measured in T-0073's terms, not tuned here.
- `upgradeFacility` (campus buildings) is a DIFFERENT feature and must not be touched.
- `sellPriceOfUpgraded` stays: selling an upgraded copy still prices the level (+10% economic value per level).

## Requirements
1. Remove the coin upgrade path end-to-end: `buyUpgrade` and `UpgradePurchaseResult` from `collection_store.dart`/`collection_results.dart`, the Upgrade button and `_upgrade` handler from the detail sheet flow (`collection_collection_screen.dart:190-215, ~336`), and any `economy_simulator.dart` usage. Merge stays the only upgrade action, offered exactly when another copy exists.
2. Remove `EconomyEngine.upgradeCostOf` and the config knobs it alone uses (`upgradeValueMultiplier`, `upgradeLevelGrowth`) — grep for other readers first and leave anything shared.
3. Remove the upgrade-discount ad hooks: `AdEngine.discountedUpgradeCost` and `adStore.upgradeDiscountActive` plus their tests — the rest of the ad system (rewarded coins etc.) is untouched.
4. Update GDD 8.4 (`docs/fcm_rivals_GDD_SRS.md:481-489`): upgrades cost duplicate cards only, dated owner decision 2026-11-09, replacing the coin-cost paragraph.
5. Tests: delete the `buyUpgrade` suite; add assertions that the detail sheet shows no Upgrade action and still shows Merge when a duplicate exists; the economy tests that referenced `upgradeCostOf` are updated or removed with the function.

## Out of Scope
- Changing merge mechanics, the +N% math or caps (T-0070).
- Re-pricing packs or match rewards to compensate for the removed coin sink (measured later, separate task if needed).
- Any other ad feature or the campus facilities economy.

## Acceptance Criteria
- [x] `grep -rn "buyUpgrade\|upgradeCostOf\|discountedUpgradeCost" lib/` returns nothing.
- [x] The detail sheet's only upgrade action is Merge (visible iff another copy of the player is owned); no coin amount is shown for upgrades anywhere.
- [x] Selling, facilities, ads (other than the upgrade discount) and the economy sim all still work; `flutter analyze` zero warnings; `flutter test` full suite green.

## How to Verify
```bash
grep -rn "buyUpgrade\|upgradeCostOf\|discountedUpgradeCost" lib/   # no matches
flutter analyze
flutter test
flutter run   # manual: open a player with a duplicate -> Merge only, no coin upgrade button
```
Expected: grep empty, analyze clean, full suite green; upgrades reachable only through merging.

---

## Developer Notes

- **Summary of changes:** The coin-purchase upgrade path is removed end-to-end. `CollectionStore.buyUpgrade` (85 lines) and `UpgradePurchaseResult` deleted; the collection screen's Upgrade button, `_upgrade` dialog handler and the `upgradeCostOf` gate are gone — the detail sheet's only upgrade action is Merge, offered exactly when another copy exists; `PlayerDetailActions` lost `upgradeLabel`/`onUpgrade` (constructor now takes onMerge/sellLabel/onSell only). `EconomyEngine.upgradeCostOf` plus its exclusive config knobs (`upgradeValueMultiplier`, `upgradeLevelGrowth`) deleted after grepping readers. `AdEngine.discountedUpgradeCost` + `upgradeDiscountFraction` knob and `AdStore.upgradeDiscountActive`/`consumeUpgradeDiscount` deleted — the rest of the ad system (boosted recovery, free packs, selling bonus, daily/season multipliers) untouched; `AdRewardKind.upgradeDiscount` enum value KEPT because stored `adUsages` rows carry its string and `grantBoost` accepts any kind (the generic per-kind duplicate-prevention test still exercises it). GDD 8.4 rewritten with the dated owner decision (duplicates are the currency; no cost formula). `sellPriceOfUpgraded` kept, as required.
- **Files changed:** `lib/features/collection/{collection_store,collection_results,collection_collection_screen,player_detail_sheet}.dart`, `lib/features/economy/economy_engine.dart`, `lib/features/ads/{ad_store,ad_engine}.dart`, `docs/fcm_rivals_GDD_SRS.md` (8.4), tests: `ad_economy_test.dart`, `economy_engine_test.dart`, `economy_balance_test.dart`, `packs_and_generation_balance_test.dart` (upgrade sections replaced with duplicate-economics locks), NEW `test/features/collection/detail_sheet_merge_only_test.dart`, `tasks/…T-0071….md`.
- **How I tested it:** Acceptance grep `grep -rn "buyUpgrade\|upgradeCostOf\|discountedUpgradeCost" lib/` → **empty**. `flutter analyze` → No issues found. NEW sheet test → **3/3**: (a) with a duplicate the sheet shows 'Merge duplicate (+1)' and NO coin-upgrade anywhere (no 'Upgrade ·' text, no trending_up icon); (b) a lone base shows no Merge and no Upgrade — Sell only; the lone case is materialized by inserting one owned copy of a never-drawn base; (c) compile-level lock that `PlayerDetailActions` has no upgrade fields. Targeted suites (economy + ads + collection store + sheet) → **62/62**. `economy_balance_test.dart` → **19/19** after replacing the removed upgrade-curve tests with an upgraded-resale lock (engine's own formula). Snapshot 1/1 and balance 90/90 with `REGEN_SNAPSHOT` unset. Full `flutter test` → **891/891 green** (was 893: removed the upgrade-curve/discount tests, +3 sheet tests, rewritten locks).
- **Debugging notes (honest record):** Two test-infrastructure lessons cost time and are worth recording: (1) the new sheet test failed because the default 600×800 test viewport cuts the modal sheet (a ListView capped at 94% of screen height) above the action buttons — the texts dump proved content stopped at 'Market value'; enlarged to 2400×3600 @ dpr 3 like `injury_surfaces_test`. (2) My resale lock initially asserted ×1.6 for +5 levels — arithmetic slip: 1 + 0.10 × 5 = 1.5; the engine was right, my test was wrong. Also `tester.pageBack()` cannot close a modal bottom sheet (no back button) — replaced with a fresh pump.
- **Concerns / assumptions:** (1) The economy loses the upgrade coin sink by design (owner's direction: pack duplicates carry that role); T-0073's sweep measures the balance consequence — nothing re-priced here, per Out of Scope. (2) The enum value `AdRewardKind.upgradeDiscount` staying while its hooks are gone means a stored 'upgradeDiscount' grant row from an old save can no longer be consumed — it just sits inert; harmless. (3) The economy simulator's `mergeAllDuplicates`-style loop still calls `canMerge`, which is always true now — every duplicate pair merges, exactly the new rule.

## Review Log

### Review 2026-11-09, attempt 1: PASS
- Ran: acceptance grep (`grep -rn "buyUpgrade\|upgradeCostOf\|discountedUpgradeCost" lib/` → empty, exit 1), `flutter analyze` (No issues found), `flutter test test/features/collection/detail_sheet_merge_only_test.dart test/features/economy/ test/features/ads/` (38/38), full `flutter test` on HEAD.
- Scope check: `git show abb0015 --name-only` — exactly the 13 declared files (collection, economy, ads, GDD 8.4, tests); `upgradeFacility`, merge mechanics and `sellPriceOfUpgraded` untouched; deleted knobs (`upgradeValueMultiplier`, `upgradeLevelGrowth`) have zero remaining readers in lib/ and test/; `AdRewardKind.upgradeDiscount` enum kept for stored DB strings exactly as documented.
- Full-suite note for the record: HEAD's full run has exactly 2 failures, both in `injury_ui_test.dart` (pre-match medical room EN + AR) — A/B attribution (worktree at 362148c, i.e. WITH this task but BEFORE T-0069) shows those tests green there and red only after T-0069's chemistry row. The regression is T-0069's, not this task's; at this task's submission state the developer's 891/891 full pass is consistent with my targeted runs. No regression from THIS task.
- Notes: the inert stored `upgradeDiscount` grant rows (concern 2) are acceptable — nothing can consume them and nothing crashes; the economy-sink removal is the owner's direction, with balance measured in T-0073's terms per Out of Scope.
