---
id: T-0008
title: AI substitutions never fire (dead code)
priority: critical
status: done
attempts: 0
depends_on: []
created: 2026-11-04
completed: 2026-11-04
# migrated from: reviews/tasks/archive/2026-11-04_match-engine_ai-substitutions.md
---

# T-0008: AI substitutions never fire (dead code)

## Goal
Archived record from the reviews/ board (status CLOSED). Kept for traceability; the work it describes was verified and accepted on the old board.

## Context
AI substitutions never happen: 0.0/match across 9,200 simulated matches. The threshold `minute >= 70 ? 30 : 40` is unreachable with `baseDrainPerMinute = 0.30` — starters sit at ~79 stamina at 70' and ~73 at full time (measured average 70.3), so `stamina < 30/40` never triggers. The AI cannot manage fatigue or chase a game; every match is 11 v 11 for 90+ minutes.

## Requirements
- [x] Task 1: Make the thresholds intersect the real stamina curve: start with `< 80` from 65' and `< 72` from 80' and tune with the harness, plus one chasing-game substitution (defender off, attacker on) for a team trailing after 70' | Where: `lib/features/match/match_engine.dart:1344-1349` (minute gate + threshold), drain context `lib/features/match/stamina.dart:14` | Expected: 2.0–4.0 AI subs/match averaged over ≥500 seeded matches with 5-man benches; never more than `config.maxSubstitutions` (5, `lib/features/match/match_engine.dart:225`); user-team substitution logic untouched.
- [x] Task 2: Verify substitution side effects: on-pitch runtime swapped, subbed-off player stops accruing stats, subbed-on player appears in lineups and the match report, no crash with an empty bench | Where: `lib/features/match/match_engine.dart:1290` (hook), `../../../lib/features/match/match_report.dart` | Expected: each sub produces a `MatchEventType.substitution` entry reflected in the report; the empty-bench early return (`:1343`) stays safe; sub starters enter with realistic stamina (~95–100).
- [x] Task 3: Lock with a test asserting average AI subs ≥ 2.0/match | Where: `../../../test/features/match` (new or extended) | Expected: green on CI, seeded and deterministic.

## Out of Scope
- Nothing beyond the requirements above was scoped out in the original task.

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated
- [x] EN/AR localized, RTL verified
- [x] No performance regression
- [x] 2.0–4.0 AI subs/match in a ≥500-match seeded run, never > 5 per team
- [x] Match report/lineups reflect substitutions; no soft-lock with an empty bench

## How to Verify
Run the board's standard gates:

```bash
flutter analyze
flutter test
```
Expected: analyzer reports no issues; the full test suite passes. Per-task checks are quoted in Requirements and Developer Notes.

---

## Developer Notes
- Gates re-tuned against the measured curve: `< 76` from 65' and `< 70` from 80' (the review's 80/72 opening values produced 4.0 subs/team — the top of the band — because `eventActivityDrain` pulls the curve down faster than the base 0.30/min). Subs are spaced ≥ 12 minutes (`lastAiSubMinute`), one per window, so windows land at ~65/77/89 like a real bench.
- Chasing-game swap runs BEFORE rotation in the window (the stronger signal must claim the bench attacker): trailing after 70' → defender off, best bench attacker on (`aiChaseSubDone` caps it at one). Measured 359 chase subs over 500 matches; 2.0–4.0 total target now reads 3.35 subs/team, max 4, entry stamina 94.6.
- GK excluded from rotation (the slot-compatibility picker had no keeper logic and swapping keepers for fatigue is not football). User-side `SubstitutionCommand` path untouched; only the AI decision function changed.
- Two legacy tests in `match_engine_test.dart` asserted the old bulk-sub behaviour (5 subs at once from minute 55): updated to the paced model while keeping their intent (cap binds; frozen stamina after coming off).
- `../../../test/features/match/ai_substitutions_test.dart` added: volume band over 500 seeds, cap, report/commentary reflection, minute accounting, empty-bench safety, determinism. Tuning harness deleted after locking the numbers into the test.

## Review Log
### 2026-11-06 — board migration
- Migrated from `reviews/` to the `tasks/` board as `T-0008` (was `reviews/tasks/archive/2026-11-04_match-engine_ai-substitutions.md`, status CLOSED).

Verified independently on FRESH seeds (10,000-10,499, reviewer harness — not the developer's seeds): 3.35 AI subs/team/match (band 2.0-4.0), max 4 per team (cap 5 holds), chasing-game swaps in 354/500 matches, every match had at least one sub. Code inspection: tired gates 65' / stamina < 76 then < 70 from 80', 12-minute spacing, GK excluded from rotation; user-team SubstitutionCommand path byte-identical since 7be7a85 (diff = 0 lines). Locked suite `ai_substitutions_test.dart` re-run green (4/4); stamina_rotation across a full AI season still green. All tasks and acceptance criteria verified — CLOSED.
