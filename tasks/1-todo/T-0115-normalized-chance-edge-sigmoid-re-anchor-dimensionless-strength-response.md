---
id: T-0115
title: Normalized chance edge + sigmoid re-anchor — the dimensionless strength response (T-0082's core swap)
priority: high
status: todo
attempts: 0
depends_on: [T-0114]
created: 2026-11-10
completed:
---

# T-0115: Normalized chance edge + sigmoid re-anchor — the dimensionless strength response

## Goal
The production swap T-0082 originally specified: the chance-creation logistic consumes a DIMENSIONLESS edge (attack-minus-defence as a share of the sides' average strength), with the sigmoid constants re-anchored on the new domain so the strength-gap ladder's rungs stay inside their existing bands with ZERO band edits. This is the only slice that changes seeded engine output — the deliberate snapshot regen happens here, once.

## Context
- T-0082's decision record (verified measurements, 2026-11-10): the normalized axis reads gap-0 ≈ 0.061, gap-4 ≈ 0.113, gap-8 ≈ 0.162, gap-12 ≈ 0.209, gap-16 ≈ 0.272, gap-20 ≈ 0.247; +10% ≈ 0.02–0.155, +25% ≈ 0.13–0.28, +50% ≈ 0.33 (away-lift) / 0.46 (home-lift); SYM is flat at 0.058–0.061 across all levels (drift ≤0.003 — the cancellation property is REAL and verified; this task ships it).
- The anchor targets (from the OLD absolute-domain calibration, preserved by construction of the re-anchor): gap-0 should sit where edge≈4.76/steepness-response reads today (~even), and each rung's win rate must stay in its band: gap-4 45–62%, gap-8 55–72%, gap-12 62–80%, gap-20 72–88% — the ladder is the contract, the constants are the free variables.
- Home advantage STAYS in the totals (the 1.07 on the home side's four totals). The T-0082 attempt measured gap-0 falling to 0.373 (band 0.42–0.52 broken) when 1.07 was divided out of the edge — twice, with different accompanying changes. The direction gap it causes (0.33 vs 0.46 at the same +50%) is T-0116's territory, handled at the win-rate layer, NOT by weakening even-strength home advantage.
- Rejected (unchanged from T-0082's spec, re-confirmed): mid/steepness-only rescale (re-breaks at +75%); hard edge clamp (breaks monotonicity +40%→+50%).

## Requirements
1. `lib/features/match/match_engine_simulation.dart` — the chance layer's edge becomes `attackEdge / ((attTotals.attack + defTotals.defence) / 2)` (comment the dimensionless semantics + the symmetric-cancellation property at the site). The `chanceP` clamp floor stays as-is (T-0114's layer is the underdog's income, not the floor).
2. `lib/features/match/match_event.dart` — re-anchor `chanceSigmoidMid` + `chanceSigmoidSteepness` onto the normalized domain. Starting point from the T-0082 attempt's evidence table (their best config): mid ≈ 0.16, steepness ≈ 4.0 — then SWEEP around it (a small probe harness, temporary, not shipped) until every ladder rung is comfortably inside its band with margin ≥0.03 from each edge at n≥800. Record the sweep table (config → per-rung win rates) in Developer Notes; ship the winner.
3. The forecast mirror: `lib/features/match/match_forecast.dart` (wherever the same absolute edge feeds a win-probability/forecast curve — grep `chanceSigmoidMid` consumers) gets the same normalization in the same change — engine and forecast must not diverge on strength semantics.
4. `test/balance/upgrade_ladder_balance_test.dart` — NO lock changes in this slice except the drift bands the regen makes stale is FORBIDDEN too: instead, this task adds NOTHING to that file. The violation lock (0.92–0.98) will read differently after the swap — it is EXPECTED to fail in this slice's intermediate state, so this task runs the upgrade ladder suite with `--plain-name` filters that EXCLUDE the lock + measured-bands tests (documenting the exclusion in Developer Notes with the measured post-swap table), and T-0116 re-locks everything. (If the post-swap readings happen to stay inside the existing locks, note that and run them green — do not edit either way.)
5. Deliberate snapshot regen: `REGEN_SNAPSHOT=1 flutter test test/features/match/engine_snapshot_test.dart`, then green with the env unset. Developer Notes record WHY the snapshot change is expected (edge semantics change → seeded output changes) + the diff summary (how many seeded matches' scorelines moved).
6. The gap ladder re-measured per rung post-swap (the probe or a plain run of the ladder group): every rung inside its band with the margin noted — this is the re-anchor's acceptance proof.
7. `flutter analyze` zero new warnings; `test/balance/` green EXCEPT the documented T-0073 lock exclusions; the full suite green otherwise.

## Out of Scope
- The two-direction ≤0.88 ceiling lock (T-0116 — this slice does not chase it).
- Turning on T-0114's income layer (stays 0 here; the snapshot regen reflects ONLY the edge swap).
- Any band edit; any economy/UI/l10n/save change.

## Acceptance Criteria
- [ ] Every ladder rung (gaps 0/4/8/12/16/20) inside its existing band, margin ≥0.03, n≥800, zero band edits.
- [ ] SYM sweep flat: normalized edge drift ≤0.01 across +0/+10/+25/+50 (measured on the axis), even-strength bands green.
- [ ] Snapshot regenerated deliberately, green with REGEN_SNAPSHOT unset; the reason + scope recorded.
- [ ] The T-0073 lock state documented (pass/fail as measured, no edit); everything else green; analyze clean.

## How to Verify
```bash
flutter analyze
flutter test test/balance/match_engine_balance_test.dart   # the ladder: zero band edits
flutter test test/features/match/                          # snapshot green (unset REGEN_SNAPSHOT)
# + the Developer-Notes table: per-rung win rates with margins
```

---

## Developer Notes

## Review Log
