---
id: T-0105
title: Typed achievement catalog + economy-safe endless reward config (pure Dart, no UI)
priority: high
status: todo
attempts: 0
depends_on: []
created: 2026-11-10
completed:
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
- [ ] Catalog + config compile with `flutter analyze` zero warnings; no magic numbers outside the config files.
- [ ] ≥10 categories, ≥40 definitions, ≥12 titles; every string localized EN+AR with real Arabic.
- [ ] The asymptote property and the derived-ceiling-vs-catalog consistency are locked by tests that FAIL if someone later adds a linear-growth coin ladder (the regression this task exists to prevent).
- [ ] Catalog test + full `flutter test` green.

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
<!-- Developer agent fills this in before moving the file to 2-needs-review. -->

- **Summary of changes:**
- **Files changed:**
- **How I tested it:**
- **Concerns / assumptions:**


## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
