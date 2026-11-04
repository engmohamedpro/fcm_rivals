# Tactics Phase 0 — Remove Playing Styles, Introduce Custom Tactics Framework
- Feature: tactics
- Type: Refactor
- Priority: Critical
- Reviewer: Coach Hady
- Created: 2026-11-04
- Status: OPEN
- Completed by: -
- Completed on: -

## Context
Product decision: the ten preset Playing Styles are removed and replaced by user-built custom tactics grouped into In Possession / Out of Possession / Transitions. Those three groups ship in phases 1–3 (separate review files, same date); this file is the shared foundation and MUST land first. Phase 0 is a pure refactor: the default `TeamTactics` must reproduce today's `PlayingStyle.balanced` behavior exactly (all-1.00 multipliers), so gameplay is unchanged until phases 1–3.

Legacy knowledge is not lost — each removed style is rebuilt as a combination in a later phase. Do NOT re-add preset style chips; the mapping is documentation only:

| Legacy style | Rebuilt by (phase) |
|---|---|
| Possession / Tiki-Taka | In Possession: Play Out + Slow + Narrow (phase 1) |
| Direct Play / Long Ball | In Possession: Long Ball + Fast (phase 1) |
| Wing Play | In Possession: Wide + Early Crosses (phase 1) |
| Gegenpressing / High Press | Out of Possession: High Press (phase 2) + Transitions: Counter-Press (phase 3) |
| Low Block | Out of Possession: Deep Line + Low Press (phase 2) |
| Counter Attack | Transitions: Fast Counter (phase 3) |

## Tasks
- [ ] Task 1: Create the `TeamTactics` value model | Where: `lib/features/match/tactics.dart` | Expected: a `TeamTactics` class composing three value classes `InPossessionTactics`, `OutOfPossessionTactics`, `TransitionTactics`. Every field has a default that produces an identity modifier bundle (attack 1.00, defence 1.00, possession 1.00, chance 1.00, stamina 1.00, passAccuracy 1.00). Expose a computed `StyleModifiers`-equivalent bundle the engine can consume at the same hook points, plus a human-visible `effectSummary` (GDD 10.3: effects must be visible). Placeholder values follow GDD rule 14. Phases 1–3 only add fields to the three sub-classes.
- [ ] Task 2: Delete `PlayingStyle` + `StyleModifiers` and migrate every call site | Where: `lib/features/match/tactics.dart:24-204`, `lib/features/match/match_engine.dart:169-181`, `:330-343`, `:551-555`, `:655-669`, `:690`, `:773`, `:791`, `:1332-1334`, `:1380-1386`; `lib/features/match/match_session.dart:101,144-146,210-212`; `lib/features/match/match_forecast.dart:89,130`; `lib/features/match/pre_match_screen.dart:92,100,787-790`; `lib/features/match/live_tactics_screen.dart:65`; plus `squad_engine`, `season_engine`, `simulation/match_simulator` and all test files found by `grep -rn "PlayingStyle" lib/ test/` | Expected: `grep -rn "PlayingStyle\|StyleModifiers" lib/ test/` returns zero matches. `ChangeStyleCommand` becomes `ChangeTacticsCommand(TeamTactics)`; engine possession competition, pass accuracy, chance creation and stamina sites read the computed bundle from `TeamTactics` instead of `style.modifiers`. Behavior with defaults is bit-identical to today's Balanced (same seeds → same results).
- [ ] Task 3: Database migration for the persisted style | Where: `lib/core/database/app_database.dart:60` (`playingStyle` column), `lib/features/collection/squad_store.dart:118-131` | Expected: schema version bump replacing the `playingStyle` text column with a `tactics` JSON column. Loader maps any legacy value (all 10 old style names) to `TeamTactics()` defaults. Add a migration test that loads a save fixture containing each legacy style name and asserts the squad loads with default tactics and no exceptions.
- [ ] Task 4: Replace the style pickers with a three-section tactics UI scaffold | Where: `lib/features/match/pre_match_screen.dart:787-790`, `lib/features/match/live_tactics_screen.dart` | Expected: the pre-match and live tactics screens show three sections/tabs — In Possession, Out of Possession, Transitions — bound to `TeamTactics`. In phase 0 each section renders its default state only (controls arrive in phases 1–3). Mentality slider, Live Match Actions and pep talks stay untouched. Section headers localized EN + AR (`lib/l10n/app_en.arb`, `app_ar.arb`) — note the old style display names were never localized; the new labels must be.
- [ ] Task 5: Migrate the §34 balance harness | Where: `test/balance/match_engine_balance_test.dart` (tactics-matrix section) | Expected: the per-style matrix is replaced by a default-vs-default baseline: 10,000 seeded sims, even-strength squads, win rate 49–51%, total goals per match 2.6–2.9, draws 22–30%. Determinism and prefix-invariant guards still pass. This pins the refactor to zero drift; phases 1–3 extend this harness with per-instruction matrices.
- [ ] Task 6: Update the GDD | Where: `docs/fcm_rivals_GDD_SRS.md:516-537` (section 10.2 Playing Styles) | Expected: section rewritten as "10.2 Custom Tactics" documenting the three groups, the instruction fields that phases 1–3 will fill in, the legacy mapping table above, and the rule that every instruction's effect summary is user-visible.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] `grep -rn "PlayingStyle" lib/ test/` returns nothing
- [ ] Same-seed matches are identical before/after the refactor (engine snapshot test)
- [ ] Legacy save with any of the 10 old style names loads with default tactics
- [ ] Default-vs-default baseline: win rate 49–51%, goals 2.6–2.9/match, draws 22–30% over 10k seeded sims

## Developer Notes
<Implementation notes, rejected points with reason.>

## Reviewer Verification
<Filled by reviewer before setting CLOSED.>
