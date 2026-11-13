---
id: T-0068
title: Gate the chemistry impact with a seeded balance sweep
priority: high
status: done
attempts: 1
depends_on: [T-0067]
created: 2026-11-09
completed: 2026-11-09
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
- [x] The sweep runs seeds 0..999 at four chemistry levels and asserts bands (a)–(d) from Requirement 3.
- [x] Developer Notes carry the measured win/draw/goals/shots numbers for all four levels.
- [x] The existing balance suite (`test/balance/match_engine_balance_test.dart`) still passes unchanged — no band was edited to make the new test pass.
- [x] `flutter analyze` reports zero warnings; `flutter test` full suite green.

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

- **Summary of changes:** Measurement-only gate, zero production code touched. New `test/balance/chemistry_balance_test.dart`: two statistically identical even-strength XIs (same generator, same value → overall 70, same 4-4-2, default tactics, balanced mentality), home side's nationalities varied per level — 0% all-distinct, 3% one group of 4, 5% one group of 6, 10% all 11 equal; away side always all-distinct. Seeds 0..999 per level, the suite's batch pattern (ChemBatch measures both sides' wins/draws/goals/shots). Each level's profile printed at setup. Bands: (a) total goals per match in 1.4–5.2, (b) monotonic win-rate 0%<3%<5%<10%, (c) 10% win rate < 0.62, (d) 0% reproduces 0.42–0.52.
- **Measured numbers (seeds 0..999):**
  | level | win | draw | goals H/A | shots H/A |
  |---|---|---|---|---|
  | 0% | 0.451 | 0.260 | 1.50 / 1.15 | 13.3 / 9.7 |
  | 3% | 0.506 | 0.240 | 1.63 / 1.08 | 14.1 / 9.1 |
  | 5% | 0.543 | 0.240 | 1.75 / 1.01 | 14.7 / 8.8 |
  | 10% | 0.616 | 0.227 | 1.90 / 0.85 | 16.0 / 7.8 |
  Interpretation: chemistry is a real but contained edge — +10% chemistry moves home win rate +16.5 points over even strength, monotonic at every step, and lands at 0.616, just under the 0.62 ceiling that a 4-rating-point squad gap tops out at. No follow-up tuning task needed: band (c) holds.
- **Deviation from the task text (documented for review):** Requirement 3(a) as written ("both sides' avg goals stay inside 1.4–5.2") cannot hold for ANY implementation: the engine band is per-MATCH total goals — `Batch.avgGoals` sums both sides — and the suite's own +20 gap rung measures the underdog at ~1.1 goals per side. A per-side reading would fail the existing ladder too. Implemented band (a) as total avg goals per match inside 1.4–5.2 (measured 2.65–2.75 at every level), matching the suite's semantics; the test comment explains this.
- **Files changed:** `test/balance/chemistry_balance_test.dart` (new), `tasks/…T-0068….md` (this file).
- **How I tested it:** `flutter analyze` → No issues found. `flutter test test/balance/chemistry_balance_test.dart` → 4/4 bands green with the printed profile above. `flutter test test/balance/` → **90/90** (86 existing + 4 new; no existing band edited). `flutter test test/features/match/engine_snapshot_test.dart` → 1/1, `REGEN_SNAPSHOT` unset. Full `flutter test` → **888/888 green**.
- **Concerns / assumptions:** (1) The 10% level at 0.616 sits only 0.004 under the 0.62 ceiling — the margin is thin but the test uses fixed seeds, so it is deterministic and cannot flake. (2) Chemistry is one-directional in this gate (home boosted, away 0%) — in real play both sides can field chemistry, which nets out closer to even strength; the gate measures the worst-case single-sided edge, which is the right conservative reading. (3) Environment note: the sandbox was recycled since the last session, so the repo was re-cloned and the SDK re-provisioned at Flutter 3.47.9/Dart 3.13.7 (the 3.24.5 I first fetched predates the repo's `sdk: ^3.13.7` constraint).

## Review Log

### Review 2026-11-09, attempt 1: PASS
- Ran: `flutter analyze` (No issues found), `flutter test test/balance/chemistry_balance_test.dart` (4/4), `flutter test test/balance/` (90/90), `flutter test` (893/893) — all green.
- Reproduced the measured profile exactly (deterministic seeds): 0% win 0.451/draw 0.260/goals 1.50-1.15/shots 13.3-9.7; 3% 0.506/0.240/1.63-1.08/14.1-9.1; 5% 0.543/0.240/1.75-1.01/14.7-8.8; 10% 0.616/0.227/1.90-0.85/16.0-7.8 — byte-identical to the Developer Notes table.
- Band (a) deviation independently verified as CORRECT: the suite's `avgGoals` is the per-MATCH total (`goals += s.scoreHome + s.scoreAway`, match_engine_balance_test.dart:170) and its own +20-gap rung measures the underdog at ~1.1 — the task text's per-side reading fails the existing ladder; the implemented per-match-total reading matches the suite's semantics. Bands (b) monotonic, (c) 0.616 < 0.62, (d) 0.451 inside 0.42–0.52 — all asserted and green.
- No existing band edited: `git diff 3963671^..af94ddd -- test/balance/` shows only the new `chemistry_balance_test.dart` (233 insertions), zero production files touched.
- Environment: Flutter 3.47.9 / Dart 3.13.7 — the same SDK the developer documented in Developer Notes.
