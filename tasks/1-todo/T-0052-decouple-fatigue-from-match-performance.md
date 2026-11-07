---
id: T-0052
title: Decouple fatigue from match performance - stamina drives injury risk only
priority: critical
status: todo
attempts: 0
depends_on: []
created: 2026-11-07
completed:
---

# T-0052: Decouple fatigue from match performance — stamina drives injury risk only

## Goal
Owner decision (2026-11-07): **fatigue must not affect player stats or match performance in any way** — a player's attributes apply at full value whatever his stamina. Stamina keeps draining and recovering (it stays the rotation currency and the substitute-management resource), but its only gameplay effect from this task on is **injury risk**, which T-0053/T-0054 build. This task removes the two existing performance couplings and re-anchors the goal-timing model on pure time so every calibration band stays real-football-shaped.

## Context (evidence, main `3614c4a`)
- Coupling 1 — per-player attribute scaling: `_TeamRuntime.computeTotals` (`lib/features/match/match_engine_runtime.dart:152-207`) multiplies every on-pitch player's attack/support/defence/goalkeeping by `player.stamina / 100` (`:173-183`). This is GDD §11.2/§12.2 "Effective Attribute = Player Attribute × Stamina Percentage" — the owner has overridden the GDD; the GDD must change with the code (Requirement 4).
- Coupling 2 — defensive fatigue term: `_defensiveFatigue` (`lib/features/match/match_engine_simulation.dart:208-263`) shapes chance creation with `(1 + 2.0 * (1 - avgStamina/100) * t²)` — tired defences concede more (GDD §12.4). Its comment states this term is "what moves real football's goal share into the last fifteen minutes": deleting it naively will flatten goal timing. It also contains the **pressBill** term — keyed to the COMPOSED style/mentality/action/pep-talk stamina DRAIN, not to stamina LEVELS (`:250-257`, slope `TuningOverrides.current.pressBillSlope = 4.2` in `tactic_modifiers.dart:228`). The pressBill is a tactics trade-off (high press pays a late-match defensive bill), not player fatigue — it **stays**.
- The engine snapshot harness locks the full metric profile with tolerances (`test/features/match/engine_snapshot_test.dart`; regen: `REGEN_SNAPSHOT=1 flutter test test/features/match/engine_snapshot_test.dart`, then commit the JSON). Both couplings move metrics → a deliberate regen with a before/after diff is part of this task.
- Guards that must hold unmodified: the whole `engine_calibration_test.dart` band set (goals 2.4-2.9, shots 9-14, goal timing "late game opens up, early game quiet" `:364`, home advantage, power-gap and extreme-gap groups), the strength-gap ladder in `test/balance/match_engine_balance_test.dart` (`:187-245`), the press-late-goals band (`:706`) and the stamina-drain band "average stamina at 75' below baseline for gegenpress" (`:874-929`), the AI substitutions suite (`test/features/match/ai_substitutions_test.dart` — its 76/70 stamina gates stay: subs now manage injury risk), and `test/features/match/stamina_test.dart` (drain/recovery math is untouched).
- Stamina plumbing that stays as-is: `staminaDrainForMinute`/`recoverStamina`/pep talks (`stamina.dart`), post-match persistence (`match_session.dart:445`), the ad +15% recovery path, pre-match stamina bars (`pre_match_phases.dart:89`). `match_forecast.dart` already excludes stamina ("like-for-like") — after this task the forecast matches the engine BETTER; no change needed there.
- Commentary has zero stamina/tiredness strings (verified by grep) — no l10n impact.
- T-0053 builds the injury system on top of this task; do not add injury rolls here.

## Requirements
1. Remove per-player stamina scaling from `computeTotals` (`match_engine_runtime.dart`): attributes sum at full value; the modifier order in the doc comment becomes mentality → custom tactics → live actions → pep talk → home advantage. Also update the stale comment in `match_session.dart:193-195` ("the boost rides the same stamina scaling") — campus attribute fractions now simply add to card values. `MatchPlayer.stamina` stays (drain, recovery, AI sub gates, injury risk input, UI).
2. Rebuild the defensive-creation term in `match_engine_simulation.dart` **without any stamina-level input**: keep the cold-start ramp and the pressBill exactly as they behave today at baseline stamina, and replace the `(1 - avg/100)` fatigue factor with a **pure time-based escalation** extracted as a pure, unit-testable function (the `staminaDrainForMinute` pattern: top-level function + `InjuryTimeConfig`-style entry in `TuningOverrides`, e.g. `lateGameOpenFactor(minute, fullTimeMinute, config)`), so the "late game opens up" calibration band is held by a knob, not by player exhaustion. Doc comments must describe the new form truthfully — no "tired defences" language may remain in engine docs (rename the method, e.g. `_defensiveOpenness`).
3. All band guards listed in Context pass **unmodified**. Iterate only inside `TuningOverrides` (time-escalation slope/shape, `pressBillSlope`) to hold them; if a band genuinely cannot hold within the knobs, STOP and record the conflict in Developer Notes — do not edit a calibration/balance band in this task.
4. GDD revision rides with the code: §11.2 rewritten (attributes unaffected by stamina; stamina governs injury risk and recovery, spec lands with T-0053), §12.2 modifier order updated (stamina scaling step removed), §12.4 and the §10/§16 "late-match cost / tired defence" lines re-worded to time-based escalation and the press trade-off. README "Stamina" module line updated to match.
5. Engine snapshot: print the before/after metric diff, regen deliberately with `REGEN_SNAPSHOT=1`, commit the updated `engine_snapshot.json`, and record the top movements in Developer Notes.
6. New tests: (a) `computeTotals` stamina-invariance — two identical squads differing only in starting stamina (100 vs 40) return identical attack/support/defence/goalkeeping at minute 0; (b) the new time-escalation function unit-tested: identity below minute 60, strictly increasing after, seed-independent (pure), and bounded (documented max); (c) a seeded full-match determinism run with AI substitutions disabled (empty bench) where different starting stamina produces **byte-identical event streams**.

## Out of Scope
- The injury system itself (risk model, events, persistence, UI — T-0053/T-0054/T-0055/T-0056).
- Any change to drain/recovery rates, pep talk bonuses, AI substitution gates, or pack/economy code.
- Any calibration-band edit (see Requirement 3).

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] New stamina-invariance + time-escalation tests green; full `flutter test` suite passes with all calibration/balance bands unmodified
- [ ] EN/AR localization complete and RTL verified where applicable (no new strings expected)
- [ ] No performance or application-size regression
- [ ] No engine doc/comment may claim stamina affects attributes or concession any more
- [ ] Engine snapshot regenerated deliberately and committed; diff recorded
- [ ] `flutter test tool/simulation_report_test.dart` determinism PASS

## How to Verify
```bash
grep -rn "stamina / 100\|stamina/100" lib/features/match/        # expect: no hits
grep -rn -i "tired defences" lib/                                 # expect: no hits
flutter analyze
flutter test test/features/match/ test/balance/
flutter test tool/simulation_report_test.dart
flutter test
```
Expected: no stamina-scaling hits; analyzer clean; match + balance suites green unmodified; determinism PASS; the snapshot diff summary appears in Developer Notes.

## Side-effect risk (high, must be reviewed with the sim)
The stamina-level term was one of two mechanisms holding the late-goal share up; the replacement is pure time so the band should hold, but the interaction with the pressBill is measured, not assumed. Season quick-sim and the AI freshness asymmetry now influence results only through tactics and subs, not stamina — the EconomySimulator multi-season runs must stay green unmodified. Squads no longer "tire" in-table: the user-visible difference (a 70-stamina starter performing like a fresh one) is the owner's explicit decision.

## Developer Notes

## Review Log
