# Match report: pass completion 15.6%, GK invisible
- Feature: match-report
- Type: Bug
- Priority: Critical
- Reviewer: Coach Hady
- Created: 2026-11-04
- Status: OPEN
- Completed by: -
- Completed on: -

## Context
Reported pass completion is 15.6% vs real 75–85%. `computeStats` adds `passesAttempted` on both possession-kept and `passMove` events, but `passesCompleted` only on `passMove` — every possession-kept segment contributes attempts with zero completions. With ~470 passes/team per match the stats screen is unusable and the GDD 13.2 stat-realism goal is broken.

## Tasks
- [ ] Task 1: Count completions on every counted attempt — either emit `passesCompleted` on possession-kept events or derive completions from the support-driven segment model | Where: `lib/features/match/match_report.dart:283-289` | Expected: pass completion 70–88% at even strength; a +6-support-point favourite completes ≥ +4 points over the underdog; verified over ≥2,000 seeded matches.
- [ ] Task 2: Keep volume realistic while fixing completion | Where: `lib/features/match/match_report.dart:79-101`, `lib/features/match/match_engine.dart:1540-1590` (computeTotals support model) | Expected: 300–600 pass attempts/team/match (470 measured today is inside the real range); possession and momentum mechanics unchanged.
- [ ] Task 3: Fix GK invisibility — the keeper enters `involvedThisMinute` only on goals conceded, so in low-scoring matches the GK never appears in involvement lists. Add GK involvement on saves, claims from crosses and corners | Where: `lib/features/match/match_engine.dart:1055-1061` | Expected: GK has non-zero involvement in ≥90% of matches, comparable to starting CBs.
- [ ] Task 4: Lock with a test asserting the completion band 0.70–0.88 | Where: `test/features/match/` (new or extended) | Expected: green on CI, seeded and deterministic.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] Pass completion 70–88% at even strength in a ≥2,000-match seeded run
- [ ] Existing balance/calibration tests show no regression from the stats change

## Developer Notes
<Implementation notes, rejected points with reason.>

## Reviewer Verification
<Filled by reviewer before setting CLOSED.>
