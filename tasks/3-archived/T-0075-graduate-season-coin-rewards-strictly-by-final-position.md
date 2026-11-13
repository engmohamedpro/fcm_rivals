---
id: T-0075
title: Graduate season coin rewards strictly by final position
priority: high
status: done
attempts: 1
depends_on: [T-0074]
created: 2026-11-09
completed: 2026-11-09
---

# T-0075: Graduate season coin rewards strictly by final position

## Goal
The season coin reward is strictly graduated by final table position: 1st pays the most, 20th pays the least, and every step down the table pays strictly less than the one before it — while the total coin faucet stays inside the calibrated bands (owner decision 2026-11-09).

## Context
- Owner decision (2026-11-09): rewards follow position — 1st the most, last the least — with a stable economy (GDD 32: "Rewards do not cause Coin inflation").
- Today's curve (`seasonRewardCoins`, `lib/features/season/season_engine.dart:747-756`): `base = seasonBaseReward (10_000) × (1 + rewardPerDivisionStep (0.25) × (division − 1))`, then an outcome multiplier: promoted pos 1 = 2.0, pos 2–3 = 1.5 (FLAT pair), stayed pos 4–17 = `(1.0 − 0.03 × (position − 4))` clamped [0.6, 1.0], relegated pos 18–20 = 0.5 (FLAT trio). It violates the owner's rule: pos 2 == pos 3 and pos 18 == pos 19 == pos 20.
- Bands that must keep holding (`test/balance/economy_balance_test.dart:88-110`): div-1 champion exactly 20_000; champion < 0.25 × 90_000 (the inflation ceiling); higher divisions pay more but d4 < 2 × d1; a 38-match season banks 70k–160k before sinks. The ad test (`test/features/ads/ad_economy_test.dart:336-343`) asserts boosted − normal == 5_000, which survives only if the div-1 champion stays exactly 20_000.
- Design decision (minimal drift, do not re-litigate): fix ONLY the flat spots; every existing anchor is preserved. Suggested shape — pos 2 = 1.6, pos 3 = 1.5; relegated graduates 0.55 / 0.52 / 0.50 for pos 18 / 19 / 20. Champion stays 2.0 (= 20_000 at div 1), the stayed band stays as is (already strictly decreasing). Any shape is acceptable as long as every acceptance band below holds.
- Note: `test/balance/economy_balance_test.dart:93` samples position 19 as "relegated" and asserts 5_000 — with the graduated relegation band that assertion must move to position 20 (the new 5_000 floor) or take position 19's new value.

## Requirements
1. `lib/features/season/season_engine.dart` — `seasonRewardCoins` becomes strictly decreasing in `position`: for every division ≥ 1 and every position p in 1..19 (with `clubsPerDivision = 20`), `seasonRewardCoins(p) > seasonRewardCoins(p + 1)` after integer rounding. Express the multipliers as named constants in ONE place (inline consts next to the function, or fields on `SeasonConfig` following `seasonBaseReward`'s precedent — implementer's choice, documented in Developer Notes).
2. Anchors preserved exactly: div-1 pos 1 == 20_000 (2.0 × 10_000), div-1 last position in [4_500, 5_000] (a meaningful participation floor near today's 5_000), division scaling unchanged (`rewardPerDivisionStep = 0.25`; d4 vs d1 stays in (1×, 2×)).
3. Update the affected test expectations: `test/features/season/season_engine_test.dart` (the position-ladder tests around lines 209-222) gains a strict-monotonicity test across ALL 20 positions at div 1 and at one higher division (e.g. div 9, where the base ×3 amplifies rounding), plus anchor equalities; `test/balance/economy_balance_test.dart` moves/updates its relegated sample and keeps champion == 20_000 and the 0.25-ceiling assertion; `test/features/ads/ad_economy_test.dart` keeps passing untouched (boosted − normal == 5_000).
4. `docs/fcm_rivals_GDD_SRS.md` §18 — one sentence recording the strict position graduation (1st most … 20th least, every step strictly less) under the same dated owner decision 2026-11-09.
5. No other faucet or sink changes: match rewards, sell prices, pack prices, starting coins, and the ad multiplier are all untouched.

## Out of Scope
- Re-adding any card/pack reward (removed by T-0074, permanently).
- Changing `seasonBaseReward`, `rewardPerDivisionStep`, `promotionSlots`/`relegationSlots`, or the division target curve.
- The multi-season stability sweep and its band locks (T-0076 — run after this).
- The AI-side economy (AI clubs never earn coins; nothing to graduate).

## Acceptance Criteria
- [x] Strict graduation: a seeded test asserts `reward(p) > reward(p+1)` for every p in 1..19 at div 1 AND at div 9 — no flat step anywhere, 1st strictly the most, 20th strictly the least.
- [x] Anchors: div-1 pos 1 == 20_000; div-1 pos 20 in [4_500, 5_000]; `reward(div 4, p) > reward(div 1, p)` and `< 2 ×` for the sampled position; champion < 22_500.
- [x] `test/features/ads/ad_economy_test.dart` passes unchanged (the ×1.25 ad boost on the 20_000 champion still adds exactly 5_000).
- [x] GDD 18 documents the strict position graduation under the 2026-11-09 owner decision.
- [x] `flutter analyze` zero warnings; `flutter test test/features/season/ test/balance/economy_balance_test.dart test/features/ads/` green; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/season/season_engine_test.dart test/balance/economy_balance_test.dart test/features/ads/ad_economy_test.dart
# Expected: all pass — strict monotonicity 1..20 (div 1 and div 9), champion == 20000,
# last in [4500, 5000], ad delta == 5000

flutter test
# Expected: full suite green, no REGEN_SNAPSHOT
```

## Developer Notes

### Attempt 1 — implementation

**Summary:** the season coin reward is now strictly graduated by final position — every step down the table pays strictly less than the one above it, at every division — with every existing anchor preserved exactly (minimal drift, exactly the suggested shape).

1. `lib/features/season/season_engine.dart` — `seasonRewardCoins` fixed ONLY at the flat spots: promotion graduates pos 2 = 1.6 / pos 3 = 1.5 (was a flat 1.5 pair); relegation graduates 0.55 / 0.52 / 0.50 for 18th / 19th / 20th (was a flat 0.50 trio). Champion stays 2.0 (div-1 = 20_000 exactly), the stayed band (4–17) is untouched — it was already strictly decreasing — and division scaling is untouched. The multipliers are SIX named private static consts next to the function (the task's option A, chosen over SeasonConfig fields because they are shape constants of this one function, not tuning knobs a config variant would legitimately override; `SeasonConfig` keeps owning the base/step that the bands actually vary). Relegation positions are derived from `config.clubsPerDivision` (not hardcoded 18/19/20), so the graduation holds for any club count. Doc comments state the dated owner decision and each constant's role.
2. `test/features/season/season_engine_test.dart` — two new tests in the Rewards group: (a) STRICT monotonicity across all 20 positions at div 1 AND div 9 (div 9 = ×3 base, where rounding is most amplified), each step with a reason string carrying both values so a future flat step names its position; (b) anchor equalities — champion 20_000, last-place in [4_500, 5_000] and == 5_000, d4 > d1 and < 2× at position 5, and the two previously-flat spots asserted strictly ordered (2 > 3, 18 > 19 > 20).
3. `test/balance/economy_balance_test.dart` — the relegated sample moved from position 19 to position 20 (the graduated band's 5_000 floor), exactly as the task's note anticipated; champion == 20_000 and the 0.25-ceiling assertion untouched; the d4-vs-d1 ladder test untouched.
4. `test/features/ads/ad_economy_test.dart` — NOT touched: the ×1.25 boost on the 20_000 champion still adds exactly 5_000 (verified numerically before running: 20_000 × 1.25 = 25_000).
5. `docs/fcm_rivals_GDD_SRS.md` §18 — one sentence recording the strict graduation (1st most … 20th least, every step strictly less, no flat pairs/trios) under the same dated owner decision 2026-11-09.
6. Curve verified numerically BEFORE touching any test: div 1 = [20000, 16000, 15000, 10000, 9700 … 6100, 5500, 5200, 5000], div 9 strictly decreasing end to end, d4/d1 = 1.75, ad delta exactly 5_000.

**Files changed:** `lib/features/season/season_engine.dart`, `test/features/season/season_engine_test.dart`, `test/balance/economy_balance_test.dart`, `docs/fcm_rivals_GDD_SRS.md` (§18 one sentence).

**How tested (every How to Verify command):** `flutter analyze` → No issues found ✓. `flutter test test/features/season/season_engine_test.dart test/balance/economy_balance_test.dart test/features/ads/ad_economy_test.dart` → 58/58 green ✓. `flutter test test/features/season/ test/balance/` → 164/164 green ✓. Full `flutter test --concurrency=1` → **931/931 green, no REGEN_SNAPSHOT** ✓.

**Concerns:**
- Div-1 full season bank (the 70k–160k band) is unaffected: the graduation only redistributes ~±800 coins around the old curve per finishing position (2nd +1_000, 19th +200, 18th +500, 20th/1st/4th–17th unchanged) — the band test passed unchanged.
- The multipliers are engine-private (not on SeasonConfig); if a future task wants difficulty presets to reshape the reward curve, these six consts are the single place to lift into the config — noted for that reviewer, not done now (out of scope).

## Review Log

### Review 2026-11-09, attempt 1: PASS
- Ran on a fresh session of Flutter 3.47.9 / Dart 3.13.7 at this HEAD: `flutter analyze` → No issues found; `flutter test test/features/season/season_engine_test.dart test/balance/economy_balance_test.dart test/features/ads/ad_economy_test.dart` → 58/58 green; full `flutter test` → 931/931 green with `REGEN_SNAPSHOT` unset (one shared run covering all three tasks in review at this HEAD).
- Diff audit (fa379f6): only the flat spots changed — promotion 2nd = 1.6 / 3rd = 1.5 (was a flat 1.5 pair), relegation 0.55 / 0.52 / 0.50 for 18th/19th/20th (was a flat 0.50 trio), derived from `config.clubsPerDivision` rather than hardcoded positions; champion 2.0, the stayed band (4–17) and the division scaling are byte-identical to before. Six named private consts sit next to the function, documented with the dated owner decision. Files touched are exactly the four requirements' targets + the task file.
- Tests verified: strict monotonicity across all 20 positions at div 1 AND div 9, each step's reason string naming both values so a future flat step names its position; anchor equalities exactly as specified (champion == 20_000, last == 5_000 within [4_500, 5_000], d4 > d1 and < 2× at position 5, both previously-flat spots strictly ordered); the economy test's relegated sample moved 19 → 20 exactly as the task's note anticipated, with the champion and 0.25-ceiling assertions untouched; the ad test untouched and green (the ×1.25 boost on the 20_000 champion still adds exactly 5_000).
- GDD §18 records the strict graduation under the dated owner decision.
- One note, no criterion impact: Developer Notes claim the graduation "holds for any club count" — true up to `clubsPerDivision = 21`, but at 22+ the stayed band's clamp at 0.6 flattens consecutive positions before relegation. The game's value is 20 (`season_engine.dart:23`), the requirement is scoped to 20, and the monotonicity tests pass — just do not reuse the claim verbatim for a hypothetical larger league without re-checking the clamp.
