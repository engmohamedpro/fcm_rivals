---
id: T-0074
title: Pay season rewards in coins only
priority: high
status: done
attempts: 1
depends_on: []
created: 2026-11-09
completed: 2026-11-09
---

# T-0074: Pay season rewards in coins only

## Goal
Season completion pays Coins and nothing else: no reward packs are granted, shown, or promised anywhere, and GDD 18 reflects the coins-only rule (owner decision 2026-11-09).

## Context
- Owner decision (2026-11-09): season rewards are coins ONLY, not cards. The coin amounts themselves are T-0075's job; this task only removes the card half and keeps every current coin value byte-identical.
- Where packs are granted today: `completeSeason` in `lib/features/season/season_store_standings.dart` — the `packCategory` switch at lines ~107-114 (promoted: 1st = premium, 2nd–3rd = normal; the `'choice'` branch is dead with the default `promotionSlots = 3` because positions 1–3 all hit the `position <= 3` arm) and the `db.into(db.packs).insert(...)` block at lines ~223-237 writing rows with `source: 'season_premium'` / `'season_normal'` / `'season_choice'`.
- Where the grant is surfaced: `SeasonCompletion.rewardPackCategory` (`lib/features/season/season_models.dart:74,88`) and the "Reward pack: …" row in the completion dialog (`lib/features/season/season_screen.dart:198-206`, hardcoded English, no l10n keys exist for it).
- Economy rationale (documented, do NOT silently reverse it): the removed packs are NOT compensated in coins. A premium pack's dynamic price far exceeds the season-reward inflation ceiling (`champion < 0.25 × 90_000` in `test/balance/economy_balance_test.dart:99`), so converting its value would break GDD 32 "Rewards do not cause Coin inflation". The card-income reduction is intentional: from now on cards come from coins spent in the store, which strengthens sink coverage.
- No test today asserts the pack grants (verified by grep) — that gap gets closed with a negative test here.
- Existing saves may already hold unopened `season_*` packs: they were earned and stay untouched (no migration, no purge).

## Requirements
1. `lib/features/season/season_store_standings.dart` — remove the `packCategory` switch and the reward-pack insert block inside the completion transaction. Expected: `completeSeason` writes no row to the `packs` table, and no `lib/` code creates a pack with a `season_` source anymore (`grep -rn "season_" lib/ --include="*.dart"` returns nothing in pack-creation contexts).
2. `lib/features/season/season_models.dart` — remove `rewardPackCategory` from `SeasonCompletion` (the field and its constructor parameter).
3. `lib/features/season/season_screen.dart` — remove the "Reward pack:" conditional row from the completion dialog; the coins row and "Next division" row stay exactly as they are.
4. `docs/fcm_rivals_GDD_SRS.md` §18 — replace the pack entries in the reward table with the coins-only structure (1st = highest coin tier … last = lowest), note the ad ×1.25 multiplier still applies to the coin payout (GDD 19.3), and record the dated owner decision 2026-11-09 ("season rewards are coins only — packs removed"). Do not touch §17.6 (season rewards are already listed as coins).
5. `test/features/season/season_store_test.dart` — add a negative assertion to the existing completion test: after `completeSeason`, the `packs` table contains zero rows whose `source` starts with `season_` (run it for a promoted finishing position and for a mid-table/relegated one). The existing ledger assertions (`reason == 'season_reward'`, credited exactly once) must keep passing unchanged.
6. Keep every coin value identical in this task: `seasonRewardCoins` itself is NOT touched here (that is T-0075).

## Out of Scope
- Changing coin amounts or the position curve (T-0075).
- Purging or migrating already-granted `season_*` packs in existing saves.
- The rewarded-ad season multiplier (+25%) — unchanged, still multiplies the coin payout.
- Localizing the completion dialog (pre-existing hardcoded-English gap; the deleted row removes one untranslated string, the rest is a separate concern).
- The economy simulator's buying strategy (`lib/features/simulation/economy_simulator.dart` never opens granted season packs, so no sim change is needed).

## Acceptance Criteria
- [x] `completeSeason` grants zero packs: negative test covering a promoted and a non-promoted finish passes; no `lib/` file references `season_premium` / `season_normal` / `season_choice` anymore.
- [x] `SeasonCompletion` has no `rewardPackCategory` field and nothing in `lib/` or `test/` references it.
- [x] The completion dialog shows the season-reward coins row and the next-division row only; no "Reward pack" text renders.
- [x] Coin payout is unchanged by this task: `seasonRewardCoins(division: 1, position: 1) == 20_000` and the existing `economy_balance_test` season-reward assertions pass without edits.
- [x] GDD 18 shows the coins-only reward structure with the dated owner decision; the ledger/coin-flow behavior matches it.
- [x] `flutter analyze` zero warnings; `flutter test test/features/season/` green; full `flutter test` green with no `REGEN_SNAPSHOT`.

## How to Verify
```bash
grep -rn "season_premium\|season_normal\|season_choice\|rewardPackCategory" lib/ test/
# Expected: no output (all references removed)

flutter analyze
# Expected: No issues found!

flutter test test/features/season/ test/balance/economy_balance_test.dart
# Expected: all pass — including the new zero-packs assertion and the untouched
# coin anchors (champion div 1 == 20000)

flutter test
# Expected: full suite green (no REGEN_SNAPSHOT), including the season screen tests
```

---

## Review Log

### Review 2026-11-09, attempt 1: PASS
- File note: this task was authored without the Developer Notes / Review Log sections (older planning format); the developer's implementation summary lives in commit 58d4d61's message. The Review Log section is added by this review per the reviewer workflow.
- Ran at HEAD f13f132 (fresh Flutter 3.47.9 / Dart 3.13.7): `grep -rn "season_premium\|season_normal\|season_choice\|rewardPackCategory" lib/ test/` → no output; `flutter analyze` → No issues found; `flutter test test/features/season/ test/balance/economy_balance_test.dart` → 86/86; the new negative test by name (`flutter test test/features/season/season_store_test.dart --plain-name "completeSeason grants ZERO packs"`) → passed; full `flutter test` → 922/922 with `REGEN_SNAPSHOT` unset (one run covers both tasks in review at this HEAD).
- Every requirement verified against the implement diff (58d4d61): the `packCategory` switch and the `packs` insert block are gone from `completeSeason` (`season_store_standings.dart`); `rewardPackCategory` deleted from model, constructor and dialog row (`season_models.dart`, `season_screen.dart` — the coins row and the Next-division row are untouched); GDD §18 rewritten coins-only with the dated 2026-11-09 owner decision, the ×1.25 ad note (§19.3) and the no-compensation rationale; the `season_store_test.dart` diff is pure addition (+76/−0), so every existing ledger assertion ran unchanged.
- Coins byte-identical: `seasonRewardCoins` (`lib/features/season/season_engine.dart:747`) has zero diff lines in the implement commit; the economy suite's champion anchor `expect(champion, 20_000)` (`economy_balance_test.dart:97`) passes unedited.
- Honest note on the dialog criterion: verified at code level — the row, the field and the "Reward pack" string no longer exist anywhere in `lib/` or `test/` (grep clean), so the text cannot render; no widget test renders the completion dialog at all (pre-existing gap — this task's Out of Scope already defers dialog coverage/localization to a separate concern).
- No out-of-scope files: the implement commit touches exactly the four requirement targets + the task file front matter + the test file.
