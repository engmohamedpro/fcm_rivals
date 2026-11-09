---
id: T-0071
title: Make merging duplicates the only upgrade path
priority: medium
status: todo
attempts: 0
depends_on: [T-0070]
created: 2026-11-09
completed:
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
- [ ] `grep -rn "buyUpgrade\|upgradeCostOf\|discountedUpgradeCost" lib/` returns nothing.
- [ ] The detail sheet's only upgrade action is Merge (visible iff another copy of the player is owned); no coin amount is shown for upgrades anywhere.
- [ ] Selling, facilities, ads (other than the upgrade discount) and the economy sim all still work; `flutter analyze` zero warnings; `flutter test` full suite green.

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

## Review Log
