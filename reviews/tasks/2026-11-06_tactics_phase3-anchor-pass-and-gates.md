# Tactics phase 3: final anchor pass on the decoupled engine, GDD sync and full-suite green gate

- Feature: tactics
- Type: Balance
- Priority: Critical
- Created: 2026-11-06
- Status: OPEN
- Completed on: -

## Context
Closing follow-up of `2026-11-05_tactics_phase3-balance-bands-and-sweep` (SPLIT 2026-11-06, rejection upheld per §6.B). After the engine-side fatigue decoupling lands (`2026-11-06_match-engine_fatigue-decoupling`), re-run the two-pool sweep, land the final anchor set, sync GDD 10.2 and make the full suite green — the suite has been red on the same four balance bands since `0218dc7`.

## Investigation & Evidence
- Investigation (carried from the balance review, both seed pools, full precision): costStackDamp 0.70→0.88 lifts allAttack 34.6→40.4 with parkShare/highPress unmoved; fcPoss is the WRONG lever (0.94 pushes parkShare to 45.4 before fastCounter reaches 50.6); fcChance is the correct fastCounter lever (1.10→1.26 lifts fastCounter 43.8→47.5, parkShare unmoved); deepPoss frozen at 0.91 (deep single sits on the band floor); lowPoss 0.91 alone drops parkShare 42.1→40.9; hpStamina must stay 1.30 (see the decoupling task for why).
- Root cause / technical justification: candidate D (cost 0.86, fcChance 1.26, hpChance 1.10, lowPoss 0.91) met 42/44 pinned cases on the sweep pool but 5 fails on the suite pool — re-score it on top of the decoupled engine, where the structural conflict no longer binds.
- Affected files/components: `lib/features/match/tactics.dart` (anchor enums), `lib/features/match/match_engine.dart` (press site), `docs/fcm_rivals_GDD_SRS.md:524-535` (GDD 10.2 anchor tables), `test/balance/match_engine_balance_test.dart`
- Evidence: sweep tooling committed and rerunnable — `tool/tactics_tuning_sweep.dart` (44 pinned cases, disjoint 700000+ seed pool; suite pool via `--dart-define=SWEEP_SEEDS_SUITE=true`; modes via SWEEP_MODE) and `tool/tactics_probe.dart` (fast sensitivity probing, PROBE_SEEDS_SUITE).
- Expected benefit / necessity: measurable target — all 44 pinned cases PASS on BOTH pools and the full suite returns to green.
- Dependencies / side effects: depends on the decoupling task; every changed constant must carry the sweep line that justifies it; the global pressBill coefficient must not move a third time (retune per-instruction values instead — it was retuned in phase 2 and phase 3 already).

## Reproduction Steps
`flutter test` on main: 4 balance-band failures (matrix, out-of-possession singles, park-the-bus possession, transitions singles). `flutter test tool/tactics_tuning_sweep.dart`: 4 fails sweep pool / 5 fails suite pool at shipped constants.

## Task
- [ ] Land the final anchor set on the decoupled engine and close the gates | Where: `lib/features/match/tactics.dart` (anchors), `docs/fcm_rivals_GDD_SRS.md:524-535`, `test/` | Expected: two-pool sweep (grid or coordinate descent; accept a candidate ONLY if green on BOTH pools — one comment per changed anchor citing its sweep line, GDD-rule-14 style); GDD 10.2 anchor rows regenerated from the code (zero drift, tables marked "harness-tuned" like phase 2); `flutter analyze` zero issues; `flutter test` full suite ALL green; final summary line pasted in Developer Notes. Band adjustments only with sweep evidence (bands stay as written by default).

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified where applicable
- [ ] No performance or application-size regression
- [ ] All pinned bands green on BOTH pools: matrix 38-60% W; singles 46-54%; gegenpress ≤58% W with stamina@75' < baseline and late goals ≥ +15%; park-the-bus 40-58% W and 30-42% possession; corners no-collapse with goals 2.4-3.1; globals goals 2.6-2.9, draws 22-30%
- [ ] GDD 10.2 anchor tables match `tactics.dart` constants exactly and are marked harness-tuned; every changed constant committed with its justifying sweep line; final suite summary line pasted in Developer Notes

## Developer Notes
<Implementation summary, files changed, exact test commands/results, and rejection reason/evidence if applicable. Implement this task only, create one task-specific commit, and push it before starting another task.>

## Reviewer Verification
<Reviewer records verification date, tested commit hash, checks performed, results, and remaining limitations. Do not add personal names.>

## Links
- Depends on: `2026-11-06_match-engine_fatigue-decoupling`
- Follows: `2026-11-05_tactics_phase3-balance-bands-and-sweep`
- Follow-up: None

## Amendments
<Reviewer-owned, append-only. Add dated entries correcting the task's target or mechanism; never rewrite the original task text.>
