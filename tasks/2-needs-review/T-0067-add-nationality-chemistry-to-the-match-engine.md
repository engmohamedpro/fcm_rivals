---
id: T-0067
title: Add nationality chemistry to the match engine
priority: high
status: needs-review
attempts: 1
depends_on: []
created: 2026-11-09
completed:
---

# T-0067: Add nationality chemistry to the match engine

## Goal
Teams whose starting players share nationalities get a chemistry bonus: every nationality group of n ≥ 2 on-pitch players adds (n − 1) percentage points, and the sum multiplies the team's attack, support, defence and goalkeeping totals (11 same-nationality players = +10%; 2 from Egypt + 4 from Brazil + 5 distinct = 1% + 3% = +4%).

## Context
- Owner spec (2026-11-09, verbatim examples): 2 players same nationality → +1% to team attack, defence, support and goalkeeping; 3 same → +2%; "and so on"; 11 same → +10%; groups add up (2 Egypt + 4 Brazil → 1% + 3% = 4%).
- The multiplier is **percentage of the totals** (multiplicative: `total × (1 + percent/100)`), not integer points — the engine totals are doubles.
- `BasePlayer.nationality` exists (`lib/core/domain/players.dart:120`) and the DB has it (`lib/core/database/app_database.dart`, `Players.nationality`), but `MatchPlayer` — the engine's player type (`lib/features/match/match_event.dart:90-139`) — does not carry it. Default it to `''` so every existing construction site and test fixture compiles unchanged.
- The integration point is `_TeamRuntime.computeTotals` (`lib/features/match/match_engine_runtime.dart:165-217`): the four totals are the role-weighted means of the on-pitch players, then multiplied by mentality → tactics → live actions → pep talk → home advantage. Chemistry is computed **from the players currently on the pitch**, so substitutions and red cards re-evaluate it automatically (computeTotals already runs on the live `onPitch` list each turn).
- Wiring sites that build `MatchPlayer` from owned cards / AI squads: `lib/features/season/season_store.dart:384` (`_userMatchPlayer` — `card.base.nationality` is in scope), `lib/features/season/season_store_opponent.dart:64,77` (AI opponents built from dataset rows — the rows carry nationality; synthetic fallback players get `''`), `lib/features/simulation/match_simulator.dart:154`.
- Zero-drift guarantee: existing engine/balance fixtures construct `MatchPlayer` without a nationality → default `''` → no group ever forms → chemistry is exactly 0% → `test/features/match/engine_snapshot_test.dart` and `test/balance/` must pass with NO snapshot regeneration.
- House style: pure logic files import no Flutter (`lib/core/domain/players.dart` header documents the pattern); chemistry is pure Dart.

## Requirements
1. New file `lib/features/match/chemistry.dart` (pure Dart, no Flutter imports): `int chemistryPercentOf(Iterable<String?> nationalities)` — skips `null` and `''`, groups equal strings, adds `max(0, n - 1)` per group of size n ≥ 2, clamps the sum to 0..10. Owner's examples become the doc-comment examples.
2. `MatchPlayer` gains `final String nationality;` with constructor default `''` (`lib/features/match/match_event.dart`); `clone()` carries it. No other field changes.
3. In `_TeamRuntime.computeTotals`, compute `final chem = chemistryPercentOf([for (final p in onPitch) p?.nationality]);` and multiply all four totals by `(1 + chem / 100)`, alongside the existing modifier chain (update the order comment at `match_engine_runtime.dart:161-164` to list chemistry as a step).
4. Wire nationality at every `MatchPlayer` construction site: `_userMatchPlayer` (`season_store.dart:384`) passes `card.base.nationality`; `match_simulator.dart:154` likewise; `season_store_opponent.dart` plumbs nationality from the dataset rows into the AI squad players (real players keep their nationality, synthetic players pass `''`) so AI teams earn chemistry fairly.
5. New `test/features/match/chemistry_test.dart`:
   - Unit tests of `chemistryPercentOf`: all-distinct → 0; a pair → 1; a triple → 2; the owner's 2 Egypt + 4 Brazil + 5 distinct → 4; eleven equal → 10; `''`/null entries never group; more than 11 entries still clamp to 10.
   - Seeded engine sweep: build two identical even-strength `MatchTeamInput`s, one with all `''` nationalities and one whose XI shares a nationality; simulate seeds 0..199 twice and assert the chemistry side's mean goals scored is strictly higher than in the no-chemistry run (fixed seeds → deterministic).
6. Zero-drift proof: `test/features/match/engine_snapshot_test.dart` and `test/balance/` pass unchanged with `REGEN_SNAPSHOT` unset (fixtures have no nationalities → 0%).

## Out of Scope
- Showing chemistry in the UI (T-0069) and measuring its balance impact (T-0068).
- Any change to engine constants, balance bands, ratings curves or the snapshot file.
- Bench chemistry — only the players on the pitch count (a sub coming on changes it, by construction).
- Nationality-based squad-building rules or filters.

## Acceptance Criteria
- [ ] `chemistryPercentOf` returns exactly the owner's numbers for the spec examples (0 / 1 / 2 / 4 / 10) and clamps at 10.
- [ ] The four engine totals scale by `(1 + chem/100)`; the seeded sweep test proves the boosted XI scores more on average across seeds 0..199.
- [ ] Substitutions/red cards re-evaluate chemistry (it is computed inside `computeTotals` from the live `onPitch` list — no cached per-match value).
- [ ] Existing engine, snapshot and balance tests pass unchanged with no regeneration — zero drift for nationality-less fixtures.
- [ ] `flutter analyze` reports zero warnings; `flutter test` full suite green.

## How to Verify
```bash
flutter analyze
flutter test test/features/match/chemistry_test.dart        # new suite green
flutter test test/features/match/engine_snapshot_test.dart  # green, NO REGEN_SNAPSHOT
flutter test test/balance/                                  # green, unchanged bands
flutter test                                                # full suite green
```
Expected: analyze clean; chemistry unit tests match the spec examples exactly; snapshot and balance suites untouched and green; full suite green.

---

## Developer Notes

- **Summary of changes:** New pure-Dart `lib/features/match/chemistry.dart` — `chemistryPercentOf(Iterable<String?>)` skips null/empty, groups equal strings, adds `max(0, n−1)` per group of n≥2, clamps to 0..10; the owner's verbatim examples are the doc comments. `MatchPlayer` gains `final String nationality` (constructor default `''`, carried by `clone()`). `_TeamRuntime.computeTotals` computes chemistry from the LIVE `onPitch` list each call and multiplies all four totals by `(1 + chem/100)` after home advantage (order comment now lists it as step 6) — substitutions and red cards re-evaluate it by construction. Wiring: `_userMatchPlayer` (forecast) and **`match_session._toMatchPlayer` (the LIVE user XI path — a construction site the task Context missed; without it chemistry would work only in forecasts, never in real matches)** pass `card.base.nationality`; `season_store_opponent.loadOpponent` looks nationalities up from the dataset Players table into a map (synthetic rows with null realPlayerId stay `''`); `AiSquadPlayer` gained an optional `nationality` (default `''`) so existing fixtures compile unchanged; `match_simulator` passes `nationality: ''` explicitly for its synthetic squads.
- **Files changed:** `lib/features/match/chemistry.dart` (new), `lib/features/match/match_event.dart`, `lib/features/match/match_engine.dart` (import), `lib/features/match/match_engine_runtime.dart`, `lib/features/match/match_session.dart`, `lib/features/season/season_store.dart`, `lib/features/season/season_store_opponent.dart`, `lib/features/season/season_ai_models.dart`, `lib/features/simulation/match_simulator.dart`, `test/features/match/chemistry_test.dart` (new), `tasks/…T-0067….md` (this file).
- **How I tested it:** `flutter analyze` → No issues found. `flutter test test/features/match/chemistry_test.dart` → **10/10**: unit level returns exactly the owner's numbers (0 / 1 / 2 / 4 / 10, clamp at 10, blank/null never group); engine level — two identical even-strength XIs, seeds 0..199 run twice: the +10% chemistry XI's mean goals strictly higher (deterministic seeds, no flake). Zero-drift: `test/features/match/engine_snapshot_test.dart` 1/1 and `test/balance/` 86/86 with `REGEN_SNAPSHOT` **never set** — nationality-less fixtures stay at exactly 0% and the committed snapshot/bands are untouched. Full `flutter test` → **877/877 green**.
- **Concerns / assumptions:** (1) I first implemented the opponent nationality via a drift LEFT JOIN, but `season_store_opponent.dart` is a `part of season_store.dart` whose drift import does not expose `JoinedRow`/typed result getters there — 15 analyze errors. Replaced with a plain `db.players` read into an `int→String` map (one extra query per opponent load, negligible; keeps the diff minimal and `_rowIdOf` untouched). (2) The map is built per `loadOpponent` call; if T-0068/T-0069 later need it hot, a cached dataset-level map is the follow-up — not done here to keep scope exact. (3) `AiSquadPlayer.nationality` is optional-with-default so `season_engine_test.dart`'s existing constructions compile unchanged (verified by full suite). (4) Chemistry multiplies goalkeeping too, exactly as the task's Requirement 1 wording ("multiplies the team's attack, support, defence and goalkeeping totals") and the owner's "+1% to team attack, defence, support and goalkeeping" require. (5) **Widget-fixture regression found and fixed:** `match_screen_test`'s dataset fixture gave all 60 players nationality 'Egypt', so once chemistry went live the user's XI genuinely earned +10% and the engineered defeat (opponent 95, seed 3) no longer ended in a defeat — the ad-boosted recovery card never appeared (2 failures: EN + AR recovery-card tests; same file 7/7 on clean HEAD). The feature is correct; the fixture was silently outcome-controlling. Fix: per-player distinct nationalities ('Country <id>') in that file's _rows only — the same chemistry-neutral philosophy the task applies to engine fixtures. No assertion was edited.

## Review Log
