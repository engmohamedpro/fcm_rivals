---
id: T-0107
title: Achievement progress derivation engine — achievements computed FROM game state, never tracked beside it
priority: high
status: todo
attempts: 0
depends_on: [T-0105]
created: 2026-11-10
completed:
---

# T-0107: Achievement progress derivation engine — achievements computed FROM game state, never tracked beside it

## Goal
Every achievement's progress is a PURE FUNCTION of the persisted game state (MatchResults, Seasons/LeagueTeams, Packs, OwnedPlayers, CoinTransactions, FacilityLevels): no parallel counters, no backfill jobs, no drift — achievements retroactively reflect reality the moment they are read, and a save migrated from before achievements existed shows correct progress immediately.

## Context
- The repo already derives standings and played-state from `MatchResults`/`Fixtures` rather than caching counters (`lib/features/season/season_store_standings.dart`); this task extends that philosophy to achievements. The failure mode it prevents: a "wins" counter that increments on match commit but forgets the replay path (T-0099's fixture replay refunds rewards — a naive counter double-counts or undercounts there), or forgets the 103 existing saves.
- Derivable metric inventory (verify exact column semantics while implementing — the tables are in `lib/core/database/app_database.dart`):
  - `matchesManaged`, `wins`, `draws`, `losses`: `MatchResults` rows where the user's club is home or away; goals attributed by side.
  - `longestWinStreak` / `longestUnbeatenStreak`: order the user's results by (seasonId, round) — a season-crossing streak CONTINUES (design decision: streaks are career-scoped, not season-scoped; document it in the code).
  - `goalsFor`, `goalsAgainst`, `cleanSheets`, `matchesScoredFirst`-style extras: from the same rows.
  - `titlesByDivision`, `promotions`, `seasonsCompleted`: `Seasons` where `userClubId`/`LeagueTeams.isUser` and `finalPosition`/`outcome` are set.
  - `packsOpened`: `Packs.opened` count (plus per-source splits: starting vs purchased vs reward — the `source` column exists).
  - `cardsOwned`, rarity-class counts, `highestUpgradeLevel`: `OwnedPlayers` where `status == 'owned'` (rarity via the dataset join, the same way `player_detail_sheet.dart`'s `rarityOf` does it).
  - `lifetimeCoinsEarned`, `coinsSpentOnPacks`, `coinsSpentOnUpgrades`, `upgradesCompleted`: `CoinTransactions` grouped by the `reason` strings the engines already write — enumerate the real reason values from `upgrade_engine.dart` / `pack_engine.dart` / `match_session.dart` / `season_store.dart` FIRST and encode them as typed constants (never raw strings scattered in queries).
  - `facilityLevelTotal`: `FacilityLevels`.
  - `joinedAt`: earliest `OwnedPlayers.acquiredAt` (or club creation timestamp if cleaner).
- Depth note (owner asked for "deep and full"): a metric that turns out NOT to be derivable (no persisted trace) is DROPPED from the catalog in a documented catalog edit — never faked with a counter, never guessed. List every such drop in Developer Notes.

## Requirements
1. `lib/features/achievements/achievement_progress.dart` — a `CareerMetrics` immutable model + a derivation API over `AppDatabase` (query-based; keep it one round-trip-friendly read per metric group, not N+1 per achievement). The catalog (T-0105) maps metric ids to these fields; a `progressFor(metricId)` lookup must never hit the DB per achievement.
2. Every metric above that is genuinely derivable; each one documented in-code with the exact table/column it derives from.
3. Ledger reason constants: one typed home for every `reason` string currently written by production code — the queries and (later) audits share it. If reasons are inconsistent/parametrized today, document the pattern and parse it robustly (e.g. `achievement:` prefix parsing is T-0108's, not here).
4. `test/features/achievements/progress_test.dart` — in-memory database fixtures exercising: empty save (all zeros, no crash); a synthetic career (mix of home/away wins, draws, losses; a replayed fixture counted ONCE; goals attributed correctly; streaks across a season boundary; a title at finalPosition 1 in two different divisions; packs split by source; owned/merged/sold player statuses; ledger rows per reason). Assert every metric. This fixture set is the shared foundation for T-0112's career stats — write it as reusable helpers under `test/features/achievements/`.
5. Retroactivity proof as a test: build the fixture save FIRST, then compute progress — no write-back, no migration, correct numbers.

## Out of Scope
- Claiming rewards (T-0108), UI (T-0110+), the Profile screen's own stats model (T-0112 composes this one).
- Any change to production write paths (no new columns, no hooks on match commit — that is the whole point).

## Acceptance Criteria
- [ ] Every catalog metric id resolves to a real derived value or is documented-and-dropped (no `// TODO` placeholders in the metric map).
- [ ] The derivation makes ZERO writes; the empty-save and synthetic-career fixtures pass with exact expected values.
- [ ] Ledger reason constants replace any raw reason strings the new queries would have used; `flutter analyze` zero warnings; full suite green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/achievements/
# Expected: green

flutter test
# Expected: full suite green
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
