# AI substitutions never fire (dead code)
- Feature: match-engine
- Type: Bug
- Priority: Critical
- Reviewer: Coach Hady
- Created: 2026-11-04
- Status: OPEN
- Completed by: -
- Completed on: -

## Context
AI substitutions never happen: 0.0/match across 9,200 simulated matches. The threshold `minute >= 70 ? 30 : 40` is unreachable with `baseDrainPerMinute = 0.30` — starters sit at ~79 stamina at 70' and ~73 at full time (measured average 70.3), so `stamina < 30/40` never triggers. The AI cannot manage fatigue or chase a game; every match is 11 v 11 for 90+ minutes.

## Tasks
- [ ] Task 1: Make the thresholds intersect the real stamina curve: start with `< 80` from 65' and `< 72` from 80' and tune with the harness, plus one chasing-game substitution (defender off, attacker on) for a team trailing after 70' | Where: `lib/features/match/match_engine.dart:1344-1349` (minute gate + threshold), drain context `lib/features/match/stamina.dart:14` | Expected: 2.0–4.0 AI subs/match averaged over ≥500 seeded matches with 5-man benches; never more than `config.maxSubstitutions` (5, `lib/features/match/match_engine.dart:225`); user-team substitution logic untouched.
- [ ] Task 2: Verify substitution side effects: on-pitch runtime swapped, subbed-off player stops accruing stats, subbed-on player appears in lineups and the match report, no crash with an empty bench | Where: `lib/features/match/match_engine.dart:1290` (hook), `lib/features/match/match_report.dart` | Expected: each sub produces a `MatchEventType.substitution` entry reflected in the report; the empty-bench early return (`:1343`) stays safe; sub starters enter with realistic stamina (~95–100).
- [ ] Task 3: Lock with a test asserting average AI subs ≥ 2.0/match | Where: `test/features/match/` (new or extended) | Expected: green on CI, seeded and deterministic.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] 2.0–4.0 AI subs/match in a ≥500-match seeded run, never > 5 per team
- [ ] Match report/lineups reflect substitutions; no soft-lock with an empty bench

## Developer Notes
<Implementation notes, rejected points with reason.>

## Reviewer Verification
<Filled by reviewer before setting CLOSED.>
