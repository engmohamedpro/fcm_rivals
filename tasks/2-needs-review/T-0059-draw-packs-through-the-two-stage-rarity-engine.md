---
id: T-0059
title: Draw packs through the two-stage rarity engine with market-value weighting
priority: critical
status: needs-review
attempts: 1
depends_on: [T-0058]
created: 2026-11-08
completed:
---

# T-0059: Draw packs through the two-stage rarity engine with market-value weighting

## Goal
Replace `PackEngine`'s MV-band tier roll with the owner's exact two-stage algorithm: stage 1 rolls a rarity from the pack's configured table (T-0058), stage 2 selects one player inside that rarity's pool weighted by `(poolMinMv / mv)^exponent` — cheap players likelier, premium exclusive to Legendary packs, prices re-deriving automatically from the new odds.

## Context
- **The algorithm (owner spec, exact order):** receive pack type → load eligible players (scope filter) → derive each player's rarity from OVR → roll a rarity from the pack's table → filter to that rarity's pool → weight by `(poolMinMv / mv)^exp` → normalize → draw one player → return player + opening info. Never select the player first; never mix the rarity roll and the MV weighting into one uncontrolled distribution; never leave the rolled rarity's pool.
- Current engine (`lib/features/packs/pack_engine.dart`): `_splitIntoTiers` partitions by MV floors, `_rollTier` rolls [low/mid/high] weights, `_drawFromTier` weight-draws by `1/economicValue^0.55` (shipped smoothing). The refactor maps this onto four OVR rarity pools (T-0058's `PackRarity` + `PackOddsConfig`), keeping the cached `_PoolDrawInfo` structure, the cumulative binary search and the single-player no-RNG-draw behavior.
- **Measured EV consequences (analysis 2026-11-08, global pool, exponent 1.5, margins 1.25/1.40):** RARE EV €3.14M econ 4,257 → price ~5,000; EPIC €6.89M econ 8,396 → ~10,000; LEGENDARY €20.24M econ 17,332 → ~24,000. EV ladder strictly increasing; premium's 2% adds only **+3.3%** to the legendary pack's EV (weighted premium E[MV] ≈ €109M) — the economy does not blow up. Prices re-derive automatically via `packPriceFor` (= EV × margin, floor to thousands) — no pricing code change needed.
- **This task reverses the T-0047 owner rule** ("a Legendary pack guarantees gold — weights [0,0,1]"): the new table gives the Legendary pack 55% EPIC / 43% LEGENDARY / 2% PREMIUM. That is the owner's explicit 2026-11-08 decision and supersedes it. `test/features/packs/legendary_regrade_audit_test.dart` asserts `legendarySub80 == 0` and `gold[legendary] == n` — it MUST be reworked to lock the new distribution instead (see requirement 6).
- **Empty-pool handling is real:** RM's legendary pool is 0 rows, GK's premium pool is 0 rows (position packs). Keep the engine's nearest-non-empty fallback (`_fallbackIndex`, extended to 4 bands) and keep booking fallback draws under the rolled rarity's share (existing tier behavior). The spec's "never select outside the pool" applies to non-empty pools; the fallback is the documented safe-empty answer.
- Determinism: unchanged discipline — the engine takes the injected `random`, tests use fixed seeds; no new RNG stream (the match engine's streams are untouched — this is the pack engine only).
- Adjacent in-flight tasks touch the same area but are independent: T-0050 (red reveal timeline, in review) and T-0051 (reveal ladder, todo) touch `pack_opening_screen_reveal.dart` — merge order only, no logical dependency.

## Requirements
1. `PackEngine.open` implements the exact two-stage sequence above: rarity roll from `PackOddsConfig`'s table for the scope's `PackTier`; pool = scope-filtered players whose `baseStats.overall` maps to the rolled `PackRarity`; within-pool weights from T-0058's `weightFor` with the config exponent; normalized draw. Per-(pool, scope) cache retained (build O(pool) once, draw O(log n)).
2. Stage-2 pool exclusivity: a rarity roll only ever selects from that rarity's pool — premium (90+) is reachable exclusively via the legendary pack's 2% premium roll (rare/epic tables are 0); a premium roll on a scope whose premium pool is empty falls back per the documented rule.
3. `oddsFor` returns per-rarity per-player probabilities (`P(rarity) × P(player | rarity)`), and the odds sheet in `lib/features/packs/packs_screen.dart` renders the four-band odds (any new label localized EN + AR via ARB, RTL-safe, no positional interpolation). `expectedPackValue` computes the two-stage EV so `packPriceFor` re-derives prices with no code change.
4. Invalid/missing market values cannot break the draw: mv ≤ 0 rows weight at the pool floor (T-0058 guard) and never produce NaN/Infinity/negative weights or a zero-weight total (assert or guard the normalization sum > 0).
5. Seeded tests (new `test/features/packs/two_stage_draw_test.dart`): fixed seed reproduces the exact same player sequence across two engines; distribution lock over ≥ 2,000 seeded opens per pack (legendary pack shares 55/43/2 within ±3 percentage points; rare pack 75/20/5; epic 40/50/10); premium exclusivity — zero premium pulls over ≥ 2,000 seeded rare AND epic opens; boundary integrity — no player outside his rarity's OVR band is ever drawn (70/80/90 edges over the same batches).
6. Edge cases (same test file): one-player rarity (deterministic draw, no RNG consumed for the stage-2 pick — the existing single-player contract); identical market values (uniform among them); extreme MV spread (10× within one rarity); an mv ≤ 0 row (draws safely at the floor weight); a scope with an empty rolled-rarity pool (RM-style: fallback draws, no crash, no null player); 10,000 consecutive opens with no exception and bounded memory (cache size ≤ the documented 32-entry cap).
7. Rework the directly-contradicted tests: `legendary_regrade_audit_test.dart` → locks the new legendary distribution + premium exclusivity (keep the population gold-share and shelf-survival assertions, they still hold); `test/features/packs/pack_tier_bands_test.dart` → bands re-derived from the rarity partition; `test/features/packs/packs_screen_test.dart` → store prices re-anchored to the re-derived bands (global ~5k/10k/24k, ±25% window). `CardRarity.values.length == 3` and the T-0049 pack-unchanged test (3 tiers, jewel accents, star counts) stay green UNMODIFIED.
8. No progression/save impact: packs still draw existing `BasePlayer`s (no attribute generation at opening), owned-player rows untouched.

## Out of Scope
- Economy calibration bands, the simulation/transparency probe, exponent tuning decisions, GDD §5 rewrite (T-0060).
- The reveal animation (T-0050/T-0051), rarity colors (T-0049), the OVR curve (T-0046).
- DB schema or store-behavior changes.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] New two-stage tests green (reproducibility, distribution locks, exclusivity, boundaries, all requirement-6 edge cases); full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified — any new odds-sheet label exists in both ARB files and renders correctly
- [ ] No performance or application-size regression (the per-(pool, scope) cache is retained; a 10,000-open soak stays fast and bounded)
- [ ] Same seed reproduces the same draw sequence (test-locked); premium appears ONLY from legendary packs (test-locked over ≥ 2,000 opens each)
- [ ] Legendary pack distribution 55/43/2 and the other tables' distributions band-locked by test
- [ ] Prices re-derive automatically with no pricing-code change (global bands documented in the test)
- [ ] `flutter test tool/simulation_report_test.dart` determinism PASS

## How to Verify
```bash
flutter analyze
flutter test test/features/packs/ test/features/collection/ test/core/ui/ test/core/domain/
flutter test tool/simulation_report_test.dart
flutter test
```
Expected: analyzer clean; packs/collection/ui/domain suites green including the reworked audit; determinism PASS; full suite green.

---
<!-- Everything below this line is filled in by agents, never by the task author. -->

## Developer Notes

**Summary of changes:** `PackEngine` now implements the owner's exact two-stage draw (T-0059): stage 1 rolls a rarity from `PackOddsConfig`'s table for the scope's `PackTier` (RARE 75/20/5/0, EPIC 40/50/10/0, LEGENDARY 0/55/43/2); stage 2 draws one player inside the rolled band's pool weighted by T-0058's `weightFor` `(poolMinMv / mv)^1.5`, via the retained per-(pool, scope, exponent) cache (≤ 32 entries, O(pool) build once, O(log n) binary-search draw, single-player bands consume no RNG). The MV-band machinery is gone: `tierWeights`/`tierBoundaries`/`absoluteTierFloorEur`/`_splitIntoTiers`/`tiersOf`/`PackTier.weights`/`PackScope.rollWeights` removed; `PackDraw.tier` and `PackOpenResult.tiers` now carry the ROLLED `PackRarity` index (0 rare < 70, 1 epic 70-79, 2 legendary 80-89, 3 premium 90+), fallback draws still booked under the rolled band (`_fallbackIndex` extended to 4 bands — RM's empty legendary pool and GK's empty premium pool covered). Normalization guard: a degenerate zero/non-finite weight total falls back to uniform instead of NaN rolls. `oddsFor` returns per-rarity per-player probabilities (`P(rarity) × P(player | rarity)`, sums to 1); `expectedPackValue` is the two-stage EV so `packPriceFor` re-derives prices with zero pricing-code change — measured ladder **rare 5,000 / epic 10,000 / legendary 24,000**, exactly the task's analysis. **T-0047's gold guarantee is reversed** per the owner's 2026-11-08 decision (legendary pack: 55% EPIC / 43% LEGENDARY / 2% PREMIUM, still zero sub-70). The odds sheet renders on every store cell (`packs_store_widgets.dart`, the packs screen's grid): one atomic localized chip per non-zero band (EN/AR ARB keys `packRarityRare/Epic/Legendary/Premium` — نادر/ملحمي/أسطوري/نخبة, matching the app's existing premium glossary), RTL-safe by construction (no sentence interpolation, `Wrap` layout). Premium is exclusive to Legendary packs (test-locked). `economy.config.packOddsSmoothing` is now inert (the stage-2 exponent lives in `PackOddsConfig.marketValueExponent`); the config field stays for save compatibility.

**Files changed:** `lib/features/packs/pack_engine.dart` (two-stage rewrite); `lib/features/packs/packs_store_widgets.dart` (odds sheet strip on cells + imports); `lib/features/collection/collection_results.dart` (tiers doc → rarity index); `lib/l10n/app_en.arb` + `app_ar.arb` + generated `app_localizations*.dart` (4 band labels); tests: NEW `test/features/packs/two_stage_draw_test.dart` (reproducibility, 2,000-open distribution locks ±3pp per table, premium exclusivity, band boundary integrity, all requirement-6 edge cases incl. the 10,000-open soak, oddsFor sum-1, EV ladder, EN/AR labels); `pack_engine_test.dart` (rewritten on OVR-banded pools: uniform/biased stage-1 configs, zero-exponent uniformity, band reachability, table-by-scope); `pack_tier_bands_test.dart` (rewritten: real-dataset band populations, per-tier 20,000-open band rates, price ladder 5k/10k/24k ±25%, boundary integrity over 5,000×2 opens, threshold bindings); `legendary_regrade_audit_test.dart` (test 3 reworked to the owner matrix + exclusivity; population share + shelf-survival kept unmodified); `test/balance/packs_and_generation_balance_test.dart` (band rates 75/20/5/0-40/50/10/0-0/55/43/2, exclusivity, z-score calibration unchanged and green, elite premise re-anchored to the partition, duplicate bound re-derived); `packs_screen_test.dart` (+2 odds-sheet widget tests EN fallback + Arabic locale). `CardRarity.values.length == 3` and the T-0049 pack-unchanged test passed UNMODIFIED.

**How I tested it:** `flutter analyze`: No issues found. `flutter test test/features/packs/ test/features/collection/ test/core/ui/ test/core/domain/`: **186 passed**. `flutter test tool/simulation_report_test.dart`: **PASS** (determinism — no new RNG stream, same injected-random discipline). `flutter test`: **817 passed**; after that one test-only addition (the price-ladder lock) went in and its suite reran green (7/7) — no production change between the two runs. Distribution locks print their shares; the duplicate-rate bound was re-derived analytically, not eyeballed: Σ Poisson P(count ≥ 2) over `oddsFor` probabilities = **17.2%** over 200 rare-pack pulls (Monte-Carlo 20% on seed 51), up from ~8% under the old flat roll because the two-stage engine concentrates probability (epic band: 20% over ~100 subsample players; legendary: 5% over ~23) — bound set to < 25%, flag for T-0060's economy calibration.

**Concerns / assumptions:** (1) The duplicate-rate jump (8% → ~17-20%) is the honest consequence of concentrating odds into smaller bands — the merge system absorbs it, but T-0060 should explicitly price it in (or flatten `marketValueExponent` further). (2) `PackOddsConfig.validate()` now runs in the `PackEngine` constructor (release-safe) — a bad table fails fast at construction instead of drawing garbage. (3) The odds sheet lives on the store cells in `packs_store_widgets.dart` (the packs screen's grid widget) rather than literally inside `packs_screen.dart` — the screen file only hosts the shell and flows; the requirement's intent (the store tab renders four-band odds, localized, RTL-safe) is met and widget-locked in both languages. (4) `PackEngine({tier})` keeps a default-tier parameter so tier-less legacy scopes still resolve; every production caller passes a scoped tier.

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
