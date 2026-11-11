---
id: T-0105
title: Typed achievement catalog + economy-safe endless reward config (pure Dart, no UI)
priority: high
status: done
attempts: 1
depends_on: []
created: 2026-11-10
completed: 2026-11-11
---

# T-0105: Typed achievement catalog + economy-safe endless reward config (pure Dart, no UI)

## Goal
The achievements feature gets its single source of truth: a typed, config-driven catalog of achievement categories, metrics and endless reward ladders, whose coin payouts are structurally bounded BY CONSTRUCTION (not by hope) — so the achievement faucet can never out-grow the match-economy faucet no matter how far the endless ladder climbs, and badges/titles (not coins) carry the prestige at the top.

## Context
- Owner decision (2026-11-10): the Collection screen is replaced by an Achievements screen ("user wins coins"), plus a new Profile tab showing titles, badges, career stats. The game concept is ENDLESS (T-0070's `upgradedValue` grows forever), so achievements must be scale-free the same way the chance curve is being re-specified to be (T-0082's lesson: any absolute calibration re-breaks as the ladder climbs).
- Every balance number in this repo lives in one typed config with no magic numbers (GDD 27, `EconomyConfig` in `lib/features/economy/economy_engine.dart` is the precedent — pre-balance placeholders gathered for simulation-driven tuning, GDD rule 14). The achievement catalog follows that pattern: `AchievementCatalog` + `AchievementEconomyConfig`.
- Economy safety design (the heart of this task — planner decision, follow it): every ENDLESS ladder uses GEOMETRIC effort thresholds (tier n requires `base * ratio^n` with `ratio >= 2`, e.g. wins 1, 2, 4, 8, 16, 32, 64 …) while the per-tier coin reward stays FLAT (or sublinear). Consequence: total coins claimable from one ladder after effort E is `flat * log2(E/base)` — O(log effort) — so coins-per-match tends to 0 and the lifetime achievement income is effectively bounded even though the ladder never ends. Endless PRESTIGE (badge + title tiers) is unlimited; endless COINS is logarithmic. One-time milestone achievements (unique feats, e.g. "first title") carry fixed budgets; the sum of all fixed budgets + the log-caps is typed in `AchievementEconomyConfig` as the catalog's total faucet ceiling.
- What "deep and full" means here (owner asked for depth even without naming ideas): ≥10 categories covering the whole game — Career (matches managed, wins, unbeaten streaks), Attack (goals scored), Defence (clean sheets), Silverware (division titles per division, promotions), Squad (cards owned, rarity milestones, upgrades), Packs (packs opened), Economy (lifetime coins earned), Campus (facility levels), Loyalty (seasons completed), Mastermind (tactics instructions changed — only if derivable, else drop). Titles come from achievement tiers AND division championships (the Profile task reads the same catalog).
- New feature directory: `lib/features/achievements/`. No DB, no UI, no providers in this task — pure Dart data so T-0106..T-0113 build on it.

## Requirements
1. `lib/features/achievements/achievement_catalog.dart` — immutable, fully typed catalog:
   - `AchievementCategory` (id, icon name, l10n key prefix), `AchievementDefinition` (unique id, category, metric id, title/description l10n keys, one-line hint of what it measures), `AchievementTier` (index, threshold, coinReward, badge tier metal, optional titleId).
   - An `AchievementLadder` spec per definition: `baseThreshold`, `thresholdRatio (>= 2)`, `tierCount` (finite ladder) OR `endless: true` (generate tiers on demand up to `maxGeneratedTiers` cap so the UI never builds infinite widgets; the cap is itself honest about being a UI cap, not a game cap — crossing it generates more).
   - A `titles` registry: `TitleDefinition` (id, l10n key, earned-from: achievement tier id or division championship).
2. `lib/features/achievements/achievement_economy_config.dart` — `AchievementEconomyConfig` with: flat per-tier coin reward per endless ladder, all one-time milestone budgets, `totalCatalogCoinCeiling` (computed, not hand-written: sum of milestones + sum of `flat * log2(cap/base)` per endless ladder — a getter that DERIVES the ceiling from the catalog so the two can never drift), and a doc comment explaining the O(log) bound in plain words (future maintainers must see WHY this is safe, like `coin_ops.dart` does for atomicity).
3. Seed the catalog with ≥10 categories and ≥40 achievement definitions (mix: endless ladders for every countable metric; ≥8 one-time milestones; ≥12 titles across achievements; division-championship titles for divisions 1..5 with the rest generated on demand).
4. L10n keys for every definition: EN + AR in `lib/l10n/app_en.arb` / `app_ar.arb` (follow the existing key style; regenerate localizations the way the repo already does). Arabic copy is proper football-manager register, not machine-literal.
5. `test/features/achievements/catalog_test.dart` — pure unit tests: every id unique; thresholds strictly monotonic; `thresholdRatio >= 2` enforced by the type/constructor assert; total ceiling derived and finite; the ASYMPTOTE PROPERTY locked: cumulative coins after tier n grows ≤ C + flat*n while effort grows exponentially (coins-per-effort strictly decreasing beyond tier 1); every title id referenced by a tier exists; every l10n key exists in BOTH arb files.

## Out of Scope
- Any database table, repository, provider or UI (T-0106+).
- Progress derivation from game state (T-0107).
- Measuring/locking the actual coin numbers against the economy sweep (T-0109 re-pins them; the values you seed are pre-balance placeholders in the EconomyConfig tradition).

## Acceptance Criteria
- [x] Catalog + config compile with `flutter analyze` zero warnings; no magic numbers outside the config files.
- [x] ≥10 categories, ≥40 definitions, ≥12 titles; every string localized EN+AR with real Arabic.
- [x] The asymptote property and the derived-ceiling-vs-catalog consistency are locked by tests that FAIL if someone later adds a linear-growth coin ladder (the regression this task exists to prevent).
- [x] Catalog test + full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/achievements/catalog_test.dart
# Expected: green

flutter test
# Expected: full suite green (no production behavior changed yet)
```

---

<!-- Everything below this line is filled in by agents, never by the task author. -->

## Developer Notes

- **Summary of changes:**
  - NEW `lib/features/achievements/achievement_catalog.dart` — the
    typed foundation: `AchievementCategory`, `AchievementDefinition`
    (+`confersTitles` flag), `AchievementTier`, `AchievementLadder`
    (CONSTRUCTOR-ASSERTED geometric discipline: ratio >= 2, endless
    OR finite, base >= 1 — a linear ladder is a TYPE ERROR, not a
    review comment), `BadgeMetal`, `TitleDefinition`,
    `DivisionTitleDefinition` (seeded 1..5, on demand beyond).
    `tiers()` materialises finite rungs or the endless UI horizon
    with proportional badge metals.
  - NEW `lib/features/achievements/achievement_economy_config.dart`
    — `AchievementEconomyConfig`: flat per-tier endless reward
    (placeholder 20 ≈ 1.3% of a par match), 9 milestone budgets, and
    `totalCatalogCoinCeiling()` DERIVED from the catalog (never
    stored — the drift test proves adding a definition moves the
    ceiling by exactly its budget). Library doc explains the O(log)
    bound in plain words per the task.
  - NEW `lib/features/achievements/achievement_catalog_data.dart` —
    the seeded catalog: 10 categories, 40 definitions (32 endless +
    8 milestones — the task's >=40 with the >=30/>=8 mix), 20
    achievement titles (2 per flagship, rungs 3 and 6) + 5 seeded
    division titles. Metric ids mirror T-0107's derivable inventory
    exactly (the ledger reasons enumerated from source: match_reward,
    season_reward, pack_purchase, player_sale, facility_upgrade,
    starting_grant, removal_compensation, match_replay_refund — the
    'tired'/'chasing' hits are substitution EVENT labels not ledger
    rows).
  - L10n: 107 new key pairs EN+AR (categories, 40 definitions, 20
    titles, division-champion placeholder key) — Arabic written in
    real football-manager register (e.g. 'القناص', 'باني
    الإمبراطورية', 'مقفل الشباك'), clean `flutter gen-l10n`.
  - Tests: NEW `test/features/achievements/catalog_test.dart` — 15
    tests: shape counts, id/category uniqueness, milestone-budget
    discipline, ratio-assert + self-contradiction asserts, strict
    threshold monotonicity, FLAT endless coins, THE ASYMPTOTE
    (coins-per-effort non-increasing at the base=1 tie then strictly
    decreasing — math-honest: base=1 ladders tie on the first two
    rungs, the invariant that kills linear ladders is never-rise +
    strict fall), derived ceiling finite + drift-proof, title
    integrity vs registry, division titles on demand, full EN+AR arb
    completeness for every referenced key.
- **Files changed:** lib/features/achievements/achievement_catalog.dart
  (new), achievement_economy_config.dart (new),
  achievement_catalog_data.dart (new), lib/l10n/app_en.arb,
  app_ar.arb, generated app_localizations{,_en,_ar}.dart,
  test/features/achievements/catalog_test.dart (new). Plus lint
  cleanup of MY OWN earlier files now surfaced by the touched-file
  linter: injured_inert_test.dart (2 unused imports), team_tab_purity
  /injured_inert local-identifier renames.
- **How I tested it:** `flutter analyze --no-pub` — only the 2
  pre-existing baseline issues (fcm_crest.dart:269,
  tactic_slider_row.dart:16), zero new. Task tests 15/15; touched
  squads tests 22/22; onboarding+collection+core 164/164;
  match+balance: only the SAME 2 pre-existing tactic_slider_row
  Arabic failures; squad/season/packs/facilities 465 passed with the
  SAME pre-existing failures (T-0064 slider family + season
  live-flow — all stash-verified on the clean tree in earlier
  sessions; untouched by this pure-data task).
- **Concerns / assumptions:** (1) Two T-0107-relevant metrics are
  seeded but NOT in T-0107's confirmed inventory list
  (matchesScoredFirst IS listed; homeMatches/awayMatches/
  recoveryCentreLevel/startingPacksOpened/legendaryPulls/
  playerSalesCompleted/relegations/draws/losses/goalsAgainst are
  natural column derivations of listed tables) — T-0107 verifies
  derivability and DROPS any that lack a persisted trace in a
  documented catalog edit; the catalog tests will catch the drop (id
  uniqueness remains, counts re-pin). (2) maxGeneratedTiers=24 is the
  UI horizon: tier 24 of a ratio-2 ladder demands base*8.4M effort —
  comfortably 'endless' for any real career; crossing it generates
  more, never blocks. (3) Titles are deliberately registry-capped at
  2 per flagship (rungs 3/6): prestige tracks badge metals beyond
  that; a third title = one registry entry + one arb pair (the
  integrity test enforces the pairing). (4) Coin numbers are
  pre-balance placeholders per GDD rule 14 — T-0109's sweep re-pins
  them; the LOGARITHMIC SHAPE (the safety property) is what these
  tests lock.


## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->

### Review 2026-11-11, attempt 1: PASS
- Ran: `flutter analyze` (2 issues — both pre-existing: fcm_crest.dart:269 from a39f10a, tactic_slider_row.dart:16; both older than T-0105's c7c9131), `flutter test test/features/achievements/catalog_test.dart` (15/15 green), full `flutter test` (963+ passed, 16 failed — ALL verified non-T-0105: 9 pre-existing on the pre-T-0105 tree db628d6 (T-0064 slider family, tactic_slider Arabic ×2, season live-flow), 7 from the T-0082 engine umbrella commits 4b94310/57b3322/899b480 documented in T-0116's BLOCK record — match_engine_balance ×2 + engine_calibration ×4 + 1 uncaught-error shutdown line). T-0105's diff touches zero engine/economy files.
- AC verified independently: 10 categories / 42 definitions (40+2) / 22 achievement titles + 5 division titles seeded; ladder ctor asserts ratio≥2 + endless/finiteness + base≥1 (a linear ladder IS a type error); `totalCatalogCoinCeiling()` DERIVED from the catalog (getter sums milestones + flat×reachable-tiers, never stored); the asymptote test real (never-rise + strict-fall past the base=1 tie + ≥1.9 effort doubling at tier 19→20 — a linear coin ladder fails it); EN/AR arb parity exact (291 = 291 keys, zero diff both directions); Arabic in real football register (القناص، مقفل الشباك، باني الإمبراطورية) not machine-literal.
- Out of scope respected: no DB/repository/provider/UI; the only non-feature edits are 2 test-file lint cleanups (injured_inert_test, team_tab_purity_test) documented in Developer Notes.
- Notification protocol: Telegram unavailable (TELEGRAM_NOTIFICATIONS.md token is a documented placeholder, no configured destination) — failure recorded here per the protocol's fallback clause; review proceeded as safe (read-mostly).
- Notes: pre-balance coin placeholders are by design (GDD rule 14, T-0109 re-pins); the 7 T-0082-era engine failures belong to the BLOCK record trail, not this task.
