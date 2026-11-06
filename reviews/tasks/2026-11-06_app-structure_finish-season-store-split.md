# App structure: finish the SeasonStore split below the 800-line convention

- Feature: app-structure
- Type: Refactor
- Priority: Minor
- Created: 2026-11-06
- Status: DONE
- Completed on: 2026-11-06

## Context
Correction follow-up of `2026-11-05_app-structure_split-season-models` (SPLIT 2026-11-06: implementation verified good, but its acceptance criterion "every resulting file ≤800 lines" is unmet — `season_store.dart` still measures 1,167 lines). This task finishes the split to the README's ~800-line convention (README.md:72-74).

## Investigation & Evidence
- Investigation: the data-class extraction landed (`season_models.dart`, 102 lines) but `season_store.dart` remains at 1,167 lines (measured 2026-11-06; 1,257 before the split) — class-level extraction is exhausted, the file now holds a single `SeasonStore` class (declared at :35) whose method families carry the bulk.
- Root cause / technical justification: the season store concentrates fixture resolution/play, quick simulation, standings, history and rewards logic in one class; only method-family extraction remains.
- Affected files/components: `lib/features/season/season_store.dart`
- Evidence: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` lists the file on main at d0fbb88.
- Expected benefit / necessity: makes the README convention real; measurable target — every resulting file ≤800 lines.
- Dependencies / side effects: the proven pattern is the engine split's (`5447a67`): cohesive method families moved verbatim into private part files or helper libraries with `season_store.dart` as the importing barrel, so every existing `import 'season_store.dart'` keeps resolving; season suites and the simulation harness are the regression net.

## Reproduction Steps
Not applicable.

## Task
- [x] Extract cohesive SeasonStore method families below the 800-line budget | Where: `lib/features/season/season_store.dart` (1,167 lines on 2026-11-06) | Expected: `season_store.dart` and every new file ≤800 lines (candidates per README's module table: fixture play/quick simulation, standings/history, rewards); pure relocation, no behaviour change — season suites and `flutter test tool/simulation_report_test.dart` green with zero test edits, determinism PASS.

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated; full `flutter test` suite passes
- [x] EN/AR localization complete and RTL verified where applicable
- [x] No performance or application-size regression
- [x] Every resulting file ≤800 lines (excluding generated `*.g.dart`)
- [x] Season suites and `flutter test tool/simulation_report_test.dart` green with zero test edits, determinism PASS

## Developer Notes
Implemented 2026-11-06. Engine-split pattern (`5447a67`): part files with `season_store.dart` as the importing barrel, moved blocks byte-identical (machine-asserted against the HEAD blob before writing; the facade's whole diff is the three `part` lines plus a trailing-newline fix at EOF). Moved method families, matching the task's candidate list:

- `season_store_opponent.dart` (NEW, 122 lines): persisted AI-opponent squad loading + AI stamina persistence (`loadOpponent`, `_rowIdOf`, `_persistAiStamina`) — `extension SeasonOpponentOps`.
- `season_store_fixture_play.dart` (NEW, 321 lines): live-session play, result commit, replay rewind, and quick simulation of remaining/round AI fixtures (`startNextFixture`, `commitFixtureResult`, `rewindFixtureForReplay`, `simulateRemainingFixtures`, `simulateAIFixturesThroughCurrentRound`, `_simulateAiFixture`, `_insertResult`) — `extension SeasonFixturePlayOps` (fixture play + quick simulation share `_insertResult`/`_simulateAiFixture`, so they form one cohesive unit).
- `season_store_standings.dart` (NEW, 316 lines): standings, match history, season completion with rewards, next-season rollover (`getStandings`, `getMatchHistory`, `completeSeason`, `startNextSeason`) — `extension SeasonStandingsOps`.
- `season_store.dart`: 1,167 → **442 lines**.

Deliberately kept in the class (documented deviation, keeps the move 100% verbatim): `loadPreMatchData` and its static helpers `_overallOf`/`_userMatchPlayer` — extensions cannot declare static members, so moving them would have forced body edits (qualified references); the lookup privates (`_realPlayerPool`, `_userOwnedPlayerIds`, `_userClub`, `_resultsFor`, `_mentalityOf`) stay near `startSeason` which is their only user apart from the moved families.

Scope note: extensions are public-named because these members are the store's public API. Every consumer already imports `season_store.dart` directly (verified per file: `providers.dart`, `economy_simulator.dart`, `season_screen.dart`, and all seven season/ads/simulation test files), so extension members resolve at every existing call site with zero consumer edits — extension scope does not propagate through re-imports, which is why the direct-import audit was required. No behaviour, schema, transaction, or localization change (relocation only); no test edits.

Exact commands and results (2026-11-06, Flutter 3.47.9 stable / Dart 3.13.7, base `f41f148`):
- `flutter analyze` → `No issues found! (ran in 2.0s)` — zero analyzer warnings.
- `flutter test test/features/season test/features/simulation tool/simulation_report_test.dart test/features/ads` → `+97: All tests passed!` with zero test edits.
- Determinism: harness test green and regenerated `simulation_report.md` (gitignored) shows `Same seed + same command sequence replays identically: PASS` and `Minute-60 tactic change alters only future events: PASS`.
- Full suite: `flutter test` → `+709: All tests passed!` exit 0, dated 2026-11-06 (~5m26s wall), zero failures.
- Line budget: facade 442 ≤ 800; new files 122 / 321 / 316 ≤ 800; `find lib … awk '$1>800'` no longer lists anything in `lib/features/season/season_store*.dart`.

## Reviewer Verification
<Reviewer records verification date, tested commit hash, checks performed, results, and remaining limitations. Do not add personal names.>

## Links
- Depends on: None
- Follows: `2026-11-05_app-structure_split-season-models`
- Follow-up: None

## Amendments
<Reviewer-owned, append-only. Add dated entries correcting the task's target or mechanism; never rewrite the original task text.>
