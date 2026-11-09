---
id: T-0068
title: Gate the chemistry impact with a seeded balance sweep
priority: high
status: todo
attempts: 0
depends_on: [T-0067]
created: 2026-11-09
completed:
---

# T-0068: Gate the chemistry impact with a seeded balance sweep

## Goal
The chemistry bonus's effect on match outcomes is measured, recorded in this task's Developer Notes, and locked by band assertions — proving that +10% chemistry is a meaningful but non-breaking edge before the feature ships.

## Context
- Chemistry (T-0067) multiplies a team's four engine totals by up to +10%. That is a real balance input: the engine's existing bands live in `test/balance/match_engine_balance_test.dart` (even-strength home win rate 0.42–0.52, draw rate 0.22–0.32, avg goals per team 1.4–5.2, avg shots per team 4–22; a 4-point rating gap already moves home win rate to 0.45–0.62 and a 20-point gap to 0.72–0.88).
- Calibration precedent: `test/features/match/engine_calibration_test.dart` and the balance suite run seeded sweeps over many matches; this task follows the same pattern.
- This task changes **no production code** — it measures and locks. If the measured impact falls outside the bands below, the tuning happens in a separate task, not here.

## Requirements
1. New `test/balance/chemistry_balance_test.dart`: two identical even-strength teams (same XIs, same tactics, same mentality, fixed seed base), varying ONLY the chemistry side's nationalities: 0% (all distinct), 3% (one group of 4), 5% (one group of 6), and 10% (all 11 equal). Sweep seeds 0..999 per level (reuse the balance suite's match-batch helpers).
2. Measure and print per level: the chemistry side's win rate, draw rate, and both sides' avg goals and avg shots per match.
3. Assert bands (locked after the first measured run, with margin): (a) both sides' avg goals stay inside the engine's 1.4–5.2 band at every level; (b) the chemistry side's win rate rises monotonically with the level (0% < 3% < 5% < 10%); (c) at 10% the chemistry side's win rate stays below 0.62 — a full-chemistry edge must remain weaker than a 4-rating-point squad gap (whose band already tops at 0.62); (d) the 0% level reproduces the even-strength band (0.42–0.52 win rate for the measured side).
4. Record the actual measured numbers for all four levels in Developer Notes (win rate, draw rate, avg goals, avg shots) — the review compares the assertions against them.
5. If (c) fails on measurement: stop, write the numbers into Developer Notes, and file the follow-up tuning task — do not tune engine constants or chemistry caps in this task.

## Out of Scope
- Any production-code change (engine, chemistry, UI) — this task is a measurement gate.
- Tuning chemistry values or engine constants — a separate task if the bands fail.
- UI display of chemistry (T-0069).

## Acceptance Criteria
- [ ] The sweep runs seeds 0..999 at four chemistry levels and asserts bands (a)–(d) from Requirement 3.
- [ ] Developer Notes carry the measured win/draw/goals/shots numbers for all four levels.
- [ ] The existing balance suite (`test/balance/match_engine_balance_test.dart`) still passes unchanged — no band was edited to make the new test pass.
- [ ] `flutter analyze` reports zero warnings; `flutter test` full suite green.

## How to Verify
```bash
flutter analyze
flutter test test/balance/chemistry_balance_test.dart   # green, bands asserted
flutter test test/balance/                              # existing bands unchanged, green
flutter test                                            # full suite green
```
Expected: analyze clean; the new sweep prints the four levels' measured numbers (matching Developer Notes) and all band assertions pass; the pre-existing balance bands are untouched.

---

## Developer Notes

## Review Log
