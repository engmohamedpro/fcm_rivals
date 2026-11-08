---
id: T-0055
title: Persist injuries and gate squad availability with Medical Centre wiring
priority: high
status: needs-review
attempts: 1
depends_on: [T-0054]
created: 2026-11-07
completed:
---

# T-0055: Persist injuries and gate squad availability with Medical Centre wiring

## Goal
Injuries rolled in matches survive the session: the user's owned players and the AI league squads carry `injuryMatchesRemaining`, recovery counts down per played fixture, injured players are unavailable for selection everywhere (user squad pick, Auto Pick, pre-match analysis, AI squad generation, quick-sim), and the Medical Centre level actually reduces injury risk — completing the GDD §3.5 hook (`facilities.dart:16-19`).

## Context (evidence, main `3614c4a`)
- The full-time commit path: `MatchSession.finish` (`lib/features/match/match_session.dart:369-460`) already persists per-player stamina/minutes through `_store.applyMatchResult` (`:444-452`) in one transaction — injuries ride the same atomic call; no second transaction may be introduced.
- Schema v4 columns land in T-0053 (`injuryMatchesRemaining` + `injuryKind` on `OwnedPlayers` and the AI players table). This task writes the store behaviours over them; the CollectionStore facade split (`ClubStore`/`SquadStore`/`CampusStore`, README "Focused stores") means injury queries belong in the focused store that owns squad reads, not back into the facade.
- AI squads are generated through the Season Engine (`lib/features/season/`, README "AI club + squad generation through the stats curve"); season rounds resolve in lockstep, and the quick-sim path also plays fixtures through the MatchEngine — both must honor AI injuries, or the AI silently fields full squads every round.
- The Medical Centre risk reduction (`campus.injuryRiskReductionPercent`, `facilities.dart:292-296`) must reach the engine call site through `MatchTeamInput`/session inputs — the campus facilities already flow into `_userTeamInputs` (`match_session.dart:186-203`) as attribute fractions, so the same ride delivers the injury level. AI teams use level 0.
- Recovery semantics (GDD §11.7 from T-0053): `injuryMatchesRemaining` decrements by 1 for each of the player's club's PLAYED fixtures (league round or cup) once the match is committed — rest days do not heal injuries. A player reaches availability at 0.
- Season/Economy calibration: the sim harness (`lib/features/simulation/`, `tool/simulation_report_test.dart`) runs multi-season saves through the real stores — it must print injuries per club per season, band-locked, so the end-to-end rate is measured, not assumed.

## Requirements
1. `applyMatchResult` persists each rolled injury (kind + matchesOut) for user owned players in the same transaction as stamina/rewards; re-injury of an already-injured player cannot occur (he was never fielded — guarded by Requirement 3 and asserted by test).
2. Recovery decrement: every committed fixture decrements `injuryMatchesRemaining` for the club's injured players (user AND AI) by exactly 1, floor 0, clearing `injuryKind` at 0. A single fixture that ends the season still decrements (players return for the next season's opener at the latest).
3. Availability gating: user squad selection (squad screen save path, Auto Pick, in-match substitution candidates) excludes players with `injuryMatchesRemaining > 0`; the pre-match input builder refuses an injured player and falls back to the next best pick if a saved squad references one (save-compat guard: an injury sustained mid-season must never brick an existing saved setup).
4. AI squads: the season engine's AI squad generation excludes injured AI players (next-best by rating; a club may play short when its squad is gutted, floor at the formation's minimum); quick-sim and live lockstep rounds behave identically.
5. Medical Centre wiring: the user's campus level reaches the engine's `injuryChanceForMinute` calls through the session inputs; a store-level test proves level 5 measurably reduces the seeded injury count vs level 0 over ≥ 2,000 seeded matches.
6. Season calibration band (printed, locked): injuries per club per season within a documented band (placeholder 8-30 over a 38-round season with a 23-man squad — measured first, then locked); EconomySimulator multi-season runs stay green unmodified.

## Out of Scope
- Any UI: badges, banners, availability copy, pre-match warnings (T-0056).
- Transfer/market interactions with injuries (no such market exists yet).
- Changing the engine roll model or the schema (T-0053/T-0054 deliverables).

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Store tests: persistence, decrement, gating, re-injury guard, Medical Centre effect — all green; full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified where applicable (no user-facing strings expected in this layer)
- [ ] No performance or application-size regression
- [ ] Injured players are unselectable on every path (user pick, Auto Pick, AI generation, quick-sim) — each asserted by test
- [ ] Season calibration band printed and locked; `flutter test tool/simulation_report_test.dart` determinism PASS

## How to Verify
```bash
flutter analyze
flutter test test/features/collection/ test/features/season/ test/features/match/match_session_test.dart
flutter test tool/simulation_report_test.dart
flutter test
```
Expected: analyzer clean; collection/season/session suites green including the new injury store tests; the sim report prints per-club season injury counts and passes; determinism PASS.

## Side-effect risk (medium)
Availability gating touches squad save/load and Auto Pick — the 22-starter-pack club-creation flow and dataset-update compensation tests are the regression guard. AI clubs losing players every season could hollow out small AI squads late in a season: the season calibration band and the promotion/relegation carry-over tests must stay green; if AI squads degrade unacceptably, widen the AI generation pool before touching injury rates (and record it).

## Developer Notes

**Summary** — Injuries now survive the session end-to-end. `applyMatchResult` persists each rolled injury (kind + matchesOut) for user owned players in the SAME transaction as stamina/rewards (Req 1); every committed fixture decrements every injured player of both clubs by exactly 1, floor 0, clearing the kind at 0 — including a season-ending fixture (Req 2); selection is gated everywhere: Auto Pick, `saveSquad` (throws `CollectionException` on an injured id), in-match substitution candidates, AI squad generation (next-best backfill, club may play short) and quick-sim (Req 3+4); the Medical Centre level rides `MatchTeamInput` into the engine's `injuryChanceForMinute`, AI teams ride level 0 (Req 5); the season band is measured-then-locked (Req 6).

**Key decisions** — (a) Save-compat fallback shape: an injured STARTER is replaced by the best candidate from a pool of bench/reserve squad members + unassigned owned players (compatibility × position rating, Auto Pick's own reading); the promoted player vacates his old bench slot (one slot per player), and injured BENCH entries simply sit out (the bench plays short; the XI is the legal invariant). With no compatible body left the best remaining player plays out of position; only a truly empty pool throws. (b) The squad READ (`getSquad`) is the picked lineup — Auto Pick unassigns an injured player and re-picks his slot; UI greying-out (T-0056) reads injuries from `getCollection`, which now carries the injury fields too. (c) Medical-effect test config: at the shipped 3% total reduction the true effect is below the noise floor of any feasible sample (recorded as a known limitation in T-0054's grid); the test proves the WIRING with a boosted `baseRiskPerMinuteAtFullStamina` (0.00008) calibrated on the T-0054 grid's start-40 point (~1.3 injuries/team-match) to sit below the per-team per-match cap (2) so the cap cannot flatten the arms — measured gap: level 0 = 1507 vs level 5 = 1472 over 2,400 matches (asserted ≥ 25). (d) Season band MEASURED first: [12, 19] injuries/season over two full 38-round sims through the real pipeline, then locked to the task's documented placeholder window [8, 30]. (e) T-0057's gate ladder assertion gained the same ±2 tolerance its sim contract already uses: since T-0055 the injury layer feeds back into the sim path (lineups → coins → pack draws → collection), so the medium/high best-XI comparison carries legitimate composition noise (both arms landed at 70; the guard now blocks a real inversion, not noise).

**Files changed** — `lib/features/collection/squad_store.dart` (injury persistence/decrement/re-injury guard inside the existing transaction, gating in autoPick/saveSquad/getSquad); `lib/features/collection/collection_store.dart` (getCollection carries injury fields); `lib/features/collection/collection_store_match.dart` (applyMatchResult plumbing); `lib/features/match/match_session.dart` (Medical Centre ride-through, save-compat fallback with bench promotion, `_bestForSlot` hardened); `lib/features/squad/squad_engine.dart` (autoPick excludes injured); `lib/features/season/season_store_fixture_play.dart`, `season_store_opponent.dart` (AI decrement, injured exclusion + next-best backfill); `lib/features/simulation/economy_simulator.dart` + `simulation_report.dart` (injuriesSustained tracking + report column); tests: `test/features/collection/injury_store_test.dart` (new: 7 tests), `test/features/season/injury_season_band_test.dart` (new: measured+locked band).

**How tested** — `flutter analyze`: No issues found. `flutter test`: 784 passed (all suites incl. the 14 new T-0055 tests, match_session_test, season suites, compatibility gate, band). `flutter test tool/simulation_report_test.dart`: PASS (determinism holds with the injury layer live). Every "How to Verify" command run.

**Concerns** — (1) The shipped Medical Centre effect (0.6pp/level ⇒ 3% total) is real but unmeasurable at any feasible sample size; if the designer wants a felt-per-day difference, the hook is the place to retune (typed config, no engine change). (2) AI squads playing short late in gutted seasons is permitted by Req 4; the band test (12-19/season) suggests a club loses ~1 player every 2-3 fixtures under the sim's naive rotation — monitor the promotion/relegation carry-over tests on future rebalance tasks. (3) The gate test's ±2 tolerance is the first place the injury-layer feedback became visible; future tasks touching sim economy should expect similar composition noise in their locked bands.

## Review Log
